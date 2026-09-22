---
name: aroli-install
description: >
  Use for installing, updating, migrating, or cleaning Aroli Desktop:
  install.sh phases, dry-run, rice CLI (aroli command), legacy migration
  from umbra-noctis, leftover checkouts, residues, backups, rollback.
  Triggers: install, update, upgrade, migrate, migration, umbra-noctis,
  legacy rice, residues, leftovers, cleanup, rollback, restore, phases,
  dry-run, aroli CLI, install.sh, config phase, spicetify phase.
---

# Install / update / migrate

Entry points: `./install.sh` (phases, default `--link`), `aroli`
(the CLI: `status | check | update | rollback | prune`), `./diagnose`
(read-only). Docs: `docs/MIGRATION.md`, `LLMS.md` (safe flows).

## Laws (from hard experience on this machine)

- `./install.sh -n` (dry-run) and `./diagnose` before anything that
  writes. Full runs need sudo and a terminal: never run them headless,
  never pass `-y` for the user by default.
- `config` lays `home/` into `$HOME` (symlinks, with `save_aside`
  backups to `~/.dotfiles-backup`). It also moves legacy runtime dirs
  (`umbra-noctis` → `aroli-desktop`) and deploys `agents/skills` to
  `~/.agents/skills`.
- `spicetify` needs `/opt/spotify` writable (ACL, sudo once) and applies
  `current_theme aroli color_scheme pywal`. See `aroli-spotify` when it
  complains.
- `final` regenerates the palette from the first wallpaper alphabetically:
  re-apply the user's wallpaper afterwards with `set-wallpaper.sh`.
- Migration: `scripts/migrate-from-legacy-rice.sh` (plan first, `--apply`
  second, explicit `--source/--target` when the checkout is not default).
  Keep the legacy clone intact unless the user explicitly says to remove
  it; if removal is requested, tarball it to `~/.audit-backups/<date>/`
  first, including uncommitted work.
- `rice prune` previews en-US rename leftovers; `--apply` moves them to
  trash with backup. Never delete `~/.dotfiles-backup` dirs unasked:
  they are the rollback, even when their symlinks dangle.
- `VERSION` is the single source of truth; releases are `vX.Y.Z` tags
  plus GitHub Releases (CI attaches binaries + checksums).
