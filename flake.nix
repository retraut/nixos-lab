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

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { nixpkgs, home-manager, stylix, nix-darwin, ... }:
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
      # The laptop's generated hardware file is intentionally optional: the
      # same flake remains usable in the VM before the real laptop is scanned.
      laptopHardware = nixpkgs.lib.optional
        (builtins.pathExists ./hardware/laptop-configuration.nix)
        ./hardware/laptop-configuration.nix;
    in {
      nixosConfigurations = {
        # Existing VM profile. Keep #nixos stable for the lab workflow.
        nixos = mkHost [ ./hosts/vm.nix ];
        # Real laptop profile. Add hardware/laptop-configuration.nix after
        # running nixos-generate-config on the laptop.
        laptop = mkHost ([ ./hosts/laptop.nix ] ++ laptopHardware);
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
