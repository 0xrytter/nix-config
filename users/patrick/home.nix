{ pkgs, pkgs-unstable, ... }: {
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/hyprland.nix
    ../../modules/home/neovim.nix
  ];

  programs.git = {
    userName = "Patrick"; # TODO: set full name
    userEmail = ""; # TODO: set email
  };

  services.easyeffects = {
    enable = true;
  };

  home.packages = with pkgs; [
    easyeffects
  ];

  home.stateVersion = "24.05";
}
