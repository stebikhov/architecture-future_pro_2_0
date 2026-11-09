# Task1Advanced — переиспользуемый модуль Terraform `vm`

Модуль `vm` создаёт виртуальную машину в Yandex Cloud: загрузочный диск, опциональный
подключаемый диск, сетевой интерфейс (VPC-сеть, подсеть и группа безопасности — по запросу)
и SSH-ключ.

Внутри модуля нет значений, привязанных к окружению: всё задаётся переменными,
а различия между `dev`, `stage` и `prod` вынесены в файл `<env>.tfvars` каждого окружения.
Модуль переиспользуется в трёх корневых модулях — по одному на окружение; каждый из них
вызывает `modules/vm` и передаёт ему только свои параметры:

```
Task1Advanced/
├── modules/vm/       # переиспользуемый модуль: main.tf, variables.tf, outputs.tf, versions.tf, tests/
└── envs/
    ├── dev/          # main.tf, variables.tf, provider.tf, versions.tf, outputs.tf, dev.tfvars, tests/
    ├── stage/        # то же + stage.tfvars
    └── prod/         # то же + prod.tfvars
```

## Параметры модуля

| Переменная                  | Тип          | По умолчанию | Описание                                                                                               |
| --------------------------- | ------------ | ------------ | ------------------------------------------------------------------------------------------------------ |
| `name`                      | string       | —            | Имя ВМ (префикс для диска, подсети и группы безопасности), ≤ 56 символов — к нему добавляются суффиксы |
| `environment`               | string       | —            | Окружение/нагрузка (только для меток)                                                                  |
| `zone`                      | string       | —            | Зона доступности                                                                                       |
| `cores`                     | number       | —            | Количество ядер                                                                                        |
| `memory_gb`                 | number       | —            | Объём RAM, ГБ                                                                                          |
| `core_fraction`             | number       | 100          | Гарантированная доля vCPU, % (допустимо 5, 20, 50, 100 — проверяется `validation`)                     |
| `preemptible`               | bool         | false        | Прерываемая ВМ                                                                                         |
| `platform_id`               | string       | standard-v3  | Платформа                                                                                              |
| `image_id`                  | string       | —            | Образ загрузочного диска                                                                               |
| `boot_disk_size_gb`         | number       | 20           | Размер загрузочного диска, ГБ                                                                          |
| `boot_disk_type`            | string       | network-ssd  | Тип загрузочного диска                                                                                 |
| `data_disk_size_gb`         | number       | 0            | Размер подключаемого диска (0 — не создавать)                                                          |
| `data_disk_type`            | string       | network-ssd  | Тип подключаемого диска                                                                                |
| `kms_key_id`                | string       | ""           | Ключ KMS для шифрования дисков (пусто — без явного шифрования)                                         |
| `subnet_id`                 | string       | ""           | ID внешней подсети (обязателен при `create_network = false`)                                           |
| `create_network`            | bool         | false        | Создавать ли VPC-сеть и подсеть модулем                                                                |
| `subnet_cidr`               | string       | 10.10.1.0/24 | CIDR создаваемой подсети (проверяется `validation`)                                                    |
| `create_security_group`     | bool         | false        | Создавать ли группу безопасности с правилом SSH                                                        |
| `ssh_port`                  | number       | 22           | Порт SSH                                                                                               |
| `ssh_ingress_cidr`          | string       | 0.0.0.0/0    | Подсети, с которых разрешён SSH (по умолчанию открыт всем — задавайте явно; проверяется `validation`)  |
| `assign_public_ip`          | bool         | false        | Публичный IP (NAT)                                                                                     |
| `security_group_ids`        | list(string) | []           | Внешние группы безопасности (дополняются созданной модулем)                                            |
| `ssh_user`                  | string       | ubuntu       | Пользователь для SSH-ключа                                                                             |
| `ssh_public_key`            | string       | —            | Публичный SSH-ключ (`sensitive = true`)                                                                |
| `service_account_id`        | string       | ""           | Сервисный аккаунт ВМ                                                                                   |
| `description`               | string       | ""           | Описание ресурсов (инвентаризация)                                                                     |
| `allow_stopping_for_update` | bool         | true         | Разрешить Terraform останавливать ВМ при смене ядер/RAM/платформы                                      |
| `labels`                    | map(string)  | {}           | Дополнительные метки                                                                                   |

