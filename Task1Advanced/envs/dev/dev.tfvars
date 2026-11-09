# Конфигурация окружения dev.
#
# Перечислены только параметры, которые отличаются от умолчаний модуля
# (modules/vm/variables.tf). Остальное модуль берёт по умолчанию: платформа
# standard-v3, загрузочный диск 20 ГБ network-ssd, подсеть 10.10.1.0/24,
# порт SSH 22, пользователь ubuntu, KMS выключен.
#
# cloud_id и folder_id намеренно не хранятся в tfvars: это идентификаторы
# реального облака, они приходят из переменных окружения (TF_VAR_cloud_id /
# TF_VAR_folder_id) или из переменных GitHub Environment. Для локального запуска:
#   bash:       export TF_VAR_cloud_id=... TF_VAR_folder_id=...
#   PowerShell: $env:TF_VAR_cloud_id="..."; $env:TF_VAR_folder_id="..."
# либо раскомментируйте строки ниже (не коммитьте реальные ID).
# cloud_id  = "b1g00000000000000001"
# folder_id = "b1g00000000000000002"

env  = "dev"
zone = "ru-central1-a"

vm_name       = "future2-dev-app-01"
cores         = 2
memory_gb     = 4
core_fraction = 20
preemptible   = true

# ID образа — заглушка: замените на образ своей среды (см. README, раздел «Образы»).
image_id = "fd8b2b3d-9b7a-4d3f-9c8e-000000000001"

data_disk_size_gb = 50
data_disk_type    = "network-hdd"

# Сеть среды создаётся модулем: VPC-сеть + подсеть + группа безопасности с SSH.
# Для dev SSH разрешён с любого адреса (песочница); в stage/prod диапазон сужен.
create_network        = true
subnet_cidr           = "10.10.1.0/24"
create_security_group = true
assign_public_ip      = true

# Публичный ключ не секретен. Заглушку нужно заменить своим ключом
# или переопределить через TF_VAR_ssh_public_key (формат должен быть валидным ключом OpenSSH).
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderDevKeyReplaceMe dev@future2"

description = "ВМ dev-среды «Будущее 2.0» (песочница, прерываемая)"

labels = {
  cost_center = "dev-sandbox"
  owner       = "platform-team"
}
