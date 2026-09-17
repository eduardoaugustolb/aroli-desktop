# ~/.config/p10k/eduardo-theme.zsh
# Overrides de Powerlevel10k: estilo LEAN de 1 linea, paleta pywal.
# Se carga DESPUES de ~/.p10k.zsh (ver el source al final de ~/.zshrc).
# Revertir: borra esa linea de source en ~/.zshrc y abre una terminal nueva.

() {
  emulate -L zsh

  # --- Paleta ANSI de kitty (sus slots 0-15 los regenera pywal) ---
  # Usar indices, en vez de RGB fijos, hace que el prompt siga al fondo incluso
  # en shells que ya estaban abiertos cuando kitty recarga su paleta.
  local orange=4 blue=6 cream=7 muted=8
  local red=1 green=2 yellow=3 dim=8

  # Respiro entre el icono de Omarchy y el directorio; sin esto quedan
  # visualmente pegados en fuentes Nerd Font compactas.
  typeset -g POWERLEVEL9K_ICON_PADDING=moderate

  # --- Segmentos: 1 linea, curados y utiles ---
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs prompt_char)
  # Solo alertas importantes a la derecha; evita una nube de versiones.
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status                  # solo aparece cuando el comando falla
    command_execution_time  # solo aparece en comandos lentos
    background_jobs         # solo aparece si hay jobs activos
    time                    # hora, siempre al final
  )

  # --- Estilo LEAN: fuera fondos y separadores powerline ---
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=' '
  typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=' '
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=' '
  typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR=' '
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR=' '

  # Quita el fondo de todos los segmentos que uso (transparente)
  local seg
  for seg in OS_ICON DIR PROMPT_CHAR STATUS COMMAND_EXECUTION_TIME BACKGROUND_JOBS TIME; do
    typeset -g POWERLEVEL9K_${seg}_BACKGROUND=
  done
  local st
  for st in CLEAN MODIFIED UNTRACKED CONFLICTED LOADING; do
    typeset -g POWERLEVEL9K_VCS_${st}_BACKGROUND=
  done

  # --- Colores por segmento ---
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=$orange

  typeset -g POWERLEVEL9K_DIR_FOREGROUND=$blue
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=$cream
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=$muted
  typeset -g POWERLEVEL9K_DIR_TRUNCATION_LENGTH=3
  typeset -g POWERLEVEL9K_DIR_TRUNCATION_SYMBOL='…/'

  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=$green
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=$yellow
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=$green
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_FOREGROUND=$red
  typeset -g POWERLEVEL9K_VCS_LOADING_FOREGROUND=$muted

  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=$green
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=$red

  # status: mostrar solo el error (sin el tic verde en cada comando OK)
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_ERROR=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=$red
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND=$red
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND=$red

  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=$dim
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=2
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=0
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PREFIX=''

  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND=$blue
  typeset -g POWERLEVEL9K_DIRENV_FOREGROUND=$yellow
  typeset -g POWERLEVEL9K_VIRTUALENV_FOREGROUND=$green
  typeset -g POWERLEVEL9K_PYENV_FOREGROUND=$green
  typeset -g POWERLEVEL9K_NODE_VERSION_FOREGROUND=$green
  typeset -g POWERLEVEL9K_RUST_VERSION_FOREGROUND=$orange
  typeset -g POWERLEVEL9K_GO_VERSION_FOREGROUND=$blue

  typeset -g POWERLEVEL9K_TIME_FOREGROUND=$muted
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M}'
  typeset -g POWERLEVEL9K_TIME_PREFIX=''

  # --- Distro icon: Omarchy on Omarchy, Arch on Arch ---
  # p10k detects the distro from the `ID=` field of /etc/os-release with a
  # `case *arch*` match, and "omarchy" contains "arch" (om-arch-y): without
  # an override, Omarchy would inherit the Arch logo (U+F303). Upstream has
  # no `omarchy` branch, so this theme forces the generic Tux (U+F17C,
  # already present in Nerd Fonts) on Omarchy only, keeping the default
  # detection (Arch and friends) on every other distro.
  # (The real Omarchy mark lives at U+E900 of the `omarchy` font, which
  # needs an explicit font family -- unavailable in prompt context.)
  local _umbra_os_id=""
  if [[ -r /etc/os-release ]]; then
    _umbra_os_id=$(. /etc/os-release 2>/dev/null; printf '%s' "${ID:-}")
  fi
  if [[ $_umbra_os_id == omarchy ]]; then
    typeset -g POWERLEVEL9K_OS_ICON_CONTENT_EXPANSION=$'\uF17C '
  fi
  unset _umbra_os_id

  (( ! $+functions[p10k] )) || p10k reload
}
