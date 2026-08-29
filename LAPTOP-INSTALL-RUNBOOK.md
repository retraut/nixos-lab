# NixOS laptop installation runbook — ROG Zephyrus G15 GA503QS

This checklist covers a clean installation of the VM-tested configuration on a
physical GA503QS. It does not clone the VM disk. An official NixOS live USB runs
`scripts/install-laptop`; Disko recreates the disk layout declared in Git and
installs the `.#laptop` profile.

> [!CAUTION]
> This workflow erases the complete internal NVMe drive. It supports neither
> dual boot nor arbitrary laptop models.

## What is automated

- Official `NixOS/nixos-hardware` profile `asus-zephyrus-ga503`.
- Local AMD iGPU override: `PCI:6:0:0` instead of upstream `PCI:7:0:0`.
- GPT and a 2 GiB EFI System Partition.
- LUKS2 over the full main data area.
- Btrfs subvolumes for `/`, `/home`, `/nix`, and `/var/log`.
- Host-specific hardware scan without duplicate `fileSystems` declarations.
- Pinned `disko-install` and `mkpasswd` from this repository's `flake.lock`.
- Root-only yescrypt hash for the initial login/sudo password.
- A snapshot of the installed flake under `/etc/nixos`.
- A dry run and several fail-closed checks before any destructive step.

The initial installation does not enroll TPM unlock. The disk first boots with
a separate, strong LUKS passphrase. Secure Boot, recovery material, and TPM2
auto-unlock come only after several stable boots.

## Stop gates before erasing the disk

Do not start the installer until every item is complete:

- [ ] The intended operation is a **full wipe of the internal NVMe**, not dual
      boot.
- [ ] Important files from the current system have been opened successfully
      from another storage location.
- [ ] Password-manager data, SSH/GPG keys, browser data, game saves, and local
      projects are synchronized or exported.
- [ ] The repository is reachable at
      `https://github.com/retraut/nixos-lab`.
- [ ] The laptop is connected to power and a working network.
- [ ] Secure Boot is currently disabled.
- [ ] The official NixOS installer USB was booted in UEFI mode.
- [ ] Two **different** strong phrases are ready: the login/sudo password and
      the LUKS passphrase.

Do not adapt destructive commands interactively. A dual-boot installation needs
a separately designed and reviewed disk layout.

## Boot the live ISO

1. Boot the NixOS USB in UEFI mode.
2. Connect to the network and open a terminal.
3. Confirm that GitHub is reachable:

```sh
git ls-remote https://github.com/retraut/nixos-lab.git HEAD
```

4. Clone the configuration:

```sh
git clone https://github.com/retraut/nixos-lab.git
cd nixos-lab
```

## Run the installer once

Start the wrapper without a disk argument:

```sh
./scripts/install-laptop
```

The script will:

1. Elevate through graphical `pkexec`, falling back to interactive `sudo` when
   Polkit is unavailable in the live ISO.
2. Refuse to run on anything other than an ASUS GA503QS.
3. Discover non-removable whole NVMe devices through `/dev/disk/by-id`, reject
   partitions and duplicate aliases, and continue only when exactly one physical
   candidate exists.
4. Refuse a target that is mounted or otherwise in use.
5. Display the model, size, serial, transport, by-id path, and resolved device.
6. Create a private installation snapshot and generate the current
   `hardware/laptop-configuration.nix` inside it.
7. Build Disko and the complete `.#laptop` profile in `--dry-run` mode without
   changing the disk.
8. Require the exact long confirmation string `ERASE ...`.
9. Prompt privately for the login/sudo password for `retraut`.
10. Prompt privately twice for a **separate** LUKS passphrase.
11. Erase the target, create GPT + EFI + LUKS2 + Btrfs, install NixOS, and save
    the installed snapshot under `/etc/nixos`.

If two internal NVMe drives exist, the script prints both and exits **before the
dry run and wipe**. Do not improvise in that situation; save the output and
design an explicit selection mechanism separately.

Passwords never enter argv, Git, or chat. The login password becomes a salted
yescrypt hash in root-only `/etc/nixos-install-user-password-hash`. Disko keeps
the LUKS passphrase only in the current process's memory. If any validation or
exact confirmation fails, the wipe does not start.

