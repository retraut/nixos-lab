{ lib, labUserName, ... }:

{
  networking.hostName = "zephyrus";

  # Let systemd-cryptsetup in the initrd consume a TPM2 token enrolled in the
  # cryptroot LUKS2 header. The passphrase remains available as fallback.
  # Enrollment itself is intentionally a manual post-install operation.
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.tpm2.enable = true;
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = [ "tpm2-device=auto" ];

  # Keep VM-only services and conveniences out of the physical host.
  services.qemuGuest.enable = false;
  services.displayManager.autoLogin.enable = false;

  # Harmless on machines without an adapter and useful on the laptop.
  hardware.bluetooth.enable = true;

  # The upstream GA503 profile assumes PCI:7:0:0. This GA503QS was inspected
  # on the running machine and its AMD iGPU is actually PCI 06:00.0.
  hardware.nvidia.prime.amdgpuBusId = lib.mkForce "PCI:6:0:0";

  # disko-install uses --no-root-password. The live installer supplies this
  # root-readable hash file without ever committing a password or hash to Git.
  # users.mutableUsers stays at its NixOS default, so later `passwd` changes
  # remain stateful instead of being reset on every rebuild.
  users.users.${labUserName}.hashedPasswordFile =
    "/etc/nixos-install-user-password-hash";
}
