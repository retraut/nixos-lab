# NixOS Quattro

An Omarchy-inspired desktop rebuilt as a native, declarative NixOS configuration.

This is my personal migration of the Omarchy/Quattro workflow to NixOS: Hyprland,
Quickshell, Stylix, systemd user services, laptop support, and a small Rust desktop
daemon are wired together through a flake. It is not an official Omarchy project
or a drop-in Omarchy distribution.

> [!IMPORTANT]
> This repository is a working personal configuration, not a generic installer.
> Read the host modules before reusing it. The laptop installer is intentionally
> hardware-gated and performs a **full disk wipe** after explicit confirmation.

## What is here

- A Quickshell status bar, launcher, notification center, OSD, calendar, weather,
  battery panel, and desktop menu.
- A native Control Center for Wi-Fi, Bluetooth, PipeWire, displays, Tailscale,
  and power profiles.
- Hyprland shortcuts designed to behave consistently across US and Ukrainian
  keyboard layouts.
- Stylix-driven Tokyo Night theming for the shell, lock screen, launcher, and
  terminal.
- Declarative clipboard, idle/lock, wallpaper, layout, voice transcription,
  and desktop-daemon services.
- Separate NixOS profiles for a disposable QEMU VM and an ASUS ROG Zephyrus G15
  GA503QS, plus an intentionally minimal Apple Silicon nix-darwin skeleton.
- LUKS2/Btrfs Disko layout, Secure Boot/TPM preparation, and a guarded laptop
  installation runbook.

## Profiles

| Flake output | Purpose | Notes |
| --- | --- | --- |
| `nixosConfigurations.nixos` | QEMU development VM | Autologin and passwordless sudo are VM-only conveniences. |
| `nixosConfigurations.laptop` | ASUS GA503QS laptop | Hardware-specific PRIME, fingerprint, Disko, LUKS2, and TPM settings. |
| `darwinConfigurations.macbook` | Apple Silicon skeleton | Shares only platform-neutral tooling; no Linux desktop modules. |

The VM and laptop layers are deliberately separate. In particular,
`hosts/laptop-disko.nix` must never be applied casually to another machine.

## Repository map

```text
flake.nix                         flake inputs and host outputs
configuration.nix                 shared NixOS base
desktop.nix                       Hyprland/Quickshell/Home Manager desktop
theme.nix                         Stylix and generated theme configuration
lockscreen.nix                    Hyprlock integration
voxtype.nix                       voice transcription service
hosts/                            VM, laptop, and Disko host layers
hardware/                         host hardware placeholder
quickshell/                       shell UI and widgets
packages/nixos-desktop-daemon/    Rust desktop integration daemon
scripts/                          desktop helpers and guarded installers
```

The longer implementation log and behavioral notes are in
[README-nix.md](./README-nix.md). The destructive laptop workflow is documented
separately in [LAPTOP-INSTALL-RUNBOOK.md](./LAPTOP-INSTALL-RUNBOOK.md).

## Inspecting the flake safely

With Nix flakes enabled:

```sh
nix flake show
nix flake check
nix build --no-link .#nixosConfigurations.nixos.config.system.build.toplevel
```

These commands evaluate or build the configuration; they do not activate it.
The repository tracks `flake.lock` so the tested dependency revisions are
reproducible.

## Reusing it

Treat this repository as reference material or a starting point for a fork. At a
minimum, review and replace:

1. `labUserName` and `macUserName` in `flake.nix`.
2. Hostnames, locale, timezone, and enabled services in `configuration.nix` and
   `hosts/`.
3. Generated hardware configuration for the target machine.
4. Laptop-specific GPU bus IDs, fingerprint support, disk layout, and TPM policy.
5. Personal application choices and key bindings in `desktop.nix` and
   `hyprland.lua`.

Do not copy credentials into Nix files. The laptop profile reads a root-only
password hash from `/etc`, and runtime Wi-Fi secrets remain in NetworkManager.

## Laptop installer warning

`scripts/install-laptop` is only for the inspected ASUS GA503QS. It refuses other
hardware, requires exactly one non-removable NVMe disk, performs a Disko dry run,
and demands an exact final confirmation before erasing the drive. Those gates are
safety measures, not a promise that the script is suitable for another machine.

## Status

The NixOS desktop is actively used and developed against `nixos-unstable`. The VM
profile is the development target; the GA503QS profile contains real-machine
assumptions; the nix-darwin output is a skeleton rather than a feature-equivalent
port.

## Credits and license

The UX is inspired by [Omarchy](https://omarchy.org/) and reimplemented for NixOS.
The repository is licensed under the MIT License; the preserved upstream Omarchy
notice is in [LICENSES/Omarchy-MIT.txt](./LICENSES/Omarchy-MIT.txt).
