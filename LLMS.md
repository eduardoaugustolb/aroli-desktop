# Operating guide for AI agents — Umbra Liminal

This document defines how agents should install, audit, and fix Umbra
Liminal without taking control away from the user. Safety and privacy take
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
  `~/.cache/umbra-liminal/update.json`. No telemetry, no identifiers,
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
Liminal identity. Every new package must be classified as essential or
optional; when in doubt, treat it as optional.
