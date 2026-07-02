# CRM API Discovery — Planning & Reports

Собрано вручную из наблюдений сети `https://crm.lima.uz` (веб LIMA CRM), отдельно от
мобильного `swagger_lima.md` (Storage/Visits/Company API — другой сервис/сваггер).

Нет публичного `swagger.json` на `crm.lima.uz` — все проверенные пути
(`/swagger/v1/swagger.json`, `/planning/swagger/v1/swagger.json` и т.п.) отдают
SPA `index.html` (content-type `text/html`), не JSON. Контракты собираются вручную
по мере обнаружения. Пополнять этот файл по мере находок.

Контекст: [задача замыкания цикла годового планирования](../agent-context/PROJECT_MAP.md)
(руководитель → регион → медпред → таскбар → факт). См. `/api/planning/*` как
вероятную основу веб-части (P0, не в этом репозитории); `/api/reports/*` как
существующую аналитику, возможный источник факта для будущих tasks-эндпоинтов
(ещё не подтверждено).

## `/api/planning/*` — годовое планирование (веб CRM, руководитель/рег.менеджер)

### `GET /api/planning/Plans/years`
Список годов, по которым есть планы. Содержимое ответа не зафиксировано.

### `GET /api/planning/Plans/companies-status?year=2026`
Статус плана по каждой компании.

```json
[
  {"company_id": 11, "company_name": "AMIKAM", "has_plan": false, "plan_id": null},
  {"company_id": 4, "company_name": "ASHA", "has_plan": false, "plan_id": null},
  {"company_id": 1, "company_name": "DREAM", "has_plan": false, "plan_id": null},
  {"company_id": 3, "company_name": "FORTIUS", "has_plan": false, "plan_id": null},
  {"company_id": 9, "company_name": "GOLDMINE", "has_plan": false, "plan_id": null},
  {"company_id": 2, "company_name": "LIMA", "has_plan": false, "plan_id": null},
  {"company_id": 6, "company_name": "LORTEK", "has_plan": false, "plan_id": null},
  {"company_id": 10, "company_name": "PROPHARMA", "has_plan": false, "plan_id": null},
  {"company_id": 7, "company_name": "SIRIUS", "has_plan": false, "plan_id": null},
  {"company_id": 5, "company_name": "VELTA", "has_plan": false, "plan_id": null},
  {"company_id": 8, "company_name": "Управление", "has_plan": false, "plan_id": null}
]
```

### `GET /api/planning/Hierarchy?year=2026`
Вероятно иерархия рег.менеджер → медпред для распределения плана. Содержимое ответа
не зафиксировано — нужно перепроверить и добавить сюда.

### `GET /api/planning/Factories?year=2026`
Вероятно план по производителям/SKU. Содержимое ответа не зафиксировано.

**Статус tasks-эндпоинтов:** не найдено. Ни `/api/planning/*`, ни где-либо ещё нет
метода с семантикой "активные задачи медпреда" или "счётчик план/факт по задаче".
Мобильный таскбар (см. project-память `lima-plan-sync-taskbar-spec`,
`lima-planning-web-backend`) заблокирован до контракта от бэкенд-команды
(Vadim Muratov / Ilyas Gabbasov).

## `/api/company/all` — справочник компаний

Компании с регионом, головной/управляющей компанией, возможной `sale_company`
(перепривязка продаж на другую компанию группы).

```json
{
  "region_id": 1,
  "region_name": "г. Ташкент",
  "area_id": 7,
  "area_name": "Чиланзарский район",
  "city_id": null,
  "address": "Ул.Катартал 38",
  "uid": "d1522ce9...",
  "id": 4,
  "name": "ASHA",
  "legal_name": null,
  "inn": 305089312,
  "head_company_id": 1,
  "head_company_name": "MAO Group",
  "manage_company_id": 8,
  "manage_company_name": "Управление",
  "one_c_code": 4,
  "contract_prefix": "A,А",
  "sale_company": {"id": 4, "name": "ASHA", "...": "..."}
}
```

11 компаний группы MAO Group: AMIKAM, ASHA, DREAM, FORTIUS, GOLDMINE, LIMA, LORTEK,
PROPHARMA, SIRIUS, VELTA, Управление.

## `/api/users?only_active=true` — все активные сотрудники

Полный справочник пользователей CRM с ролью, регионом, компанией, direction и
(потенциально) прямым менеджером.

```json
{
  "id": 99,
  "full_name": "Abdimuminov Egamberdi Beknazarovich",
  "phone": "998938361133",
  "region_id": 9,
  "region_name": "Самаркандская область",
  "telegram_id": null,
  "role_id": 14,
  "role_name": "Региональный менеджер",
  "active": true,
  "manager_user_id": null,
  "manager_user_id2": null,
  "order_processing_users": [],
  "company": {
    "id": 4, "name": "ASHA", "legal_name": null, "one_c_code": 4,
    "manage_company_id": 8, "manage_company_name": "Управление"
  },
  "direction": null
}
```

