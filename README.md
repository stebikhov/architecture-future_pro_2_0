# architecture-future_pro_2_0

Разработка архитектуры для компании «Будущее 2.0» (11-й спринт): трансформация IT-ландшафта в облачную событийную платформу портала самообслуживания (data mesh).

Компания — экосистема (клиники, ИИ-сервисы, банк), исходная инфраструктура: DWH на SQL Server 2008, ESB на Apache Camel, интерфейс операторов на PowerBuilder. Целевые результаты: доменная модель владения данными, событийная интеграция, near-real-time аналитика, функционал самообслуживания для формирования отчётов.

## Что в репозитории

| Задание                                    | Директория                                 | Артефакты                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------------------------ | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1. Переиспользуемый модуль Terraform       | [`Task1Advanced`](Task1Advanced/README.md) | `modules/vm/` (`main.tf`, `variables.tf`, `outputs.tf`), окружения `envs/{dev,stage,prod}/` с `<env>.tfvars`, [README](Task1Advanced/README.md)                                                                                                                                                                                                                                                                                                    |
| 2. Terraform + удалённое состояние + CI/CD | [`Task2Advanced`](Task2Advanced/README.md) | root-модуль (сеть, подсеть, бакет), `envs/*.tfvars`, backend `s3` + `scripts/gen-backend-config.sh`, pipeline [`.github/workflows`](.github/workflows), [README](Task2Advanced/README.md)                                                                                                                                                                                                                                                          |
| 3. Целевая архитектура и риски             | `Task3Advanced`                            | [c4-context.md](Task3Advanced/c4-context.md), [c4-container.md](Task3Advanced/c4-container.md), [c4-component.md](Task3Advanced/c4-component.md), [risk-map.md](Task3Advanced/risk-map.md), [risk-management-plan.md](Task3Advanced/risk-management-plan.md); диаграммы — [c4-context.drawio](Task3Advanced/c4-context.drawio), [c4-container.drawio](Task3Advanced/c4-container.drawio), [c4-component.drawio](Task3Advanced/c4-component.drawio) |
| 4. Домены и интеграции                     | `Task4Advanced`                            | [bounded-contexts.md](Task4Advanced/bounded-contexts.md), [context-map.md](Task4Advanced/context-map.md), [event-storming.md](Task4Advanced/event-storming.md), [aggregates.md](Task4Advanced/aggregates.md), [events.md](Task4Advanced/events.md), [justification.md](Task4Advanced/justification.md), [dwh-to-billing-rules.md](Task4Advanced/dwh-to-billing-rules.md)                                                                           |
| 5. Технологический стек                    | `Task5Advanced`                            | [tech-radar.md](Task5Advanced/tech-radar.md), [tco-analysis.md](Task5Advanced/tco-analysis.md), [roadmap.md](Task5Advanced/roadmap.md)                                                                                                                                                                                                                                                                                                             |

## Быстрый старт (Terraform)

```bash
# Нужен Terraform >= 1.9 и переменные TF_VAR_cloud_id / TF_VAR_folder_id / YC_TOKEN
cd Task1Advanced
terraform fmt -check -recursive
terraform -chdir=envs/dev init -backend=false && terraform -chdir=envs/dev validate
terraform -chdir=modules/vm init -backend=false && terraform -chdir=modules/vm test
```

```bash
cd Task2Advanced
export YC_TOKEN="$(yc iam create-token)"
export YC_STORAGE_ACCESS_KEY="<static-key-id>" YC_STORAGE_SECRET_KEY="<static-secret>"
export TF_VAR_cloud_id="<cloud-id>" TF_VAR_folder_id="<folder-id>"
export TF_STATE_BUCKET="<bucket>"
export TF_STATE_ENDPOINT="<s3-endpoint>"
bash scripts/gen-backend-config.sh dev
terraform init -backend-config=backend.hcl
terraform plan -var-file=envs/dev.tfvars
```

## CI/CD

Pipeline лежит в [`.github/workflows`](.github/workflows): GitHub Actions читает workflows только из
корня репозитория, поэтому в `Task2Advanced/` лежит только Terraform-код.

| Файл                                                               | Назначение                                                                                                                                                                                 |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`terraform.yml`](.github/workflows/terraform.yml)                 | `validate` — fmt, validate, офлайн-тесты, tflint, trivy (без секретов);`plan` — план по каждому окружению со сводкой в PR; `apply` — только ручной запуск (`workflow_dispatch`) с approval |
| [`terraform-destroy.yml`](.github/workflows/terraform-destroy.yml) | Ручное удаление окружения с двойным подтверждением (`destroy-<env>`)                                                                                                                       |

Нужно настроить шесть GitHub Environment — `plan-dev`, `plan-stage`, `plan-prod` (только чтение
состояния) и `dev`, `stage`, `prod` (полный доступ; для `stage` и `prod` — Required reviewers):

- Secrets: `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `YC_TOKEN`;
- Variables: `YC_CLOUD_ID`, `YC_FOLDER_ID`, `TF_STATE_BUCKET`, `TF_STATE_ENDPOINT`.
