# Офлайн-проверка окружения: план собирается с конфигурацией из dev.tfvars.
# Значения переменных окружения берутся из tfvars, поэтому тест запускается так:
#
#   cd envs/dev && terraform test -var-file=dev.tfvars
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

  assert {
    condition     = module.vm.name == "future2-dev-app-01"
    error_message = "Имя ВМ должно приходить из dev.tfvars: future2-dev-app-01."
  }
}
