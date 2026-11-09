# Конфигурация окружения prod.
#
# Перечислены только параметры, которые отличаются от умолчаний модуля
# (modules/vm/variables.tf). Остальное модуль берёт по умолчанию: платформа
# standard-v3, загрузочный диск network-ssd, порт SSH 22, пользователь ubuntu,
# публичный IP не выдаётся.
#
# cloud_id и folder_id намеренно не хранятся в tfvars: это идентификаторы
# реального облака, они приходят из переменных окружения (TF_VAR_cloud_id /
# TF_VAR_folder_id) или из переменных GitHub Environment. Для prod используется
# отдельный каталог (folder_id) с доступом по принципу наименьших привилегий.
#   bash:       export TF_VAR_cloud_id=... TF_VAR_folder_id=...
#   PowerShell: $env:TF_VAR_cloud_id="..."; $env:TF_VAR_folder_id="..."
# либо раскомментируйте строки ниже (не коммитьте реальные ID).
# cloud_id  = "b1g00000000000000001"
# folder_id = "b1g00000000000000003"

env  = "prod"
zone = "ru-central1-a"

vm_name       = "future2-prod-app-01"
cores         = 16
memory_gb     = 64
core_fraction = 100
preemptible   = false

# ID образа — заглушка: замените на hardened-образ prod (см. README, раздел «Образы»).
image_id          = "fd8b2b3d-9b7a-4d3f-9c8e-000000000001"
boot_disk_size_gb = 50

data_disk_size_gb = 1000

# ID ключа KMS для шифрования дисков prod. Заглушка: пустая строка = без явного шифрования,
# и тогда plan печатает предупреждение check "kms_encryption_enabled" (envs/prod/main.tf).
# Задайте реальный ключ — в tfvars или через TF_VAR_kms_key_id (см. README, раздел
# «Образы, KMS и подготовка среды»). В dev и stage KMS не включается: там ключ провайдера по умолчанию.
kms_key_id = ""

# Сеть среды создаётся модулем. Публичного IP нет, SSH разрешён только из
# внутреннего диапазона 10.0.0.0/8. Путь до ВМ (bastion/VPN/пиринг) настраивается
# отдельно — в Task1 он не создаётся.
create_network        = true
subnet_cidr           = "10.30.1.0/24"
create_security_group = true
ssh_ingress_cidr      = "10.0.0.0/8"

# Публичный ключ не секретен. Заглушку нужно заменить своим ключом
# или переопределить через TF_VAR_ssh_public_key (формат должен быть валидным ключом OpenSSH).
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderProdKeyReplaceMe prod@future2"

description = "ВМ prod-среды «Будущее 2.0» (боевой контур, защищён от случайного destroy)"

labels = {
  cost_center = "production"
  owner       = "platform-team"
  criticality = "high"
}
