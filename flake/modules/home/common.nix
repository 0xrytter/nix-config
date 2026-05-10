{ pkgs, agents, tmux-gruvbox, ... }: {
  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = false;
      "credential \"https://github.com\"".helper = [
        ""
        "!/run/current-system/sw/bin/gh auth git-credential"
      ];
      "credential \"https://gist.github.com\"".helper = [
        ""
        "!/run/current-system/sw/bin/gh auth git-credential"
      ];
    };
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting ""
      set -gx EDITOR nvim
      set -gx VISUAL nvim
      fish_vi_key_bindings

      if not set -q SSH_AUTH_SOCK
          eval (ssh-agent -c)
          ssh-add
      end
    '';
    functions.pi = ''
      if not docker image inspect pi-sandbox >/dev/null 2>&1
        echo "Building pi-sandbox image..."
        set -l ctx (mktemp -d)
        cp (readlink -f ~/.config/pi-sandbox/Dockerfile) $ctx/Dockerfile
        docker build -t pi-sandbox $ctx
        rm -rf $ctx
      end
      docker run --rm -it \
        --privileged \
        -v (pwd):/work \
        -v $HOME/.pi/agent:/root/.pi/agent:ro \
        -w /work \
        pi-sandbox $argv
    '';
    shellAbbrs = {
      g = "git";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gs = "git status";
      lg = "lazygit";
      ld = "lazydocker";
      nd = "nix develop";
      ai = "claude";
      tmr = "tmux source ~/.config/tmux/tmux.conf";
      apr = "systemctl --user restart wireplumber pipewire pipewire-pulse";
      fsr = "source ~/.config/fish/config.fish";
      nr  = "bash -c 'cd ~/Projects/nix-config && bash rebuild.sh'";
      nu  = "bash -c 'cd ~/Projects/nix-config && bash update.sh'";
    };
  };

  programs.starship.enable = true;

  programs.tmux = {
    enable = true;
    prefix = "C-Space";
    baseIndex = 1;
    mouse = true;
    keyMode = "vi";
    terminal = "xterm-256color";
    plugins = with pkgs.tmuxPlugins; [
      sensible
      vim-tmux-navigator
      yank
      resurrect
      {
        plugin = pkgs.tmuxPlugins.mkTmuxPlugin {
          pluginName = "tmux-gruvbox";
          rtpFilePath = "gruvbox-tpm.tmux";
          version = "master";
          src = tmux-gruvbox;
        };
        extraConfig = ''
          set -g @tmux-gruvbox "dark"
          set -g @tmux-gruvbox-right-status-z "#h "
          set -g @tmux-gruvbox-right-status-x "#(date '+%H:%M') "
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-save-interval '5'
        '';
      }
    ];
    extraConfig = ''
      set-option -sa terminal-overrides ",xterm*:Tc"
      set-option -g update-environment "SSH_AUTH_SOCK"
      set -g history-limit 50000
      run-shell "${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/restore.sh"

      set -g automatic-rename on
      set -g automatic-rename-format "#{b:pane_current_path}"

      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      set -g pane-base-index 1
      set-window-option -g pane-base-index 1
      set-option -g renumber-windows on

      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      bind -n S-Left previous-window
      bind -n S-Right next-window
      bind -n M-H previous-window
      bind -n M-L next-window

      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      bind-key s display-popup -E -w 80% -h 80% 'sesh connect $(sesh list | fzf --preview "sesh preview {}" --bind "ctrl-d:execute(tmux kill-session -t {})+reload(sesh list)")'
      bind-key b run-shell 'if [ "$(tmux display-message -p "#W")" = "scratch" ]; then tmux last-window; else tmux capture-pane -peS -32768 > /tmp/tmux-scrollback-#{session_id}; tmux kill-window -t scratch 2>/dev/null; tmux new-window -n scratch "nvim -n + /tmp/tmux-scrollback-#{session_id}"; fi'

      set-hook -g after-select-pane 'refresh-client -S'
    '';
  };

  programs.alacritty = {
    enable = true;
    settings = {
      bell = { animation = "EaseOutExpo"; duration = 0; };
      cursor = {
        blink_interval = 500;
        blink_timeout = 5;
        unfocused_hollow = false;
        style = { blinking = "Off"; shape = "Block"; };
      };
      env.TERM = "xterm-256color";
      general.live_config_reload = true;
      mouse = {
        hide_when_typing = true;
        bindings = [{ action = "PasteSelection"; mouse = "Middle"; }];
      };
      selection.semantic_escape_chars = ",│`|:\"' ()[]{}<>";
      terminal.shell.program = "/run/current-system/sw/bin/tmux";
      window = {
        decorations = "full";
        dynamic_title = true;
        startup_mode = "Maximized";
        padding = { x = 4; y = 4; };
      };
    };
  };

  stylix.targets = {
    neovim.enable = false;
    qt.enable = false;
    tmux.enable = false;
  };

  gtk.gtk4.theme = null;

  gtk.iconTheme = {
    name = "oomox-gruvbox-dark";
    package = pkgs.gruvbox-dark-icons-gtk;
  };

  programs.chromium = {
    enable = true;
    extensions = [
      { id = "ddkjiahejlhfcafbddmgiahcphecmpfh"; } # uBlock Origin Lite
      { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # Vimium
      { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # Dark Reader
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
      { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; } # SponsorBlock
      { id = "gebbhagfogifgggkldgodflihgfeippi"; } # Return YouTube Dislike
      { id = "pkehgijcmpdhfbdbbnkijodmdjhbjlgp"; } # Privacy Badger
    ];
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = {
    "text/html"                = "chromium-browser.desktop";
    "x-scheme-handler/http"    = "chromium-browser.desktop";
    "x-scheme-handler/https"   = "chromium-browser.desktop";
    "x-scheme-handler/about"   = "chromium-browser.desktop";
    "x-scheme-handler/unknown" = "chromium-browser.desktop";
    "x-scheme-handler/msteams" = "teams-for-linux.desktop";
    "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
  };

  programs.fzf.enable = true;
  programs.zoxide.enable = true;

  home.file.".ideavimrc".source = ../../config/ideavimrc;

  home.file.".claude/hooks" = {
    source = ../../config/claude-hooks;
    recursive = true;
  };
  home.file.".claude/settings.json".source = ../../config/claude-settings.json;
  home.file.".claude/pricing.json".source = ../../config/claude-pricing.json;
  home.file.".claude/caps.json".source = ../../config/caps.json;
  home.file.".config/tmux/ai-status.py".source = ../../config/tmux/ai-status.py;
  home.file.".config/tmux/ai-dispatch.sh" = {
    source = ../../config/tmux/ai-dispatch.sh;
    executable = true;
  };

  home.file.".config/opencode/config.json".source = ../../config/opencode/config.json;

  home.file.".config/pi-sandbox/Dockerfile".source = ../../config/pi-sandbox/Dockerfile;

  home.file.".pi/agent/themes/gruvbox.json".source = ../../config/pi-gruvbox.json;
  home.file.".pi/agent/extensions" = {
    source = ../../config/pi-extensions;
    recursive = true;
  };

  home.packages = with pkgs; [
    fd
    ripgrep
    sesh
    # AI coding agents
    agents.opencode
    agents.pi
    t3code
    # formatters for neovim/conform
    stylua
    prettierd
    csharpier
  ];
}
