# Changelog — Umbra Noctis

All notable changes to this rice are documented here, newest first.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and version numbers follow [Semantic Versioning](https://semver.org/):

- `MAJOR`: breaking change (new Hyprland requirement, removed phase,
  renamed deployed path, config format that old installs cannot read).
- `MINOR`: new feature that stays compatible (new panel, script, package,
  translation, optional).
- `PATCH`: fix or docs with no behavior change for existing installs.

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
