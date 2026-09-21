# Changelog, Aroli Desktop

All notable changes to this rice are documented here, newest first.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and version numbers follow [Semantic Versioning](https://semver.org/):

- `MAJOR`: breaking change (new Hyprland requirement, removed phase,
  renamed deployed path, config format that old installs cannot read).
- `MINOR`: new feature that stays compatible (new panel, script, package,
  translation, optional).
- `PATCH`: fix or docs with no behavior change for existing installs.

## [3.0.0] - 2026-09-21

### Changed

- Product rebrand: Umbra Noctis is now **Aroli Desktop**
  (`github.com/eduardoaugustolb/aroli-desktop`), the desktop product of the
  Aroli family. The `rice` binary name is unchanged. `install.sh config`
  migrates `~/.local/share/umbra-noctis`, `~/.local/state/umbra-noctis` and
  `~/.cache/umbra-noctis` to their `aroli-desktop` counterparts (nothing is
  copied when the new location already exists), and `rice export`/`import`
  reads the legacy `umbra-preferences.json` when `aroli-preferences.json`
  is absent. `AROLI_DESKTOP_REPO` replaces `UMBRA_RICE_REPO` (still honored
  as a fallback).

Historical entries below keep the Umbra Noctis name as published.

- Follow the upstream `umbra` → `aroli` rename
  (`github.com/eduardoaugustolb/aroli`): the `cursor` phase clones the new
  repo, builds `themes/cursor/aroli` and installs `~/.local/share/icons/Aroli`
  (`Aroli Pointer`). Configs (`hyprland.lua`, `hyprland.conf`, GTK 2/3/4)
  point at `Aroli`; the legacy `~/.local/share/icons/Umbra` is moved to
  `Umbra.bak` after a successful install.
- Bundled wallpapers renamed to Aroli Backdrops following upstream:
  `aroli-ember-coast.png`, `aroli-obsidian-dunes.png`,
  `aroli-silent-threshold.png`, `aroli-black-mountains.png`
  (was `umbra-ink-mountains.png`). `install.sh config` renames the live
  copies in `~/Pictures/wallpapers` and fixes the `~/.cache/wal/wal` pointer
  instead of duplicating files.
- `home/.local/bin/aroli-cursor-size` is the canonical cursor-size tool;
  `umbra-cursor-size` remains as a deprecated shim. `build-umbra-hyprcursor.sh`
  is now `build-aroli-hyprcursor.sh` (with fallback to the old `Umbra` source
  dir when present).

## [2.3.2] - 2026-09-21

### Fixed

- Shell tool PATHs no longer vanish on every rice install (`bun: command
  not found`). The deployed rcs only carried `~/.local/bin`, and being
  symlinks into the repo, any `export PATH` an installer (bun, rustup,
  mise) appended to them was lost on the next `install.sh config` /
  `rice update`. `.zshrc`, `.profile`, `.bashrc` and `.zprofile` now build
  the standard tool PATHs themselves (`~/.bun/bin` honoring `$BUN_INSTALL`,
  `~/go/bin`, `~/.cargo/bin`, mise shims last like upstream Omarchy),
  `zsh`/`bash` activate mise when present, and personal overrides live in
  `~/.zshrc.local` / `~/.bashrc.local` / `~/.zprofile.local` /
  `~/.profile.local`, seeded once by the installer, never touched by
  updates. `install.sh` also rescues surviving tool-PATH lines from a
  replaced rc file into its `*.local` counterpart instead of dropping them.

## [2.3.1] - 2026-09-20

### Fixed

- `rice update` hands over to the target release's own updater (extracted
  from git without touching the worktree), so updater fixes apply to the
  very update that delivers them, an old backend can no longer block its
  own replacement. Tags without a usable updater are refused, and an
  unreachable remote falls back to the checkout's updater.

## [2.3.0] - 2026-09-20

### Fixed

- `rice update` and `rice rollback` no longer refuse to run over a dirty
  checkout. Files the desktop rewrites on its own (`kdeglobals`, spicetify
  colors) are reset, they rebuild on the next wallpaper/theme change, and
  anything else is stashed automatically and restored after the checkout.
  Changes that do not re-apply cleanly stay in the stash, never deleted.
- The installer reloads a live Hyprland session at the end of the `final`
  phase, so an update can no longer leave a stale config-error banner (e.g.
  "cannot open hyprland.lua" caught mid-checkout) parked on screen.

### Added

- Login update notice (`rice-update-notify.service`, enabled by default):
  reads only the update cache on graphical login, no network, oneshot,
  idle priority, and shows one desktop notification per pending release.
  Disable with `systemctl --user disable rice-update-notify.service`; the
  daily check is now also nag-once-per-release instead of once per day.
- The Omarchy mark (bar logo and Settings › About header) is tinted with
  the wallpaper accent via `MultiEffect` colorization, so it follows the
  palette like the Arch glyph already did. Untinted images stay untouched:
  the tint only applies when `BarItem.imageTint` is set.

### Changed

