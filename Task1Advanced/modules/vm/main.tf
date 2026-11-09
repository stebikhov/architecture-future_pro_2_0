locals {
  labels = merge(
    {
      environment = var.environment
      managed_by  = "terraform"
    },
    var.labels
  )

  create_data_disk = var.data_disk_size_gb > 0

  # Сеть: либо создаётся модулем (create_network), либо берётся извне (subnet_id).
  # network_id нужен для группы безопасности: при внешней подсети он читается из data source.
  network_id = var.create_network ? yandex_vpc_network.this[0].id : try(data.yandex_vpc_subnet.this[0].network_id, null)
  subnet_id  = var.create_network ? yandex_vpc_subnet.this[0].id : var.subnet_id

  # Группы безопасности модуля объединяются с переданными извне; distinct
  # убирает дубли, если внешняя группа уже попала в security_group_ids.
  security_group_ids = distinct(concat(
    var.security_group_ids,
    var.create_security_group ? [yandex_vpc_security_group.this[0].id] : [],
  ))

  # Провайдер не заполняет nat_ip_address, если NAT не назначен: в состоянии будет "",
  # а не null. Приведение к единому null делается в outputs.tf.
  public_ip = try(yandex_compute_instance.this.network_interface[0].nat_ip_address, "")
}

# Сеть и подсеть создаются модулем, только если create_network = true.
resource "yandex_vpc_network" "this" {
  count = var.create_network ? 1 : 0

  name        = "${var.name}-net"
  description = var.description
  labels      = local.labels
}

resource "yandex_vpc_subnet" "this" {
  count = var.create_network ? 1 : 0

  name           = "${var.name}-subnet"
  description    = var.description
  zone           = var.zone
  network_id     = yandex_vpc_network.this[0].id
  v4_cidr_blocks = [var.subnet_cidr]
  labels         = local.labels
}

# Data source нужен только когда модуль создаёт группу безопасности для внешней
# подсети: иначе plan дёргал бы API для заведомо несуществующего subnet_id.
data "yandex_vpc_subnet" "this" {
  count = var.create_security_group && !var.create_network ? 1 : 0

  subnet_id = var.subnet_id
}

# Единственное правило — SSH с указанного диапазона; остальные порты закрыты.
resource "yandex_vpc_security_group" "this" {
  count = var.create_security_group ? 1 : 0

  name        = "${var.name}-sg"
  description = "SSH-доступ к ВМ ${var.name}"
  network_id  = local.network_id
  labels      = local.labels

  ingress {
    protocol       = "TCP"
    port           = var.ssh_port
    v4_cidr_blocks = [var.ssh_ingress_cidr]
    description    = "SSH с ${var.ssh_ingress_cidr}"
  }
}

# Дополнительный диск. Не создаётся, если data_disk_size_gb = 0.
resource "yandex_compute_disk" "data" {
  count = local.create_data_disk ? 1 : 0

  name       = "${var.name}-data"
  zone       = var.zone
  type       = var.data_disk_type
  size       = var.data_disk_size_gb
  kms_key_id = var.kms_key_id != "" ? var.kms_key_id : null
  labels     = local.labels
}

resource "yandex_compute_instance" "this" {
  name                      = var.name
  hostname                  = var.name
  description               = var.description
  zone                      = var.zone
  platform_id               = var.platform_id
  labels                    = local.labels
  service_account_id        = var.service_account_id != "" ? var.service_account_id : null
  allow_stopping_for_update = var.allow_stopping_for_update

  resources {
    cores         = var.cores
    memory        = var.memory_gb
    core_fraction = var.core_fraction
  }

  scheduling_policy {
    preemptible = var.preemptible
  }

  boot_disk {
    initialize_params {
      image_id   = var.image_id
      size       = var.boot_disk_size_gb
      type       = var.boot_disk_type
      kms_key_id = var.kms_key_id != "" ? var.kms_key_id : null
    }
  }

  dynamic "secondary_disk" {
    for_each = yandex_compute_disk.data
    content {
      disk_id     = secondary_disk.value.id
      auto_delete = false
    }
  }

  network_interface {
    subnet_id          = local.subnet_id
    nat                = var.assign_public_ip
    security_group_ids = local.security_group_ids
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  lifecycle {
    precondition {
      condition     = var.create_network || length(trimspace(var.subnet_id)) > 0
      error_message = "subnet_id обязателен, если create_network = false."
    }

    precondition {
      condition     = !var.create_network || length(trimspace(var.subnet_id)) == 0
      error_message = "subnet_id нельзя задавать при create_network = true: подсеть создаётся модулем."
    }

    precondition {
      condition     = !var.create_security_group || var.create_network || length(trimspace(var.subnet_id)) > 0
      error_message = "Для create_security_group = true нужна подсеть: subnet_id или create_network = true."
    }
  }
}
