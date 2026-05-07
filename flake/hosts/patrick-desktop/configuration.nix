{ config, pkgs, lib, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/hyprland.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/stylix.nix
    ../../users/patrick/nixos.nix
  ];

  networking.hostName = "patrick-desktop";
  
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # GRUB for multi-boot — auto-detects Windows and other drives
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;

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
