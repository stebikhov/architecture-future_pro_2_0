# Task2Advanced — Terraform интеграция с CI/CD и удалённым хранением состояния

Код создаёт сеть, подсеть и приватный бакет домена для окружений `dev`, `stage`, `prod`.
Состояние хранится в S3-совместимом хранилище (Yandex Object Storage или MinIO), локально — никогда.
Блокировка состояния — S3-native (`use_lockfile`), дополнительных сервисов не требует.

## Соответствие требованиям задания 2

| Требование задания                                 | Где реализовано                                                                                                          |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Terraform-код в каталоге `Task2Advanced`           | `main.tf`, `variables.tf`, `versions.tf`, `outputs.tf`, `envs/*.tfvars`, `tests/plan.tftest.hcl`                         |
| Backend с использованием S3-совместимого хранилища | `versions.tf` — `backend "s3"`; параметры подставляются при `init` через `scripts/gen-backend-config.sh`                 |
| `terraform init`                                   | Шаг `terraform init` в job'ах `plan` и `apply` обоих workflow                                                            |
| `terraform plan`                                   | Job `plan`: план считается, сохраняется артефактом и публикуется сводкой в PR                                            |
| `terraform apply` по кнопке / с флагом approval    | Job `apply` — только `workflow_dispatch`; approval даёт GitHub Environment (Required reviewers)                          |
| Состояние не хранится локально                     | Backend `s3` во всех окружениях; локальный backend остался только в проверочных job'ах (`init -backend=false`) и в Task1 |
| README описывает все скрипты                       | Разделы «Файлы», «Backend», «Pipeline», «Что настроить перед запуском», «Локальный запуск», «Как удалить ресурсы»        |

CI лежит в `.github/workflows/`, а не в `Task2Advanced/`: GitHub Actions читает workflows
только из корня репозитория. Terraform-код при этом полностью в `Task2Advanced/`.

## Файлы

| Файл                                         | Назначение                                                                                                                                                    |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `versions.tf`                                | Версии Terraform/провайдера и `backend "s3"` без секретов и адресов: S3-native блокировка (`use_lockfile`), path-style и skip\_\* для S3-совместимых хранилищ |
| `variables.tf`                               | Входные переменные (`env` валидируется: dev/stage/prod)                                                                                                       |
| `main.tf`                                    | Провайдер, сеть, подсеть, бакет с версионированием                                                                                                            |
| `outputs.tf`                                 | ID сети/подсети, имя бакета                                                                                                                                   |
| `envs/*.tfvars`                              | Параметры окружений                                                                                                                                           |
| `.terraform.lock.hcl`                        | Фиксация версии провайдера `yandex-cloud/yandex` 0.243.0                                                                                                      |
| `.tflint.hcl`                                | Правила TFLint для Task2 (рекомендованный пресет + документирование и структура модуля)                                                                       |
| `scripts/gen-backend-config.sh`              | Генерация `backend.hcl` из переменных окружения (вызывается из конвейера CI)                                                                                  |
| `tests/plan.tftest.hcl`                      | Офлайн-план с `mock_provider`: проверяет CIDR, приватность и версионирование бакета, имя сети                                                                 |
| `../.github/workflows/terraform.yml`         | Pipeline (лежит в корне репозитория — GitHub читает workflows только оттуда)                                                                                  |
| `../.github/workflows/terraform-destroy.yml` | Ручное удаление окружения с подтверждением                                                                                                                    |
| `../.tflint.hcl`                             | Правила TFLint для окружений Task1 (общий конфиг репозитория)                                                                                                 |

## Backend

Параметры не зашиты в код и передаются при `init` через файл `backend.hcl`, который генерирует
`scripts/gen-backend-config.sh` из переменных окружения (в репозиторий не попадает):

```hcl
bucket = "<bucket>"
key    = "<env>/terraform.tfstate"
endpoints = {
  s3 = "<s3 endpoint>"
}
```

Значения `region = "ru-central1"`, `use_lockfile = true`, `use_path_style = true` и `skip_*` заданы
в `versions.tf` и в `backend.hcl` не повторяются: файл нужен только для `bucket`, `key` и `endpoint`.

Скрипт требует `TF_STATE_BUCKET` и `TF_STATE_ENDPOINT` и проверяет их формат: имя бакета — без
пути, endpoint — URL со схемой `http(s)://`.

