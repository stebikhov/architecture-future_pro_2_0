# Входные параметры окружения prod.
#
# Объявлены только параметры, которые окружение задаёт само (см. prod.tfvars), и
# доступ к облаку. Полный интерфейс переиспользуемого модуля и все проверки
# значений — в modules/vm/variables.tf: дублировать их здесь не нужно, модуль
# отклоняет некорректные значения сам. Локальные правила окружения — список имён
# сред, допустимая зона и запрет прерываемой ВМ в prod — оставлены ниже.

variable "cloud_id" {
  description = "ID облака Yandex Cloud. Приходит из TF_VAR_cloud_id или переменной GitHub Environment."
  type        = string
  nullable    = false
}

variable "folder_id" {
  description = "ID каталога Yandex Cloud. Приходит из TF_VAR_folder_id или переменной GitHub Environment."
  type        = string
  nullable    = false
}

variable "token" {
  description = "IAM/OAuth-токен. Предпочтительно передавать через YC_TOKEN, а не в .tfvars."
  type        = string
  default     = null
  sensitive   = true
}

variable "env" {
  description = "Имя окружения: dev, stage или prod."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["dev", "stage", "prod"], var.env)
    error_message = "env должно быть одним из: dev, stage, prod."
  }
}

variable "zone" {
  description = "Зона доступности окружения."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^ru-central1-[a-z]$", var.zone))
    error_message = "zone должна быть одной из зон ru-central1-a, ru-central1-b, ru-central1-c, ru-central1-d."
  }
}

variable "preemptible" {
  description = "Прерываемая ВМ. Запрещена в prod."
  type        = bool
  default     = false

  validation {
    condition     = var.env != "prod" || !var.preemptible
    error_message = "В prod preemptible должен быть false."
  }
}

# Параметры ВМ, которые задаёт prod.tfvars. Проверки значений — в модуле
# (modules/vm/variables.tf); здесь только описания для читателя и tflint.

variable "vm_name" {
  description = "Имя ВМ в окружении prod."
  type        = string
}

variable "cores" {
  description = "Количество vCPU."
  type        = number
}

variable "memory_gb" {
  description = "Объём RAM, ГБ."
  type        = number
}

variable "core_fraction" {
  description = "Гарантированная доля vCPU, % (5, 20, 50, 100)."
  type        = number
}

variable "image_id" {
  description = "ID образа загрузочного диска. Значение в prod.tfvars — заглушка, замените на hardened-образ (см. README, раздел «Образы, KMS и подготовка среды»)."
  type        = string
}

variable "boot_disk_size_gb" {
  description = "Размер загрузочного диска, ГБ."
  type        = number
}

variable "data_disk_size_gb" {
  description = "Размер подключаемого диска, ГБ."
  type        = number
}

variable "kms_key_id" {
  description = "ID ключа KMS для шифрования дисков prod. Пустая строка — без явного шифрования; тогда plan печатает предупреждение check \"kms_encryption_enabled\"."
  type        = string
  default     = ""
}

variable "create_network" {
  description = "Создавать ли VPC-сеть и подсеть модулем."
  type        = bool
}

variable "subnet_cidr" {
  description = "CIDR создаваемой подсети."
  type        = string
}

variable "create_security_group" {
  description = "Создавать ли группу безопасности с правилом SSH."
  type        = bool
}

variable "ssh_ingress_cidr" {
  description = "Подсети, с которых разрешён SSH в создаваемой группе безопасности."
  type        = string
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ в формате OpenSSH."
  type        = string
}

variable "description" {
  description = "Описание ресурсов ВМ (инвентаризация)."
  type        = string
}

variable "labels" {
  description = "Метки ресурсов."
  type        = map(string)
}
