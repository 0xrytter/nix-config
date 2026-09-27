{ config, lib, pkgs, ... }:
let
  # zellij 0.44.2 is what the pinned nixpkgs (2026-05-06) ships, and its
  # renderer is measurably why nvim scrolling drags under it — a bare WezTerm
  # pane with the same nvim is smooth. Pull just this package from a current
  # rev, the same single-package pattern opencode.nix uses for graphify: a
  # whole-lock bump has broken things before (fish completions) and is a much
  # bigger change than this needs. Delete this block and go back to `zellij`
  # if a newer renderer turns out not to help.
  zellijNixpkgs = import (builtins.fetchTree {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "a32edd7654519351e48e80372a928df336394670";
  }) { system = pkgs.system; };

  # The /model picker lineup, declared rather than discovered. Gateway discovery
  # keeps only ids containing "claude" or "anthropic", and Hyper's open-weight
  # ids contain neither, so discovery drops every model Hyper serves. The shared
  # ~/.claude/settings.json is also allowlisted to three Anthropic ids, which
  # would block these from being selected at all.
  #
  # Passed with --settings (which merges over the shared file for this session)
  # so the lineup stays on this machine: the NixOS hosts share
  # claude-settings.json and still talk to Anthropic.
  hyperClaudeSettings = pkgs.writeText "claude-hyper-settings.json" (builtins.toJSON {
    availableModels = [ "deepseek-v4.1-flash" "kimi-k3" "glm-5.3-flash" ];
    modelPicker = {
      replaceBuiltInOptions = true;
      options = [
        {
          model = "deepseek-v4.1-flash";
          label = "DeepSeek V4.1 Flash";
          description = "Fast and cheap - the default";
        }
        {
          model = "kimi-k3";
          label = "Kimi K3";
          description = "Stronger reasoning for harder work";
        }
        {
          model = "glm-5.3-flash";
          label = "GLM 5.3 Flash";
          description = "Fast and cheap";
        }
      ];
    };
  });
