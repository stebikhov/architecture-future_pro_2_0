# Каталог доменных событий

Именование: `<контекст>.<агрегат или сущность>.<факт в прошедшем времени>`. Если у агрегата несколько
разных фактов, используется `<контекст>.<агрегат>.<объект>.<факт в прошедшем времени>`
(`finance.period.close.started`, `billing.ai_usage.recorded`, `finance.report.submitted`). Правило
применяется ко всем составным фактам без исключений.

Допустимые отклонения от правила «факт в прошедшем времени» (список полный):
`identity.consent.changed` — событие фиксирует изменение состояния согласия, а новое значение задаёт
поле `granted` в payload.

Мажорная версия контракта — в суффиксе топика
(`.v1`), версия схемы — в `event_version`. Общий конверт события обязателен для всех.

## Общий конверт

```json
{
  "event_id": "uuidv7",
  "event_type": "billing.invoice.issued",
  "event_version": 1,
  "occurred_at": "2026-10-30T12:00:00Z",
  "producer": "billing",
  "correlation_id": "uuid",
  "causation_id": "uuid",
  "partition_key": "invoice_id",
  "payload": {}
}
```

Правила: доставка at-least-once, потребители идемпотентны по `event_id`; порядок гарантируется внутри партиции
(ключ — идентификатор агрегата); изменения схемы — только обратно совместимые (добавление необязательных полей).

Маршрутизация оплаты и корреляции:

- `billing.invoice.issued` идентифицирует счёт клиники через `invoice_id` и приём — через `appointment_id`;
  счёт клиента в нём не указывается, потому что связь «пациент ↔ клиент банка» живёт только в Identity
  и передаётся через `identity.consent.changed`.
- `payments.payment.received` несёт `account_id` (счёт, с которого списаны деньги) и `reference` — идентификатор
  счёта клиники, если платёж закрывает именно его; закрытие счёта оформляет Billing событием
  `billing.invoice.paid`.
- Отчётный период коррелируется между доменами по `period` (ГГГГ-ММ): `billing.settlement.closed` приходит
  с периодом, `finance.facts.collected` и `finance.report.generated` — с тем же значением.

## Типы данных

Единый словарь типов для payload событий и ключей агрегатов — он же используется в `aggregates.md`:

| Тип              | Применение                                              | Пример                          |
| ---------------- | ------------------------------------------------------- | ------------------------------- |
| `uuid`           | Идентификаторы сущностей и агрегатов (UUIDv7)           | `invoice_id: uuid`              |
| `text`           | Строка без фиксированной длины: коды, названия, причины | `reason: text`                  |
| `char(3)`        | Код валюты по ISO 4217                                  | `currency: char(3)`             |
| `decimal(18,2)`  | Денежные суммы и их части                               | `amount: decimal(18,2)`         |
| `decimal(7,4)`   | Процентные ставки                                       | `rate: decimal(7,4)`            |
| `decimal(5,2)`   | Скоринг-балл и полнота данных                           | `score: decimal(5,2)`           |
| `int`            | Количества, счётчики, номера версий                     | `quantity: int`                 |
| `boolean`        | Флаги                                                   | `granted: boolean`              |
| `date`           | Дата без времени                                        | `due_date: date`                |
| `timestamptz`    | Момент времени в UTC                                    | `completed_at: timestamptz`     |
| `text[]`         | Списки строк                                            | `report_types: text[]`          |
| `uuid[]`         | Списки идентификаторов                                  | `line_items: uuid[]`           |
| `text` (ГГГГ-ММ) | Отчётный период                                         | `period: text` (`ГГГГ-ММ`)      |
| `enum(<домен>)`  | Ограниченный словарь значений                           | `status: enum(analysis_status)` |

Домены `enum`: `study_type` (код исследования), `analysis_status` (`queued` / `running` / `completed` / `failed` /
`rejected`), `scoring_decision` (`approved` / `declined` / `manual_review`), `collection_stage` (`notice` / `bureau` /
`legal` / `written_off`), `consent_scope` (`clinical` / `ai_analysis` / `marketing` / `research` / `bank_products`),
`authority` (`cbr` / `roszdravnadzor` / `rkn`).

Неизвестные значения `enum` консьюмер обязан игнорировать (tolerant reader, правило 2 в разделе о версионировании).
Обязательные поля в контракте не имеют значения по умолчанию; необязательные добавляются только с новой
`event_version` и всегда имеют осмысленное значение по умолчанию.

## Каталог

