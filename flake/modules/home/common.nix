{ config, lib, pkgs, agents, ... }: {
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

    # One hook directory for every repository on the box, present and future,
    # rather than a file installed into each .git/hooks.
    #
    # Do not also set settings.core.hooksPath: home-manager merges both into
    # iniContent at equal priority, so declaring both is an evaluation error
    # rather than a silent winner.
    #
    # Setting this also stops the Claude Code runner from installing its own
    # hook to add a Co-authored-by trailer - it skips the install when
    # core.hooksPath is already set, so it defers to this instead of fighting
    # it. See config/git-hooks/commit-msg for what the hook does and why it
    # matches on trailer keys rather than harness names.
    hooks.commit-msg = ../../config/git-hooks/commit-msg;
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
          # Identities come from the vault via `unlock`, not from ~/.ssh. This
          # only picks up a default ~/.ssh identity if one still exists, and is
          # silent when none does.
          ssh-add 2>/dev/null
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
      apr = "systemctl --user restart wireplumber pipewire pipewire-pulse";
    };
    functions.fsr = ''
      # Full fish session refresh: remove stale abbreviations and reload config + functions.
      for name in (abbr --list)
        abbr --erase $name 2>/dev/null
      end

      set -l function_files ~/.config/fish/functions/*.fish
      for file in $function_files
        set -l name (basename $file .fish)
        if test "$name" != fsr
          functions --erase $name 2>/dev/null
        end
      end

      source ~/.config/fish/config.fish

      for file in $function_files
        set -l name (basename $file .fish)
        if test "$name" != fsr
          source $file
        end
      end

      echo "Reloaded fish config, abbreviations, and functions"
    '';
    functions.nr = ''
      set -l root (fd -H -t f '^\.nix-config$' ~ --max-results 1 2>/dev/null | xargs -I{} dirname {})
      bash -c "cd $root && bash rebuild.sh"
    '';
    functions.kqb = ''
      pkill qbittorrent 2>/dev/null
      rm -f ~/.config/qBittorrent/lockfile
      rm -f ~/.config/qBittorrent/rss/storage.lock
      rm -f ~/.local/share/qBittorrent/rss/articles/storage.lock
      setsid -f qbittorrent >/tmp/qbittorrent-launch.log 2>&1
      sleep 1

      if pgrep -x qbittorrent >/dev/null
        echo "qBittorrent restarted"
      else
        echo "qBittorrent did not stay running. See /tmp/qbittorrent-launch.log"
        tail -20 /tmp/qbittorrent-launch.log 2>/dev/null
        return 1
      end
    '';
    functions.nu = ''
      set -l root (fd -H -t f '^\.nix-config$' ~ --max-results 1 2>/dev/null | xargs -I{} dirname {})
      bash -c "cd $root && bash update.sh"
    '';
  };

  # Multiplexer. Restored from git (dropped in fe169a4 for zellij); zellij stays
  # installed but is no longer the WezTerm default_prog. Catppuccin replaces the
  # old tmux-gruvbox plugin, so no extra flake input is needed.
  #
  # Clipboard: opencode writes its own OSC 52 to set the clipboard and also wraps
  # a copy in a tmux passthrough DCS. `set-clipboard on` accepts the raw sequence
  # from inside, `allow-passthrough on` lets the wrapped copy reach WezTerm, and
  # the `Ms` override gives tmux the capability to emit OSC 52 itself. WezTerm
  # owns the actual Windows clipboard.
  programs.tmux = {
    enable = true;
    prefix = "C-Space";
    baseIndex = 1;
    mouse = true;
    keyMode = "vi";
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [
      sensible
      vim-tmux-navigator
      yank
      resurrect
      # Discoverability: prefix + Space opens a which-key style popup menu of the
      # common actions. XDG mode is needed because the nix store is read-only and
      # the plugin otherwise writes its config/init next to itself.
      {
        plugin = tmux-which-key;
        extraConfig = ''
          set -g @tmux-which-key-xdg-enable 1
        '';
      }
      # catppuccin: the README "Recommended Default Configuration" only sets the
      # flavour and rounded windows. Window text/number come from plugin defaults.
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor "mocha"
          set -g @catppuccin_window_status_style "rounded"
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
      set -g default-shell "${pkgs.fish}/bin/fish"
      set-option -sa terminal-overrides ",xterm*:Tc"
      set-option -g update-environment "SSH_AUTH_SOCK"
      set -g history-limit 50000

      # No auto-restore: resurrect's restore.sh ran on every start and brought
      # back the last saved session, which predates this config (Sep 18, the
      # pre-zellij layout), so each launch opened a stale 10-window session
      # instead of a clean one. Saving stays on (continuum, 5 min); restoring is
      # manual (prefix + Ctrl-r), and the old saves are kept on disk.

      # Status bar: catppuccin v2 declares modules as @catppuccin_status_<name>,
      # and they only exist once the plugin has loaded. home-manager emits plugin
      # run-shells before this extraConfig, so this is the correct side of that
      # ordering. README "Recommended Default Configuration" module list, minus
      # cpu and battery: both come up empty on WSL (no battery, and the cpu
      # sampler reads nothing here), so they only added blank segments.
      set -g status-right-length 100
      set -g status-left-length 100
      set -g status-left ""
      set -g status-right "#{E:@catppuccin_status_application}"
      set -ag status-right "#{E:@catppuccin_status_session}"
      set -ag status-right "#{E:@catppuccin_status_uptime}"

      # Two Catppuccin choices don't compose with its own bar, so both are
      # corrected here (neither is caused by the additions in this file):
      #   * message-style uses bg=default: its CTP_MESSAGE_BACKGROUND expands
      #     @catppuccin_status_background, which is the literal string "default",
      #     so prompts are painted the terminal's base colour on the mantle bar.
      #     Its fg is also @thm_teal, a colour that appears nowhere else, so the
      #     kill/confirm prompt reads as foreign text. Pin to the bar and use the
      #     bar's own text colour.
      #   * window-status-bell-style / -activity-style set a whole-pill
      #     background, but window-status-format has a #[none] reset immediately
      #     before the window number, so that number inherits the bell style and
      #     renders as a yellow-on-crust slab inside a pill whose rounded notches
      #     are pinned to the bar colour (the "cutout"). Keep the background and
      #     recolour only the number.
      #   * and with no width/fill the prompt is drawn as a partial band over the
      #     bar, so it slices through whatever pill sits under it. fill= makes it
      #     cover the full width, so the prompt replaces the bar cleanly instead
      #     of cutting a pill in half.
      set -gF message-style "fg=#{@thm_fg},bg=#{@thm_mantle},fill=#{@thm_mantle},align=centre"
      set -gF message-command-style "fg=#{@thm_fg},bg=#{@thm_mantle},fill=#{@thm_mantle},align=centre"
      set -gF window-status-bell-style "bg=default,fg=#{@thm_yellow}"
      set -gF window-status-activity-style "bg=default,fg=#{@thm_lavender}"

      set -g set-clipboard on
      set -g allow-passthrough on
      set -as terminal-overrides ',*:Ms=\E]52;%p1%s;%p2%s\007'

      # Ban cursor-colour overrides at the source. tmux relays an application's
      # OSC 12 to the terminal through the Cs/Cr capabilities, and has no
      # per-pane model for the cursor (it is device state, not a cell colour), so
      # an app that sets it, or fails to reset it, leaves the terminal's cursor
      # coloured until something else changes it. Cancelling the capabilities
      # stops tmux emitting those escapes at all. Measured with a pane writing
      # OSC 12: without this, tmux relays it; with it, the client sees zero
      # cursor-colour escapes. Trade: apps (and tmux's own cursor-colour option)
      # can no longer theme the cursor.
      set -as terminal-overrides ',*:Cs@:Cr@'

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

      # fzf ships its own defaults, which colour the pointer/marker/highlight
      # with ANSI red (that red pointer in the sesh popup is fzf's, not ours).
      # Give fzf Catppuccin Mocha's palette instead. Set on the tmux server's
      # global environment because popups inherit that, not the client's shell.
      set-environment -g FZF_DEFAULT_OPTS "--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8,fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC,marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8,selected-bg:#45475A,border:#6C7086,label:#CDD6F4"
      bind-key b run-shell 'if [ "$(tmux display-message -p "#W")" = "scratch" ]; then tmux last-window; else tmux capture-pane -peS -32768 > /tmp/tmux-scrollback-#{session_id}; tmux kill-window -t scratch 2>/dev/null; tmux new-window -n scratch "nvim -n + /tmp/tmux-scrollback-#{session_id}"; fi'

      set-hook -g after-select-pane 'refresh-client -S'
    '';
  };

  programs.starship.enable = true;


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
      { id = "hlepfoohegkhhmjieoechaddaejaokhf"; } # Refined GitHub
      { id = "pobhoodpcipjmedfenaigbeloiidbflp"; } # Minimal Theme for Twitter / X
    ];
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  sops.age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";

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

  # tmux-which-key menu; see the plugin entry in programs.tmux above. XDG mode
  # makes the plugin read this and write its generated init.tmux under
  # ~/.local/share, rather than into its own (read-only) store path.
  xdg.configFile."tmux/plugins/tmux-which-key/config.yaml".source =
    ../../config/tmux/which-key.yaml;

  # tmux-which-key autobuilds its menu from config.yaml into init.tmux, but it
  # first copies its example init into that path, and the example comes from the
  # read-only nix store, so the copied file is unwritable and build.py dies with
  # EACCES (which, under `set -e`, also skips the `tmux source-file` that would
  # apply the menu). Pre-create it writable so the copy is skipped.
  home.activation.ensureWhichKeyInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _d="${config.home.homeDirectory}/.local/share/tmux/plugins/tmux-which-key"
    $DRY_RUN_CMD mkdir -p "$_d"
    if [ ! -e "$_d/init.tmux" ]; then
      $DRY_RUN_CMD touch "$_d/init.tmux"
    fi
    $DRY_RUN_CMD chmod u+w "$_d/init.tmux"
  '';

  home.file.".ideavimrc".source = ../../config/ideavimrc;

  home.file.".claude/hooks" = {
    source = ../../config/claude-hooks;
    recursive = true;
  };
  home.file.".claude/settings.json".source = ../../config/claude-settings.json;
  home.file.".claude/pricing.json".source = ../../config/claude-pricing.json;
  home.file.".claude/caps.json".source = ../../config/caps.json;
  # The one rules file, loaded into every Claude Code session in every project on
  # every host (user scope). Same source as the crush/opencode context paths, so
  # there stays exactly one copy to edit.
  home.file.".claude/CLAUDE.md".source = ../../config/agent-rules.md;

  home.packages = with pkgs; [
    fd
    ripgrep
    sesh
    age
    sops
    ssh-to-age
    wl-clipboard
    # AI coding agents
    t3code
    # formatters for neovim/conform
    stylua
    prettierd
    csharpier
  ];
}