in {
  imports = [
    ./common.nix
    ./neovim.nix
  ];

  # ── WSL2 / Ubuntu adjustments ────────────────────────────────────────────────
  # No X11/Wayland here: drop the GUI bits that common.nix pulls in.
  programs.alacritty.enable = lib.mkForce false;
  programs.chromium.enable = lib.mkForce false;
  xdg.mimeApps.enable = lib.mkForce false;
  gtk.enable = lib.mkForce false;

  # Standalone home-manager on Ubuntu has no /run/current-system; resolve `gh`
  # from the user profile PATH instead.
  programs.git.settings."credential \"https://github.com\"".helper =
    lib.mkForce [ "" "!/usr/bin/env gh auth git-credential" ];
  programs.git.settings."credential \"https://gist.github.com\"".helper =
    lib.mkForce [ "" "!/usr/bin/env gh auth git-credential" ];

  # `rebuild.sh` is NixOS-only; point the fish helpers at the WSL2 switch script.
  programs.fish.functions.nr = lib.mkForce ''
    set -l root (fd -H -t f '^\.nix-config$' ~ --max-results 1 2>/dev/null | xargs -I{} dirname {})
    bash -c "cd $root && bash wsl2/switch.sh"
  '';
  programs.fish.functions.nu = lib.mkForce ''
    set -l root (fd -H -t f '^\.nix-config$' ~ --max-results 1 2>/dev/null | xargs -I{} dirname {})
    bash -c "cd $root && nix flake update --flake ./flake && bash wsl2/switch.sh"
  '';

  # Nerd fonts + fontconfig so Windows Terminal / VS Code can pick them up.
  fonts.fontconfig.enable = true;

  # Ubuntu's nix install only puts the nix bin dirs on PATH for bash login
  # shells(/etc/profile.d/nix.sh). When fish is the shell (a WSL login or a herdr
  # pane) that never runs, so nix-installed tools like zoxide/nvim
  # become "not found". Ensure the nix user + default profile bins are always on
  # PATH inside fish. conf.d runs before config.fish, i.e. before hm-session-vars.
  xdg.configFile."fish/conf.d/10-nix-path.fish".text = ''
    set -l nix_link "$HOME/.nix-profile"
    if test -e "$nix_link/bin"
      if type -q fish_add_path
        fish_add_path --prepend --move "$nix_link/bin" "/nix/var/nix/profiles/default/bin"
      else
        set -gx PATH "$nix_link/bin" "/nix/var/nix/profiles/default/bin" $PATH
      end
    end
  '';

  # Terminal multiplexer. Catppuccin ships inside Zellij (theme "catppuccin-mocha"
  # selects it) and session persistence is built in rather than plugin-based:
  # serialization is Zellij's resurrect/continuum equivalent, so neither TPM nor
  # those plugins carry over.
  # WezTerm (Windows side) is themed by hand in wsl2/wezterm.lua — stylix cannot
  # reach it, and stylix is only enabled for the NixOS hosts in any case.
  xdg.configFile."zellij/config.kdl".text = ''
    theme "catppuccin-mocha"

    // Session persistence — the cheap half only. Viewport serialization is off
    // by default upstream, and enabling it copies up to `scrollback_lines_to_serialize`
    // lines per pane on every serialization tick, which shows up as interactive
    // stutter (nvim scrolling especially). Layout + commands are what recovery
    // actually needs. (Requires restart to change.)
    session_serialization true
  '';

  home.packages = with pkgs; [
    zellijNixpkgs.zellij
    git
    gh
    lazygit
    lazydocker
    docker-compose
    bubblewrap
    nerd-fonts.jetbrains-mono
    # Browser handoff for headless WSL: `xdg-open` (via xdg-utils) honours
# $BROWSER and our tiny `wslview` opens the URL with the Windows browser, so
# CLI login flows (flyctl auth login, gh, ...) complete normally.
    xdg-utils
    (pkgs.writeShellScriptBin "wslview" ''
      url="''${1:-}"
      if [ -n "$url" ]; then
        cmd.exe /c start ''' "$url" >/dev/null 2>&1 &
      fi
    '')
    # The fleet (iacthing) is tailnet-only: its Grafana, Loki and the agent box's
    # API answer on the tunnel and nowhere else. The client comes from here so a
    # new machine needs no package manager; the daemon is a system service because
    # it creates a tun interface, and wsl2/tailscale-setup.sh links the unit that
    # starts it. See step 9 of wsl2/README.md.
    tailscale
    # herdr owns the terminals the coding agents live in: detach without
    # stopping work, and one window over the local machine plus the agent box.
    # It is in nixpkgs, so nothing is curl-installed; the box carries the same
    # package so a remote session runs the same build.
    herdr
    # Same claude-code the NixOS hosts carry. It is unfree, which is why the
    # flake's allowUnfreePredicate names it alongside crush.
    claude-code
  ];

  # Herdr's config is a plain XDG file, so home-manager owns it rather than
  # herdr's settings editor. The store symlink is read-only on purpose: change
  # settings in flake/config/herdr.toml and switch. Machine profiles
  # (`herdr machine add`) are runtime state, not configuration, so they stay out
  # of Nix.
  xdg.configFile."herdr/config.toml" = {
    source = ../../config/herdr.toml;
    # The real file already there is herdr's own `onboarding = false`, and this
    # declaration says the same thing, so replacing it outright loses nothing
    # and leaves the path Nix-owned from here on.
    force = true;
  };

  # Point xdg-open's $BROWSER at wslview so login flows open on Windows.
  home.sessionVariables.BROWSER = "wslview";

  # A client for the fleet's agent box, which runs crush as a server on the
  # tailnet. Three things here are not preference:
  #
  #   CRUSH_CLIENT_SERVER=1 is the whole difference between driving that server
  #   and running the agent in this process. Without it the `-H` flag is parsed
  #   and ignored, which looks exactly like a local agent that can see your files.
  #   crush95, not crush, because the deployed server is the patched 0.95.0 and
  #   the wire protocol is not stable between releases.
  #   no OPENCODE_API_KEY: the credential is the box's, and the box does the work.
  #   Everything the agent touches is over there - which is also why the path it
  #   works in has to exist on both ends. iacthing's roles/agent.nix mirrors
  #   /home/rytter/src on the box for exactly that: run this from ~/src/<repo> and
  #   the workspace is that same path on the box.
  #
  # The same colour scrub as `crush`, for the same tmux/cursed_renderer reason.
  programs.fish.functions.agent = ''
    set -lx CRUSH_CLIENT_SERVER 1
    command crush95 -H tcp://agent01:7799 $argv
    printf '\e]112\a\e]111\a'
  '';

  # Claude Code, routed through Charm Hyper. Hyper speaks the Anthropic Messages
  # API and this machine's own Hyper key is the credential; the three models in
  # rotation come from hyperClaudeSettings above, which replaces the built-in
  # picker lineup. `command claude` skips this function, so a first-party
  # Anthropic session is still one word away.
  #
  # The key is a real secret, so it is not declared here: seedHyperKey below
  # creates the slot empty, and the launcher lifts the file into the environment
  # at start, the same shape as the opencode-go launchers in
  # modules/home/opencode.nix.
  programs.fish.functions.claude = ''
    set -l key ${config.xdg.configHome}/opencode/secrets/hyper-local.key
    if not test -s $key
      echo "no Hyper key at $key (see wsl2/README.md, 'Agent credentials')" >&2
      return 1
    end
    set -lx ANTHROPIC_BASE_URL https://hyper.charm.land
    set -lx ANTHROPIC_API_KEY (cat $key)
    set -lx ANTHROPIC_MODEL deepseek-v4.1-flash
    set -lx ANTHROPIC_DEFAULT_SONNET_MODEL kimi-k3
    set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL glm-5.3-flash
    command claude --settings ${hyperClaudeSettings} $argv
  '';

  # The Hyper key slot: an empty mode-600 file, created once so the operator only
  # has to paste a key in rather than also get the file's mode right. The
  # launcher refuses to start while it is empty (test -s), so a half-finished
  # setup fails loudly instead of sending an empty key.
  home.activation.seedHyperKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${config.xdg.configHome}/opencode/secrets
    $DRY_RUN_CMD chmod 700 ${config.xdg.configHome}/opencode/secrets
    if [ ! -e ${config.xdg.configHome}/opencode/secrets/hyper-local.key ]; then
      $DRY_RUN_CMD install -m 600 /dev/null ${config.xdg.configHome}/opencode/secrets/hyper-local.key
    fi
  '';
}
