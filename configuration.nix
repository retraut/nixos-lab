# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, labUserName, ... }:

let
  goodixLibfprint = pkgs.callPackage ./packages/libfprint-goodix-521d.nix { };
  goodixFprintdBase = pkgs.fprintd.override { libfprint = goodixLibfprint; };
  goodixFprintd = goodixFprintdBase.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      # fprintd 1.94.5 added one retry enum after the 1.94.1 driver fork.
      # The older driver falls back to the generic retry result instead.
      substituteInPlace meson.build \
        --replace-fail "libfprint_min_version = '1.94.9'" "libfprint_min_version = '1.94.1'"
      sed -i '/case FP_DEVICE_RETRY_TOO_FAST:/,+1d' src/device.c
    '';
  });
in

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Keep the desktop laptop-ready even when this configuration is evaluated
  # in the QEMU VM, where no Bluetooth adapter is exposed.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Tailscale client and tailscaled system service. Authentication is manual
  # after the first rebuild: `sudo tailscale up`.
  services.tailscale.enable = true;
  services.power-profiles-daemon.enable = true;

  # Expose the firmware TPM 2.0 device to userspace tooling. This prepares the
  # machine for measured boot and TPM-backed secrets without enrolling or
  # sealing any keys yet.
  security.tpm2.enable = true;

  # Bitwarden's Linux desktop biometric unlock asks Polkit to authorize the
  # `com.bitwarden.Bitwarden.unlock` action. Keep the policy declarative so
  # the NixOS package can use the existing Polkit agent and PAM fingerprint
  # setup without a manual file under /usr/share.
  environment.etc."polkit-1/actions/com.bitwarden.Bitwarden.policy".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC
      "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
      "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">
    <policyconfig>
      <action id="com.bitwarden.Bitwarden.unlock">
        <description>Unlock Bitwarden</description>
        <message>Authenticate to unlock Bitwarden</message>
        <defaults>
          <allow_any>no</allow_any>
          <allow_inactive>no</allow_inactive>
          <allow_active>auth_self</allow_active>
        </defaults>
      </action>
    </policyconfig>
  '';

  # Goodix 27c6:521d support. Enrollment and repeated verification succeeded,
  # so Polkit may now offer the sensor before falling back to the password.
  services.dbus.packages = [ goodixFprintd ];
  systemd.packages = [ goodixFprintd ];
  services.udev.packages = [ goodixLibfprint ];
  security.pam.services = {
    "polkit-1".fprintAuth = true;
    # Keep the reboot/display-manager entry password-only. Fingerprint auth is
    # intentionally limited to the in-session Hyprlock and Polkit flows.
    login.fprintAuth = false;
    sddm.fprintAuth = false;
    # Hyprlock handles fingerprint over fprintd's D-Bus API in parallel with
    # the password-only PAM flow. This keeps password input immediately usable
    # instead of waiting for the fingerprint attempts to finish first.
    hyprlock = {
      fprintAuth = false;
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Warsaw";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pl_PL.UTF-8";
    LC_IDENTIFICATION = "pl_PL.UTF-8";
    LC_MEASUREMENT = "pl_PL.UTF-8";
    LC_MONETARY = "pl_PL.UTF-8";
    LC_NAME = "pl_PL.UTF-8";
    LC_NUMERIC = "pl_PL.UTF-8";
    LC_PAPER = "pl_PL.UTF-8";
    LC_TELEPHONE = "pl_PL.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${labUserName} = {
    isNormalUser = true;
    description = labUserName;
    extraGroups = [ "networkmanager" "tss" "wheel" ];
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # All lockscreen behavior, including the formerly external success-state PR,
  # lives in one versioned local patch so a changed or closed PR cannot break
  # the build.
  nixpkgs.overlays = [
    (final: prev: {
      hyprlock = prev.hyprlock.overrideAttrs (old: {
        patches = (old.patches or []) ++ [
          ./hyprlock-fingerprint-mode.patch
        ];
      });
    })
  ];

  # Required for Home Manager's declarative dconf settings.
  programs.dconf.enable = true;

  # Enable flakes and the modern Nix CLI.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    bat
    chafa
    ffmpegthumbnailer
    gnutar
    less
    mediainfo
    pkgs."poppler-utils"
    tree
    unzip
    wget
    htop
    # Codex's sandbox runner. Keep it in the system profile so both the
    # terminal Codex package and the official ChatGPT app can find `bwrap`.
    bubblewrap
    tpm2-tools
    goodixFprintd
  ];

  # Link Home Manager's desktop and portal entries into the system profile.
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}
