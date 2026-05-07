{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/hyprland.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/stylix.nix
    ../../users/rytter/nixos.nix
  ];

  networking.hostName = "DIY-Desktop";

  virtualisation.waydroid.enable = true;
  programs.steam.enable = true;

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "24.05";
}
