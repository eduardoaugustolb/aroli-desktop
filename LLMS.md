# Operating guide for AI agents — Umbra Noctis

This document defines how agents should install, audit, and fix Umbra
Noctis without taking control away from the user. Safety and privacy take
precedence over convenience.

## Non-negotiable principles

1. **Inspect before changing.** Run diagnostics and dry-run mode before
   installing, migrating, enabling services, or editing configurations.
2. **Explicit consent for material effects.** Ask for authorization before
   using sudo/pkexec, installing or removing packages, enabling services,
   writing to `/etc`, changing the wallpaper, re-logging/restarting the
   session, or sending any data over the network.
3. **No automatic bloatware.** The `packages/optional-*.txt` files
   contain optional apps and tools. Each package requires individual
   confirmation; `--yes`, CI, and non-interactive runs must skip them.
4. **Privacy by default.** Do not read, print, store, send, or version
   keys, tokens, passwords, cookies, history, browser profiles, messaging
   data, or files in `~/.ssh`, `~/.gnupg`, `~/.config/gh`, and the like.
5. **Never edit `/usr/share/omarchy/`.** Use only user paths and
   official Omarchy mechanisms.
6. **No destructive actions without a confirmed target and reason.** Prefer
   verifiable backup, Trash, and reversible operations.

## Relevant structure

| Path | Purpose |
| --- | --- |
| `install.sh` | Phased installer; use `--dry-run` first. |
| `diagnose` | Read-only diagnostics. |
| `packages/pacman.txt` | Required rice base. |
| `packages/optional-*.txt` | Opt-in items, never default. |
| `home/` | Files to be linked or copied into `$HOME`. |
| `home/.local/bin/rice` | Version, update, rollback, and cleanup CLI (`rice --help`). |
| `VERSION` / `CHANGELOG.md` | Single source of truth for the version and per-release history. |
| `home/Pictures/wallpapers/` | Default wallpapers shipped by the rice. |
| `scripts/migrate-from-legacy-rice.sh` | Safe migration from the legacy fork. |
| `OMARCHY.md` | Compatibility contract with Omarchy. |

## Safe install flow

```sh
# 1. Audit with no writes.
./diagnose
./install.sh --dry-run --lang pt-BR

# 2. Only after the user's explicit approval.
./install.sh --lang pt-BR
```

Do not use `--yes` as a substitute for human choice for optional packages. If
the user wants an optional package, show the name, purpose, origin (official
repository or AUR), relevant dependencies, and estimated size before
installing.

## Safe migration flow

```sh
# Changes nothing.
./scripts/migrate-from-legacy-rice.sh

# Only after the user approves the symlink list.
./scripts/migrate-from-legacy-rice.sh --apply
```

The script keeps the legacy clone intact. Do not remove the old directory or
delete backups without an explicit request.

## Auditing and fixing

Start with write-free commands:

```sh
omarchy debug --no-sudo --print
hyprctl configerrors
systemctl --user is-active quickshell
./diagnose
git status --short
```

Before fixing, explain the likely cause, target files, expected effect, and
how to revert. After a Hyprland change, validate with `hyprctl reload` and
`hyprctl configerrors`. After changing the shell, check that `quickshell`
is still active. Do not use `omarchy refresh` without confirmation: it
replaces user configurations, although it creates a backup.

## Network and data

- Wallpaper downloads, updates, clones, and AUR queries require
  explicit consent, with ONE declared exception: the daily timer
  `rice-update-check.timer` (enabled by the installer) transfers a few
  KB (`git ls-remote --tags` or a conditional GET against the GitHub
  releases API, with ETag) once a day and only writes
  `~/.cache/umbra-noctis/update.json`. No telemetry, no identifiers,
  no cached response body. To turn it off:
  `systemctl --user disable rice-update-check.timer`. `rice update`,
  `rice rollback`, and `rice prune --apply` never run on their own: they
  require the command (and confirmation, except for the user's explicit
  `--yes`).
- Do not send complete diagnostic reports to external services; strip
  usernames, personal paths, IP addresses, SSIDs, and identifiers.
- Do not add telemetry, analytics, remote plugins, or background
  processes without a clear, reversible user choice.

## Contributions

Preserve [LICENSE](LICENSE), the upstream attribution, and the Umbra
Noctis identity. Every new package must be classified as essential or
optional; when in doubt, treat it as optional.

## Recommended CLI-first workflow

`rice` is the supported interface for people and agents. Do not invoke
`install.sh` directly unless debugging the installer implementation or the CLI
is unavailable. The CLI can bootstrap the checkout in
`~/.local/share/umbra-noctis`, keeps its binary in `~/.local/bin/rice`, and
presents the same safe installer phases.

