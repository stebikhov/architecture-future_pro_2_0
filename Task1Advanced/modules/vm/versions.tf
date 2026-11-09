terraform {
  # >= 1.7 — минимальная версия с mock_provider, который используется в тестах модуля.
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.243"
    }
  }
}