Почему отдельный скрипт, а не генерация файла прямо в workflow: в YAML блок `run: |` сдвигает все строки
вправо, включая закрывающий `EOF`. Heredoc `<<EOF` ищет разделитель строго в начале строки и не закрывается;
`<<-EOF` снимает только табы, а отступ в YAML — пробелы, поэтому он тоже не помогает. В `.sh`-файле
логика пишется без YAML-отступов и легко проверяется локально.

```bash
# вручную, если backend.hcl нужен локально
export TF_STATE_BUCKET=... TF_STATE_ENDPOINT=...
bash scripts/gen-backend-config.sh dev
terraform init -backend-config=backend.hcl
```

Используется синтаксис `endpoints.*`: параметры `endpoint` и `dynamodb_endpoint` объявлены устаревшими
и выдают предупреждения при `init`. Для Yandex Object Storage и MinIO нужны `skip_*`-параметры и
`use_path_style` из `versions.tf`; `endpoints.*` требуют Terraform ≥ 1.6.3 (по документации Yandex Cloud).
Офлайн-тесты используют `mock_provider`, поэтому для конфигурации в целом достаточно 1.7.0, но
`use_lockfile` требует 1.10 — в `versions.tf` задано `required_version = ">= 1.10.0, < 2.0.0"`.

**Шифрование состояния.** В backend нет `encrypt = true`: без `kms_key_id` Terraform отправляет алгоритм
`AES256`, а Yandex Object Storage принимает только `aws:kms`. При этом S3-backend валидирует `kms_key_id`
как AWS KMS ID/ARN, поэтому KMS-ключ Yandex туда не передать. Включайте шифрование на бакете состояния
(KMS-ключ Object Storage) — это поддерживаемый способ.

**Блокировка.** Блокировка включена в самом backend (`use_lockfile = true`, Terraform ≥ 1.10): во время
операции рядом с состоянием создаётся объект `<env>/terraform.tfstate.tflock`, и он удаляется по
завершении. Ни DynamoDB, ни YDB, ни отдельная таблица блокировок больше не нужны — конвейер не может
оказаться в состоянии «состояние без блокировки», а bootstrap сводится к одному бакету.

Требования к хранилищу и правам:

- хранилище должно поддерживать условные запросы (`If-None-Match` на `PutObject`) — именно на этом
  держится атомарность захвата lock-файла; это выполняют Yandex Object Storage и MinIO;
- ключу доступа к состоянию нужны права на чтение и запись объекта состояния **и** удаление объекта
  `.tflock` (в Object Storage это `storage.editor` на конкретный бакет; для S3 — `s3:GetObject`,
  `s3:PutObject` и `s3:DeleteObject` на `<key>.tflock`);
- полезно включить версионирование бакета состояния: оно даёт восстановление после случайного удаления.

**Bootstrap.** Бакет состояния создаётся один раз вручную (консоль Yandex Cloud, `yc storage bucket
create`, `mc mb` для MinIO или `aws s3api create-bucket`). Обязательные свойства: версионирование
включено, анонимный доступ закрыт, для prod — шифрование KMS-ключом Object Storage.

Сервисному аккаунту, чьи статические ключи используются, нужны права на бакет состояния
(`storage.editor`) и на каталог с ресурсами окружения. Для prod лучше использовать отдельные бакет
и ключ, чтобы доступ к dev не давал доступ к prod-состоянию.

Ключи доступа — `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` для S3-backend и
`YC_STORAGE_ACCESS_KEY` / `YC_STORAGE_SECRET_KEY` для провайдера Yandex Cloud; в CI обе пары
задаются из одних секретов `S3_ACCESS_KEY` / `S3_SECRET_KEY`. Отдельный ключ состояния на окружение
(`dev/terraform.tfstate` и т. д.) изолирует состояния; блокировка через lock-файл не допускает
параллельных apply. Бакет состояния создаётся заранее вручную (bootstrap, см. выше).

## Pipeline (GitHub Actions)

1. `setup` — вычисляет matrix для `plan`: на PR/push — все три окружения, на ручном запуске — только
   выбранное. Без этого apply одного окружения тянул бы за собой план остальных (и их approval).
2. `validate` — `terraform fmt -check`, `init -backend=false -lockfile=readonly`, `validate`,
   офлайн-`terraform test` с `mock_provider`, `tflint` и `trivy` (конфигурация IaC). Job выполняется
   без секретов и без доступа к backend.
3. `validate-task1` и `test-module` — то же самое для Task1: форматирование, валидация и офлайн-тесты
   окружений `dev`/`stage`/`prod` и переиспользуемого модуля `vm`. Секреты не нужны.
