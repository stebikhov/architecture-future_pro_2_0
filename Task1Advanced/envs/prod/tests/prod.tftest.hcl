# Офлайн-проверка окружения: план собирается с конфигурацией из prod.tfvars.
# Значения переменных окружения берутся из tfvars, поэтому тест запускается так:
#
#   cd envs/prod && terraform test -var-file=prod.tfvars
#
# mock_provider не обращается к Yandex Cloud — проверяется связность конфигурации
# (вызов модуля, передача параметров, валидации), а не факт создания ресурсов.

mock_provider "yandex" {}

variables {
  # Идентификаторы облака и каталога приходят из переменных окружения в реальном
  # запуске; в тесте они не используются, потому что провайдер замокан.
  cloud_id  = "test-cloud-id"
  folder_id = "test-folder-id"
}

run "plan" {
  command = plan

  # Значения из run-блока имеют приоритет над -var-file, поэтому KMS-ключ здесь
  # задаётся фиктивным: реальный ключ в prod обязателен (check в main.tf), но
  # для офлайн-проверки конфигурации он не нужен.
  variables {
    kms_key_id = "test-kms-key-not-a-real-key"
  }

  assert {
    condition     = module.vm.name == "future2-prod-app-01"
    error_message = "Имя ВМ должно приходить из prod.tfvars: future2-prod-app-01."
  }

  assert {
    condition     = terraform_data.destroy_guard.input == "future2-prod: удаление окружения запрещено (prevent_destroy)"
    error_message = "В prod должен быть служебный ресурс-защита от случайного destroy."
  }
}
