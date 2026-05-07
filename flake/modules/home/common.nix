{ pkgs, pkgs-unstable, agents, ... }: {
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
      fish_vi_key_bindings

      if not pgrep ssh-agent > /dev/null
          eval (ssh-agent -c)
          ssh-add
      end
      if not set -q SSH_AUTH_SOCK
          eval (ssh-agent -c)
      end

    '';
  };

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
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor 'mocha'
          set -g @catppuccin_window_status_style "rounded"
          set -g @catppuccin_window_text " #{b:pane_current_path}"
          set -g @catppuccin_window_current_text " #{b:pane_current_path}"
          set -g @catppuccin_window_number "#I"
          set -g @catppuccin_window_current_number "#I"
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-save-interval '5'
          set -g @continuum-restore 'on'
        '';
      }
    ];
    extraConfig = ''
      set-option -sa terminal-overrides ",xterm*:Tc"
      set-option -g update-environment "SSH_AUTH_SOCK"

      set -g automatic-rename on
      set -g automatic-rename-format "#{b:pane_current_path}"

      # Status bar — catppuccin v2 requires explicit module declarations
      set -g status-left-length 100
      set -g status-right-length 100
      set -g status-left ""
      set -g status-right "#{E:@catppuccin_status_directory}"
      set -ag status-right "#{E:@catppuccin_status_session}"

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
        dimensions = { columns = 160; lines = 80; };
        padding = { x = 4; y = 4; };
      };
    };
  };

  stylix.targets = {
    neovim.enable = false;
    tmux.enable = false;
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

  home.packages = with pkgs; [
    fd
    ripgrep
    gh
    lazygit
    lazydocker
    easyeffects
    # AI coding agents
    agents.opencode
    agents.pi
    pkgs-unstable.t3code
    # formatters for neovim/conform
    stylua
    prettierd
    csharpier
  ];
}