## First boot: passphrase only

After `Install complete`:

1. Shut down, remove the USB, and boot from the internal NVMe.
2. Enter the LUKS passphrase.
3. Sign in as `retraut` with the login password.
4. Run:

```sh
systemctl --failed
systemctl --user --failed
hyprctl configerrors
lsblk --fs
findmnt / /boot /home /nix /var/log
sudo cryptsetup luksDump /dev/disk/by-label/NIXOS_CRYPT
```

- [ ] Root is inside `cryptroot`/LUKS2.
- [ ] `/`, `/home`, `/nix`, and `/var/log` are the expected Btrfs subvolumes.
- [ ] `sudo` requires a password; passwordless sudo remains limited to
      `hosts/vm.nix`.
- [ ] Autologin is disabled.
- [ ] Wi-Fi, Bluetooth, audio/microphone, brightness, and touchpad work.
- [ ] Suspend/resume and keyboard layouts work.
- [ ] AMD desktop rendering and NVIDIA offload were tested separately.
- [ ] Battery profiles, fans, and thermals were checked.
- [ ] At least two cold boots succeeded with the passphrase.
- [ ] A known-good NixOS generation remains available.

After the first boot, the source of truth exists both in public Git and locally
under `/etc/nixos`. The generated hardware scan may later be moved back into Git.
UUIDs and kernel module lists are not passwords, but always inspect the diff
before committing it.

## Secure Boot with Lanzaboote — separate phase

Proceed only after the passphrase-based system is stable:

- [ ] Add and pin the Lanzaboote input/module.
- [ ] Create personal Secure Boot keys and protect the private keys.
- [ ] Verify signed boot artifacts before changing firmware settings.
- [ ] Decide whether Microsoft keys must remain for device compatibility.
- [ ] Enroll keys in firmware deliberately and enable Secure Boot.
- [ ] Check `bootctl status`, `sbctl status`, and several boots.

Do not enroll TPM unlock before Secure Boot is stable. A changed PCR state after
enrollment otherwise falls back immediately to the passphrase.

## Recovery material before TPM

- [ ] Add a separate LUKS recovery key with `systemd-cryptenroll`.
- [ ] Store it in the password manager and one additional offline location.
- [ ] Back up the LUKS header to separate encrypted storage.
- [ ] Confirm through a real reboot that the normal passphrase still works.

The recovery key and header backup are secrets. Never put them in the flake,
Git, shell history, process arguments, logs, or chat.

## TPM2 auto-unlock — after recovery and Secure Boot

After Secure Boot is stable:

- [ ] Enable systemd initrd and TPM2 support in NixOS.
- [ ] Choose a PCR/signed-policy strategy for the actual boot chain rather than
      copying an arbitrary PCR list.
- [ ] Add a TPM2 token to the LUKS2 header:

```sh
sudo systemd-cryptenroll \
  --tpm2-device=auto \
  /dev/disk/by-label/NIXOS_CRYPT
```

The command asks for the current LUKS passphrase but no TPM PIN. If using a
PCR-bound policy, add only verified PCR options for the real Secure Boot chain.
Never pass a passphrase through shell arguments.

- [ ] Keep the ordinary LUKS passphrase enrolled.
- [ ] Test TPM auto-unlock, fallback passphrase, and recovery key.
- [ ] Test a normal NixOS rebuild and plan for firmware updates.

TPM unlock may fail after BIOS setting changes, a BIOS update, Secure Boot key
changes, TPM clearing, or motherboard replacement. That is expected: unlock
with the passphrase or recovery key and enroll the TPM token again.

## Definition of done

- [ ] One command reproduces the install with one auto-detected NVMe.
- [ ] Root is LUKS2/Btrfs and the first passphrase boots are stable.
- [ ] Login and `sudo` require a password; VM-only passwordless sudo is absent.
- [ ] `.#laptop` rebuilds without QEMU or autologin settings.
- [ ] Wi-Fi, Bluetooth, audio, suspend, AMD rendering, and NVIDIA offload work.
- [ ] No system/user units fail and Hyprland reports no configuration errors.
- [ ] Verified Secure Boot and TPM2 auto-unlock are enabled later.
- [ ] The passphrase, recovery key, and header backup all work as fallbacks.