4. `plan` — `init` с backend → `plan -var-file=envs/<env>.tfvars -out`.
   - pull request: план для `dev`, `stage` и `prod` считается без обращения к облаку
     (`-refresh=false`) и без блокировки (`-lock=false`) — учётные данные окружения `plan-<env>`
     дают только чтение состояния; из форков план пропускается (нет доступа к секретам);
   - push в `main`: тот же информационный план в окружении `plan-<env>` — без refresh и блокировки;
   - ручной запуск: авторитетный план для apply — в окружении `<env>`, с refresh и блокировкой
     состояния, с правом записи; дальше apply только для выбранного окружения.
   - в PR публикуется сводка (`actions/github-script`, маркер `<!-- terraform-plan:<env> -->` —
     отдельный комментарий на окружение, иначе matrix-job'ы перезаписывали бы один и тот же
     комментарий): адреса ресурсов и действия (`create`/`update`/`delete`/`replace`) плюс их
     количество. Значения ресурсов не публикуются. Полный план остаётся в логе job'а.
5. `apply` — только вручную (`workflow_dispatch`, выбор окружения: `dev`, `stage` или `prod`).
   Применяется именно сохранённый план (`apply tfplan`), что исключает дрейф между просмотром и
   применением. В начале job повторно выполняется `terraform fmt -check -recursive`: если план
   собран из неотформатированной ветки, apply не начнётся. Apply зависит от job `plan` (`needs: plan`)
   и берёт артефакт плана из того же запуска: применить можно только план, построенный в этом
   запуске, поэтому «старый» план применить нельзя.
6. `terraform-destroy` (отдельный workflow) — удаление окружения вручную, см. раздел ниже.
7. **Триггеры:** workflow срабатывает на путях `Task1Advanced/**`, `Task2Advanced/**` и
   `.github/workflows/**`.

Разделение окружений (почему это важно). Правила защиты GitHub Environment привязаны к job'у, а не к
шагу. Если бы `plan` и `apply` работали в одном Environment, то:

- PR-план для `stage`/`prod` ждал бы ручного approval, хотя ничего не применяет, и запуски в `main`
  оставались бы в состоянии «ожидает согласования»;
- код из PR-ветки получал бы prod-учётные данные с правом записи.

Поэтому в репозитории шесть окружений: три «плановых» и три «применяющих».

| GitHub Environment                    | Кто использует                                                           | Secrets                                                                                                               | Variables                                                             | Права                                                                              |
| ------------------------------------- | ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `plan-dev`, `plan-stage`, `plan-prod` | job `plan` на pull request и push                                        | `S3_ACCESS_KEY` / `S3_SECRET_KEY` — ключ **только на чтение** бакета состояния; `YC_TOKEN` — IAM-токен с ролью Viewer | `YC_CLOUD_ID`, `YC_FOLDER_ID`, `TF_STATE_BUCKET`, `TF_STATE_ENDPOINT` | чтение состояния, без блокировки и без записи                                      |
| `dev`, `stage`, `prod`                | job `plan` при ручном запуске, job `apply`, workflow `terraform-destroy` | `S3_ACCESS_KEY` / `S3_SECRET_KEY` — ключ с правом записи; `YC_TOKEN` — токен с правами на ресурсы                     | те же                                                                 | полный доступ к своему окружению; для `stage` и `prod` включите Required reviewers |

Имена секретов в обоих типах окружений совпадают: GitHub подставляет значение из того окружения,
которое назначено job'у. Поэтому достаточно создать `plan-<env>` и положить в него те же имена
секретов с другими (read-only) значениями.

Для ручного развёртывания в `stage`/`prod` требуется два согласования: на job `plan` (окружение
`<env>`, авторитетный план с refresh и блокировкой) и на job `apply` (то же окружение). Это осознанно:
второе согласование даёт ревьюеру возможность посмотреть именно тот план, который будет применён.

Безопасность и изоляция:

- секреты (`S3_ACCESS_KEY`, `S3_SECRET_KEY`, `YC_TOKEN`) хранятся в GitHub Environments — у каждого окружения свои;
- секреты выдаются **на уровне шагов**, а не job'а: сторонние actions (`checkout`, `setup-terraform`,
  `upload-artifact`, `github-script`) не видят ключи;