| Событие                           | Контекст-источник   | Семантика                                                    | Минимальный контракт (payload)                                                                                                                          |
| --------------------------------- | ------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `patient.patient.registered`      | Patient Flow        | Зарегистрирован новый пациент                                | `patient_id: uuid`, `registered_at: timestamptz`, `clinic_id: uuid`                                                                                     |
| `patient.patient.merged`          | Patient Flow        | Дубликаты профилей объединены                                | `surviving_patient_id: uuid`, `merged_patient_id: uuid`                                                                                                 |
| `patient.appointment.completed`   | Patient Flow        | Приём состоялся                                              | `appointment_id: uuid`, `patient_id: uuid`, `employee_id: uuid`, `clinic_id: uuid`, `service_codes: text[]`, `completed_at: timestamptz`               |
| `diagnostics.study.ordered`       | Diagnostics         | Исследование назначено                                       | `study_order_id: uuid`, `patient_id: uuid`, `study_type: enum(study_type)`                                                                              |
| `diagnostics.study.completed`     | Diagnostics         | Пройдено исследование                                        | `study_id: uuid`, `study_order_id: uuid`, `patient_id: uuid`, `study_type: enum(study_type)`, `completed_at: timestamptz`, `storage_ref: text`                                  |
| `ai.analysis.completed`           | AI Analysis         | ИИ-анализ завершён успешно                                   | `analysis_id: uuid`, `study_id: uuid`, `model_version: text`, `completed_at: timestamptz`                                    |
| `billing.invoice.issued`          | Billing             | Счёт за услугу выставлен                                     | `invoice_id: uuid`, `patient_id: uuid`, `appointment_id: uuid`, `amount: decimal(18,2)`, `currency: char(3)`, `due_date: date`                     |
| `billing.invoice.paid`            | Billing             | Счёт оплачен                                                 | `invoice_id: uuid`, `paid_at: timestamptz`, `payment_id: uuid`                                                                                          |
| `billing.invoice.corrected`       | Billing             | Счёт скорректирован компенсирующим событием                  | `invoice_id: uuid`, `delta_amount: decimal(18,2)`, `reason: text`                                                                                       |
| `billing.settlement.closed`       | Billing             | Расчётный период закрыт                                      | `settlement_id: uuid`, `period: text` (ГГГГ-ММ), `balance: decimal(18,2)`                                                                               |
| `billing.ai_usage.recorded`       | Billing             | Использование ИИ зафиксировано для тарификации и монетизации | `usage_id: uuid`, `analysis_id: uuid`, `tariff_version: text`, `amount: decimal(18,2)`, `recorded_at: timestamptz`                                      |
| `payments.account.opened`         | Accounts & Payments | Счёт клиента открыт                                          | `account_id: uuid`, `customer_id: uuid`, `currency: char(3)`, `opened_at: timestamptz`                                                                  |
| `payments.payment.received`       | Accounts & Payments | Платёж получен                                               | `payment_id: uuid`, `idempotency_key: uuid`, `account_id: uuid`, `amount: decimal(18,2)`, `currency: char(3)`, `reference: text`         |
| `lending.application.submitted`   | Lending             | Заявка на кредит создана                                     | `application_id: uuid`, `customer_id: uuid`, `requested_amount: decimal(18,2)`, `term_months: int`, `submitted_at: timestamptz`                         |
| `lending.loan.created`            | Lending             | Создан кредитный договор                                     | `loan_id: uuid`, `customer_id: uuid`, `principal: decimal(18,2)`, `rate: decimal(7,4)`, `term_months: int`, `created_at: timestamptz`                   |
| `lending.loan.approved`           | Lending             | Кредит одобрен                                               | `loan_id: uuid`, `approved_amount: decimal(18,2)`, `approved_at: timestamptz`                                                                           |
| `lending.loan.disbursed`          | Lending             | Кредит выдан, средства зачислены                             | `loan_id: uuid`, `disbursement_id: uuid`, `amount: decimal(18,2)`, `account_id: uuid`, `disbursed_at: timestamptz`                                      |
| `lending.schedule.generated`      | Lending             | График платежей сформирован                                  | `loan_id: uuid`, `schedule_id: uuid`, `version: int`, `installments_count: int`, `generated_at: timestamptz`                                            |
| `lending.repayment.received`      | Lending             | Платёж по кредиту получен                                    | `loan_id: uuid`, `repayment_id: uuid`, `idempotency_key: uuid`, `amount: decimal(18,2)`, `principal_part: decimal(18,2)`, `interest_part: decimal(18,2)`, `paid_at: timestamptz` |
| `lending.payment.overdue`         | Lending             | Платёж по кредиту просрочен                                  | `loan_id: uuid`, `due_date: date`, `overdue_amount: decimal(18,2)`, `days_overdue: int`                                                                 |
| `lending.collection.started`      | Lending             | Запущено взыскание                                           | `loan_id: uuid`, `collection_case_id: uuid`, `stage: enum(collection_stage)`, `started_at: timestamptz`                                                 |
| `lending.loan.closed`             | Lending             | Кредит полностью погашен и закрыт                            | `loan_id: uuid`, `closed_at: timestamptz`, `total_paid: decimal(18,2)`                                                                                  |
| `scoring.case.completed`          | Credit Scoring      | Скоринг завершён                                             | `scoring_id: uuid`, `application_id: uuid`, `decision: enum(scoring_decision)`, `score: decimal(5,2)`, `model_version: text`                            |
| `workforce.shift.scheduled`       | Workforce           | Смена назначена                                              | `shift_id: uuid`, `employee_id: uuid`, `clinic_id: uuid`, `role: text`, `starts_at: timestamptz`, `ends_at: timestamptz`                                |
| `inventory.stock.low`             | Inventory & Supply  | Остаток ниже порога                                          | `sku: text`, `location_id: uuid`, `quantity: int`, `threshold: int`                                                                                     |
| `inventory.purchase.requested`    | Inventory & Supply  | Создана заявка на закупку                                    | `request_id: uuid`, `idempotency_key: uuid`, `sku: text`, `period: text` (ГГГГ-ММ), `location_id: uuid`, `quantity: int`, `requested_by: uuid`, `requested_at: timestamptz` |
| `inventory.purchase.approved`     | Inventory & Supply  | Заявка на закупку согласована                                | `request_id: uuid`, `approved_by: uuid`, `approved_at: timestamptz`                                                                                     |
| `inventory.order.placed`          | Inventory & Supply  | Заказ размещён у поставщика                                  | `order_id: uuid`, `supplier_id: uuid`, `sku: text`, `quantity: int`, `expected_at: date`                                                                |
| `inventory.goods.received`        | Inventory & Supply  | Поставка принята на склад                                    | `receipt_id: uuid`, `order_id: uuid`, `sku: text`, `quantity: int`, `location_id: uuid`, `received_at: timestamptz`                                 |
| `inventory.stock.updated`         | Inventory & Supply  | Остаток обновлён после приёмки или списания                  | `sku: text`, `location_id: uuid`, `quantity: int`, `updated_at: timestamptz`                                                                            |
| `identity.consent.changed`        | Identity & Access   | Согласие изменено или отозвано                               | `subject_id: uuid`, `policy_id: uuid`, `scope: enum(consent_scope)`, `granted: boolean`, `changed_at: timestamptz`                                   |
| `finance.period.close.started`    | Corporate Finance   | Начато закрытие отчётного периода                            | `period_id: uuid`, `period: text` (ГГГГ-ММ), `started_at: timestamptz`, `deadline: date`                                                                |
| `finance.facts.collected`         | Corporate Finance   | Факты периода собраны из доменов                             | `period_id: uuid`, `sources: text[]`, `collected_at: timestamptz`, `completeness: decimal(5,2)`                                                         |
| `finance.indicators.consolidated` | Corporate Finance   | Показатели консолидированы                                   | `consolidation_id: uuid`, `period_id: uuid`, `indicator_set: text`, `consolidated_at: timestamptz`                                                |
| `finance.report.generated`        | Corporate Finance   | Пакет отчётности сформирован                                 | `report_package_id: uuid`, `period_id: uuid`, `period: text` (ГГГГ-ММ), `report_types: text[]`, `generated_at: timestamptz`                                |
| `finance.report.submitted`        | Corporate Finance   | Отчётность отправлена регулятору                             | `report_package_id: uuid`, `period_id: uuid`, `version: int`, `authority: enum(authority)`, `submitted_at: timestamptz`, `receipt_id: text`                |

