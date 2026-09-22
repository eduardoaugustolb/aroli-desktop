---
name: aroli-quickshell
description: >
  REQUIRED when editing or adding Quickshell QML on this rice: bar, notch,
  island, control center, Settings window, launcher, overview, lock screen,
  panels, widgets, translations. Triggers: qml, quickshell, bar, notch,
  island, control center, Super+D, settings UI, launcher, overview, lock
  screen, panel, widget, translation, i18n, appearance, colors, motion,
  animation, easing, spring.
---

# Quickshell development laws

`~/.config/quickshell` is a symlink into the repo checkout: editing the
repo edits the live shell. Quickshell hot-reloads `.qml`; structural root
changes or new imports may need `~/.config/quickshell/reload.sh`.

## Tokens or it is a bug

- `Appearance.qml`: sizes (`fsCaption`–`fsXXL`), radii (`radS/M/L/Pill`),
  gaps (`gapS/M/G/L`, `pad`), motion scale (`mQuick/mIn/mOut/mInScale/
  mOutScale/mShape`, `mFollow`/`mTint`, `mTick`, `mStagger`), springs
  (`sprTight/Panel/Loose/Squash`), hitbox (`hitPad`). Round text to the
  nearest size step, ties down. Panel shells: 22/22/20/18.
- `Colors.qml`: dynamic pywal (`bg/fg/accent/...`) plus fixed semantic
  (`ok/warn/crit`) and fixed text inks (`inkHi/Mid/Lo`). Never hardcode a
  grey scale; never use pywal slots for status meaning.
- Text on wallpaper (bar) uses contrast-guaranteed ink (`onWallAccent`),
  never the raw accent. Tinting an image can never hit a guaranteed ink
  (colorization keeps source lightness): use exact `color:` on glyphs.

## Shape, motion, i18n

- Roundness belongs to the shell: cards + hairline. `clip: true` crops to
  a RECTANGLE even with radius: real rounding needs a `MultiEffect` mask
  (see MediaPanel/NotchContent patterns). Toggles and chips are true
  pills (`height / 2`); rows use `radS`.
- Opacity fades ride `OutCubic`; travel/scale/press ride springs;
  never animate layout size except deliberate expand/collapse.
  No layout reflow in fixed-height surfaces (lock screen).
- User strings go through `I18n.tr("English")` with es/pt-BR entries in
  `translations-*.js` (alphabetical); run `tools/i18n-check.py`.
  Concatenate nothing: use `{0}` placeholders. Window titles used for
  Hyprland focus lookups must resolve through the same translation.

## Verify

`journalctl --user -u quickshell -b` filtered for your file; screenshot
regions with `grim` and measure pixels for alignment claims.
