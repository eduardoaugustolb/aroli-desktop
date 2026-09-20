<h1 align="center">Umbra Noctis</h1>

<p align="center">
  A premium visual layer for <strong>Omarchy</strong>, Arch Linux, Hyprland, and Quickshell.<br>
  Dark by nature. Personal by wallpaper. Yours by choice.
</p>

<p align="center">
  <a href="https://github.com/eduardoaugustolb/umbra-noctis/stargazers"><img src="https://img.shields.io/github/stars/eduardoaugustolb/umbra-noctis?style=flat-square&color=8b7cff&label=stars" alt="GitHub stars"></a>
  <a href="https://github.com/eduardoaugustolb/umbra-noctis/releases"><img src="https://img.shields.io/github/v/release/eduardoaugustolb/umbra-noctis?display_name=tag&style=flat-square&color=8b7cff&label=release" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/eduardoaugustolb/umbra-noctis?style=flat-square&color=8b7cff" alt="GPL-3.0 license"></a>
  <a href="https://github.com/eduardoaugustolb/umbra-noctis/actions"><img src="https://img.shields.io/github/actions/workflow/status/eduardoaugustolb/umbra-noctis/release.yml?style=flat-square&label=build" alt="Build status"></a>
</p>

<p align="center">
  <a href="#installation">Install</a> ·
  <a href="#the-threshold">The threshold</a> ·
  <a href="#privacy-and-control">Privacy</a> ·
  <a href="OMARCHY.md">Omarchy</a> ·
  <a href="LLMS.md">LLMS</a>
</p>

---

## The threshold

**Umbra Noctis** is the visual layer of the Umbra workspace on top of the
stable Omarchy base. “Noctis” evokes its nocturnal, premium visual language:
the rice keeps the structure — notch, dark surfaces, cutouts, and luminance
bands — while each wallpaper sets the mood with Pywal.

The dark foundation is fixed: depth, negative space, and contrast remain
Umbra. Your wallpaper supplies the accent palette, so the result changes with
your image without turning every application surface into its dominant colour.

| Base | Umbra surface | Your choice |
| --- | --- | --- |
| Omarchy · Arch · Hyprland | Quickshell, notch, and dynamic palette | Wallpaper, language, and optionals |

<p align="center">
  <a href="https://github.com/eduardoaugustolb/umbra-noctis/commits/main"><img src="https://img.shields.io/github/commit-activity/m/eduardoaugustolb/umbra-noctis?style=flat-square&color=8b7cff&label=community%20activity" alt="Monthly commit activity"></a>
  <a href="https://github.com/eduardoaugustolb/umbra-noctis/issues"><img src="https://img.shields.io/github/issues/eduardoaugustolb/umbra-noctis?style=flat-square&color=8b7cff&label=issues" alt="Open issues"></a>
  <a href="https://github.com/eduardoaugustolb/umbra-noctis/network/members"><img src="https://img.shields.io/github/forks/eduardoaugustolb/umbra-noctis?style=flat-square&color=8b7cff&label=forks" alt="GitHub forks"></a>
</p>

<p align="center">
  <img src="home/Pictures/wallpapers/umbra-ember-coast.png" alt="Ember Coast — bundled wallpaper" width="49%">
  <img src="home/Pictures/wallpapers/umbra-obsidian-dunes.png" alt="Obsidian Dunes — bundled wallpaper" width="49%">
</p>

## What ships with Noctis

- Complete Quickshell interface, with notch, launcher, panels, and overview.
- Interface translation in **Brazilian Portuguese** and ABNT2 keyboard layout.
- **Umbra** cursor and visual identification of the active platform: Omarchy on
  Omarchy, Arch on Arch.
- Pywal accents extracted from the current wallpaper, applied over stable dark
  Umbra surfaces. Settings › Appearance › Colour system can restore the legacy
  mode where the wallpaper also tints application backgrounds.
- Four Umbra wallpapers installed with the rice: Ember Coast, Silent
  Threshold, Obsidian Dunes, and Ink Mountains.
- Assisted migration for installs coming from the previous fork.

Change the cursor size consistently across Hyprland and GTK with
`umbra-cursor-size 40`. Values from 16 to 96 are accepted; relog afterwards
so already-running applications reload the XCursor.

<details>
<summary><strong>See the rice in motion</strong></summary>
<br>

