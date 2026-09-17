<p align="center">
  <img src="home/Pictures/wallpapers/umbra-ink-mountains.png" alt="Montanhas em tinta — wallpaper Umbra Liminal" width="100%">
</p>

<p align="center">
  <sub>U M B R A &nbsp; / &nbsp; L I M I N A L</sub>
</p>

<h1 align="center">Umbra Liminal</h1>

<p align="center">
  Um rice para <strong>Omarchy</strong>, Arch Linux, Hyprland e Quickshell.<br>
  Escuro por natureza. Pessoal por wallpaper. Seu por escolha.
</p>

<p align="center">
  <a href="#instalação">Instalar</a> ·
  <a href="#o-limiar">O limiar</a> ·
  <a href="#privacidade-e-controle">Privacidade</a> ·
  <a href="OMARCHY.md">Omarchy</a> ·
  <a href="LLMS.md">LLMS</a>
</p>

---

## O limiar

**Umbra Liminal** é a camada visual do workspace Umbra para a base estável do
Omarchy. “Liminal” é o ponto de passagem entre sistema e pessoa: o rice mantém
a estrutura — notch, superfícies escuras, recortes e bandas de luminância — e
deixa cada wallpaper determinar a cor do ambiente com Pywal.

Não há uma paleta fixa para decorar o desktop. Há uma linguagem: profundidade,
espaço negativo e contraste. O resultado muda quando a sua imagem muda, mas
continua reconhecível como Umbra.

| Base | Superfície Umbra | Sua escolha |
| --- | --- | --- |
| Omarchy · Arch · Hyprland | Quickshell, notch e paleta dinâmica | Wallpaper, idioma e opcionais |

<p align="center">
  <img src="home/Pictures/wallpapers/umbra-ember-coast.png" alt="Ember Coast — wallpaper incluído" width="49%">
  <img src="home/Pictures/wallpapers/umbra-obsidian-dunes.png" alt="Obsidian Dunes — wallpaper incluído" width="49%">
</p>

## O que chega com o Liminal

- Interface Quickshell completa, com notch, lançador, painéis e visão geral.
- Tradução da interface em **português do Brasil** e teclado ABNT2.
- Cursor **Umbra** e identificação visual da plataforma ativa: Omarchy no
  Omarchy, Arch no Arch.
- Paleta Pywal extraída do wallpaper atual, aplicada ao shell e às superfícies
  compatíveis.
- Quatro wallpapers Umbra instalados junto do rice: Ember Coast, Silent
  Threshold, Obsidian Dunes e Ink Mountains.
- Migração assistida para instalações oriundas do fork anterior.

<details>
<summary><strong>Ver o rice em movimento</strong></summary>
<br>

[Abrir demo em vídeo](https://github.com/user-attachments/assets/2b35a6fb-5a08-4539-99a9-7c525eb463b3)

</details>

## Instalação

> [!IMPORTANT]
> Leia o plano antes de escrever no sistema. O modo seco não altera arquivos,
> não instala pacotes e não pede privilégios.

```sh
git clone https://github.com/eduardoaugustolb/umbra-liminal.git
cd umbra-liminal

# veja exatamente o que aconteceria
./install.sh --dry-run --lang pt-BR

# instale somente após revisar o plano
./install.sh --lang pt-BR
```

Requer **Hyprland 0.56+**. Este rice usa `hyprland.lua`, não
`hyprland.conf`.

| Comando | Resultado |
| --- | --- |
| `./install.sh --dry-run --lang pt-BR` | Mostra o plano sem mudar nada. |
| `./install.sh --lang pt-BR` | Instala o rice em português do Brasil. |
| `./install.sh restore` | Restaura os arquivos anteriores da configuração. |
| `./diagnose` | Diagnóstico somente leitura. |

## Privacidade e controle

O Liminal não decide seu desktop por você.

- Aplicativos extras nunca entram como padrão: cada item em
  `packages/optional-*.txt` requer confirmação individual.
- Execuções com `--yes`, CI ou sem terminal **não instalam opcionais**.
- O projeto não adiciona telemetria, analytics ou serviços remotos.
- O instalador preserva backups das configurações substituídas.
- O projeto não toca em `/boot`, bootloader ou partições.

Para automações e agentes de IA, [LLMS.md](LLMS.md) é o contrato operacional:
auditar antes de alterar, pedir consentimento para ações materiais e nunca
coletar ou expor credenciais, tokens, histórico ou perfis pessoais.

## Omarchy-friendly

O Umbra Liminal trabalha sobre o Omarchy, sem substituir sua fundação. Ele não
edita `/usr/share/omarchy/` e mantém as personalizações nos caminhos de usuário
apropriados. Consulte [OMARCHY.md](OMARCHY.md) para compatibilidade, limites e
diagnóstico seguro.

## Migrando do rice anterior

O script primeiro inspeciona os links existentes; só muda algo com `--apply`.

```sh
./scripts/migrate-from-legacy-rice.sh
./scripts/migrate-from-legacy-rice.sh --apply
```

Veja o passo a passo e as garantias em [docs/MIGRACAO.md](docs/MIGRACAO.md).

---

<p align="center">
  <sub>
    Umbra Liminal · identidade Umbra sobre plataformas abertas<br>
    Código sob <a href="LICENSE">GPL-3.0</a> · detalhes em <a href="docs/IDENTIDADE.md">Identidade</a>
  </sub>
</p>
