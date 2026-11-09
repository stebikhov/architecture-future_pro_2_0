#!/usr/bin/env bash
# Генерирует backend.hcl для `terraform init`.
#
# Использование: gen-backend-config.sh <dev|stage|prod> [путь к backend.hcl]
#
# Значения берутся из переменных окружения (их задаёт workflow через переменные
# GitHub Environment), поэтому в репозиторий и артефакты ничего секретного не попадает.
#
# Блокировка состояния здесь не настраивается: она включена в versions.tf
# (backend "s3" { use_lockfile = true }), поэтому lock-файл создаётся в том же бакете
# рядом с состоянием (<key>.tflock) и дополнительных сервисов не требуется.
set -euo pipefail

env_name="${1:?использование: gen-backend-config.sh <dev|stage|prod> [файл-вывода]}"
out="${2:-backend.hcl}"

case "$env_name" in
  dev|stage|prod) ;;
  *)
    echo "окружение должно быть одним из: dev, stage, prod (получено: ${env_name})" >&2
    exit 1
    ;;
esac

: "${TF_STATE_BUCKET:?TF_STATE_BUCKET обязателен}"
: "${TF_STATE_ENDPOINT:?TF_STATE_ENDPOINT обязателен}"

case "$TF_STATE_BUCKET" in
  */*)
    echo "TF_STATE_BUCKET должен быть именем бакета без пути (получено: ${TF_STATE_BUCKET})" >&2
    exit 1
    ;;
esac

case "$TF_STATE_ENDPOINT" in
  http://*|https://*) ;;
  *)
    echo "TF_STATE_ENDPOINT должен быть URL со схемой http(s):// (получено: ${TF_STATE_ENDPOINT})" >&2
    exit 1
    ;;
esac

{
  echo "bucket = \"${TF_STATE_BUCKET}\""
  echo "key    = \"${env_name}/terraform.tfstate\""
  echo "endpoints = {"
  echo "  s3 = \"${TF_STATE_ENDPOINT}\""
  echo "}"
} > "$out"

echo "backend-конфигурация записана в ${out} (окружение: ${env_name})"
