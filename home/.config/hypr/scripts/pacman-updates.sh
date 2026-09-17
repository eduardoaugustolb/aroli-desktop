#!/usr/bin/env bash

set -u

readonly state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
readonly stamp_file="$state_dir/pacman-updates.last-sync"
readonly lock_file="$state_dir/pacman-updates.lock"
readonly error_log="$state_dir/pacman-updates.error.log"
readonly check_db="${CHECKUPDATES_DB:-${TMPDIR:-/tmp}/checkup-db-${UID}}"
readonly sync_interval=3600  # 1 h: data changes rarely; 600 s was about 6x more aggressive than needed

mkdir -p "$state_dir"

emit_json() {
    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$1" "$2" "$3"
}

sync_description() {
    local last_sync=0

    if [[ -r "$stamp_file" ]]; then
        read -r last_sync < "$stamp_file"
    fi
    if [[ "$last_sync" =~ ^[0-9]+$ ]] && (( last_sync > 0 )); then
        printf 'repositories synchronized at %s' "$(date --date="@$last_sync" '+%H:%M')"
    else
        printf 'repositories not synchronized yet'
    fi
}

run_check() {
    local -a args=(--nocolor --nosync)
    local last_sync=0
    local now

    now=$(date +%s)
    if [[ -r "$stamp_file" ]]; then
        read -r last_sync < "$stamp_file"
    fi
    [[ "$last_sync" =~ ^[0-9]+$ ]] || last_sync=0

    full_sync=false
    if (( now < last_sync || now - last_sync >= sync_interval )) ||
        [[ ! -d "$check_db/sync" ]]; then
        args=(--nocolor)
        full_sync=true
    fi

    updates=$(timeout 60 checkupdates "${args[@]}" 2>"$error_log")
    check_status=$?

    if $full_sync && (( check_status == 0 || check_status == 2 )); then
        printf '%s\n' "$now" > "$stamp_file"
    fi
    if (( check_status == 0 || check_status == 2 )); then
        rm -f "$error_log"
    fi
}

exec 9> "$lock_file"
if ! flock -w 65 9; then
    emit_json "?" "Another update check is still in progress" "error"
    exit 0
fi

case "${1:-}" in
    --list)
        rm -f "$stamp_file"
        run_check
        case $check_status in
            0) printf '%s\n' "$updates" ;;
            2) printf 'No updates\n' ;;
            *) printf 'Could not check for updates\n' ;;
        esac
        exit 0
        ;;
    --refresh)
        # This used to signal Waybar to reload its module. Quickshell now owns
        # the bar, so invalidate the timestamp and continue to emit fresh JSON.
        rm -f "$stamp_file"
        ;;
esac

run_check
case $check_status in
    0)
        count=$(awk 'NF { count++ } END { print count + 0 }' <<< "$updates")
        emit_json "$count" "$count updates available · $(sync_description)" "updates"
        ;;
    2)
        emit_json "0" "System is up to date · $(sync_description)" "none"
        ;;
    *)
        emit_json "?" "Check failed · details in $error_log" "error"
        ;;
esac
