# Bounded contexts — «Будущее 2.0»

Домены выделены по бизнес-возможностям и владельцам данных, а не по текущим таблицам DWH.
Каждый контекст владеет собственной моделью и хранилищем; интеграция — через события и публичные контракты.

**Диаграмма:** [`bounded-contexts.drawio`](bounded-contexts.drawio) — домены, контексты и события между ними.
Mermaid-версия ниже рендерится на GitHub без draw.io.
Диаграмма drawio дана на уровне доменов: рёбра между контейнерами доменов группируют потоки, а блоки
внутри доменов показывают, кто именно публикует и кто получает факты (Diagnostics & AI и Lending & Scoring
объединены с их единственными потребителями). Авторитетный список подписок —
[Context Map](context-map.md) и [матрица подписок](event-storming.md). Уведомление
`finance.period.close.started` указано в блоке Corporate Finance: получают его Billing,
Accounts & Payments и Lending.
Стратегические отношения (OHS, PL, C/S, Conformist, ACL, Partnership, Separate Ways) — на отдельной
[Context Map](context-map.md) с Mermaid-диаграммой и таблицей расшифровки.

```mermaid
%%{init: {"theme":"base","themeVariables":{"darkMode":true,"background":"#0d1117","mainBkg":"#161b22","primaryColor":"#1f3a5f","primaryTextColor":"#f0f6fc","primaryBorderColor":"#79c0ff","secondaryColor":"#21262d","tertiaryColor":"#161b22","lineColor":"#d0d7de","textColor":"#f0f6fc","titleColor":"#ffffff","edgeLabelBackground":"#0d1117","clusterBkg":"#161b22","clusterBorder":"#8b949e","nodeBorder":"#79c0ff"}}}%%
flowchart TB
  classDef core fill:#12261e,stroke:#7ee787,stroke-width:2px,color:#ffffff
  classDef supp fill:#1f3a5f,stroke:#79c0ff,stroke-width:2px,color:#ffffff
  classDef generic fill:#21262d,stroke:#8b949e,stroke-width:2px,color:#f0f6fc
  classDef closed fill:#2b1618,stroke:#ff7b72,stroke-width:2px,stroke-dasharray:5 3,color:#ffffff
  classDef leg fill:#2a2410,stroke:#ffd166,stroke-width:2px,stroke-dasharray:4 3,color:#ffffff

  subgraph clinical["Клинический домен"]
    pf["Patient Flow"]:::core
    dx["Diagnostics"]:::supp
    ai["AI Analysis"]:::core
    mr["Medical Record<br/>закрытый контур"]:::closed
  end
  subgraph fintech["Финтех"]
    ap["Accounts & Payments"]:::core
    ln["Lending"]:::core
    cs["Credit Scoring"]:::supp
  end
  subgraph corporate["Корпоративный домен"]
    bl["Billing & Settlement"]:::core
    wf["Workforce"]:::generic
    inv["Inventory & Supply"]:::supp
    cf["Corporate Finance"]:::supp
  end
  subgraph platform["Платформенные контексты"]
    id["Identity & Access"]:::generic
    dc["Data Catalog"]:::generic
    bi["Self-service BI"]:::supp
  end
  leg["Легаси DWH / Camel"]:::leg

  id -->|"identity.consent.changed"| pf
  id -->|"identity.consent.changed"| ap
  wf -->|"workforce.shift.scheduled"| pf
  mr -.->|"внутри контура"| pf
  pf -->|"patient.patient.registered, patient.appointment.completed"| bl
  pf -->|"patient.appointment.completed"| wf
  pf -->|"patient.patient.registered, patient.appointment.completed"| cf
  dx -->|"diagnostics.study.completed"| ai
  dx -->|"diagnostics.study.completed"| bl
  dx -->|"diagnostics.study.ordered"| inv
  dx -->|"diagnostics.study.ordered"| wf
  ai -->|"ai.analysis.completed"| bl
  ai -->|"ai.analysis.completed"| cf
  ap -->|"payments.payment.received"| bl
  ap -->|"payments.account.opened, payments.payment.received"| cf
  ap <-->|"платежи, график"| ln
  ln -->|"lending.application.submitted"| cs
  cs -->|"scoring.case.completed"| ln
  ln -->|"lending.loan.*, lending.schedule.generated, lending.repayment.received, lending.payment.overdue"| ap
  ln -->|"lending.loan.*, lending.schedule.generated, lending.repayment.received, lending.application.submitted, lending.payment.overdue, lending.collection.started"| cf
  bl -->|"billing.invoice.*, billing.ai_usage.recorded, billing.settlement.closed"| cf
  bl -->|"billing.invoice.issued, billing.invoice.corrected"| ap
  inv -->|"inventory.stock.low, inventory.purchase.*, inventory.order.placed, inventory.goods.received"| cf
  inv -->|"inventory.goods.received"| bl
  inv -->|"inventory.stock.updated"| dx
  inv -->|"inventory.stock.updated"| pf
  inv -->|"заказы и остатки"| partners
  cf -.->|"уведомление: finance.period.close.started"| bl
  cf -.->|"уведомление: finance.period.close.started"| ap
  cf -.->|"уведомление: finance.period.close.started"| ln
  dc -->|"контракты data products"| bi
  leg -->|"CDC / ACL"| bl
  leg -->|"CDC / ACL"| pf
  leg -->|"CDC / ACL"| cf
  leg -.->|"только через ACL"| mr
  partners["Фарма-партнёры"]:::generic
```

