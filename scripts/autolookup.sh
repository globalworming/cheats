#!/usr/bin/env bash

# Autolookup
#
# Host-side KDE/Plasma clipboard watcher for the local cheat.sh deployment.
# This stays outside the container stack and acts only as a terminal helper
# around the local `cht.sh` client.
#
# TODO:
# - [x] subscribe to Klipper clipboard change signals over D-Bus; do not poll
# - [x] read the current clipboard contents from Klipper after each signal
# - [x] extract the first whitespace-delimited token from the clipboard text
# - [x] ignore empty tokens and repeated tokens that match the current lookup
# - [x] render only the latest lookup into a temporary file
# - [x] show that temporary file in `less -R` positioned at the top
# - [x] when a new token arrives, stop the current pager and reopen it on the
#   refreshed temporary file
#
# User-visible examples:
# - copying `git` looks up `git`
# - copying `git status` still looks up `git`
# - copying `git status` again does not interfer with pager as `git` is already current
#
# Expected runtime shape:
# - the terminal view should behave like `cht.sh <word> | less -R`
# - the pager always shows the latest lookup result
# 
# Required host dependencies:
# - KDE Plasma with Klipper
# - `qdbus6`
# - `dbus-monitor`
# - `less`
# - `cht.sh`
#
# Environment overrides:
# - `AUTOLOOKUP_CHTSH_COMMAND`

set -euo pipefail

KLIPPER_SERVICE="org.kde.klipper"
KLIPPER_PATH="/klipper"
KLIPPER_INTERFACE="org.kde.klipper.klipper"

AUTOLOOKUP_CHTSH_COMMAND="${AUTOLOOKUP_CHTSH_COMMAND:-cht.sh}"
AUTOLOOKUP_RENDER_FILE=""

pager_pid=""
current_word=""

require_command() {
  local command_name="$1"
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "missing dependency: ${command_name}" >&2
    exit 1
  }
}

cleanup() {
  if [[ -n "${pager_pid}" ]] && kill -0 "${pager_pid}" 2>/dev/null; then
    kill "${pager_pid}" 2>/dev/null || true
    wait "${pager_pid}" 2>/dev/null || true
  fi

  if [[ -n "${AUTOLOOKUP_RENDER_FILE}" ]]; then
    rm -f "${AUTOLOOKUP_RENDER_FILE}"
  fi
}

init_render_file() {
  AUTOLOOKUP_RENDER_FILE="$(mktemp)"
}

restart_pager() {
  if [[ -n "${pager_pid}" ]] && kill -0 "${pager_pid}" 2>/dev/null; then
    kill "${pager_pid}" 2>/dev/null || true
    wait "${pager_pid}" 2>/dev/null || true
  fi

  less -R +g "${AUTOLOOKUP_RENDER_FILE}" </dev/tty >/dev/tty 2>/dev/tty &
  pager_pid=$!
}

render_waiting_screen() {
  cat >"${AUTOLOOKUP_RENDER_FILE}" <<'EOF'
Waiting for a new first word from Klipper.

Copy any text into the clipboard and the first whitespace-delimited token
will open here as if you had run:

  cht.sh <word> | less -R
EOF
}

extract_first_word() {
  printf '%s\n' "$1" | awk 'NF { print $1; exit }'
}

get_clipboard_contents() {
  qdbus6 "${KLIPPER_SERVICE}" "${KLIPPER_PATH}" "${KLIPPER_INTERFACE}.getClipboardContents"
}

render_lookup() {
  local word="$1"
  local tmp_render

  tmp_render="$(mktemp "${AUTOLOOKUP_RENDER_FILE}.XXXXXX")"
  if "${AUTOLOOKUP_CHTSH_COMMAND}" "${word}" >"${tmp_render}" 2>&1; then
    mv "${tmp_render}" "${AUTOLOOKUP_RENDER_FILE}"
    return
  fi

  {
    printf 'lookup failed for %s\n\n' "${word}"
    cat "${tmp_render}"
  } >"${AUTOLOOKUP_RENDER_FILE}"
  rm -f "${tmp_render}"
}

refresh_from_clipboard() {
  local clipboard_text
  local word

  clipboard_text="$(get_clipboard_contents)"
  word="$(extract_first_word "${clipboard_text}")"

  if [[ -z "${word}" ]] || [[ "${word}" == "${current_word}" ]]; then
    return
  fi

  current_word="${word}"
  render_lookup "${word}"
  restart_pager
}

main() {
  trap cleanup EXIT INT TERM

  require_command qdbus6
  require_command dbus-monitor
  require_command less
  require_command awk
  require_command mktemp
  require_command "${AUTOLOOKUP_CHTSH_COMMAND}"

  init_render_file
  render_waiting_screen
  restart_pager
  refresh_from_clipboard || true

  exec {monitor_fd}< <(
    dbus-monitor --session \
      "type='signal',path='${KLIPPER_PATH}',interface='${KLIPPER_INTERFACE}',member='clipboardHistoryUpdated'" \
      2>/dev/null
  )

  while IFS= read -r -u "${monitor_fd}" line; do
    if [[ "${line}" == signal*clipboardHistoryUpdated* ]]; then
      refresh_from_clipboard || true
    fi
  done
}

main "$@"
