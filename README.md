# Umbra Liminal

O rice do workspace **Umbra** para Omarchy, Arch Linux, Hyprland e
Quickshell. **Umbra Liminal** é uma camada visual própria e
Omarchy-friendly: preserva a base do Omarchy e recompõe a superfície do
desktop a partir do wallpaper via Pywal.

O nome Liminal representa o limiar entre a plataforma e a experiência pessoal:
notch, bandas de luminância, superfície escura e uma paleta que muda com a
imagem ativa. A identidade é Umbra; Omarchy e Arch seguem reconhecidos como
plataformas de terceiros.

## Demo

A full run-through of the desktop.

[<video src="media/rice.mp4" controls width="600"></video>](https://github.com/user-attachments/assets/2b35a6fb-5a08-4539-99a9-7c525eb463b3)

## Install

```sh
git clone https://github.com/eduardoaugustolb/umbra-liminal.git
cd umbra-liminal
./install.sh --lang pt-BR
```

Needs **Hyprland 0.56+** — the config is `hyprland.lua`, not `hyprland.conf`.

- `./install.sh --lang pt-BR` — instala a interface em português do Brasil.
  O idioma pode ser alterado em Configurações → Aparência sem reiniciar.
- `./install.sh --dry-run` — see the plan, change nothing
- `./install.sh restore` — undo it
- `./diagnose` — what is missing or will not start

### Migração do fork anterior

Use o modo de inspeção primeiro; a migração só religa configurações com
`--apply`:

```sh
./scripts/migrate-from-diego-rice.sh
./scripts/migrate-from-diego-rice.sh --apply
```

Veja [docs/MIGRACAO.md](docs/MIGRACAO.md) e [OMARCHY.md](OMARCHY.md).

Agentes de IA e ferramentas de automação devem seguir [LLMS.md](LLMS.md): ele
define consentimento, privacidade, auditoria e instalação opt-in.

It never touches `/boot`, the bootloader or your partitions. Outside `$HOME` it writes only the twelve files in `system/etc/`, and asks before every phase that needs sudo.

## Licence

GPL-3.0 — see [LICENSE](LICENSE). O código derivado continua livre sob GPL;
"Umbra Liminal" identifica esta manutenção e sua direção visual, não altera a
licença upstream.
