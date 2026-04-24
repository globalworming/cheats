#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

KLIPPER_SERVICE="org.kde.klipper"
KLIPPER_PATH="/klipper"
KLIPPER_INTERFACE="org.kde.klipper.klipper"

AUTOLOOKUP_STATE_DIR="${AUTOLOOKUP_STATE_DIR:-${REPO_ROOT}/.autolookup/state}"
AUTOLOOKUP_CACHE_DIR="${AUTOLOOKUP_CACHE_DIR:-${REPO_ROOT}/.autolookup/cache}"
AUTOLOOKUP_WORDS_FILE="${AUTOLOOKUP_WORDS_FILE:-${AUTOLOOKUP_STATE_DIR}/autolookup.words}"
AUTOLOOKUP_RENDER_FILE="${AUTOLOOKUP_RENDER_FILE:-${AUTOLOOKUP_CACHE_DIR}/autolookup.current}"
AUTOLOOKUP_CHTSH_COMMAND="${AUTOLOOKUP_CHTSH_COMMAND:-cht.sh}"

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

record_word() {
  local word="$1"

  mkdir -p "${AUTOLOOKUP_STATE_DIR}"
  touch "${AUTOLOOKUP_WORDS_FILE}"

  if ! grep -Fqx "${word}" "${AUTOLOOKUP_WORDS_FILE}"; then
    printf '%s\n' "${word}" >>"${AUTOLOOKUP_WORDS_FILE}"
  fi
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
  record_word "${word}"
  render_lookup "${word}"
  restart_pager
}

main() {
  trap cleanup EXIT INT TERM

  require_command qdbus6
  require_command dbus-monitor
  require_command less
  require_command awk
  require_command grep
  require_command mktemp
  require_command "${AUTOLOOKUP_CHTSH_COMMAND}"

  mkdir -p "${AUTOLOOKUP_CACHE_DIR}" "${AUTOLOOKUP_STATE_DIR}"

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
