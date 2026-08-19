{ lib, ... }:

{
  networking.hostName = "nixos-laptop";

  # The laptop hardware scan is loaded automatically by flake.nix when
  # hardware/laptop-configuration.nix exists. Keep VM-only services out.
  services.qemuGuest.enable = false;
  services.displayManager.autoLogin.enable = false;

  # Harmless on machines without an adapter and useful on the laptop.
  hardware.bluetooth.enable = true;

  # Evaluation defaults only. The generated laptop hardware file has normal
  # priority and overrides these paths once it is added to the repository.
  fileSystems."/" = {
    device = lib.mkDefault "/dev/disk/by-label/NIXOS_ROOT";
    fsType = lib.mkDefault "ext4";
  };
  fileSystems."/boot" = {
    device = lib.mkDefault "/dev/disk/by-label/NIXOS_EFI";
    fsType = lib.mkDefault "vfat";
  };
}
