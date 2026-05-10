{ pkgs, ... }: {
  time.timeZone = "Europe/Copenhagen";

  i18n.defaultLocale = "en_DK.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "da_DK.UTF-8";
    LC_IDENTIFICATION = "da_DK.UTF-8";
    LC_MEASUREMENT = "da_DK.UTF-8";
    LC_MONETARY = "da_DK.UTF-8";
    LC_NAME = "da_DK.UTF-8";
    LC_NUMERIC = "da_DK.UTF-8";
    LC_PAPER = "da_DK.UTF-8";
    LC_TELEPHONE = "da_DK.UTF-8";
    LC_TIME = "da_DK.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "colemak_dh_iso";
    options = "compose:ralt";
  };

  nix.settings.trusted-users = [ "rytter" ];

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main.capslock = "layer(nav)";
        nav = {
          j = "left";
          k = "down";
          l = "up";
          semicolon = "right";
        };
      };
    };
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.pipewire.wireplumber.extraConfig.bluetoothEnhancements = {
    "monitor.bluez5.properties" = {
      "bluez5.enable-msbc" = true;
      "bluez5.enable-hw-volume" = true;
      "bluez5.headset-roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
    };
  };
  services.pipewire.wireplumber.extraConfig.suspendOnIdle = {
    "monitor.bluez5.rules" = [
      {
        matches = [ { "node.name" = "~bluez_output.*"; } ];
        actions."update-props" = {
          "session.suspend-timeout-seconds" = 0;
          "node.pause-on-idle" = false;
        };
      }
    ];
  };

  users.users.rytter = {
    isNormalUser = true;
    description = "Jakob Rytter";
    extraGroups = [ "networkmanager" "wheel" "docker" "keyd" ];
    shell = pkgs.fish;
    packages = with pkgs; [ mullvad-vpn qbittorrent webcord ];
  };
}
