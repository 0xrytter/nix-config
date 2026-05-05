{ pkgs, pkgs-unstable, ... }: {
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/hyprland.nix
    ../../modules/home/neovim.nix
  ];

  programs.git = {
    userName = "rytter";
    userEmail = "rytter.jakob@gmail.com";
  };

  # Override keyboard layout from hyprland module default (dk)
  wayland.windowManager.hyprland.extraConfig = ''
    input {
      kb_layout = us
      kb_variant = colemak_dh_iso
    }
  '';

  home.stateVersion = "24.05";
}
