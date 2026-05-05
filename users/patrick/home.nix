{ pkgs, pkgs-unstable, ... }: {
  imports = [ ../../modules/home/common.nix ];

  programs.git = {
    userName = "Patrick"; # TODO: set full name
    userEmail = ""; # TODO: set email
  };

  home.stateVersion = "24.05";
}
