#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/app"
UPSTREAM_DIR="${APP_DIR}/upstream"

repo_url_for_dir() {
  local repo_dir_name="$1"
  case "${repo_dir_name}" in
    app)
      echo "git@github.com:chubin/cheat.sh.git"
      ;;
    tldr)
      echo "git@github.com:tldr-pages/tldr.git"
      ;;
    cheatsheets)
      echo "git@github.com:cheat/cheatsheets.git"
      ;;
    learnxinyminutes-docs)
      echo "git@github.com:adambard/learnxinyminutes-docs.git"
      ;;
    cheat.sheets)
      echo "git@github.com:chubin/cheat.sheets.git"
      ;;
    *)
      return 1
      ;;
  esac
}

if [[ ! -d "${APP_DIR}/.git" ]]; then
  echo "run ./scripts/init_sources.sh first" >&2
  exit 1
fi

git -C "${APP_DIR}" remote set-url origin "$(repo_url_for_dir app)"
git -C "${APP_DIR}" fetch --all --prune
git -C "${APP_DIR}" pull --ff-only

while IFS= read -r repo_dir; do
  repo_name="$(basename "${repo_dir}")"
  if ! repo_url="$(repo_url_for_dir "${repo_name}")"; then
    echo "skipping unknown mirror directory ${repo_name}" >&2
    continue
  fi
  git -C "${repo_dir}" remote set-url origin "${repo_url}"
  git -C "${repo_dir}" fetch --all --prune
  git -C "${repo_dir}" pull --ff-only
done < <(find "${UPSTREAM_DIR}" -mindepth 1 -maxdepth 1 -type d | sort)

"${ROOT_DIR}/scripts/apply_airgap_patch.sh"

docker compose -f "${ROOT_DIR}/docker-compose.yml" up -d --build
