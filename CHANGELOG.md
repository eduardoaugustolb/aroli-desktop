# Changelog — Umbra Noctis

All notable changes to this rice are documented here, newest first.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and version numbers follow [Semantic Versioning](https://semver.org/):

- `MAJOR`: breaking change (new Hyprland requirement, removed phase,
  renamed deployed path, config format that old installs cannot read).
- `MINOR`: new feature that stays compatible (new panel, script, package,
  translation, optional).
- `PATCH`: fix or docs with no behavior change for existing installs.

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

## [Unreleased]

## [1.0.0] - 2026-09-17

### Added

- First versioned release of Umbra Noctis. Everything before this tag is
  unversioned history; from here on every user-visible change lands under
  a `vX.Y.Z` tag with release notes.