[Open video demo](https://github.com/user-attachments/assets/2b35a6fb-5a08-4539-99a9-7c525eb463b3)

</details>

## Installation

> [!IMPORTANT]
> Read the plan before writing to the system. Dry-run mode changes no files,
> installs no packages, and asks for no privileges.

> [!TIP]
> `rice` is the recommended installation path. It gives first-time users a guided
> terminal assistant, while the explicit subcommands remain suitable for automation.

```sh
# Stable version (recommended) — prebuilt binary from GitHub Releases
# Note: versioned `go install ...@vX.Y.Z` does not work for v2+ releases
# because the module intentionally has no `/v2` suffix; use the binary.
arch="$(uname -m)"; case "$arch" in x86_64) arch=amd64;; aarch64|arm64) arch=arm64;; esac
curl -fL "https://github.com/eduardoaugustolb/umbra-noctis/releases/latest/download/rice-linux-$arch" -o ~/.local/bin/rice
chmod +x ~/.local/bin/rice

# Or install from the current main branch (Go 1.27+, development version)
go install github.com/eduardoaugustolb/umbra-noctis/cmd/rice@main

# Opens a guided terminal interface for first-time users
rice

# Or use the non-interactive commands
rice install --dry-run --lang pt-BR
rice install --lang pt-BR
```

Requires **Hyprland 0.56+**. This rice uses `hyprland.lua`, not
`hyprland.conf`.

| Command | Result |
| --- | --- |
| `rice` | Opens the guided terminal interface. |
| `rice install --dry-run --lang pt-BR` | Shows the plan without changing anything. |
| `rice install --lang pt-BR` | Installs the rice in Brazilian Portuguese. |
| `rice install restore` | Restores the previous configuration files. |
| `rice diagnose` | Read-only diagnostics. |
| `rice doctor` | Checks the local desktop integration; `--fix` offers safe session repairs. |
| `rice status` | Installed version, last check, and rollback ref. |
| `rice profile list` | Lists curated, transparent installation profiles. |
| `rice profile install creator` | Installs a named set of phases; its optional apps remain visible and confirmable. |
| `rice snapshot create before-tweaks` | Saves the supported visual configuration paths locally. |
| `rice snapshot restore before-tweaks` | Restores a configuration snapshot while retaining the current files as backups. |
| `rice wallpaper list` | Lists bundled and imported wallpapers. |
| `rice wallpaper set umbra-ember-coast.png` | Applies a wallpaper and its dynamic Pywal palette. |
| `rice gaming on` | Temporarily disables expensive compositor effects, preserving their exact previous state. |
| `rice gaming launch steam` | Runs a game under GameMode when the optional `gamemode` package is installed. |
| `rice battery set power-saver` | Selects the Power Profiles Daemon energy-saver profile. |
| `rice battery balanced` | Selects the balanced profile; `performance` is available when supported by the hardware. |
| `rice session apply laptop` | Applies a coordinated daily-use profile. |
| `rice recover --snapshot latest` | Recovers stuck modes and can restore the newest local snapshot. |
| `rice export ~/umbra-preferences` | Exports portable visual preferences without credentials or personal data. |
| `rice update --dry-run` | Shows the update plan without changing anything. |
| `rice prune` | Lists files retired by the latest release (nothing is deleted without `--apply`). |
| `rice plugins list` | Lists optional applications and tools that can be installed later. |
| `rice plugins install btop` | Installs only the selected optional item, after confirmation. |
| `rice cli update --dry-run` | Checks the CLI release and its verified binary update plan. |
| `rice cli update` | Updates only the CLI binary after verifying SHA-256. |
| `rice install --resume` | Continues from the last successfully completed installation phase. |
| `rice logs` | Shows the last 100 lines of the latest installation log. |

## Updates

The rice follows **stable tags** (`vX.Y.Z`, SemVer) — never `main` —
and notifies you on its own when a release lands on GitHub:

- A daily timer (`rice-update-check.timer`, idle priority, no
  resident process) transfers a few KB and writes
  `~/.cache/umbra-noctis/update.json`. The bar/notch shows a dot
  and `Settings > About` shows the version seen.
- A login notice (`rice-update-notify.service`) reads only that cache file —
  no network, exits in milliseconds — and shows one desktop notification per
  release when an update is pending.
- Updating is always your own act: `rice update --dry-run` shows the plan,
  `rice update` asks for confirmation, records the rollback point, and re-runs
  the installer. Local changes are stashed automatically and restored
  afterwards, so files the desktop rewrote on its own never block the update.
  `rice rollback` undoes it. `rice prune --apply` moves
  leftovers to the Trash (with backup), never deletes directly — and never
  touches files you modified.
- To turn off the notices (the cache, the dot, and `rice status` keep working):
  `systemctl --user disable rice-update-check.timer rice-update-notify.service`.
Details and history in [CHANGELOG.md](CHANGELOG.md).

## Privacy and control

Noctis does not decide your desktop for you.

- Extra apps never come by default: each item in
  `packages/optional-*.txt` requires individual confirmation.
- Runs with `--yes`, CI, or no terminal **do not install unselected
  optionals**; named items and documented profiles remain explicit choices.
- The project adds no telemetry, analytics, or remote services.
- The installer preserves backups of replaced configurations.
- Snapshots are stored locally in `~/.local/share/umbra-noctis/snapshots` and
  never include credentials, browser data, or personal documents.
- The project does not touch `/boot`, the bootloader, or partitions.

For automations and AI agents, [LLMS.md](LLMS.md) is the operating contract:
audit before changing, ask for consent for material actions, and never
collect or expose credentials, tokens, history, or personal profiles.

## Omarchy-friendly

Umbra Noctis works on top of Omarchy without replacing its foundation. It does
not edit `/usr/share/omarchy/` and keeps customizations in the appropriate
user paths. See [OMARCHY.md](OMARCHY.md) for compatibility, limits, and
safe diagnostics.

## Migrating from the previous rice

The script first inspects existing links; it only changes anything with `--apply`.

```sh
./scripts/migrate-from-legacy-rice.sh
./scripts/migrate-from-legacy-rice.sh --apply
```

See the step-by-step walkthrough and guarantees in [docs/MIGRATION.md](docs/MIGRATION.md).

---

<p align="center">
  <sub>
    Umbra Noctis · Umbra identity on open platforms<br>
    Code under <a href="LICENSE">GPL-3.0</a> · details in <a href="docs/IDENTITY.md">Identity</a>
  </sub>
</p>
