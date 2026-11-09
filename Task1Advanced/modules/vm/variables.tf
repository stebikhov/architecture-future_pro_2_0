variable "name" {
  description = "Имя ВМ (используется как префикс для дисков, подсети и группы безопасности)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,54}[a-z0-9])?$", var.name))
    error_message = "name: строчные латинские буквы, цифры и дефис, не длиннее 56 символов (к имени добавляются суффиксы -net/-subnet/-sg/-data)."
  }
}

variable "environment" {
  description = "Имя окружения или рабочей нагрузки (dev, stage, prod, имя команды и т. п.). Используется в метках ресурсов."
  type        = string
  nullable    = false
}

variable "zone" {
  description = "Зона доступности, в которой создаются ВМ, диски и сеть."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.zone))
    error_message = "zone должна содержать только строчные латинские буквы, цифры и дефис (например, ru-central1-a)."
  }
}

variable "cores" {
  description = "Количество vCPU."
  type        = number
  nullable    = false

  validation {
    condition     = var.cores >= 1
    error_message = "cores должно быть >= 1."
  }
}

variable "memory_gb" {
  description = "Объём RAM в ГБ."
  type        = number
  nullable    = false

  validation {
    condition     = var.memory_gb >= 1
    error_message = "memory_gb должно быть >= 1."
  }
}

variable "core_fraction" {
  description = "Гарантированная доля vCPU, % (5, 20, 50, 100). Применима только к платформам standard-*."
  type        = number
  default     = 100

  validation {
    condition     = contains([5, 20, 50, 100], var.core_fraction)
    error_message = "core_fraction должно быть одним из: 5, 20, 50, 100."
  }
}

variable "preemptible" {
  description = "Прерываемая ВМ (для dev/stage экономит бюджет)."
  type        = bool
  default     = false
}

variable "platform_id" {
  description = "Платформа ВМ."
  type        = string
  default     = "standard-v3"
}

variable "image_id" {
  description = "ID образа загрузочного диска."
  type        = string
  nullable    = false
}

variable "boot_disk_size_gb" {
  description = "Размер загрузочного диска, ГБ."
  type        = number
  default     = 20

  validation {
    condition     = var.boot_disk_size_gb >= 10
    error_message = "boot_disk_size_gb должно быть >= 10."
  }
}

variable "boot_disk_type" {
  description = "Тип загрузочного диска (network-hdd, network-ssd, network-ssd-nonreplicated)."
  type        = string
  default     = "network-ssd"

  validation {
    condition     = contains(["network-hdd", "network-ssd", "network-ssd-nonreplicated"], var.boot_disk_type)
    error_message = "boot_disk_type должно быть одним из: network-hdd, network-ssd, network-ssd-nonreplicated."
  }
}

variable "data_disk_size_gb" {
  description = "Размер подключаемого (дополнительного) диска, ГБ. 0 — диск не создаётся."
  type        = number
  default     = 0

  validation {
    condition     = var.data_disk_size_gb >= 0
    error_message = "data_disk_size_gb не может быть отрицательным."
  }
}

variable "data_disk_type" {
  description = "Тип подключаемого диска (network-hdd, network-ssd, network-ssd-nonreplicated)."
  type        = string
  default     = "network-ssd"

  validation {
    condition     = contains(["network-hdd", "network-ssd", "network-ssd-nonreplicated"], var.data_disk_type)
    error_message = "data_disk_type должно быть одним из: network-hdd, network-ssd, network-ssd-nonreplicated."
  }
}

variable "kms_key_id" {
  description = "ID ключа KMS для шифрования загрузочного и подключаемого дисков. Пустая строка — без явного шифрования."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "ID подсети, к которой подключается ВМ. Обязателен, если create_network = false."
  type        = string
  default     = ""
  nullable    = false
}

variable "create_network" {
  description = "Создавать ли внутри модуля VPC-сеть и подсеть (true) или использовать внешнюю подсеть из subnet_id (false)."
  type        = bool
  default     = false
}

variable "subnet_cidr" {
  description = "CIDR создаваемой подсети (используется при create_network = true)."
  type        = string
  default     = "10.10.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.subnet_cidr))
    error_message = "subnet_cidr должен быть корректным IPv4 CIDR, например 10.10.1.0/24."
  }
}

variable "create_security_group" {
  description = "Создавать ли группу безопасности с правилом SSH. Требует подсеть (subnet_id или созданную модулем)."
  type        = bool
  default     = false
}

variable "ssh_port" {
  description = "Порт SSH в создаваемой группе безопасности."
  type        = number
  default     = 22

  validation {
    condition     = var.ssh_port >= 1 && var.ssh_port <= 65535
    error_message = "ssh_port должен быть в диапазоне 1–65535."
  }
}

variable "ssh_ingress_cidr" {
  description = "Подсети, с которых разрешён SSH в создаваемой группе безопасности. Значение по умолчанию открывает SSH всему интернету: для stage/prod задавайте внутренний диапазон явно."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrnetmask(var.ssh_ingress_cidr))
    error_message = "ssh_ingress_cidr должен быть корректным IPv4 CIDR, например 10.0.0.0/8."
  }
}

variable "assign_public_ip" {
  description = "Выдавать ли ВМ публичный IP (NAT)."
  type        = bool
  default     = false
}

variable "security_group_ids" {
  description = "Список ID групп безопасности для сетевого интерфейса (дополняется созданной модулем)."
  type        = list(string)
  default     = []
}

variable "ssh_user" {
  description = "Имя пользователя, для которого добавляется SSH-ключ."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ (содержимое, например, из ~/.ssh/id_ed25519.pub)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) ", var.ssh_public_key))
    error_message = "ssh_public_key должен быть публичным ключом в формате OpenSSH (ssh-ed25519, ssh-rsa, ecdsa-sha2-*)."
  }

  # Публичный ключ не является секретом. Пометка sensitive лишь убирает значение из вывода
  # plan/apply, чтобы не засорять логи CI; как меру защиты её рассматривать не следует.
  sensitive = true
}

variable "service_account_id" {
  description = "ID сервисного аккаунта, привязываемого к ВМ. Пустая строка — без сервисного аккаунта."
  type        = string
  default     = ""
}

variable "description" {
  description = "Описание ресурсов ВМ, дисков и сети (инвентаризация)."
  type        = string
  default     = ""
}

variable "allow_stopping_for_update" {
  description = "Разрешить Terraform останавливать ВМ для обновления ресурсов (ядра, RAM, платформа, preemptible)."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Дополнительные метки ресурсов."
  type        = map(string)
  default     = {}
}
