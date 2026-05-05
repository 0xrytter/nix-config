{ pkgs, pkgs-unstable, ... }: {
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/hyprland.nix
    ../../modules/home/neovim.nix
  ];

  programs.git.settings.user = {
    name = "Patrick"; # TODO: set full name
    email = ""; # TODO: set email
  };

  home.stateVersion = "24.05";
}