## Outputs (/modules/vm/outputs.tf)

| Выход                | Описание                                                                                                                              |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `id`                 | ID ВМ                                                                                                                                 |
| `name`               | Имя ВМ                                                                                                                                |
| `fqdn`               | FQDN ВМ внутри Yandex Cloud                                                                                                           |
| `internal_ip`        | Внутренний IP                                                                                                                         |
| `public_ip`          | Публичный IP (`null`, если не выдан)                                                                                                  |
| `data_disk_id`       | ID подключаемого диска (`null`, если нет)                                                                                             |
| `boot_disk_id`       | ID загрузочного диска                                                                                                                 |
| `subnet_id`          | ID подсети, к которой подключена ВМ                                                                                                   |
| `network_id`         | ID VPC-сети: созданной модулем или найденной по внешней подсети (`null`, если сеть не создавалась и группа безопасности не запрошена) |
| `security_group_ids` | ID применённых групп безопасности                                                                                                     |

## Запуск окружений

Требуется Terraform **≥ 1.9** для окружений (`envs/*` — нужны проверки переменных, ссылающиеся на
другие переменные) и **≥ 1.7** для самого модуля (`modules/vm/versions.tf`: `mock_provider` доступен
с 1.7). В CI версия зафиксирована — 1.17.1.

Авторизация: `export YC_TOKEN=$(yc iam create-token)` (токен не хранится в коде).
Идентификаторы облака и каталога тоже не хранятся в репозитории — они приходят из
переменных окружения или из переменных GitHub Environment:

```bash
export TF_VAR_cloud_id="<cloud-id>"   # обязательное
export TF_VAR_folder_id="<folder-id>" # обязательное
export YC_TOKEN="$(yc iam create-token)"

cd envs/dev     # или envs/stage, envs/prod
terraform init
terraform plan  -var-file=dev.tfvars     # для stage: stage.tfvars, для prod: prod.tfvars
terraform apply -var-file=dev.tfvars
```

В PowerShell — то же через `$env:TF_VAR_cloud_id="..."`, `$env:YC_TOKEN="..."`.

| Окружение | Ядра      | RAM   | Подключаемый диск | Публичный IP | Прерываемая | SSH откуда              |
| --------- | --------- | ----- | ----------------- | ------------ | ----------- | ----------------------- |
| dev       | 2 (20%)   | 4 ГБ  | 50 ГБ HDD         | да           | да          | любой адрес (песочница) |
| stage     | 4 (50%)   | 8 ГБ  | 200 ГБ SSD        | нет          | нет         | 10.0.0.0/8              |
| prod      | 16 (100%) | 64 ГБ | 1000 ГБ SSD       | нет          | нет         | 10.0.0.0/8              |

Перед первым `apply` замените заглушки в `<env>.tfvars`: `image_id` (идентификатор образа
среды) и `ssh_public_key` — подробности в разделе «Образы, KMS и подготовка среды». Провайдер проверяет
IAM-токен уже на этапе конфигурации, поэтому без валидного `YC_TOKEN` план не собирается: ошибка
`failed to get IAM token … OAuth token is invalid or expired`.

В `prod` окружение защищено от случайного удаления: в `envs/prod/main.tf` есть служебный ресурс
`terraform_data.destroy_guard` с `lifecycle { prevent_destroy = true }`. При попытке
`terraform destroy` план падает целиком — не удаляется ни один ресурс prod. (Блок `lifecycle`
нельзя разместить в блоке `module`: Terraform не поддерживает lifecycle в module-блоках, поэтому
защита реализована отдельным ресурсом.) Снять защиту — только осознанным удалением этого блока
из файла, с обязательным ревью. Оговорка: защита срабатывает только на полном `terraform destroy`;
точечное удаление (`terraform destroy -target=module.vm`) или удаление ресурсов в консоли
Yandex Cloud её обходит — это защита от случайной команды, а не от администратора с правами.