## Что намеренно отсутствует

- Диагноз, результаты исследования, медицинские заключения — содержимое не входит ни в один контракт события.
  Событие хранит ссылку и идентификатор, получатель с правом доступа забирает данные в клиническом контуре.
- Персональные идентификаторы — только `patient_id`/`customer_id`; ФИО, паспорт, контакты не передаются.

## Внешние системы

Внешние системы не являются доменами и не публикуют доменных событий: они получают данные через шлюзы
и ACL-адаптеры, а не через Kafka. Полный состав внешнего окружения — на [C4-диаграмме уровня 1](../Task3Advanced/c4-context.md).

| Внешняя система                                       | Что получает от «Будущего 2.0»                                                                        | Что отдаёт                                    | Канал                                                        | Правило                                                                                                                          |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| ЦБ РФ (банковская отчётность и надзор)                | Пакеты отчётности по периоду: `finance.report.generated` → сборка пакета → `finance.report.submitted` | Квитанции и замечания по отчётности           | Регуляторный шлюз (файловое и СУИД-взаимодействие), не Kafka | Только агрегированные финансовые данные; финтех-контур не сливается в общий lakehouse (риск S2 в `../Task3Advanced/risk-map.md`) |
| Росздравнадзор / ЕГИСЗ (медицинские данные)           | Отчётность, собранная **в клиническом контуре**: ни одно доменное событие не содержит содержимого     | —                                             | ACL-адаптер клинического контура                             | Источник — только клинический домен, не lakehouse и не портал (правило 4 в `bounded-contexts.md`)                                |
| Роскомнадзор (локализация ПДн)                        | Реестр обработки ПДн и изменения согласий: `identity.consent.changed`                                 | Требования по локализации                     | Регуляторный шлюз                                            | Наружу — только метаданные обработки, без данных субъектов                                                                       |
| Платёжная инфраструктура (НСПК, банки-корреспонденты) | `payments.payment.received` — факт платежа (`idempotency_key`, сумма, валюта)                         | Подтверждения и статусы платежей              | Двунаправленный шлюз mTLS, не Kafka                          | Идемпотентность по `idempotency_key`; в контур финтеха входят только идентификаторы и суммы                                      |
| Фарма-партнёры                                        | `inventory.order.placed` — заказ поставщику (`sku`, количество, срок)                                 | `inventory.goods.received` — приёмка поставки | Партнёрский шлюз, mTLS                                       | Open Host Service: контракт принадлежит Inventory & Supply; медданных нет                                                        |
| Производитель мед. электроники                        | — (телеметрия идёт через Device Telemetry Gateway → Kafka, минуя доменные события)                    | Телеметрия и статусы оборудования             | MQTT-шлюз (Device Telemetry Gateway)                         | В аналитику попадают только технические метрики; данных пациентов в телеметрии нет                                               |

