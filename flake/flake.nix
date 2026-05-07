{
  description = "NixOS + home-manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, nixvim, llm-agents, stylix }:
  let
    system = "x86_64-linux";
    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
    agents = llm-agents.packages.${system};
    homeManagerModule = users: {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = { inherit pkgs-unstable agents; };
      home-manager.sharedModules = [ nixvim.homeModules.nixvim ];
      home-manager.users = users;
    };
  in
  {
    nixosConfigurations = {
      DIY-Desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-unstable agents; };
        modules = [
          ./hosts/DIY-Desktop/configuration.nix
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
          (homeManagerModule { rytter = import ./users/rytter/home.nix; })
        ];
      };

      T480 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-unstable agents; };
        modules = [
          ./hosts/T480/configuration.nix
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
          (homeManagerModule { rytter = import ./users/rytter/home.nix; })
        ];
      };

      patrick-desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-unstable agents; };
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