Отдельно в `envs/prod/main.tf` есть `check "kms_encryption_enabled"`: он требует непустой
`kms_key_id` и печатает предупреждение, если шифрование prod не задано. В обычном `plan`/`apply`
это предупреждение, а не ошибка; в `terraform test` неудачная проверка валит тест, поэтому
офлайн-тест prod задаёт фиктивный ключ в run-блоке (см. раздел «Образы, KMS и подготовка среды»).

У каждого окружения собственное локальное состояние, поэтому развёртывание выполняется вручную
по командам выше. CI (`.github/workflows/terraform.yml`) проверяет конфигурацию без доступа
в облако: форматирование, валидация, `tflint`, `trivy` и офлайн-тесты с `mock_provider`.

## Образы, KMS и подготовка среды

### Загрузочный образ

`image_id` в `<env>.tfvars` — **заглушка**: идентификатор `fd8b2b3d-9b7a-4d3f-9c8e-000000000001` не
соответствует реальному образу, и `terraform apply` с ним завершится ошибкой поиска образа. Это
осознанный fail-fast: apply не должен молча создавать ВМ на неверном образе.

Получить рабочий ID образа:

```bash
yc compute image list --family-family standard-images \
  --filter "name~ubuntu-2204-lts" --format json
```

Подставить полученный ID в `<env>.tfvars` или, не меняя репозиторий, передать переменной окружения
(Terraform подхватывает `TF_VAR_<имя>` автоматически, и переменная окружения имеет приоритет над
значением в `.tfvars`):

```bash
export TF_VAR_image_id="fd8b2b3d-9b7a-4d3f-9c8e-000000000002"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

### KMS для prod

В `prod` диски должны шифроваться KMS-ключом. В `prod.tfvars` оставлена пустая заглушка
`kms_key_id = ""`; пока ключ не задан, `terraform plan` в `envs/prod` печатает **предупреждение**
(check `kms_encryption_enabled` в `envs/prod/main.tf`) — apply при этом не блокируется, но предупреждение
видно на каждом плане и не даёт «забыть» про шифрование.

Офлайн-тест окружения (`envs/prod/tests/prod.tftest.hcl`) задаёт фиктивный ключ в run-блоке: в тесте
провайдер замокан, реальный ключ не нужен, а проверка `check` не должна валить тест.

Задать реальный ключ:

```bash
yc kms symmetric-key get --name future2-prod-disk-key --format json
export TF_VAR_kms_key_id="<key-id>"
```

В `dev` и `stage` KMS не включается: диски шифруются ключом провайдера по умолчанию.

## Работа в существующей сети

По умолчанию модуль создаёт VPC-сеть и подсеть сам (`create_network = true`). Если среда уже существует
и ВМ нужно подключить к чужой подсети, используется параметр `subnet_id` из интерфейса модуля:

```hcl
module "vm" {
  source = "../../modules/vm"

  name              = var.vm_name
  environment       = var.env
  zone              = var.zone
  cores             = var.cores
  memory_gb         = var.memory_gb
  image_id          = var.image_id
  data_disk_size_gb = var.data_disk_size_gb
  ssh_public_key    = var.ssh_public_key

  create_network        = false
  subnet_id             = var.subnet_id   # ID существующей подсети
  create_security_group = true            # группа безопасности создаётся в сети этой подсети
  ssh_ingress_cidr      = var.ssh_ingress_cidr
}
```

Ограничения модуля: `subnet_id` обязателен при `create_network = false` и запрещён при
`create_network = true`; сеть при `create_network = false` не создаётся, а её ID берётся из существующей
подсети (если нужна группа безопасности). Оба режима покрыты офлайн-тестами в
`modules/vm/tests/vm.tftest.hcl`: `vm_with_external_subnet`, `subnet_id_required`,
`subnet_id_conflicts_with_create_network`.
