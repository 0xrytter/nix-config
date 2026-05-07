{ pkgs, ... }: {
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/hyprland.nix
    ../../modules/home/neovim.nix
  ];

  programs.git.settings.user = {
    name = "Patrick"; # TODO: set full name
    email = "devantier.devantier@gmail.com"; # TODO: set email
  };

  home.stateVersion = "24.05";
}
