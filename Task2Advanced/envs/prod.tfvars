# cloud_id и folder_id задаются через TF_VAR_cloud_id / TF_VAR_folder_id
# (в CI — через переменные GitHub Environment, локально — через переменные окружения). Пример:
#   bash: export TF_VAR_cloud_id=... TF_VAR_folder_id=...
#   PowerShell: $env:TF_VAR_cloud_id="..."; $env:TF_VAR_folder_id="..."
# cloud_id  = "b1g00000000000000001"
# folder_id = "b1g00000000000000002"

env         = "prod"
zone        = "ru-central1-a"
subnet_cidr = "10.30.0.0/24"
