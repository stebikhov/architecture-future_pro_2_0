# cloud_id и folder_id намеренно не хранятся в tfvars: в CI они приходят из
# переменных GitHub Environment (TF_VAR_cloud_id / TF_VAR_folder_id). Для локального запуска
# задайте их переменными окружения:
#   bash:       export TF_VAR_cloud_id=... TF_VAR_folder_id=...
#   PowerShell: $env:TF_VAR_cloud_id="..."; $env:TF_VAR_folder_id="..."
# либо раскомментируйте строки ниже (не коммитьте реальные ID).
# cloud_id  = "b1g00000000000000001"
# folder_id = "b1g00000000000000002"

env         = "dev"
zone        = "ru-central1-a"
subnet_cidr = "10.10.0.0/24"