- нестабильные параметры (`YC_CLOUD_ID`, `TF_STATE_BUCKET` и др.) — в переменных окружения;
- `permissions` минимальны (`contents: read`); право `pull-requests: write` выдано только job'у `plan` и нужно исключительно для комментария со сводкой;
- ключи Object Storage для провайдера (`YC_STORAGE_ACCESS_KEY`/`YC_STORAGE_SECRET_KEY`) берутся из тех же секретов;
- `concurrency` по окружению не допускает параллельных запусков (plan, apply и destroy используют одну группу `tf-<env>`);
- `.gitignore` исключает `*.tfstate`, `.terraform/`, `backend.hcl`, `plan.txt`, `plan.json` и планы;
- `terraform init` во всех шагах выполняется с `-lockfile=readonly`: конвейер применяет ровно ту версию
  провайдера, что зафиксирована в `.terraform.lock.hcl`, и не переписывает lock-файл;
- бинарный план (`tfplan-*`) содержит значения переменных, поэтому выгружается артефактом только для
  ручного запуска (из которого следует apply) и хранится 1 день; в PR наружу уходит только сводка;
- статический анализ: `tflint` (стиль и ошибки провайдера) и `trivy` (конфигурация IaC, находки
  HIGH/CRITICAL блокируют конвейер) выполняются в job'ах `validate` без секретов. `trivy` заменил
  `tfsec`: `tfsec` переведён в режим поддержки, а набор его правил не содержит Yandex Cloud, то есть
  для кода задания срабатывали только общие terraform-правила. Компенсирующий контроль — assertions в
  `tests/plan.tftest.hcl` (приватность бакета, версионирование, имя сети).

Ограничения и замечания:

- версии actions закреплены по тегам (`@v4`, `@v3`); для строгой цепочки поставки их стоит закрепить
  по commit SHA;
- блок `env` повторяется в jobs `plan`, `apply` и `destroy`; при росте числа окружений его можно вынести
  в переиспользуемый workflow (reusable workflow);
- **`plan` на PR выполняется в окружении `plan-<env>` с read-only учётными данными.** Провайдер
  Yandex Cloud проверяет IAM-токен уже на этапе конфигурации, поэтому `YC_TOKEN` в `plan-<env>` должен
  быть валидным (роль Viewer). Права на запись у него нет;
- `YC_TOKEN` — короткоживущий IAM-токен. Для длинных approval-пауз надёжнее сервисный аккаунт через
  `YC_SERVICE_ACCOUNT_KEY_FILE` или OIDC-федерация удостоверений рабочих нагрузок, а не ручной `yc iam create-token`;
- ограничьте **Deployment branches** в настройках каждого GitHub Environment (например, только `main`),
  иначе `workflow_dispatch` с произвольной ветки сможет получить секреты окружения и применить код из неё;
- стартовое наполнение (бакет состояния) сейчас выполняется вручную; его можно оформить
  отдельным Terraform-каталогом `bootstrap/` с локальным состоянием и `prevent_destroy`, чтобы инфраструктура
  состояния тоже была воспроизводимой;
- ресурс `yandex_storage_bucket` требует статических ключей Object Storage — они приходят из секретов CI
  (`YC_STORAGE_ACCESS_KEY` / `YC_STORAGE_SECRET_KEY`), не из кода;
- имя бакета данных глобально уникально; при коллизии добавьте префикс организации;
- для данных домена в prod стоит включить KMS-шифрование бакета и lifecycle-правила для неактуальных
  версий; в шаблоне это не включено, чтобы не требовать KMS-ключ в каждом окружении.

## Что настроить перед запуском

Secrets (для каждого Environment: `dev`, `stage`, `prod`):
`S3_ACCESS_KEY`, `S3_SECRET_KEY`, `YC_TOKEN`.
Variables: `YC_CLOUD_ID`, `YC_FOLDER_ID`, `TF_STATE_BUCKET`, `TF_STATE_ENDPOINT`.

Отдельно создайте Environments `plan-dev`, `plan-stage`, `plan-prod` с теми же именами секретов:
`S3_ACCESS_KEY`/`S3_SECRET_KEY` — ключ только на чтение бакета состояния, `YC_TOKEN` — IAM-токен с
ролью Viewer; variables те же. Без них план на pull request не сможет прочитать состояние.

Для `stage` и `prod` включите **Required reviewers** в настройках Environment — это и есть этап
approval перед `apply` и `destroy`.

### Локальный запуск

В `envs/*.tfvars` нет `cloud_id` и `folder_id` — они приходят из CI. Локально их нужно задать
переменными окружения (Terraform сам превращает `TF_VAR_<name>` в переменную `<name>`):

