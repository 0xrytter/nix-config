{ config, pkgs, lib, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/stylix.nix
    ../../users/rytter/nixos.nix
  ];

  networking.hostName = "T480";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  networking.networkmanager.wifi.powersave = false;

  services.displayManager.gdm.enable = true;

  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [{
    settings = {
      "org/gnome/desktop/interface" = {
        gtk-enable-primary-paste = false;
      };
    };
  }];

  services.libinput = {
    enable = true;
    touchpad = {
      tapping = false;
      scrollMethod = "none";
      middleEmulation = false;
      disableWhileTyping = true;
      naturalScrolling = false;
    };
  };

  environment.etc."libinput/local-overrides.quirks".text = ''
    [ThinkPad T480 TouchPad]
    MatchName=Synaptics TM3276-022
    MatchUdevType=touchpad
    AttrInputCode=-EV_KEY:BTN_MIDDLE

    [ThinkPad T480 TrackPoint]
    MatchName=TPPS/2 IBM TrackPoint
    MatchUdevType=pointingstick
    AttrInputCode=-EV_KEY:BTN_MIDDLE
  '';

  boot.kernelModules = [ "uinput" ];

  systemd.services.disable-middle-click = {
    description = "Swallow BTN_MIDDLE from T480 touchpad and trackpoint";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      ExecStart = let
        python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
        script = pkgs.writeText "disable-middle-click.py" ''
          import asyncio
          from evdev import InputDevice, UInput, ecodes, list_devices

          TARGET_NAMES = {"Synaptics TM3276-022", "TPPS/2 IBM TrackPoint"}

          async def relay(device):
              ui = UInput.from_device(device, name=f"nomiddle-{device.name}")
              device.grab()
              async for event in device.async_read_loop():
                  if event.type == ecodes.EV_KEY and event.code == ecodes.BTN_MIDDLE:
                      continue
                  ui.write_event(event)

          async def main():
              devices = [InputDevice(p) for p in list_devices()]
              targets = [d for d in devices if d.name in TARGET_NAMES]
              if not targets:
                  raise SystemExit("No target devices found")
              await asyncio.gather(*[relay(d) for d in targets])

          asyncio.run(main())
        '';
      in "${python}/bin/python3 ${script}";
      Restart = "on-failure";
      RestartSec = "3s";
    };
  };

  hardware.trackpoint = {
    enable = true;
    emulateWheel = false;
    sensitivity = 200;
  };

  environment.systemPackages = with pkgs; [
    teams-for-linux
    google-chrome
    gearlever
    libva mesa libglvnd libdrm wayland libinput
    libx11 libxext libxrender libxrandr
    libxfixes libxau libxdmcp
    libva-utils curl nss nspr zlib alsa-lib
    gnome2.GConf gcc.cc.lib libuv
  ];

  system.stateVersion = "24.11";
}
