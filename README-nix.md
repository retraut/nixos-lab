# NixOS Quattro engineering notes

> The public overview, safety notes, and entry points are in
> [`README.md`](./README.md). This file is the detailed implementation log.

This is an experimental NixOS configuration developed in the `nixos-lab` VM:
a modular Quickshell/Hyprland desktop that recreates the desired Omarchy UX
while remaining NixOS-native, declarative, and independent of the Arch/Omarchy
runtime or a third-party flake.

The repository is the source of truth. It is synchronized into the VM at
`~/nixos-lab-config` and activated with the `.#nixos` profile. The last audited
VM generation had no failed system or user units.

The clean-install checklist for the physical ASUS ROG Zephyrus G15 GA503QS,
including Disko, LUKS2, Secure Boot, recovery, and TPM2 auto-unlock, is in
[LAPTOP-INSTALL-RUNBOOK.md](./LAPTOP-INSTALL-RUNBOOK.md).

## Base system

- The development target is a KVM/QEMU NixOS VM.
- The stable VM flake profile is `nixos`; the physical laptop profile is
  `laptop`.
- `labUserName` keeps shared modules independent of a literal username.
- Project-specific dependencies are separated from the main application list
  in `desktop.nix`.
- The desktop includes Ghostty, Chromium, Tailscale, Bitwarden, Codex CLI,
  system utilities, and the required Nerd Fonts.
- NetworkManager, Blueman, Pavucontrol, PipeWire, UPower,
  power-profiles-daemon, Polkit, and the Tailscale system service support the
  full Control Center.

## Theme and typography

- Stylix provides the Tokyo Night palette.
- The palette generates one `Theme.qml` for Quickshell and declaratively
  produces `hyprlock.conf` and `fuzzel.ini`.
- There is deliberately no runtime theme picker.
- The bar is `20px`, status icons are `24px`, widget text is `30px`, the cursor
  is DMZ-Black, and the typeface is JetBrainsMono Nerd Font.
- Widgets use sharp rectangular borders rather than rounded corners.
- Popup dimensions are derived from content with stable bounds instead of
  depending on unreliable initial `panel.width` and `panel.height` values.

## Shell, bar, and shortcuts

The Quattro-style bar contains workspaces, clock, weather, keyboard layout,
tray, battery, agents, notifications, and Control Center. Workspaces are mouse
selectable, and the bar defaults to an opaque background for reliable contrast.

Hyprland owns the important Super-key behavior so it remains consistent across
US and Ukrainian layouts. The application launcher uses one proportional
`uiScale = 1.5`; Chromium, ChatGPT, and Bitwarden launch at the matching scale.

| Shortcut | Behavior |
| --- | --- |
| `Super+Space` | Select the English layout and open the 150% launcher |
| `Super+Enter` | Ghostty |
| `Super+Shift+B` | Chromium |
| `Super+Shift+F` | Nautilus |
| `Super+Ctrl+O` | Control Center |
| `Super+Ctrl+M` | Desktop menu |
| `Super+N` | Notification Center; a new window inside Chromium |
| `Super+A` | Select all; native `Ctrl+Shift+A` inside Ghostty |
| `Super+C` / `Super+V` | Layout-independent copy and paste |
| `Super+T` / `Super+R` | New tab / refresh in Chromium |
| `Super+W` | Close a Chromium tab or another application's window |
| `Super+-` / `Super+=` | Zoom Chromium or Ghostty on either keyboard layout |
| `Super+Shift+V` | Clipboard history |
| `Super+Ctrl+Space` | Emoji picker |
| `Super+Escape` | Lock the session |
| `Print` / `Super+Print` / `Shift+Print` | Region / active window / full-screen capture |
| `Super+1…0` | Select workspace 1…10; add `Shift` to move the active window |

Media keys control volume, microphone mute, and brightness through the custom
OSD.

## Bar, tray, and touchpad interactions

- Double-clicking empty bar space toggles an opaque or transparent background.
- Left-clicking weather opens current/hourly conditions; right- or
  middle-clicking opens the weekly view.
- The clock opens Calendar, and the keyboard indicator cycles US/UA.
- The tray expands on hover or click. Left click activates an item, middle click
  invokes its secondary action, and right click or a two-finger tap opens its
  menu.
