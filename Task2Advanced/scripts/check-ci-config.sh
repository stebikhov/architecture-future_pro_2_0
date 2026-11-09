#!/usr/bin/env bash
# Проверяет, что CI настроен для планирования/применения в облаке.
#
# Использование: check-ci-config.sh [--environment <имя>] [--message-file <файл>]
#
# Значения берутся из переменных окружения (их задаёт workflow через
# переменные и секреты GitHub Environment):
#   TF_VAR_cloud_id, TF_VAR_folder_id  — идентификаторы Yandex Cloud;
#   TF_STATE_BUCKET, TF_STATE_ENDPOINT  — бакет и endpoint состояния;
#   S3_ACCESS_KEY, S3_SECRET_KEY       — ключи доступа к состоянию.
#
# Аутентификация провайдера задаётся одним из двух способов (одновременно
# нельзя: в провайдере token и service_account_key_file конфликтуют):
#   YC_TOKEN                    — IAM-токен, короткоживущий (до 12 часов);
#   YC_SERVICE_ACCOUNT_KEY_FILE — путь к ключу сервисного аккаунта, без срока.
#
# Код возврата:
#   0 — все параметры заданы;
#   1 — часть параметров не задана (список — в stderr);
#   2 — ошибка аргументов.
#
# Скрипт ничего не печатает в stdout при успехе: вызывающая сторона решает,
# что делать — упасть или пропустить шаг.
set -uo pipefail

environment=""
message_file=""

while [ $# -gt 0 ]; do
  case "$1" in
    --environment)
      environment="${2:?--environment требует значение}"
      shift 2
      ;;
    --message-file)
      message_file="${2:?--message-file требует значение}"
      shift 2
      ;;
    -h | --help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "неизвестный аргумент: $1" >&2
      exit 2
      ;;
  esac
done

# Список обязательных параметров: имя переменной окружения и то, как оно
# называется в настройках GitHub (variables/secrets).
required=(
  "TF_VAR_cloud_id:YC_CLOUD_ID"
  "TF_VAR_folder_id:YC_FOLDER_ID"
  "TF_STATE_BUCKET:TF_STATE_BUCKET"
  "TF_STATE_ENDPOINT:TF_STATE_ENDPOINT"
  "S3_ACCESS_KEY:S3_ACCESS_KEY"
  "S3_SECRET_KEY:S3_SECRET_KEY"
)

missing=()
for entry in "${required[@]}"; do
  var_name="${entry%%:*}"
  gh_name="${entry##*:}"
  if [ -z "${!var_name:-}" ]; then
    missing+=("$gh_name")
  fi
done

# Аутентификация провайдера: достаточно одного из двух способов.
if [ -z "${YC_TOKEN:-}" ] && [ -z "${YC_SERVICE_ACCOUNT_KEY_FILE:-}" ]; then
  missing+=("YC_SA_KEY_FILE или YC_TOKEN")
fi

if [ ${#missing[@]} -eq 0 ]; then
  exit 0
fi

if [ -n "$message_file" ]; then
  {
    echo "## План не выполнен: CI не настроен"
    echo
    echo "Не заданы: \`${missing[*]}\`."
    echo
    if [ -n "$environment" ]; then
      echo "Окружение GitHub Environment: \`$environment\`."
      echo
    fi
    echo "Переменные GitHub (Environment): \`YC_CLOUD_ID\`, \`YC_FOLDER_ID\`,"
    echo "\`TF_STATE_BUCKET\`, \`TF_STATE_ENDPOINT\`."
    echo
    echo "Секреты GitHub (тот же Environment): \`S3_ACCESS_KEY\`, \`S3_SECRET_KEY\`."
    echo "Аутентификация провайдера: \`YC_SA_KEY_FILE\` (ключ сервисного аккаунта)"
    echo "или \`YC_TOKEN\` (IAM-токен, до 12 часов) — достаточно одного из них."
  } > "$message_file"
fi

echo "Не заданы параметры CI: ${missing[*]}" >&2
exit 1
