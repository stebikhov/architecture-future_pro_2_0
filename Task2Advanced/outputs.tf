output "network_id" {
  description = "ID сети окружения."
  value       = yandex_vpc_network.this.id
}

output "subnet_id" {
  description = "ID подсети окружения."
  value       = yandex_vpc_subnet.this.id
}

output "data_bucket" {
  description = "Имя бакета данных домена."
  value       = yandex_storage_bucket.data.bucket
}
