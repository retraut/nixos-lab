{ lib, pkgs, labUserName, ... }:

let
  factorioTouchpadHold = pkgs.writeShellApplication {
    name = "factorio-touchpad-hold";
    runtimeInputs = [ pkgs.hyprland pkgs.ydotool ];
    text = ''
      exec ${pkgs.python3}/bin/python ${../packages/factorio-touchpad-hold.py}
    '';
  };
in
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

  # Preserve ordinary two-finger scrolling, but turn a stationary two-finger
  # hold into RMB while Factorio is focused. Access is limited to this exact
  # touchpad; the helper does not grab or suppress its normal event stream.
  hardware.uinput.enable = true;
  programs.ydotool.enable = true;
  users.groups.factorio-touchpad = { };
  users.users.${labUserName} = {
    extraGroups = [ "factorio-touchpad" "ydotool" ];
    # disko-install uses --no-root-password. The live installer supplies this
    # root-readable hash file without ever committing a password or hash to Git.
    # users.mutableUsers stays at its NixOS default, so later `passwd` changes
    # remain stateful instead of being reset on every rebuild.
    hashedPasswordFile = "/etc/nixos-install-user-password-hash";
  };
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="ASUE1209:00 04F3:319F Touchpad", MODE="0660", GROUP="factorio-touchpad", SYMLINK+="input/factorio-touchpad"
  '';

  home-manager.users.${labUserName}.systemd.user.services.factorio-touchpad-hold = {
    Unit = {
      Description = "Factorio two-finger RMB hold";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionPathExists = "/dev/input/factorio-touchpad";
    };
    Service = {
      ExecStart = "${factorioTouchpadHold}/bin/factorio-touchpad-hold";
      Environment = [ "YDOTOOL_SOCKET=/run/ydotoold/socket" ];
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # The upstream GA503 profile assumes PCI:7:0:0. This GA503QS was inspected
  # on the running machine and its AMD iGPU is actually PCI 06:00.0.
  hardware.nvidia.prime.amdgpuBusId = lib.mkForce "PCI:6:0:0";

}
