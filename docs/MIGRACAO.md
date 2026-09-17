# Migração do fork legado para Umbra Liminal

`scripts/migrate-from-legacy-rice.sh` troca apenas symlinks de `~/.config` que
ainda apontam para `~/.local/share/diegoMalagrida-dotfiles`. O clone legado não
é apagado, para permitir reversão manual.

```sh
# Inspeciona as mudanças, sem escrever nada.
./scripts/migrate-from-legacy-rice.sh

# Cria ~/.local/share/umbra-liminal e religa os symlinks detectados.
./scripts/migrate-from-legacy-rice.sh --apply
```

Após a migração, encerre a sessão e valide:

```sh
hyprctl configerrors
systemctl --user is-active quickshell
```
