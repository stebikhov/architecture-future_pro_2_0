output "id" {
  description = "ID виртуальной машины."
  value       = yandex_compute_instance.this.id
}

output "name" {
  description = "Имя виртуальной машины."
  value       = yandex_compute_instance.this.name
}

output "fqdn" {
  description = "FQDN виртуальной машины (внутри Yandex Cloud)."
  value       = yandex_compute_instance.this.fqdn
}

output "internal_ip" {
  description = "Внутренний IP-адрес ВМ."
  value       = yandex_compute_instance.this.network_interface[0].ip_address
}

output "public_ip" {
  description = "Публичный IP-адрес ВМ (null, если публичный IP не выдавался)."
  value       = local.public_ip != "" ? local.public_ip : null
}

output "data_disk_id" {
  description = "ID подключаемого диска (null, если диск не создавался)."
  value       = one(yandex_compute_disk.data[*].id)
}

output "boot_disk_id" {
  description = "ID загрузочного диска."
  value       = yandex_compute_instance.this.boot_disk[0].disk_id
}

output "subnet_id" {
  description = "ID подсети, к которой подключена ВМ (созданная модулем или внешняя)."
  value       = local.subnet_id
}

output "network_id" {
  description = "ID VPC-сети (созданной модулем или найденной по внешней подсети; null, если сеть не создавалась и группа безопасности не запрошена)."
  value       = local.network_id
}

output "security_group_ids" {
  description = "ID групп безопасности, применённых к сетевому интерфейсу ВМ."
  value       = local.security_group_ids
}