- Tray menus are anchored to the selected icon and adjust at the screen edge.
- Left-clicking the notification bell opens Notification Center. Right click or
  a two-finger tap toggles DND, with a dedicated state popup even while regular
  toasts are muted.
- Left-clicking the gear toggles Control Center; right click explicitly closes
  it. Hover alone never changes its state.

## Quickshell widgets

- `agents.qml`: available CLI providers, usage, and launch actions.
- `battery-panel.qml`: battery state and power profile.
- `control-center.qml`: compact dashboard with system statistics and six control
  categories.
- `control-panel.qml`: stateful Wi-Fi, Bluetooth, PipeWire, display, Tailscale,
  and power detail pages, with links to native advanced tools where appropriate.
- `calendar.qml`: navigable month view.
- `weather.qml`: current, hourly, and seven-day forecasts.
- `menu.qml`: clipboard, emoji, screenshot, notification, and lock actions.
- `app-launcher.qml`: fuzzy application and web-app launcher.

Adaptive layouts keep long descriptions, hourly columns, weekly rows, and
launcher entries usable with large fonts.

## Control Center

The dashboard follows the Omarchy Control Center structure but is implemented
natively for NixOS. It uses compact typography, reports CPU, RAM, swap, storage,
and temperature, and keeps a fixed 2×3 control grid. Laptop controls remain
visible in the VM and explicitly report missing hardware.

| Panel | Implemented behavior |
| --- | --- |
| Wi-Fi | Radio state, scan, access points, signal/security, connect, password prompt, disconnect, forget, NetworkManager settings, and QR sharing |
| Bluetooth | Adapter power, scan, discovered/paired/connected devices, connect, disconnect, forget, and Blueman |
| Audio | PipeWire output/input volume up to 150%, mute, defaults, application streams, and Pavucontrol |
| Display | Backlight slider for real backlight devices; read-only monitor name, mode, refresh rate, and scale |
| Tailscale | Backend/auth state, connect/disconnect, self node, peers, online state, and exit-node toggle |
| Power | Current and available power-profiles-daemon profiles |

Display controls are intentionally conservative. There is no runtime scale
picker, DPMS-off action, or monitor enable/disable mutation in QML or the action
backend. Scale remains declarative through `hl.monitor(...)` in `hyprland.lua`.

The implementation separates the read-only state provider
`scripts/nixos-control-state`, mutation helper `scripts/nixos-control-action`,
QR helper `scripts/nixos-wifi-qr`, dashboard UI, and detail UI. External values
are never interpolated into shell commands.

Wi-Fi QR generation happens only on request for the active NetworkManager
profile. The PSK is read with `nmcli --show-secrets`, passed to `qrencode` over
stdin, omitted from argv/state/logs, and written as
`$XDG_RUNTIME_DIR/nixos-wifi-share.png` with mode `0600`.

## Omarchy-style UX without runtime mutation

- Quickshell owns `org.freedesktop.Notifications` and provides toasts, DND,
  in-session history, and a right-side Notification Center.
- A bottom-center OSD covers volume, mute, microphone, and brightness.
- `hypridle` and `hyprlock` are declarative: lock at five minutes, DPMS off at
  5:30, and lock before sleep.
- `cliphist` uses separate text and image watchers; Fuzzel handles clipboard and
  emoji selection.
- Screenshots use `grim`, `slurp`, the clipboard, and desktop notifications.
- Quickshell, wallpaper, layout, idle, voice, daemon, and clipboard processes
  are Home Manager user services with explicit restart policies.
- UPower, rtkit, and Bluetooth are enabled system-wide.

## Audit fixes and safety properties

- Calendar and Weather launchers verify a live Quickshell process rather than
  trusting a successful IPC exit code.
- Exact process matching avoids false positives from similar command lines.
- Control Center geometry no longer starts as an invisible `60x44` card.
- Dashboard typography is independent of the launcher's 150% scale.
- The 2×3 grid remains stable even when VM hardware capabilities are absent.
- Gear-button open/close behavior is deterministic and has no hover race.
- Display discovery accepts real backlight devices, not keyboard LEDs.
- Monitor state is read-only, preventing accidental black-screen actions.
- Wi-Fi passwords enter the action helper over stdin and never appear in the
  process list.
