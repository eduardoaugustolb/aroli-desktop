#!/usr/bin/env bash
# Opens NetworkManager's editor for a WPA-EAP network without passing identity
# or password through argv. The shell provides only the SSID, which is not secret.

set -euo pipefail

action="${1:-edit}"
ssid="${2:-}"

find_profile_uuid() {
    local line uuid type candidate found=""
    while IFS= read -r line; do
        uuid="${line%%:*}"
        type="${line#*:}"
        [[ "$type" == "802-11-wireless" ]] || continue
        candidate="$(nmcli --escape no -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null | head -n 1 || true)"
        if [[ "$candidate" == "$ssid" ]]; then
            # Two profiles with the same SSID may have different identities or
            # CAs. Do not guess which one: the editor will show the list.
            [[ -z "$found" ]] || return 2
            found="$uuid"
        fi
    done < <(nmcli -t -f UUID,TYPE connection show)
    [[ -n "$found" ]] || return 1
    printf '%s\n' "$found"
}

case "$action" in
    edit)
        if uuid="$(find_profile_uuid)"; then
            exec nm-connection-editor --edit="$uuid"
        fi
        # If Quickshell marked it known but NetworkManager finds no profile for
        # the SSID, show the list rather than editing the wrong profile.
        exec nm-connection-editor --show
        ;;
    create)
        # Quickshell may take a moment to mark `known`; check again before
        # creating so an existing profile is not duplicated.
        if uuid="$(find_profile_uuid)"; then
            exec nm-connection-editor --edit="$uuid"
        else
            result=$?
            [[ "$result" -ne 2 ]] || exec nm-connection-editor --show
        fi
        # The editor saves secrets through NetworkManager. Do not construct
        # `nmcli ... password ...`, which would expose the password in `ps`.
        exec nm-connection-editor --create --type=802-11-wireless
        ;;
    *)
        printf 'Usage: %s {edit|create} SSID\n' "${0##*/}" >&2
        exit 2
        ;;
esac
