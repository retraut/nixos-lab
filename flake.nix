{
  description = "A personal NixOS Hyprland desktop lab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, stylix, disko, nixos-hardware, nix-darwin, ... }:
    let
      labUserName = "retraut";
      macUserName = "retraut";
      commonModules = [
        ./configuration.nix
        ./desktop.nix
        stylix.nixosModules.stylix
        ./theme.nix
        home-manager.nixosModules.home-manager
      ];
      mkHost = hostModules: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit labUserName; };
        modules = commonModules ++ hostModules;
      };
    in {
      nixosConfigurations = {
        # Existing VM profile. Keep #nixos stable for the lab workflow.
        nixos = mkHost [ ./hosts/vm.nix ];
        # Physical GA503QS profile: upstream hardware quirks plus a reusable,
        # encrypted Disko layout. The installer replaces the placeholder
        # hardware scan in its private installation snapshot.
        laptop = mkHost [
          disko.nixosModules.disko
          nixos-hardware.nixosModules.asus-zephyrus-ga503
          ./hosts/laptop.nix
          ./hosts/laptop-disko.nix
          ./hardware/laptop-configuration.nix
        ];
      };

      # Pin the installer tooling to this flake.lock so the live-ISO script
      # does not silently fetch a different Disko or nixpkgs revision.
      packages.x86_64-linux = {
        disko-install = disko.packages.x86_64-linux.disko-install;
        mkpasswd = nixpkgs.legacyPackages.x86_64-linux.mkpasswd;
      };

      # Apple Silicon/macOS skeleton. Keep Linux desktop modules out of it.
      darwinConfigurations.macbook = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit macUserName; };
        modules = [
          ./darwin.nix
          ./darwin/homebrew.nix
          home-manager.darwinModules.home-manager
        ];
      };
    };
}