```sh
# First run: inspect only. This does not install packages or edit files.
rice install --dry-run --lang pt-BR

# After explicit user authorization for package, sudo, and configuration work.
rice install --lang pt-BR

# Continue an interrupted installation; completed checkpointed phases are skipped.
rice install --resume

# Read the most recent local install record, or enumerate older records.
rice logs
rice logs --list
```

The no-argument `rice` terminal assistant is appropriate for a user who wants
help choosing an action. For an agent or an unattended instruction, use an
explicit subcommand so the requested side effect is auditable.

### Package-manager policy

On Omarchy, use its package interface only: `omarchy-pkg-add` for official
packages, `omarchy-pkg-aur-add` for AUR packages, and `omarchy-update` for a
full system update. `rice` detects these commands and delegates to them. Do
not bypass Omarchy with direct `pacman -Syu`, do not edit
`/usr/share/omarchy/`, and do not disable its package hooks. On plain Arch,
`rice` falls back to `pacman` and `yay`.

Optional software is never part of the normal install result. First show the
catalog, then obtain approval for each selected package:

```sh
rice plugins list
rice plugins install --dry-run btop
rice plugins install btop
```

Treat AUR software as a materially different trust decision. State that it is
from the AUR before executing it, even when `rice` has already classified it.

## Agent decision procedure

1. Establish whether the rice is installed with `rice status`; if it is not,
   use `rice install --dry-run` and do not clone or install until authorized.
2. Run `rice diagnose` and the dry-run before a first installation, repair, or
   post-update reapply. Read the plan for disk, network, sudo, package source,
   and `/etc` effects.
3. Ask for a single explicit confirmation that names the material effects:
   package installation, sudo writes, services, network download, and any
   selected optional/AUR package. Never treat “continue” as permission for an
   optional package the user did not name.
4. On success, report the installed rice version (`rice status`), the backup
   path printed by the installer when applicable, the install-log path, and
   the required reboot/log-out. Do not reboot, reload Hyprland, or enable a
   new service without separate approval.
5. On failure, stop at the failed phase. Preserve the checkout, backup,
   checkpoint, and log; do not retry a large package transaction blindly.
   Report the exact failed command/phase and offer the smallest safe next
   command below.

## Failure playbook

| Situation | Read-only evidence | Safe next action after approval | Do not do |
| --- | --- | --- | --- |
| Network or mirror download failed | `rice logs`, `ping -c1 archlinux.org`, package-manager error | Restore connectivity or refresh mirrors, then `rice install --resume` | Re-run all phases repeatedly or delete package caches without approval. |
| Disk-space preflight failed | `df -h "$HOME"`, `rice logs` | Ask the user to free at least the stated headroom, then resume | Delete user files, caches, or backups on the agent's initiative. |
| AUR/yay failure | `rice logs`, `command -v omarchy-pkg-aur-add`, `command -v yay` | Complete only the missing AUR/helper prerequisite, then resume | Replace an AUR package with a different package without consent. |
| Sudo or Omarchy package hook rejected work | Exact command output, `omarchy-version` when available | Explain the required authorization or use the Omarchy package command | Work around Omarchy hooks or write beneath `/usr/share/omarchy/`. |
| Configuration, SDDM, Hyprland, or Quickshell fails after install | `rice diagnose`, `hyprctl configerrors`, `systemctl --user status quickshell` | Fix the smallest identified cause and re-run its named phase | Run `restore`, remove symlinks, or reboot automatically. |
| Interrupted install | `rice logs`, `~/.local/state/umbra-noctis/install.checkpoint` | `rice install --resume` after cause is fixed | Delete the checkpoint; it is the recovery record. |
| CLI update verification fails | `rice cli update --dry-run`, release/checksum error | Keep the current binary and report the integrity failure | Install an unchecked binary or disable SHA-256 validation. |

`rice update` updates the rice checkout and reapplies it. `rice cli update`
updates only the Go CLI binary after verifying the published SHA-256 checksum.
They are distinct operations; explain which one is needed before running either.

## Completion criteria

A successful installation is not merely a zero exit code. Confirm all of the
following before reporting completion:

- the requested phases completed and `rice status` locates the checkout;
- no installer checkpoint remains, unless the user deliberately stopped before
  completion;
- `rice diagnose` has no new blocking failure attributable to the install;
- the user knows whether to reboot or log out for groups, drivers, or SDDM;
- optional packages were installed only when individually named and approved;
- no secrets, diagnostics containing identifiers, or local logs were sent off
  the machine.
