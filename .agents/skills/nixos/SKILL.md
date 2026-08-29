---
name: nixos
description: Work on this repository's NixOS, Home Manager, Hyprland, flake, host, and system configuration tasks. Use when inspecting or editing /home/retraut/.config/nixos or when the user asks about this NixOS setup.
metadata:
  short-description: Maintain and verify the personal NixOS configuration
---

# NixOS repository workflow

This skill applies to the personal NixOS configuration at `/home/retraut/.config/nixos`.

## Operating boundary

- The user always performs the actual rebuild or activation themselves.
- Codex may inspect files, edit the configuration when requested, and run non-mutating validation.
- Codex must not run `nixos-rebuild switch`, `boot`, or `test`; must not invoke `sudo` or `pkexec` for activation; and must not run installation, partitioning, formatting, Disko, or other destructive system operations.
- When a change is ready, report what was checked and give the exact command the user can run manually. Treat that command as a handoff, not as permission to execute it.

## Repository facts

- The flake is `/home/retraut/.config/nixos/flake.nix`.
- NixOS outputs are `nixosConfigurations.nixos` for the VM and `nixosConfigurations.laptop` for the physical ASUS GA503QS laptop.
- The normal laptop activation command is:

  `sudo nixos-rebuild switch --flake /home/retraut/.config/nixos#laptop`

- The stable VM activation target is `#nixos`.
- `darwinConfigurations.macbook` is the separate nix-darwin profile and should not receive Linux desktop modules.
- The repository's helper `scripts/nixos-rebuild` is an activation wrapper; inspect or edit it when needed, but do not execute it as Codex.

## Verification workflow

Choose checks appropriate to the requested change. Prefer read-only checks such as:

In the Codex sandbox, keep Nix's writable cache under `/tmp` because the user's
home cache may not be writable there. Use this prefix for Nix checks:

`env XDG_CACHE_HOME=/tmp/codex-nixos-cache`

For example:

- `env XDG_CACHE_HOME=/tmp/codex-nixos-cache nix flake check /home/retraut/.config/nixos`
- `env XDG_CACHE_HOME=/tmp/codex-nixos-cache nix flake show /home/retraut/.config/nixos`
- `env XDG_CACHE_HOME=/tmp/codex-nixos-cache nix eval --raw /home/retraut/.config/nixos#nixosConfigurations.laptop.config.system.stateVersion`
- `env XDG_CACHE_HOME=/tmp/codex-nixos-cache nix build --no-link /home/retraut/.config/nixos#nixosConfigurations.<host>.config.system.build.toplevel`

If the sandbox cannot access `/nix/var/nix/daemon-socket/socket` or the Nix
store database, retry the same read-only check with the sandbox escalation
request. Do not use `NIX_REMOTE=local` as a workaround and do not broaden the
permission request to activation commands.

Building a derivation is verification only; never switch to or boot the result. If a check needs network access, elevated permissions, or would mutate the running system, stop and ask the user to run it or explicitly provide a safe alternative.

## Rebuild-triggered restarts for long-running user services

- When a `systemd.user` service runs a binary built by Nix, set `Service.ExecStart` to the concrete store path (`${package}/bin/program`), not to a stable Home Manager symlink such as `%h/.local/bin/program`.
- A stable symlink does not change the generated unit when the package is rebuilt, so systemd may keep the old long-running process alive after activation. A store path changes with the derivation and causes Home Manager to reload the changed unit and restart the service during the rebuild.
- The symlink under `.local/bin` may still be installed for interactive/manual invocation, but it must not be the service's `ExecStart` target.
- Keep `Restart=on-failure` (or the service-appropriate policy) for crash recovery; it does not replace the rebuild-triggered unit change.

Before editing, inspect the relevant module imports and host target. Preserve the separation between VM-only settings in `hosts/vm.nix`, laptop-specific settings in `hosts/laptop.nix`, and shared modules. Be especially cautious with `hosts/laptop-disko.nix`: its disk layout is destructive and must never be executed as part of validation.

In the final handoff, summarize changed files, checks and their results, any remaining warnings, and the manual activation command when relevant.
