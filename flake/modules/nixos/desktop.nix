{ pkgs, ... }: {
  services.xserver.enable = true;
  services.desktopManager.gnome.enable = true;

  services.printing.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = false;
    wireplumber.extraConfig.bluetoothEnhancements = {
      "monitor.bluez5.properties" = {
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        "bluez5.headset-roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
      };
    };
    wireplumber.extraConfig.bluetoothAutoSwitch = {
      "wireplumber.settings" = {
        "bluetooth.autoswitch-to-headset-profile" = true;
      };
    };
  };

  services.gnome.gnome-keyring.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };
}
