# Umbra Liminal no Omarchy

Umbra Liminal é **Omarchy-friendly**: uma camada Umbra para Arch, Hyprland e
Quickshell que roda sobre a pilha já fornecida pelo Omarchy.

## Regras de compatibilidade

- Nunca modifique `/usr/share/omarchy/`. O diretório pertence ao pacote e será
  substituído em atualizações.
- Mantenha personalizações em `~/.config`, `~/.local/share` e neste clone.
- Prefira os comandos `omarchy` para operações do sistema: `omarchy update`,
  `omarchy pkg` e `omarchy theme`.
- O Liminal inicia seu shell Quickshell depois que `WAYLAND_DISPLAY` está
  disponível. Um flash curto da barra nativa pode aparecer durante o login.

## O que o Liminal altera

| Área | Comportamento |
| --- | --- |
| Shell | Notch e painéis Quickshell do Liminal. |
| Paleta | Pywal extrai cores do wallpaper selecionado. |
| Idioma | Shell, Hyprlock e SDDM em pt-BR. |
| Cursor | XCursor Umbra, sem definir `HYPRCURSOR_THEME`. |
| Teclado | ABNT2 (`br`) no Hyprland. |
| Pacotes opcionais | Cada item exige confirmação individual. |

## Componentes preservados

O projeto não substitui Hyprland, SDDM, PipeWire, WirePlumber,
NetworkManager, `xdg-desktop-portal-hyprland` ou o pacote `omarchy`.

## Diagnóstico seguro

```sh
omarchy debug --no-sudo --print
hyprctl configerrors
./diagnose
```

## Migração

Para converter symlinks de uma instalação legada, rode primeiro sem efeitos:

```sh
./scripts/migrate-from-diego-rice.sh
./scripts/migrate-from-diego-rice.sh --apply
```

Veja [docs/MIGRACAO.md](docs/MIGRACAO.md) e [LLMS.md](LLMS.md).
