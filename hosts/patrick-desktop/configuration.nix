{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/hyprland.nix
    ../../modules/nixos/nvidia.nix
    ../../users/patrick/nixos.nix
  ];

  networking.hostName = "patrick-desktop";

  services.xserver.xkb = {
    layout = "dk";
    variant = "";
  };
  console.keyMap = "dk-latin1";

  virtualisation.waydroid.enable = true;
  programs.steam.enable = true;

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "24.05";
}
