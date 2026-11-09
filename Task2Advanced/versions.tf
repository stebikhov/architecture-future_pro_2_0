terraform {
  # >= 1.10.0 — S3-native блокировка состояния (use_lockfile) и mock_provider
  # для офлайн-тестов; < 2.0.0 — защита от breaking changes.
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.243"
    }
  }

  # Удалённое состояние в S3-совместимом хранилище (Yandex Object Storage / MinIO).
  # Параметры bucket/key/endpoint и ключи доступа НЕ хранятся в коде:
  # они передаются через `terraform init -backend-config=...` и переменные окружения
  # AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (секреты CI).
  backend "s3" {
    region = "ru-central1"

    # Блокировка состояния — S3-native: lock-файл <key>.tflock создаётся в том же
    # бакете рядом с состоянием (Terraform >= 1.10). Требует поддержки условных
    # запросов (If-None-Match) со стороны хранилища. DynamoDB-совместимая
    # блокировка объявлена HashiCorp устаревшей и больше не используется:
    # дополнительных сервисов (YDB/DynamoDB) и их ручного bootstrap не требуется.
    use_lockfile = true

    # Параметры ниже нужны для S3-совместимых хранилищ, не являющихся AWS.
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true

    # Шифрование состояния включается на бакете (KMS-ключ Yandex Object Storage),
    # а не через encrypt = true: Terraform без kms_key_id отправляет AES256,
    # который Object Storage не поддерживает, а kms_key_id валидируется как AWS KMS ID/ARN.
  }
}
