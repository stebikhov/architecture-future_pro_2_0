# Офлайн-тесты модуля: mock_provider не обращается к Yandex Cloud,
# поэтому проверяется логика конфигурации (количество ресурсов, параметры ВМ,
# валидации переменных), а не факт создания ресурсов.
#
#   cd modules/vm && terraform test

mock_provider "yandex" {}

variables {
  name           = "test-vm"
  environment    = "test"
  zone           = "ru-central1-a"
  cores          = 2
  memory_gb      = 4
  image_id       = "test-image-id"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestOnlyKeyForUnitTests test@example"

  create_network        = true
  create_security_group = true
}

# Базовая конфигурация: ВМ + подключаемый диск.
run "vm_with_data_disk" {
  command = plan

  variables {
    data_disk_size_gb = 50
    data_disk_type    = "network-ssd"
  }

  assert {
    condition     = yandex_compute_instance.this.name == "test-vm"
    error_message = "ВМ должна создаваться с переданным именем."
  }

  assert {
    condition     = length(yandex_compute_disk.data) == 1
    error_message = "При data_disk_size_gb = 50 должен создаваться один подключаемый диск."
  }

  assert {
    condition     = yandex_compute_instance.this.resources[0].cores == 2
    error_message = "Количество ядер должно передаваться в ресурсы ВМ без изменений."
  }

  assert {
    condition     = yandex_compute_instance.this.resources[0].memory == 4
    error_message = "Объём RAM должен передаваться в ресурсы ВМ без изменений."
  }

  assert {
    condition     = length(yandex_vpc_network.this) == 1 && length(yandex_vpc_subnet.this) == 1
    error_message = "При create_network = true должны создаваться сеть и подсеть."
  }

  assert {
    condition     = length(yandex_vpc_security_group.this) == 1
    error_message = "При create_security_group = true должна создаваться группа безопасности."
  }
}

# Конфигурация без подключаемого диска.
run "vm_without_data_disk" {
  command = plan

  variables {
    data_disk_size_gb = 0
  }

  assert {
    condition     = length(yandex_compute_disk.data) == 0
    error_message = "При data_disk_size_gb = 0 подключаемый диск создаваться не должен."
  }

  assert {
    condition     = yandex_compute_instance.this.name == "test-vm"
    error_message = "ВМ должна создаваться в любом случае."
  }
}

# Внешняя подсеть: сеть и подсеть модулем не создаются.
run "vm_with_external_subnet" {
  command = plan

  variables {
    create_network        = false
    create_security_group = false
    subnet_id             = "external-subnet-id"
  }

  assert {
    condition     = length(yandex_vpc_network.this) == 0 && length(yandex_vpc_subnet.this) == 0
    error_message = "При create_network = false сеть и подсеть создаваться не должны."
  }

  assert {
    condition     = yandex_compute_instance.this.network_interface[0].subnet_id == "external-subnet-id"
    error_message = "ВМ должна подключаться к переданной внешней подсети."
  }
}

# Некорректная доля vCPU отклоняется на этапе plan.
run "invalid_core_fraction" {
  command = plan

  variables {
    core_fraction = 7
  }

  expect_failures = [
    var.core_fraction,
  ]
}

# Без подсети и без create_network конфигурация невалидна.
run "subnet_id_required" {
  command = plan

  variables {
    create_network = false
    subnet_id      = ""
  }

  expect_failures = [
    yandex_compute_instance.this,
  ]
}

# subnet_id и create_network = true несовместимы: подсеть создаёт модуль.
run "subnet_id_conflicts_with_create_network" {
  command = plan

  variables {
    create_network = true
    subnet_id      = "external-subnet-id"
  }

  expect_failures = [
    yandex_compute_instance.this,
  ]
}
