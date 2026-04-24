#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/app"
TEMPLATE_DIR="${ROOT_DIR}/templates"

if [[ ! -d "${APP_DIR}/.git" ]]; then
  echo "expected upstream cheat.sh checkout at ${APP_DIR}" >&2
  exit 1
fi

mkdir -p "${APP_DIR}/etc"
mkdir -p "${APP_DIR}/lib/adapter"
mkdir -p "${APP_DIR}/lib"

install -m 0644 "${TEMPLATE_DIR}/config.yaml" "${APP_DIR}/etc/config.yaml"
install -m 0644 "${TEMPLATE_DIR}/Dockerfile.airgapped" "${APP_DIR}/Dockerfile"
install -m 0644 "${TEMPLATE_DIR}/question.py" "${APP_DIR}/lib/adapter/question.py"
install -m 0644 "${TEMPLATE_DIR}/personal.py" "${APP_DIR}/lib/adapter/personal.py"
