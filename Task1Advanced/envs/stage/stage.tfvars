# Конфигурация окружения stage.
#
# Перечислены только параметры, которые отличаются от умолчаний модуля
# (modules/vm/variables.tf). Остальное модуль берёт по умолчанию: платформа
# standard-v3, загрузочный диск 20 ГБ network-ssd, порт SSH 22, пользователь
# ubuntu, KMS выключен, публичный IP не выдаётся.
#
# cloud_id и folder_id намеренно не хранятся в tfvars: это идентификаторы
# реального облака, они приходят из переменных окружения (TF_VAR_cloud_id /
# TF_VAR_folder_id) или из переменных GitHub Environment. Для локального запуска:
#   bash:       export TF_VAR_cloud_id=... TF_VAR_folder_id=...
#   PowerShell: $env:TF_VAR_cloud_id="..."; $env:TF_VAR_folder_id="..."
# либо раскомментируйте строки ниже (не коммитьте реальные ID).
# cloud_id  = "b1g00000000000000001"
# folder_id = "b1g00000000000000002"

env  = "stage"
zone = "ru-central1-b"

vm_name       = "future2-stage-app-01"
cores         = 4
memory_gb     = 8
core_fraction = 50
preemptible   = false

# ID образа — заглушка: замените на образ своей среды (см. README, раздел «Образы»).
image_id          = "fd8b2b3d-9b7a-4d3f-9c8e-000000000001"
boot_disk_size_gb = 30

data_disk_size_gb = 200

# Сеть среды создаётся модулем. Публичного IP нет: SSH разрешён из корпоративного
# диапазона, а путь до ВМ (bastion/VPN/пиринг) настраивается отдельно — в Task1 он не создаётся.
create_network        = true
subnet_cidr           = "10.20.1.0/24"
create_security_group = true
ssh_ingress_cidr      = "10.0.0.0/8"

# Публичный ключ не секретен. Заглушку нужно заменить своим ключом
# или переопределить через TF_VAR_ssh_public_key (формат должен быть валидным ключом OpenSSH).
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderStageKeyReplaceMe stage@future2"

description = "ВМ stage-среды «Будущее 2.0» (предрелизный контур)"

labels = {
  cost_center = "qa"
  owner       = "platform-team"
}