- Wi-Fi QR data is created only on demand and remains a mode-`0600` runtime file.
- Privileged power and Tailscale actions use graphical Polkit authorization.
- System statistics omit unstable power-draw estimates and per-process usage.

## Verification history

- The VM profile has completed `nixos-rebuild switch` successfully.
- Agents, Battery, Control Center, Calendar, Weather, Menu, and App Launcher QML
  loaded without fatal errors.
- The dashboard and all six detail pages passed IPC and visual smoke tests.
- Open, IPC dismiss, close, and repeated-close behavior was exercised.
- Volume and privileged power actions were tested; destructive network actions
  were deliberately not toggled in the VM.
- Display `off` and `toggle` actions return unsupported, with no clickable
  mutation target in the monitor list.
- The Wi-Fi QR helper returns a structured error when no adapter or active
  connection exists.
- Notification toasts, Notification Center, OSD, menu, emoji picker, clipboard
  watchers, and full-screen capture passed smoke tests.
- QEMU uses virtio-vga-gl/virgl, and Quickshell starts without the previous
  `MESA-EGL failed to create dri2 screen` failure.

## QEMU VM workflow

The development VM is reachable through forwarded SSH:

```sh
ssh -p 2222 retraut@127.0.0.1
```

After synchronizing the repository:

```sh
cd ~/nixos-lab-config
sudo nixos-rebuild switch --flake .#nixos
```

Until the disposable VM has a known password, stop the rebuilt idle manager so
it cannot lock the session:

```sh
systemctl --user stop nixos-hypridle.service
```

Useful smoke checks:

```sh
systemctl --failed
systemctl --user --failed
systemctl --user status nixos-shell.service
hyprctl configerrors
```

The Control Center IPC target is `nixos-control-center`, with `panel(kind)`,
`dashboard()`, and `dismiss()` methods. The launcher supports `toggle`, `open`,
and `close`.

The VM has no battery, backlight, Wi-Fi, or Bluetooth devices. Their controls
remain visible as a preview of the laptop profile and report missing hardware.

## Hardware layers

- `hosts/vm.nix`: QEMU guest agent, VM hardware scan, autologin, and passwordless
  sudo for the disposable VM only.
- `hosts/laptop.nix`: laptop hostname, login password-hash path, GA503QS PRIME
  override, and no QEMU/autologin/passwordless-sudo settings.
- `hosts/laptop-disko.nix`: destructive GPT + 2 GiB EFI + LUKS2 + Btrfs layout.
- `hardware-configuration.nix`: generated configuration for the current VM.
- `hardware/laptop-configuration.nix`: safe placeholder replaced by the installer
  inside its private installation snapshot.
- `asus-zephyrus-ga503`: upstream AMD/NVIDIA and model-specific quirks.

Profiles can be activated manually by the machine owner:

```sh
# VM
sudo nixos-rebuild switch --flake .#nixos

# inspected GA503QS laptop only
sudo nixos-rebuild switch --flake .#laptop
```

The clean laptop installer is hardware-gated, auto-detects exactly one
non-removable whole NVMe disk, creates a hardware layer without filesystems,
performs a pinned Disko dry run, requires exact destructive confirmation, and
collects separate login and LUKS passphrases. See the runbook before using it.

## Apple Silicon / nix-darwin skeleton

`darwinConfigurations.macbook` targets `aarch64-darwin` and shares only
platform-neutral Nix, flakes, zsh, Git, eza, jq, and aliases. The separate
[Homebrew layer](./darwin/homebrew.nix) installs Ghostty, Chromium, and Bitwarden
without automatic upgrades. Hyprland, Quickshell, SDDM, Wayland bindings, and
Linux systemd services are never imported into the macOS profile.

After replacing the placeholder `macUserName`, the intended activation command
is:

```sh
sudo nix run nix-darwin/master#darwin-rebuild -- \
  switch --flake .#macbook
```

## Next steps

- Complete the physical-laptop runbook and validate Wi-Fi, audio, suspend,
  AMD/NVIDIA PRIME, and thermals.
- After several stable LUKS-passphrase boots, complete Lanzaboote, recovery
  material, and TPM2 auto-unlock.
- Continue refining Control Center, Weather, and tray behavior without importing
  Arch/Omarchy runtime mutation or update mechanisms.