Общие правила работы с внешними системами:

1. Внешняя система не знает о доменных событиях и не подписывается на топики: обмен идёт через шлюз с
   собственным контрактом и регламентом — это Anti-Corruption Layer на границе.
2. Наружу уходят только идентификаторы, факты и агрегаты; содержимое медицинских документов и ПДн —
   никогда (см. «Что намеренно отсутствует»).
3. Синхронный запрос-ответ с внешней системой допускается только в пограничных сценариях (проверка
   остатка перед заказом, сверка платежа); он не меняет модель домена и не создаёт цикла зависимостей.
4. За каждой внешней системой закреплён один владелец домена с точки зрения контракта: ЦБ РФ и
   Росздравнадзор/ЕГИСЗ — Corporate Finance (клинический контур — Patient Flow), Роскомнадзор —
   Identity & Access, платёжная инфраструктура — Accounts & Payments, фарма-партнёры и производитель
   электроники — Inventory & Supply.

## Версионирование и эволюция контрактов

Версия живёт в двух местах: `event_version` в конверте — версия схемы `payload` (растёт и при обратно
совместимых добавлениях), и суффикс топика (`.v1`, `.v2`) — мажорная версия контракта, которая меняется
только при ломающем изменении. Конверт стабилен и не версионируется отдельно.

### Правила совместимости

1. **Внутри мажорной версии — только обратно совместимые изменения:** добавить необязательное поле
   с понятным значением по умолчанию; расширить словарь значений, если консьюмеры обязаны игнорировать
   неизвестные значения. Нельзя удалять и переименовывать поля, менять тип, единицы и семантику.
2. **Консьюмер — tolerant reader (устойчивый к неизвестным полям):** неизвестные поля игнорируются, отсутствующие необязательные поля
   заменяются значением по умолчанию. Это проверяется contract-тестом, а не соглашением на словах.
3. **Обратно совместимое добавление повышает `event_version` в рамках текущего топика** (`.v1`)
   и не создаёт новый топик. **Ломающее изменение — новая мажорная версия топика** (`.v2`) и следующий
   `event_version`; продюсер публикует старый и новый топик параллельно не меньше двух релизных циклов
   и не меньше 90 дней.
