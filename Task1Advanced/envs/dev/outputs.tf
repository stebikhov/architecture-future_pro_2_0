output "vm_id" {
  description = "ID виртуальной машины."
  value       = module.vm.id
}

output "vm_name" {
  description = "Имя виртуальной машины."
  value       = module.vm.name
}

output "vm_fqdn" {
  description = "FQDN виртуальной машины внутри Yandex Cloud."
  value       = module.vm.fqdn
}

output "internal_ip" {
  description = "Внутренний IP-адрес ВМ."
  value       = module.vm.internal_ip
}

output "public_ip" {
  description = "Публичный IP-адрес ВМ (null, если публичный IP не выдавался)."
  value       = module.vm.public_ip
}

output "data_disk_id" {
  description = "ID подключаемого диска (null, если диск не создавался)."
  value       = module.vm.data_disk_id
}

output "boot_disk_id" {
  description = "ID загрузочного диска."
  value       = module.vm.boot_disk_id
}

output "subnet_id" {
  description = "ID подсети, к которой подключена ВМ."
  value       = module.vm.subnet_id
}

output "network_id" {
  description = "ID VPC-сети (созданной модулем или найденной по внешней подсети; null, если сеть не создавалась и группа безопасности не запрошена)."
  value       = module.vm.network_id
}

output "security_group_ids" {
  description = "ID групп безопасности, применённых к ВМ."
  value       = module.vm.security_group_ids
}
