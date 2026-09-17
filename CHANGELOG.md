# Changelog — Umbra Noctis

All notable changes to this rice are documented here, newest first.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and version numbers follow [Semantic Versioning](https://semver.org/):

- `MAJOR`: breaking change (new Hyprland requirement, removed phase,
  renamed deployed path, config format that old installs cannot read).
- `MINOR`: new feature that stays compatible (new panel, script, package,
  translation, optional).
- `PATCH`: fix or docs with no behavior change for existing installs.

## [Unreleased]

### Added

- Release and update system: `VERSION` as the single source of truth,
  `rice` CLI (`version`, `status`, `check`, `update`, `rollback`, `prune`),
  background check via systemd user timer (24 h, idle priority, zero
  resident processes), and update badge in the shell (reads a local cache
  file only, no extra polling).

## [1.0.0] - 2026-09-17

### Added

- First versioned release of Umbra Noctis. Everything before this tag is
  unversioned history; from here on every user-visible change lands under
  a `vX.Y.Z` tag with release notes.
