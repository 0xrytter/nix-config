{ config, lib, pkgs, ... }:
{
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

  home.packages = with pkgs; [
    git
    gh
    lazygit
    lazydocker
    docker-compose
    nerd-fonts.jetbrains-mono
  ];
}