- Faster terminal startup: the first-kitty detection is one `hyprctl`
  call instead of two (workspace derived from `$PPID`, no `ps` fork),
  sprite transcoding moved to the background on cache miss, and
  OMZ/plugins/theme are byte-compiled (`zcompile`, refreshed only when
  sources change).

## [2.2.0] - 2026-09-20

### Added

- Quick-app keybinds with `launch-*.sh` helpers honoring system defaults
  with rice fallbacks: `Super+T` / `Super+Alt+T` (terminal), `Super+Alt+M`
  (Spotify), `Super+Alt+D` (Discord), and `Super+Alt+C` (default text
  editor).
- Update-safe Hyprland user override layer (`user.lua` / `user.conf` seeded
  once from `.example` templates and loaded last), with dirty-tree guard
  messaging and prune protection in `install.sh`.
- Settings shortcuts panel now parses keybinds from both the base and user
  override files with shared variables, plus pt-BR/es translation updates.

## [2.1.0] - 2026-09-19

### Added

- Configurable wallpaper palette intensity (0-4 slider): level 0 keeps the
  stable Umbra surfaces, level 4 reproduces the previous raw pywal output,
  and existing `paletteMode` settings migrate to the matching endpoint so
  no one's desktop changes on upgrade.
- Full configurable Umbra palette system: `Wallpaper`, `Umbra`, `Hybrid`,
  and `Manual` presets, manual canvas/surface/text/accent tokens with
  capture and restore, saturation and minimum-contrast guards, and
  independent scopes for shell, terminal, GTK/Qt, and Hyprland.
- Quickshell threshold lock screen (WlSessionLock + PAM card with morph
  badge, pill input, caps/num states, and pt-BR/es translations) replacing
  the hyprlock session island. Lock entry points (idle, power menu,
  launcher, `Super+L`) go through `loginctl`; the hyprlock binary stays
  installed for the remote/RustDesk profile.
- Consolidated adaptive desktop controls: unified hypridle normal/remote
  profiles, Umbra XCursor build with text-cursor aliases and live apply,
  and expanded network, Bluetooth, and system settings panels.

### Fixed

- Declared the runtime shell dependencies in `packages/pacman.txt`.
- Kept the Umbra threshold treatment out of expanded panels and removed
  the broken threshold notch treatment.

### Changed

- The remote profile now runs hyprlock with its built-in defaults (the
  session lock-preference sync script left with the hyprlock island).

## [2.0.0] - 2026-09-17

### Added

- Coordinated session profiles, recovery, preference export/import, and
  explicit rules between Game Mode, Reading Mode, and Power Saver.
- A reversible Game Mode toggle in the Control Panel and `rice gaming`.
- A Power Profile selector in the Control Panel, System Settings, and `rice
  battery` for power-saver, balanced, and supported performance modes.
- A read-only smoke-test release gate and a 2.0 compatibility guide.

## [1.1.7] - 2026-09-17

### Fixed

- Release asset uploads now remove stale assets before re-uploading, avoiding
  GitHub's duplicate asset name validation errors.

## [1.1.6] - 2026-09-17

### Fixed

- TUI actions now suspend Bubble Tea while running, allowing native `sudo`
  password prompts and other interactive commands to receive terminal input.
- Release publication is idempotent and no longer relies on a hanging upload
  action.

## [1.1.5] - 2026-09-17

### Fixed

- Plugin discovery now runs asynchronously with a loading state, cancellation
  path, and a 45-second network timeout instead of blocking the TUI.

## [1.1.4] - 2026-09-17

### Fixed

- Suppressed temporary repository clone output at the subprocess level so it
  cannot leak into the Bubble Tea screen.

### Changed

- Added screen titles and breadcrumbs throughout the TUI navigation flow.

## [1.1.3] - 2026-09-17

### Fixed

- Kept plugin catalog bootstrap and repository cloning out of the Bubble Tea
  screen while opening the plugin manager.

## [1.1.2] - 2026-09-17

### Fixed

- Prevented installer and diagnostic output from corrupting the Bubble Tea
  alternate screen while actions run inside the TUI.

## [1.1.1] - 2026-09-17

### Fixed

- `rice cli update` now replaces the executable actually selected by the
  current shell, including installations managed through Go or mise.

## [1.1.0] - 2026-09-17

### Added

- Go `rice` CLI with a guided terminal interface, individual optional-package management (`rice plugins list` and `rice plugins install`), verified self-updates, resumable installation checkpoints, and persistent install logs.

- Release and update system: `VERSION` as the single source of truth,
  `rice` CLI (`version`, `status`, `check`, `update`, `rollback`, `prune`),
  background check via systemd user timer (24 h, idle priority, zero
  resident processes), and update badge in the shell (reads a local cache
  file only, no extra polling).

### Changed

- Replaced the numeric first-run menu with a keyboard-driven Bubble Tea v2
  interface using Charm styling, plugin selection, confirmations, and action
  feedback.
- Added Linux amd64 and arm64 CLI release binaries with SHA-256 verification.

## [1.0.0] - 2026-09-17

### Added

- First versioned release of Umbra Noctis. Everything before this tag is
  unversioned history; from here on every user-visible change lands under
  a `vX.Y.Z` tag with release notes.
