# Updating Codex CLI

`codex.nix` installs the official prebuilt x86_64 Linux binaries from the
Codex GitHub release: the CLI and its `codex-code-mode-host` companion. It
does not compile Rust or download Cargo dependencies.

## Update

```bash
cd ~/.config/nixos
bash ./scripts/update-codex
```

The helper reads the latest `rust-v*` release tag from GitHub, downloads the
matching Linux archives to calculate their SHAs, updates `codex.nix`, and
verifies the complete NixOS build. To pin a specific release:

```bash
bash ./scripts/update-codex rust-v0.153.3
```

After a successful update, activate it with:

```bash
sudo nixos-rebuild switch --flake .#laptop
codex --version
```

The version and SHA remain pinned so rebuilds stay reproducible; the helper
means they do not need to be edited manually.