## Контексты и их отношения

| Контекст             | Домен         | Тип                | Ответственность                              | Отношение к соседям                                                                                                                                                                                      |
| -------------------- | ------------- | ------------------ | -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Patient Flow         | Клинический   | Core               | Регистрация пациента, запись, приём, выписка | Open Host для Billing; Customer/Supplier с Workforce                                                                                                                                                     |
| Diagnostics          | Клинический   | Supporting         | Заказ и проведение исследований              | Published Language для AI Analysis                                                                                                                                                                       |
| AI Analysis          | Клинический   | Core (монетизация) | ИИ-заключения, версии моделей                | Conformist к формату исследований                                                                                                                                                                        |
| Medical Record       | Клинический   | Закрытый контур    | Медкарта, история болезни                    | **Не публикуется в аналитику**; обмен с Patient Flow — только внутри клинического домена, наружу не идёт ни одного события                                                                               |
| Accounts & Payments  | Финтех        | Core               | Счета, проводки, платежи                     | Partnership с Lending; с Billing — два встречных потока фактов: потребляет `billing.invoice.issued` и `billing.invoice.corrected` (downstream) и публикует `payments.payment.received` (upstream), без цикла моделей (см. Context Map) |
| Lending              | Финтех        | Core               | Кредитные договоры, график платежей          | Customer/Supplier со Scoring                                                                                                                                                                             |
| Credit Scoring       | Финтех        | Supporting         | Оценка заёмщика                              | Публикует `scoring.case.completed`                                                                                                                                                                       |
| Billing & Settlement | Корпоративный | Core               | Счета за услуги, сверка с клиниками и банком | ACL к DWH-логике; перечень правил и порядок переноса — [`dwh-to-billing-rules.md`](dwh-to-billing-rules.md)                                                                                              |
| Workforce            | Корпоративный | Generic            | Смены, квалификации                          | Поставщик для Patient Flow                                                                                                                                                                               |
| Inventory & Supply   | Корпоративный | Supporting         | Остатки, закупки, фарма-партнёры             | Open Host для партнёров                                                                                                                                                                                  |
| Corporate Finance    | Корпоративный | Supporting         | Управленческая и регуляторная отчётность     | Подписчик событий всех доменов                                                                                                                                                                           |
| Identity & Access    | Платформенный | Generic            | Роли, ABAC                                   | Shared Kernel с платформой                                                                                                                                                                               |
| Data Catalog         | Платформенный | Generic            | Контракты, data products                     | Published Language                                                                                                                                                                                       |
| Self-service BI      | Платформенный | Supporting         | Портал отчётов                               | Потребляет только data products                                                                                                                                                                          |
| Легаси DWH / Camel   | Мост          | Легаси             | Историческая логика                          | Anti-Corruption Layer для всех новых контекстов                                                                                                                                                          |

## Правила границ

1. Чужие БД не читаются — только события и API.
2. Модели не разделяются: каждый контекст хранит свой «Пациент», «Клиент», «Счёт» со своим смыслом.
3. Идентификаторы между контекстами — глобальные ключи (`patient_id`, `customer_id`), без сквозных числовых внешних ключей.
4. Медицинские данные остаются внутри клинического домена; в событиях передаются только идентификаторы и факты,
   необходимые другим доменам (например, «приём завершён», но не диагноз).
