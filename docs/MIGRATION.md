# Migrating from the legacy fork to Umbra Liminal

`scripts/migrate-from-legacy-rice.sh` only swaps `~/.config` symlinks that
still point at `~/.local/share/diegoMalagrida-dotfiles`. The legacy clone is
not deleted, to allow manual rollback.

```sh
# Inspect the changes, without writing anything.
./scripts/migrate-from-legacy-rice.sh

# Create ~/.local/share/umbra-liminal and relink the detected symlinks.
./scripts/migrate-from-legacy-rice.sh --apply
```

After migrating, log out and validate:

```sh
hyprctl configerrors
systemctl --user is-active quickshell
```

## Migrating to en-US file names

The en-US release renames repository files, including the Quickshell
translation dictionaries, the SDDM uninstall script, the spring test helper,
and the paccache systemd drop-in.

- Symlink installs follow the renamed repository paths automatically after the
  checkout.
- Copy installs retain old files until `rice prune --apply` has verified they
  are unchanged and moved them to the Trash (with a backup). User-modified
  files are reported and left untouched.
- `effects.lua` replaces the runtime state file `efectos.lua`. The installer
  moves the old state file only when the new one does not exist; Hyprland also
  reads the old name as a fallback until migration runs.
- The system phase moves the old paccache drop-in to
  `desinstalados.conf.before-en-us-rename` rather than deleting it. It never
  overwrites an existing backup.

Preview cleanup before applying it:

```sh
rice prune
rice prune --apply
```
