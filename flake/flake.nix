{
  description = "NixOS + home-manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tmux-gruvbox = {
      url = "github:egel/tmux-gruvbox";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, nixvim, llm-agents, stylix, sops-nix, tmux-gruvbox }:
  let
    system = "x86_64-linux";
    agents = llm-agents.packages.${system};
    # crush is FSL-1.1-MIT (unfree); allow just it, not all unfree packages.
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg: (nixpkgs.lib.getName pkg) == "crush";
    };
    homeManagerModule = users: {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "hm-bak";
      home-manager.extraSpecialArgs = { inherit agents tmux-gruvbox; };
      home-manager.sharedModules = [
        nixvim.homeModules.nixvim
        sops-nix.homeManagerModules.sops
      ];
      home-manager.users = users;
    };
    mkHome = username: homeDirectory: userModule: home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = { inherit agents tmux-gruvbox; };
      modules = [
        nixvim.homeModules.nixvim
        sops-nix.homeManagerModules.sops
        stylix.homeModules.stylix
        {
          home.username = username;
          home.homeDirectory = homeDirectory;
        }
        (import userModule)
      ];
    };
  in
  {
    homeConfigurations = {
      wsl2 = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgs;
        extraSpecialArgs = { inherit agents tmux-gruvbox; };
        modules = [
          nixvim.homeModules.nixvim
          sops-nix.homeManagerModules.sops
          stylix.homeModules.stylix
          (import ./hosts/wsl2/home.nix)
        ];
      };

      T480 = mkHome "rytter" "/home/rytter" ./users/rytter/home.nix;
      DIY-Desktop = mkHome "rytter" "/home/rytter" ./users/rytter/home.nix;
      patrick-desktop = mkHome "pallep" "/home/pallep" ./users/patrick/home.nix;
    };

    nixosConfigurations = {
      DIY-Desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit agents; };
        modules = [
          ./hosts/DIY-Desktop/configuration.nix
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
          (homeManagerModule { rytter = import ./users/rytter/home.nix; })
        ];
      };

      T480 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit agents; };
        modules = [
          ./hosts/T480/configuration.nix
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
          (homeManagerModule { rytter = import ./users/rytter/home.nix; })
        ];
      };

      patrick-desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit agents; };
        modules = [
          ./hosts/patrick-desktop/configuration.nix
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
          (homeManagerModule { pallep = import ./users/patrick/home.nix; })
        ];
      };
    };
  };
}
