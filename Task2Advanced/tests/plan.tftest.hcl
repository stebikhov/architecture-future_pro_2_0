# Офлайн-проверка конфигурации Task1Advanced: mock_provider не обращается к Yandex Cloud.
# Проверяются состав ресурсов и ключевые параметры, а не факт создания в облаке.
#
#   cd Task2Advanced && terraform init -backend=false && terraform test

mock_provider "yandex" {}

variables {
  cloud_id    = "test-cloud-id"
  folder_id   = "test-folder-id"
  env         = "dev"
  subnet_cidr = "10.10.0.0/24"
}

run "plan" {
  command = plan

  assert {
    condition     = yandex_vpc_subnet.this.v4_cidr_blocks[0] == "10.10.0.0/24"
    error_message = "CIDR подсети должен приходить из subnet_cidr."
  }

  assert {
    condition     = one([for flag in yandex_storage_bucket.data.anonymous_access_flags : flag.read]) == false
    error_message = "Бакет данных должен быть приватным (read = false)."
  }

  assert {
    condition     = one([for flag in yandex_storage_bucket.data.anonymous_access_flags : flag.list]) == false
    error_message = "Листинг бакета данных должен быть запрещён (list = false)."
  }

  assert {
    condition     = one([for v in yandex_storage_bucket.data.versioning : v.enabled]) == true
    error_message = "Версионирование бакета данных должно быть включено."
  }

  assert {
    condition     = yandex_storage_bucket.data.bucket == "future2-dev-domain-data"
    error_message = "Имя бакета данных должно включать окружение."
  }

  assert {
    condition     = yandex_vpc_network.this.name == "future2-dev-net"
    error_message = "Имя сети должно включать окружение."
  }
}
