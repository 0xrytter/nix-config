{ config, pkgs, agents, ... }: {
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

  home.file.".ideavimrc".source = ../../config/ideavimrc;

  home.file.".claude/hooks" = {
    source = ../../config/claude-hooks;
    recursive = true;
  };
  home.file.".claude/settings.json".source = ../../config/claude-settings.json;
  home.file.".claude/pricing.json".source = ../../config/claude-pricing.json;
  home.file.".claude/caps.json".source = ../../config/caps.json;

  home.packages = with pkgs; [
    fd
    ripgrep
    sesh
    age
    sops
    ssh-to-age
    wl-clipboard
    # AI coding agents
    agents.opencode
    t3code
    # formatters for neovim/conform
    stylua
    prettierd
    csharpier
  ];
}
