{ pkgs, pkgs-unstable, ... }: {
  imports = [ ../../modules/home/common.nix ];

  programs.git = {
    userName = "Jakob Rytter";
    userEmail = "rytter.jakob@gmail.com";
  };

  home.stateVersion = "24.05";
}