```bash
export YC_TOKEN="$(yc iam create-token)"
export TF_VAR_cloud_id="<cloud-id>"
export TF_VAR_folder_id="<folder-id>"
# Для управления бакетом провайдеру нужны статические ключи Object Storage:
export YC_STORAGE_ACCESS_KEY="<static-key-id>"
export YC_STORAGE_SECRET_KEY="<static-secret>"
export TF_STATE_BUCKET="<bucket>" TF_STATE_ENDPOINT="<s3-endpoint>"

bash scripts/gen-backend-config.sh dev
terraform init -backend-config=backend.hcl
terraform plan -var-file=envs/dev.tfvars
```

PowerShell:

```powershell
$env:YC_TOKEN = (yc iam create-token)
$env:TF_VAR_cloud_id = "<cloud-id>"
$env:TF_VAR_folder_id = "<folder-id>"
$env:YC_STORAGE_ACCESS_KEY = "<static-key-id>"
$env:YC_STORAGE_SECRET_KEY = "<static-secret>"
$env:TF_STATE_BUCKET = "<bucket>"; $env:TF_STATE_ENDPOINT = "<s3-endpoint>"
bash scripts/gen-backend-config.sh dev
terraform init -backend-config=backend.hcl
terraform plan -var-file=envs/dev.tfvars
```

Если `cloud_id`/`folder_id` не задать, `plan` остановится с ошибкой «No value for required variable».
В `envs/*.tfvars` оставлены закомментированные строки-подсказки.

### Как удалить ресурсы

Удаление — ручная операция с двойным подтверждением:

1. Actions → **terraform-destroy** → Run workflow.
2. Выбрать `environment` и ввести `confirm` = `destroy-<environment>` (например, `destroy-dev`).
   Без точного совпадения job `check` завершится ошибкой с подсказкой, и destroy не запустится.
3. Пройти approval в GitHub Environment, если для выбранного окружения включены Required reviewers.
4. Workflow сначала выполняет `terraform plan -destroy -out=destroy.tfplan` (видно, что будет удалено),
   затем применяет именно этот сохранённый план: `terraform apply -auto-approve destroy.tfplan`.
5. Группа `concurrency` та же, что у plan/apply (`tf-<env>`), поэтому destroy не пересечётся с apply.

Локально: `terraform destroy -var-file=envs/dev.tfvars` в каталоге `Task2Advanced` (с тем же `init`,
что и для plan). Бакет состояния не удаляется — это стартовый ресурс, общий для окружений; чистить его
вручную нужно только при полном выводе проекта. Если в бакете данных (`future2-<env>-domain-data`)
есть объекты, `terraform destroy` не сможет его удалить: очистите бакет или осознанно включите
`force_destroy` в ресурсе `yandex_storage_bucket`.

Проверки выполняются в CI на зафиксированной версии Terraform 1.17.1: `fmt -check`,
`init -backend=false -lockfile=readonly`, `validate`, офлайн-тест `terraform test`
(mock_provider, без облака), `tflint` и `trivy`. Реальный `apply` в репозитории не выполнялся —
для него нужны доступ к Yandex Cloud и секреты, которых в коде нет. Переход на `use_lockfile`
требует разовой проверки на целевом хранилище: lock-файл должен появиться в бакете состояния
(`<env>/terraform.tfstate.tflock`) во время операции и исчезнуть после неё.

## Связь с целевой архитектурой

Этот root-модуль — шаблон «среды домена»: сеть, подсеть и приватное объектное хранилище с версионированием.
В целевой архитектуре таких сред будет много — по одной на домен и регион
(`patient-flow`, `fintech`, `billing`, …), и каждая получит собственное состояние и свои права доступа.
Доменные сервисы разворачиваются в Kubernetes поверх этих сетей, данные попадают в то же объектное
хранилище (lakehouse, Iceberg). То есть Task1 даёт переиспользуемый модуль ресурса (ВМ), Task2Advanced — паттерн
среды и CI/CD, а целевая архитектура определяет, сколько таких сред нужно и что в них живёт. Модули для
кластера, Kafka и бакетов с политиками жизненного цикла строятся по той же схеме.

Имена ресурсов сейчас включают только `env`. Если несколько доменов живут в одном каталоге, задайте
им отдельные `folder_id`/state или добавьте префикс домена в имена сети и бакета — иначе имена пересекутся.

Task1 (переиспользуемый модуль `vm`) в CI проверяется только статически и офлайн-тестами: у его
окружений состояние локальное, поэтому `apply` для них выполняется вручную, вне конвейера, — иначе
ресурсы были бы созданы без сохранённого состояния и потеряли бы управление. Единый механизм
удалённого состояния для Task1 — отдельная задача (см. корневой README).
