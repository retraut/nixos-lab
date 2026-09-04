---
name: codex
description: Update or pin the declaratively installed Codex CLI in this NixOS configuration.
metadata:
  short-description: Maintain the pinned Codex CLI package
---

# Codex CLI in this NixOS configuration

Use this skill when the user asks to update, pin, verify, or troubleshoot the
Codex CLI package managed by this repository.

## Package layout

- Package definition: `/home/retraut/.config/nixos/codex.nix`
- Update helper: `/home/retraut/.config/nixos/scripts/update-codex`
- Laptop flake target: `/home/retraut/.config/nixos#laptop`

The package installs the official prebuilt x86_64 Linux CLI and
`codex-code-mode-host` archives. Keep both archive hashes pinned in
`codex.nix`.

## Update to the latest release

Run the repository helper through Bash:

```bash
bash /home/retraut/.config/nixos/scripts/update-codex
```

The helper discovers the latest `rust-v*` GitHub release, prefetches both
required archives, calculates their Nix SHA256 hashes, updates `codex.nix`,
and verifies the laptop system build. If the build fails, it restores the
previous `codex.nix`.

## Pin a specific release

Pass the complete release tag, including the `rust-v` prefix:

```bash
bash /home/retraut/.config/nixos/scripts/update-codex rust-v0.153.3
```

Do not run `nixos-rebuild switch`, `boot`, or `test` as part of the update.
After the helper succeeds, the user can activate the result manually:

```bash
sudo nixos-rebuild switch --flake /home/retraut/.config/nixos#laptop
codex --version
```