Роли, встреченные в выгрузке: Медицинский представитель (`role_id=11`),
Региональный менеджер (`role_id=14`), Field-force менеджер (`role_id=6`),
Оператор (`role_id=10`), Менеджер отдела КиЛТО (`role_id=5`),
Руководитель отдела КиЛТО (`role_id=8`), Контент менеджер (`role_id=4`),
Администратор (`role_id=1`).

`manager_user_id` / `manager_user_id2` присутствуют в схеме (иерархия подчинения),
но в увиденных записях были `null` — не проверено на записях с фактическим
менеджером.

## `/api/dict/*` — справочники

### `GET /api/dict/organizations/health-care-facility/types`
Типы ЛПУ. **Используется в мобильном приложении** —
`RemoteApiService.getHealthcareFacilityTypes()` в
`lib/core/network/remote_api_service.dart` теперь зовёт этот endpoint напрямую
(раньше был обходной путь через пробы `/dict/organizations?health_care_facility_type_id=$id`
для id 1–8, т.к. считалось, что выделенного справочника нет).

```json
[
  {"id": 1, "name": "Поликлиника"},
  {"id": 2, "name": "Роддом"},
  {"id": 6, "name": "Салон красоты"},
  {"id": 3, "name": "Санаторий"},
  {"id": 4, "name": "Стационар"},
  {"id": 5, "name": "Стоматология"}
]
```

### `GET /api/dict/doctors/specialization` (или аналогичный путь дающий этот список)
Полный справочник специализаций врачей с `proxima_id`/`proxima_name` — маппинг на
внешнюю систему Proxima. ~170 специализаций, в т.ч. административные должности
(Главный врач, Директор, Зав. отделением и т.д.). Уже частично используется
мобильным приложением через `getSpecializations()` (см.
`lib/core/network/remote_api_service.dart`, добавлено в 1.0.4+18 для add-doctor).
Полный список не дублируется здесь — см. живой endpoint.

### `GET /api/dict/common/regions/{id}`
Справочник региона по id. Содержимое ответа не зафиксировано для повторной проверки.

## `/api/reports/*` — аналитика (существующий модуль, отдельно от planning)

### `GET /api/reports/visits/count?start_date=&end_date=`
```json
{"orders_count": 0, "visits_count": 16}
```

### `GET /api/reports/sales?start_date=&end_date=`
Содержимое ответа не зафиксировано.

### `GET /api/reports/sales/percentage?start_date=&end_date=`
Содержимое ответа не зафиксировано.

### `GET /api/reports/visits?start_date=&end_date=`
Содержимое ответа не зафиксировано.

### `GET /api/reports/doctors/statistics?start_date=&end_date=`
Статистика охвата врачей (visited/prescribes), похоже общая сводка не по
конкретному медпреду (`med_rep_id: null` в примере).

```json
[
  {
    "med_rep_id": null,
    "doctors_count": 59801,
    "med_rep_doctors_count": 3977,
    "visit_to_doctors_count": 6,
    "prescribes_count": 3,
    "familiarized_does_not_prescribes_count": 0,
    "not_familiar_does_not_prescribes_count": 0,
    "med_rep_doctors_percentage": 6.6503906,
    "visit_to_doctors_percentage": 0.15086749,
    "prescribes_percentage": 0.075433746,
    "familiarized_does_not_prescribes_percentage": 0,
    "not_familiar_does_not_prescribes_percentage": 0
  }
]
```

### `GET /api/reports/drugs?start_date=&end_date=`
Разрез: организация → медпред (`user_name`) → список препаратов с count за период.
**Вероятный источник факта** для авто-счётчика плановых задач в будущем таскбаре
(сколько упаковок препарата X продал/оформил конкретный медпред за период) — не
подтверждённый контракт, но структурно ближе всего к тому, что нужно для раздела
4.2 спеки ("Плановые задачи: счётчик растёт автоматически, когда оператор
подтверждает заявку").

```json
{
  "organization_name": "RAVSHAN MIRZAYEV-MEDSERVIS",
  "organization_region_id": 10,
  "organization_region_name": "Сурхандарьинская область",
  "health_care_facility_type_id": 0,
  "health_care_facility_type_name": null,
  "user_name": "Safarov Jahongir",
  "drugs": [
    {"drug_id": 5, "drug_name": "аккорд раствор для инфузий 50 мл", "count": 2},
    {"drug_id": 6, "drug_name": "цитаргин раствор для инфузий 100 мл", "count": 1}
  ]
}
```

### `GET /api/reports/orders/sum?`
```json
{"order_total_sum": 0, "sold_total_sum": 0}
```

## Открытые вопросы

- Полное содержимое `Hierarchy`, `Factories`, `sales`, `sales/percentage`, `visits`
  (report), `regions/{id}` — нужно перезапросить и вставить сюда.
- Нет tasks/taskbar эндпоинтов — статус не меняется с последней проверки.
- `manager_user_id` в `/api/users` — не видели заполненным ни разу, проверить на
  записи с известной иерархией (например региональный менеджер → его медпред).
