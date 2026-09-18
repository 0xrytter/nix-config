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
  # shells(/etc/profile.d/nix.sh). When fish is the shell (WSL login or a tmux
  # default-shell pane) that never runs, so nix-installed tools like zoxide/nvim
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
  ];

  # Point xdg-open's $BROWSER at wslview so login flows open on Windows.
  home.sessionVariables.BROWSER = "wslview";
}