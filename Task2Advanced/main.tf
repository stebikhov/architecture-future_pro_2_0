# Аутентификация провайдера: переменная окружения YC_TOKEN или YC_SERVICE_ACCOUNT_KEY_FILE (из секретов CI).
provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

locals {
  # Служебные метки идут последними: пользовательские labels не должны
  # перетирать environment/managed_by и вводить в заблуждение при инвентаризации.
  labels = merge(var.labels, { environment = var.env, managed_by = "terraform" })
}

resource "yandex_vpc_network" "this" {
  name   = "future2-${var.env}-net"
  labels = local.labels
}

resource "yandex_vpc_subnet" "this" {
  name           = "future2-${var.env}-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = [var.subnet_cidr]
  labels         = local.labels
}

# Бакет под озеро данных домена. Версионирование включено: удаление объекта
# в озерных данных должно быть обратимо.
resource "yandex_storage_bucket" "data" {
  bucket = "future2-${var.env}-domain-data"
  tags   = local.labels

  anonymous_access_flags {
    read = false
    list = false
  }

  versioning {
    enabled = true
  }
}
