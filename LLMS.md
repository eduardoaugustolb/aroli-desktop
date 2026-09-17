# Guia operacional para agentes de IA — Umbra Liminal

Este documento define como agentes devem instalar, auditar e corrigir o Umbra
Liminal sem tirar o controle do usuário. A segurança e a privacidade têm
precedência sobre conveniência.

## Princípios inegociáveis

1. **Inspecione antes de alterar.** Execute diagnóstico e modo seco antes de
   instalar, migrar, habilitar serviços ou editar configurações.
2. **Consentimento explícito para efeitos materiais.** Peça autorização antes
   de usar sudo/pkexec, instalar ou remover pacotes, habilitar serviços,
   escrever em `/etc`, trocar wallpaper, relogar/reiniciar a sessão ou enviar
   qualquer dado pela rede.
3. **Nenhum bloatware automático.** Os arquivos `packages/optional-*.txt`
   contêm aplicativos e ferramentas opcionais. Cada pacote exige confirmação
   individual; `--yes`, CI e execuções não interativas devem ignorá-los.
4. **Privacidade por padrão.** Não leia, imprima, armazene, envie ou versione
   chaves, tokens, senhas, cookies, histórico, perfis de navegador, dados de
   mensageria ou arquivos em `~/.ssh`, `~/.gnupg`, `~/.config/gh` e similares.
5. **Nunca edite `/usr/share/omarchy/`.** Use somente caminhos de usuário e
   mecanismos oficiais do Omarchy.
6. **Não faça ações destrutivas sem alvo e motivo confirmados.** Prefira backup
   verificável, Lixeira e operações reversíveis.

## Estrutura relevante

| Caminho | Finalidade |
| --- | --- |
| `install.sh` | Instalador por fases; use `--dry-run` primeiro. |
| `diagnose` | Diagnóstico somente leitura. |
| `packages/pacman.txt` | Base necessária do rice. |
| `packages/optional-*.txt` | Itens opt-in, nunca padrão. |
| `home/` | Arquivos que serão ligados ou copiados para `$HOME`. |
| `home/Pictures/wallpapers/` | Wallpapers padrão distribuídos pelo rice. |
| `scripts/migrate-from-legacy-rice.sh` | Migração segura do fork legado. |
| `OMARCHY.md` | Contrato de compatibilidade com Omarchy. |

## Fluxo seguro para instalação

```sh
# 1. Auditoria sem escrita.
./diagnose
./install.sh --dry-run --lang pt-BR

# 2. Só após aprovação explícita do usuário.
./install.sh --lang pt-BR
```

Não use `--yes` como substituto da escolha humana para pacotes opcionais. Se o
usuário quiser um opcional, mostre o nome, a finalidade, a origem (repositório
oficial ou AUR), dependências relevantes e espaço estimado antes de instalar.

## Fluxo seguro para migração

```sh
# Não altera nada.
./scripts/migrate-from-legacy-rice.sh

# Só após o usuário aprovar a lista de symlinks.
./scripts/migrate-from-legacy-rice.sh --apply
```

O script mantém o clone legado intacto. Não remova o diretório antigo nem
apague backups sem pedido explícito.

## Auditoria e correção

Comece com comandos sem escrita:

```sh
omarchy debug --no-sudo --print
hyprctl configerrors
systemctl --user is-active quickshell
./diagnose
git status --short
```

Antes de corrigir, explique causa provável, arquivos alvo, efeito esperado e
como reverter. Após uma alteração em Hyprland, valide com `hyprctl reload` e
`hyprctl configerrors`. Após alterar o shell, valide se `quickshell` continua
ativo. Não use `omarchy refresh` sem confirmação: ele substitui configurações
do usuário, embora crie backup.

## Rede e dados

- Downloads de wallpapers, atualizações, clones e consultas a AUR exigem
  consentimento explícito.
- Não envie relatórios de diagnóstico completos a serviços externos; remova
  nomes de usuário, caminhos pessoais, endereços IP, SSIDs e identificadores.
- Não adicione telemetria, analytics, plugins remotos ou processos em segundo
  plano sem uma escolha clara e reversível do usuário.

## Contribuições

Preserve [LICENSE](LICENSE), a atribuição ao upstream e a identidade Umbra
Liminal. Todo novo pacote deve ser classificado como essencial ou opcional; em
caso de dúvida, trate-o como opcional.
