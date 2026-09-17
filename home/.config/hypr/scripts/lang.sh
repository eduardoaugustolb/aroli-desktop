# lang.sh - language for Hyprland script notifications.
#
# Not executed directly: sourced by other scripts.
#
#   . "$HOME/.config/hypr/scripts/lang.sh" 2>/dev/null || tr_() { printf '%s' "$1"; }
#   notify-send "$(tr_ 'Luz nocturna' 'Night light')" "$(tr_ 'Activada' 'On')"
#
# Brazilian Portuguese is this fork's original language and is always the
# default. If the language file or its line is missing, or has any other value,
# use pt-BR: extra text is preferable to blank text.
#
# ~/.config/hypr/language.conf is the source of truth, shared with hyprlock so
# lock screen and notifications cannot diverge. Environment $RICE_LANG wins for testing:
#   RICE_LANG=en ~/.config/hypr/scripts/hyprsunset-toggle.sh

if [ -z "${RICE_LANG:-}" ]; then
    RICE_LANG=pt-BR
    _rice_lang_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/language.conf"
    if [ -r "$_rice_lang_conf" ]; then
        # No grep or sed: this is a two-line file sourced by hotkey scripts.
        while IFS= read -r _rice_lang_line || [ -n "$_rice_lang_line" ]; do
            case "$_rice_lang_line" in
                '$uiLang'*=*)
                    _rice_lang_value="${_rice_lang_line#*=}"
                    _rice_lang_value="${_rice_lang_value// /}"
                    _rice_lang_value="${_rice_lang_value//$'\t'/}"
                    [ -n "$_rice_lang_value" ] && RICE_LANG="$_rice_lang_value"
                    ;;
            esac
        done < "$_rice_lang_conf"
    fi
    unset _rice_lang_conf _rice_lang_line _rice_lang_value
fi

# tr_ SPANISH ENGLISH BRAZILIAN-PORTUGUESE
tr_() {
    case "$RICE_LANG" in
        en) printf '%s' "$2" ;;
        pt-BR) printf '%s' "${3:-$1}" ;;
        *) printf '%s' "$1" ;;
    esac
}
