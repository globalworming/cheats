#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/app"
UPSTREAM_DIR="${APP_DIR}/upstream"

clone_or_update_repo() {
  local repo_url="$1"
  local destination="$2"

  if [[ -d "${destination}/.git" ]]; then
    git -C "${destination}" remote set-url origin "${repo_url}"
    git -C "${destination}" fetch --all --prune
    git -C "${destination}" pull --ff-only
    return
  fi

  rm -rf "${destination}"
  git clone --depth=1 "${repo_url}" "${destination}"
}

mkdir -p "${ROOT_DIR}/scripts"

clone_or_update_repo "git@github.com:chubin/cheat.sh.git" "${APP_DIR}"
mkdir -p "${UPSTREAM_DIR}"

clone_or_update_repo "git@github.com:tldr-pages/tldr.git" "${UPSTREAM_DIR}/tldr"
clone_or_update_repo "git@github.com:cheat/cheatsheets.git" "${UPSTREAM_DIR}/cheatsheets"
clone_or_update_repo "git@github.com:adambard/learnxinyminutes-docs.git" "${UPSTREAM_DIR}/learnxinyminutes-docs"
clone_or_update_repo "git@github.com:chubin/cheat.sheets.git" "${UPSTREAM_DIR}/cheat.sheets"

"${ROOT_DIR}/scripts/apply_airgap_patch.sh"
