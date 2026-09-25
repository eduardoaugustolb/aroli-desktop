# Aroli

Tela inicial do Brave Origin, não um popup: hero com saudação e relógio à
esquerda e o Encaixe oficial à direita, busca em faixa total, zonas de
atalhos, tarefas e atividade GitHub, e a assinatura embaixo. Inspirada na
MaterialYouNewTab só no escopo (núcleo + grade de commits); visual, forma
e movimento seguem a identidade Aroli (`Tudo encontra seu lugar`,
`DESIGN.md` no repo `aroli`).

Símbolo e favicon são os vetores oficiais (`branding/aroli/logo/`:
`aroli-symbol.svg`, `aroli-avatar.svg`); os traços são verbatim, e a
tinta acompanha o acento do tema. Ícone da extensão gerado de `icon.svg`
(`magick icon.svg -resize 128x128 icon-128.png`).

Os ajustes moram numa aba oculta (engrenagem no canto inferior direito):
tema do navegador, buscador, nome e novo atalho. A busca aceita link
direto (com ou sem esquema: `site.com/caminho` navega; o resto pesquisa).
O buscador usa dropdown próprio 100% no tema (o popup do `<select>`
nativo é renderizado pelo OS e não tem estilo). Relógio em `22h27` com
dígitos tabulares e transição por algarismo. Tipografia Aroli Sans no
texto e Aroli Mono NF no relógio (instaladas pelo rice, sem bundle).
Animações via anime.js vendorizado (`vendor/anime.min.js`, MIT, sem CDN):
entrada em cascata, dígitos do relógio, painel de ajustes, itens —
sempre na curva de acomodação, com fallback instantâneo sob
`prefers-reduced-motion`.

## Custo

Quase nulo por desenho, não por otimização tardia:

- sem rede (só navega quando você busca ou clica);
- sem polling: a página lê `theme-system.css` / `theme-system.json`
  estáticos; o service worker só roda no boot/instalação;
- um único `setTimeout` até o próximo minuto (relógio `22h27`);
- atividade GitHub: recarrega a cada abertura (sem token: últimos ~90
  dias em até 3 páginas de eventos, ~300 no teto da API; com token:
  365 dias); o cache só segura a pintura até chegar;
- a paleta do wallpaper é derivada **uma vez** por troca, por
  `~/.config/hypr/scripts/aroli-newtab-pywal.sh`.

Sem previsão do tempo, sem wallpaper diário remoto, sem favicons:
tudo isso custa rede e timers permanentes.

## Máquina

Quadrado ao lado do ano com o essencial do Super+Shift+D: CPU (%,
threads, sparkline), memória (% e GiB), disco (% e livres), temperatura
e bateria, mais uptime. O Brave Origin não expõe `chrome.system.*`,
então um host nativo stdlib (`host/aroli-sys.py`, ~12MB, 0,3ms por
amostra) lê `/proc`/`/sys`. Uma instância por guia visível; oculta, a
porta fecha e o processo morre. Registrado pelo `install.sh config` em
`Brave-Origin/NativeMessagingHosts/com.aroli.sys.json` (nome pontilhado:
este build rejeita `_` em host nativo).

## Tema do navegador

A aba de ajustes alterna entre três modos, persistidos em
`chrome.storage.local`. O token do GitHub segue o mesmo cofre, com
regras próprias: o campo nasce sempre vazio (nunca reexibido), valor
inválido não é persistido, e há botão Remover. Ele só viaja para
`api.github.com` via HTTPS; nada mais na extensão faz rede.

- **Sistema** (padrão): segue o wallpaper via pywal;
- **Aroli Dark**: charcoal `#101111`, texto Bone, acento sage-blue;
- **Aroli Black**: mesma linguagem em Ink `#050505`.

O modo repinta o navegador inteiro: a chave da página manda o frame
ao host (`set-frame`, uma vez por valor), que pinta via
`omarchy-theme-set-browser-policy` com refresh — o único caminho que
vence a policy no frame. Toolbar e abas vão por `chrome.theme`. O
startup abre `chrome://newtab/` (o override serve a Aroli sem correria
de boot); o id vive na allowlist gerenciada contra o bloqueio.

## Instalação

Automática pelo rice: `install.sh config` deposita esta pasta em
`~/.config/aroli-newtab`, semeia os arquivos vivos a partir dos
`.example`, deriva o tema da paleta atual e registra a pasta no
`--load-extension` de `~/.config/brave-origin-flags.conf`
(mesmo mecanismo das extensões do Omarchy). Reinicie o Brave Origin
uma vez. Estado (nome, buscador, atalhos, tarefas, modo) mora no
perfil do navegador e sobrevive a updates do rice.

Para testar sem instalar: `brave-origin --load-extension=$PWD`
(numa sessão de teste) ou abra `newtab.html` como arquivo
(o frame do navegador não repinta fora da extensão).
