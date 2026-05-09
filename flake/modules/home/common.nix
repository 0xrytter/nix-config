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
      fish_vi_key_bindings

      if not set -q SSH_AUTH_SOCK
          eval (ssh-agent -c)
          ssh-add
      end
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
      fsr = "source ~/.config/fish/config.fish";
      micon = "pactl set-card-profile bluez_card.00_22_BB_B9_F9_C0 headset-head-unit";
      micoff = "pactl set-card-profile bluez_card.00_22_BB_B9_F9_C0 a2dp-sink";
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
          set -g @tmux-gruvbox-right-status-y "#(upower -i /org/freedesktop/UPower/devices/headset_dev_00_22_BB_B9_F9_C0 2>/dev/null | awk '/percentage/{print $2}') "
          set -g @tmux-gruvbox-right-status-x "#(wpctl status 2>/dev/null | grep -q 'bluez_input.00_22' && echo 'MIC' || echo) "
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

  programs.fzf.enable = true;
  programs.zoxide.enable = true;

  services.easyeffects.enable = true;

  home.file.".ideavimrc".source = ../../config/ideavimrc;

  home.file.".claude/hooks" = {
    source = ../../config/claude-hooks;
    recursive = true;
  };
  home.file.".claude/settings.json".source = ../../config/claude-settings.json;
  home.file.".claude/pricing.json".source = ../../config/claude-pricing.json;

  home.file.".pi/agent/themes/gruvbox.json".source = ../../config/pi-gruvbox.json;

  home.packages = with pkgs; [
    fd
    ripgrep
    sesh
    easyeffects
    pulseaudio
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