4. **Вывод v1** — только после отчёта Schema Registry и групп потребителей: у всех групп лаг по v1 = 0,
   трафика нет 14 дней подряд. В каталоге ставится `deprecated_since`, на трафик v1 — алерт.
5. **Schema Registry:** режим `BACKWARD_TRANSITIVE`; публикация схемы без прохождения проверки запрещена.
   Контрактные тесты каждого консьюмера запускаются в CI до merge.
6. **Семантика важнее структуры.** Если меняется смысл поля (например, `amount` с «без НДС» на «с НДС»),
   это ломающее изменение даже при том же типе.

### Пример: обратно совместимое расширение `billing.invoice.issued` (`event_version` 1 → 2, топик остаётся `.v1`)

Текущая схема (`event_version: 1`):

```json
{
  "event_id": "018f3c1e-7a2b-7c4d-9e01-2f3a4b5c6d7e",
  "event_type": "billing.invoice.issued",
  "event_version": 1,
  "occurred_at": "2026-10-30T12:00:00Z",
  "producer": "billing",
  "correlation_id": "6f1d0f5e-3c1a-4b8e-9d2f-0a1b2c3d4e5f",
  "causation_id": "1b2c3d4e-5f60-4a7b-8c9d-0e1f2a3b4c5d",
  "partition_key": "018f3c20-1a2b-7c3d-8e4f-5a6b7c8d9e0f",
  "payload": {
    "invoice_id": "018f3c20-1a2b-7c3d-8e4f-5a6b7c8d9e0f",
    "patient_id": "018f3c1f-0a1b-7c2d-9e3f-4a5b6c7d8e9f",
    "amount": 12500.00,
    "currency": "RUB",
    "due_date": "2026-11-30"
  }
}
```

Следующая схема (`event_version: 2`; добавлены необязательные поля; топик остаётся `.v1`;
старые консьюмеры продолжают работать):

```json
{
  "event_id": "018f3c1e-7a2b-7c4d-9e01-2f3a4b5c6d7e",
  "event_type": "billing.invoice.issued",
  "event_version": 2,
  "occurred_at": "2026-10-30T12:00:00Z",
  "producer": "billing",
  "correlation_id": "6f1d0f5e-3c1a-4b8e-9d2f-0a1b2c3d4e5f",
  "causation_id": "1b2c3d4e-5f60-4a7b-8c9d-0e1f2a3b4c5d",
  "partition_key": "018f3c20-1a2b-7c3d-8e4f-5a6b7c8d9e0f",
  "payload": {
    "invoice_id": "018f3c20-1a2b-7c3d-8e4f-5a6b7c8d9e0f",
    "patient_id": "018f3c1f-0a1b-7c2d-9e3f-4a5b6c7d8e9f",
    "amount": 12500.00,
    "currency": "RUB",
    "due_date": "2026-11-30",
    "clinic_id": "018f3c1e-9f8e-7d6c-8b5a-4f3e2d1c0b9a",
    "tax_amount": 2083.33,
    "service_lines": [
      { "service_code": "MRI-HEAD", "quantity": 1, "unit_price": 9000.00 },
      { "service_code": "AI-RAD-01", "quantity": 1, "unit_price": 3500.00 }
    ]
  }
}
```

Правила для `event_version: 2`:
- старый консьюмер (схема 1) читает только известные поля и не падает — это проверено contract-тестом;
- новый консьюмер обязан принимать и схему 1 (тогда `clinic_id = null`, `tax_amount = 0`), потому что
  во время параллельной публикации приходят оба варианта;
- `service_lines` — массив без гарантии порядка; `amount` остаётся суммой по счёту с НДС, `tax_amount`
  выделяется отдельно (семантика не изменилась);
- если позже потребуется **убрать** `patient_id` или сменить `amount` на сумму без НДС — это ломающее
  изменение: новый топик `billing.invoice.issued.v2` и следующий `event_version`, а не «тихое» изменение.

## Служебные топики

| Топик              | Назначение                                                         |
| ------------------ | ------------------------------------------------------------------ |
| `<topic>.dlq`      | Сообщения, не обработанные после N повторов; алерт и ручной разбор |
| `<topic>.retry`    | Отложенные повторы с экспоненциальной задержкой                    |
| `dwh.cdc.*`        | CDC из DWH; потребляется только ACL-адаптерами                     |
