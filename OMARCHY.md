# Umbra Liminal on Omarchy

Umbra Liminal is **Omarchy-friendly**: an Umbra layer for Arch, Hyprland, and
Quickshell that runs on top of the stack already provided by Omarchy.

## Compatibility rules

- Never modify `/usr/share/omarchy/`. The directory belongs to the package and
  will be replaced on updates.
- Keep customizations in `~/.config`, `~/.local/share`, and this clone.
- Prefer the `omarchy` commands for system operations: `omarchy update`,
  `omarchy pkg`, and `omarchy theme`.
- Liminal starts its Quickshell shell after `WAYLAND_DISPLAY` is
  available. A brief flash of the native bar may appear during login.

## What Liminal changes

| Area | Behavior |
| --- | --- |
| Shell | Liminal Quickshell notch and panels. |
| Palette | Pywal extracts colors from the selected wallpaper. |
| Language | Shell, Hyprlock, and SDDM in pt-BR. |
| Cursor | Umbra XCursor, without setting `HYPRCURSOR_THEME`. |
| Keyboard | ABNT2 (`br`) in Hyprland. |
| Optional packages | Each item requires individual confirmation. |

## Preserved components

The project does not replace Hyprland, SDDM, PipeWire, WirePlumber,
NetworkManager, `xdg-desktop-portal-hyprland`, or the `omarchy` package.

## Safe diagnostics

```sh
omarchy debug --no-sudo --print
hyprctl configerrors
./diagnose
```

## Migration

To convert symlinks from a legacy install, first run with no effects:

```sh
./scripts/migrate-from-legacy-rice.sh
./scripts/migrate-from-legacy-rice.sh --apply
```

See [docs/MIGRATION.md](docs/MIGRATION.md) and [LLMS.md](LLMS.md).
