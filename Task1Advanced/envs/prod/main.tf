module "vm" {
  source = "../../modules/vm"

  name          = var.vm_name
  environment   = var.env
  zone          = var.zone
  cores         = var.cores
  memory_gb     = var.memory_gb
  core_fraction = var.core_fraction
  preemptible   = var.preemptible

  image_id          = var.image_id
  boot_disk_size_gb = var.boot_disk_size_gb
  data_disk_size_gb = var.data_disk_size_gb
  kms_key_id        = var.kms_key_id

  create_network        = var.create_network
  subnet_cidr           = var.subnet_cidr
  create_security_group = var.create_security_group
  ssh_ingress_cidr      = var.ssh_ingress_cidr

  ssh_public_key = var.ssh_public_key
  description    = var.description

  labels = var.labels
}

# Защита prod от случайного удаления.
#
# Блок `lifecycle` нельзя разместить в блоке `module` (Terraform не поддерживает
# lifecycle в module-блоках), поэтому защита реализована служебным ресурсом с
# prevent_destroy: при попытке удалить окружение план destroy падает целиком —
# ни один ресурс prod не удаляется. Снять защиту — только осознанным удалением
# этого блока из файла (review обязателен).
resource "terraform_data" "destroy_guard" {
  input = "future2-prod: удаление окружения запрещено (prevent_destroy)"

  lifecycle {
    prevent_destroy = true
  }
}

# Контроль KMS-шифрования prod. Именно check, а не validation: проверка не блокирует apply
# (иначе офлайн-тест окружения падал бы на заглушке), но попадает в вывод каждого плана.
check "kms_encryption_enabled" {
  assert {
    condition     = length(trimspace(var.kms_key_id)) > 0
    error_message = "В prod диски должны шифроваться KMS-ключом: задайте kms_key_id (см. README, раздел «Образы, KMS и подготовка среды»)."
  }
}
