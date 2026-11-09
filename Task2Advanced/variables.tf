variable "cloud_id" {
  description = "ID облака Yandex Cloud."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.cloud_id)) > 0
    error_message = "cloud_id не может быть пустым."
  }
}

variable "folder_id" {
  description = "ID каталога Yandex Cloud."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.folder_id)) > 0
    error_message = "folder_id не может быть пустым."
  }
}

variable "zone" {
  description = "Зона доступности."
  type        = string
  default     = "ru-central1-a"

  validation {
    condition     = can(regex("^ru-central1-[a-z]$", var.zone))
    error_message = "zone должна быть одной из зон ru-central1-a, ru-central1-b, ru-central1-c, ru-central1-d."
  }
}

variable "env" {
  description = "Окружение: dev, stage или prod."
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.env)
    error_message = "env должно быть одним из: dev, stage, prod."
  }
}

variable "subnet_cidr" {
  description = "CIDR подсети окружения."
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrnetmask(var.subnet_cidr))
    error_message = "subnet_cidr должен быть корректным IPv4 CIDR, например 10.10.0.0/24."
  }
}

variable "labels" {
  description = "Метки ресурсов."
  type        = map(string)
  default     = {}
}
