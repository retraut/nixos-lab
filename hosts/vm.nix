{ labUserName, ... }:

{
  # Generated hardware for the current disposable QEMU VM.
  imports = [ ../hardware-configuration.nix ];

  networking.hostName = "nixos";

  # VM-only integration and bootstrap conveniences.
  services.qemuGuest.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = labUserName;
  };

  # Never carry this setting to the real laptop profile.
  security.sudo.wheelNeedsPassword = false;
}
