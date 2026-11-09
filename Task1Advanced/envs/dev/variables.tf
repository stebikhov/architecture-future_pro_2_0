# Входные параметры окружения dev.
#
# Объявлены только параметры, которые окружение задаёт само (см. dev.tfvars), и
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

# Параметры ВМ, которые задаёт dev.tfvars. Проверки значений — в модуле
# (modules/vm/variables.tf); здесь только описания для читателя и tflint.

variable "vm_name" {
  description = "Имя ВМ в окружении dev."
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
  description = "ID образа загрузочного диска. Значение в dev.tfvars — заглушка, замените (см. README, раздел «Образы, KMS и подготовка среды»)."
  type        = string
}

variable "data_disk_size_gb" {
  description = "Размер подключаемого диска, ГБ."
  type        = number
}

variable "data_disk_type" {
  description = "Тип подключаемого диска (network-hdd, network-ssd, network-ssd-nonreplicated)."
  type        = string
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

variable "assign_public_ip" {
  description = "Выдавать ли ВМ публичный IP (NAT)."
  type        = bool
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
