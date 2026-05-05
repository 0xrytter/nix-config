{ pkgs, pkgs-unstable, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      claude-code = pkgs-unstable.claude-code;
    })
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [ "beekeeper-studio-5.3.4" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  programs.fish.enable = true;
  programs.firefox.enable = true;
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
    pkgs-unstable.bitwarden-cli
    git gh
    gcc13 gnumake clang unzip ripgrep coreutils wget
    vimPlugins.telescope-live-grep-args-nvim
    xclip wl-clipboard libxkbcommon
    fzf zoxide fd
    bazecor kanata stow
    tmux neovim
    jetbrains.webstorm jetbrains.rider
    wezterm alacritty
    lazygit lazydocker docker-compose
    qbittorrent
    (with dotnetCorePackages; combinePackages [ sdk_8_0_4xx sdk_9_0 ])
    erlang elixir nodejs_22 pnpm python3 openssl
    lsof inotify-tools
    beekeeper-studio
    zed-editor helix code-cursor
    vlc libreoffice-qt6-fresh
    discord postgresql
    fuse appimage-run
    vivaldi librewolf
    pavucontrol
    obsidian brave keepassxc ungoogled-chromium
    wine wine64
    webcord
    lutris cockatrice popsicle
  ];
}
