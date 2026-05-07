{ pkgs, ... }: {
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/neovim.nix
  ];

  programs.git.settings.user = {
    name = "rytter";
    email = "rytter.jakob@gmail.com";
  };

  home.stateVersion = "24.05";
}
