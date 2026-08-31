{ pkgs, ... }:
let
  wgnordTemplate = pkgs.writeText "wgnord-template.conf" ''
    [Interface]
    PrivateKey = PRIVKEY
    Address = 10.5.0.2/32
    DNS = 103.86.96.100, 103.86.99.100

    [Peer]
    PublicKey = SERVER_PUBKEY
    AllowedIPs = 0.0.0.0/0, ::/0
    Endpoint = SERVER_IP:51820
    PersistentKeepalive = 25
  '';
in {
  nixpkgs.overlays = [
    (final: prev: {
      openldap = prev.openldap.overrideAttrs { doCheck = false; };
      gtksourceview5 = prev.gtksourceview5.overrideAttrs { doCheck = false; };
    })
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [ "beekeeper-studio-5.3.4" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSin4="
  ];
  nix.settings.trusted-users = [ "root" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  systemd.tmpfiles.rules = [
    "d /var/lib/wgnord 0700 root root -"
    "d /etc/wireguard 0700 root root -"
    "C+ /var/lib/wgnord/template.conf 0600 root root - ${wgnordTemplate}"
  ];

  programs.fish.enable = true;
  programs.nix-ld.enable = true;
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  virtualisation.docker.enable = true;

  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];

  environment.pathsToLink = [ "/libexec" ];

  environment.sessionVariables = {
    DOTNET_ROOT = "$(dirname $(readlink -f $(which dotnet)))";
  };

  environment.systemPackages = with pkgs; [
    codex
    claude-code
    bitwarden-desktop
    git gh
    wgnord
    wl-clipboard
    tmux neovim
    jetbrains.rider
    alacritty ghostty
    lazygit lazydocker docker-compose
    (with dotnetCorePackages; combinePackages [ sdk_8_0_4xx sdk_9_0 ])
    python3
    beekeeper-studio
    vlc
    discord
    obsidian keepassxc
    popsicle
  ];
}
