terraform {
  # >= 1.9 — нужны проверки переменных, ссылающиеся на другие переменные.
  # mock_provider в офлайн-тестах доступен с 1.7.
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.243"
    }
  }

  # В Task1 состояние локальное, чтобы apply -var-file=<env>.tfvars работал без внешних зависимостей.
  # Удалённый backend (S3) показан в Task2Advanced.
}
