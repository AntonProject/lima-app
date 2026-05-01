# Agent Workflow Documentation

> **Полный workflow для мобильного агентского приложения (agent/)**
> Последнее обновление: 2026-04-14

---

## Содержание

1. [Обзор архитектуры](#обзор-архитектуры)
2. [Типы организаций и визитов](#типы-организаций-и-визитов)
3. [Flow: Начало рабочего дня](#flow-начало-рабочего-дня)
4. [Flow: Поиск организаций](#flow-поиск-организаций)
5. [Flow: Визит в ЛПУ](#flow-визит-в-лпу)
6. [Flow: Бронь в аптеке](#flow-бронь-в-аптеке)
7. [Flow: Снятие остатков](#flow-снятие-остатков)
8. [Flow: Фарм кружок](#flow-фарм-кружок)
9. [API Endpoints Reference](#api-endpoints-reference)
10. [Stores Reference](#stores-reference)

---

## Обзор архитектуры

### Структура проекта

```
agent/
├── src/
│   ├── features/           # Страницы по фичам
│   │   ├── auth/           # Авторизация
│   │   ├── main/           # Главная страница
│   │   ├── organizations/  # Поиск, детали организаций
│   │   ├── visits/         # Визиты (ЛПУ)
│   │   ├── pharmacy/       # Аптеки (бронь, остатки, фарм кружок)
│   │   └── history/        # История визитов
│   ├── stores/             # Pinia stores
│   ├── shared/             # Общие компоненты
│   └── plugins/            # Axios, i18n
```

### Технологический стек

- **Vue 3** + Composition API (`<script setup>`)
- **Pinia** - state management
- **Vue Router** - навигация
- **Naive UI** - UI компоненты
- **SCSS** - стили
- **Axios** - HTTP клиент
- **PWA** - Progressive Web App

---

## Типы организаций и визитов

### Типы организаций (`type_id`)

| type_id | Название | Описание |
|---------|----------|----------|
| 1 | **Аптека** | Бронь, снятие остатков, фарм кружок |
| 2 | **ЛПУ** | Визиты к врачам |

### Типы визитов (`visit_type`)

| visit_type | Название | Применение |
|------------|----------|------------|
| 1 | Визит в аптеку | Бронь + Фарм кружок |
| 2 | Визит в ЛПУ | Визиты к врачам |
| 3 | Визит к оптовику | -- |
| 4 | Остатки | Снятие остатков (инвентаризация) |

### Режимы визитов в ЛПУ

| Режим | Описание | Параметры URL |
|-------|----------|---------------|
| **Single** | 1 врач | `doc_id={id}` |
| **Group** | Несколько врачей | `doctor_ids={id1},{id2}` |
| **Double** | С менеджером | `manager_ids={id}` |

### Действия в аптеке

| Действие | visit_type | Описание |
|----------|------------|----------|
| **Бронь** | 1 | Создание заказа препаратов |
| **Снятие остатков** | 4 | Инвентаризация препаратов |
| **Фарм кружок** | 1 | Презентация для фармацевтов |

---

## Flow: Начало рабочего дня

### Компоненты

- `MainPage.vue` - главная страница
- `stores/workday.js` - управление рабочим днём

### Последовательность

```
┌────────────────────────────────────────────────────────────────┐
│                        ГЛАВНАЯ СТРАНИЦА                        │
├────────────────────────────────────────────────────────────────┤
│  1. Загрузка при входе                                         │
│     └─► GET /workday/status                                    │
│         Response: { status: "not_started"|"started"|"ended" }  │
│                                                                │
│  2. Если статус = "not_started"                                │
│     └─► Показать модалку "Начать рабочий день"                 │
│         └─► GET /daytype (загрузка типов рабочих дней)         │
│             Response: [ { id, name, description } ]            │
│                                                                │
│  3. Пользователь выбирает тип дня и нажимает "Начать"          │
│     └─► POST /workday/start                                    │
│         Body: { daytype_id: number, latitude, longitude }      │
│         Response: 200 OK                                       │
│                                                                │
│  4. Теперь можно работать (статус = "started")                 │
└────────────────────────────────────────────────────────────────┘
```

### API вызовы

#### GET /workday/status
```javascript
// stores/workday.js
const fetchStatus = async () => {
  const response = await axios.get('/workday/status')
  status.value = response.data?.status || 'not_started'
}
```

#### GET /daytype
```javascript
const fetchDayTypes = async () => {
  const response = await axios.get('/daytype')
  dayTypes.value = response.data?.result || response.data || []
}
```

#### POST /workday/start
```javascript
const startWorkday = async (daytypeId, latitude = 0, longitude = 0) => {
  await axios.post('/workday/start', {
    daytype_id: daytypeId,
    latitude,
    longitude
  })
  status.value = 'started'
}
```

#### POST /workday/end
```javascript
const endWorkday = async (latitude = 0, longitude = 0) => {
  await axios.post('/workday/end', {
    latitude,
    longitude
  })
  status.value = 'ended'
}
```

---

## Flow: Поиск организаций

### Компоненты

- `SearchPage.vue` - страница поиска
- `stores/organizations.js` - организации

### Последовательность

```
┌────────────────────────────────────────────────────────────────┐
│                       ПОИСК ОРГАНИЗАЦИЙ                        │
│                         /search                                │
├────────────────────────────────────────────────────────────────┤
│  1. Открытие страницы                                          │
│     └─► Показать поле поиска + табы (Аптеки / ЛПУ)             │
│                                                                │
│  2. Пользователь выбирает тип (type_id)                        │
│     ├─► type_id = 1 → Аптеки                                   │
│     └─► type_id = 2 → ЛПУ                                      │
│                                                                │
│  3. Пользователь вводит поисковый запрос (min 2 символа)       │
│     └─► GET /organizations/search?type_id={type}&search={query}│
│         Response: {                                            │
│           result: [                                            │
│             { id, name, type_id, address, inn, ... }           │
│           ]                                                    │
│         }                                                      │
│                                                                │
│  4. Пользователь нажимает на организацию                       │
│     └─► router.push(`/organization/${id}/${type_id}`)          │
│                                                                │
│  5. GET /organizations/{id} (загрузка деталей)                 │
│     Response: { id, name, inn, address, phone, ... }           │
└────────────────────────────────────────────────────────────────┘
```

### API вызовы

#### GET /organizations/search
```javascript
// stores/organizations.js
const searchOrganizations = async (query, typeId) => {
  if (query.length < 2) return

  const response = await axios.get('/organizations/search', {
    params: {
      search: query,
      type_id: typeId  // 1 = аптека, 2 = ЛПУ
    }
  })
  searchResults.value = response.data?.result || []
}
```

#### GET /organizations/{id}
```javascript
const fetchOrganization = async (id) => {
  const response = await axios.get(`/organizations/${id}`)
  organization.value = response.data?.result || response.data
}
```

#### GET /organizations/favorites
```javascript
const fetchFavorites = async () => {
  const response = await axios.get('/organizations/favorites')
  favorites.value = response.data?.result || []
}
```

#### POST /organizations/favorites/{id}
```javascript
const toggleFavorite = async (id, isFavorite) => {
  if (isFavorite) {
    await axios.delete(`/organizations/favorites/${id}`)
  } else {
    await axios.post(`/organizations/favorites/${id}`)
  }
}
```

---

## Flow: Визит в ЛПУ

### Компоненты

1. `OrganizationPage.vue` - детали организации
2. `ChooseDoctorPage.vue` - выбор врачей
3. `StatusDrugsPage.vue` - статус препаратов + завершение

### Последовательность

```
┌────────────────────────────────────────────────────────────────┐
│                    ВИЗИТ В ЛПУ (type_id=2)                     │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ЭТАП 1: ДЕТАЛИ ОРГАНИЗАЦИИ                                   │
│  /organization/{id}/2                                          │
│  ─────────────────────────────────────────────────────────────│
│  1. Загрузка организации                                       │
│     └─► GET /organizations/{id}                                │
│                                                                │
│  2. Загрузка врачей организации                                │
│     └─► GET /doctors/by-organization/{id}                      │
│         Response: {                                            │
│           result: [                                            │
│             {                                                  │
│               id, full_name, specialization_id,                │
│               specialization_name, category_id,                │
│               phone, hobby, interests, birthday                │
│             }                                                  │
│           ]                                                    │
│         }                                                      │
│                                                                │
│  3. Пользователь нажимает "Визит"                              │
│     └─► router.push(`/choose-doctor?org_id=${id}&type_id=2`)   │
│                                                                │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ЭТАП 2: ВЫБОР ВРАЧЕЙ                                          │
│  /choose-doctor?org_id={id}&type_id=2                          │
│  ─────────────────────────────────────────────────────────────│
│  1. Загрузка врачей + специализаций                            │
│     ├─► GET /doctors/by-organization/{org_id}                  │
│     └─► GET /doctors/specializations                           │
│         Response: [ { id, name } ]                             │
│                                                                │
│  2. Опционально: Добавление нового врача                       │
│     └─► POST /doctors                                          │
│         Body: {                                                │
│           full_name: string,                                   │
│           phone: string (без пробелов!),                       │
│           specialization_id: number,                           │
│           position: string,                                    │
│           category_id: number (1=A, 2=B, 3=C),                 │
│           organization_id: [number] (массив!)                  │
│         }                                                      │
│                                                                │
│  3. Пользователь выбирает врачей и нажимает "Продолжить"       │
│     └─► Формирование URL:                                      │
│         • 1 врач: /status-drugs?org_id={}&type_id=2&doc_id={}  │
│         • N врачей: ...&doctor_ids={id1},{id2}                 │
│         • С менеджером: ...&manager_ids={id}                   │
│                                                                │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ЭТАП 3: СТАТУС ПРЕПАРАТОВ И ЗАВЕРШЕНИЕ                        │
│  /status-drugs?org_id={}&type_id=2&doc_id={} или doctor_ids=   │
│  ─────────────────────────────────────────────────────────────│
│  1. Загрузка препаратов (bindings)                             │
│     └─► GET /dict/drugs/bindings                               │
│         Response: [                                            │
│           {                                                    │
│             id: number (это binding ID!),                      │
│             drug: { id, drug_id, name },                       │
│             producer: { id, name }                             │
│           }                                                    │
│         ]                                                      │
│                                                                │
│  2. Загрузка материалов для препарата                          │
│     └─► GET /documents/by-drug/{drug_id}                       │
│         Response: {                                            │
│           drug: {...},                                         │
│           documents: [                                         │
│             {                                                  │
│               id, title, file_name, file_uid, file_url,        │
│               document_type_name, must_see                     │
│             }                                                  │
│           ]                                                    │
│         }                                                      │
│                                                                │
│  3. Загрузка файла материала                                   │
│     └─► GET /files/download/{file_uid}                         │
│         Response: Blob (PDF, video, image)                     │
│                                                                │
│  4. Выбор статуса препарата (4/5/6/null)                       │
│     • 4 = Знаком + выписывает                                  │
│     • 5 = Знаком + НЕ выписывает                               │
│     • 6 = НЕ знаком + НЕ выписывает                            │
│     • null = Оставить комментарий                              │
│                                                                │
│  5. Завершение визита                                          │
│     └─► POST /visits/add                                       │
│         Body: {                                                │
│           organization_id: number,                             │
│           visit_type: 2,                                       │
│           complete: true,                                      │
│           latitude: number,                                    │
│           longitude: number,                                   │
│           doctor_ids: [number] (массив!),                      │
│           manager_ids?: [number],                              │
│           talked_about_drugs: [                                │
│             {                                                  │
│               drug_id: number (binding ID!),                   │
│               status_id: number (4/5/6),                       │
│               ball?: number,                                   │
│               comment?: string,                                │
│               document_ids: [number]                           │
│             }                                                  │
│           ]                                                    │
│         }                                                      │
│         Response: { visit_id: number }                         │
│                                                                │
│  6. Показ Success модалки → переход на главную                 │
└────────────────────────────────────────────────────────────────┘
```

### API вызовы

#### GET /doctors/by-organization/{id}
```javascript
// stores/doctors.js
const fetchDoctorsByOrganization = async (orgId) => {
  const response = await axios.get(`/doctors/by-organization/${orgId}`)
  doctors.value = response.data?.result || []
}
```

#### GET /doctors/specializations
```javascript
const fetchSpecializations = async () => {
  const response = await axios.get('/doctors/specializations')
  specializations.value = response.data?.result || response.data || []
}
```

#### POST /doctors
```javascript
const createDoctor = async (doctorData) => {
  const response = await axios.post('/doctors', {
    full_name: doctorData.full_name,
    phone: doctorData.phone.replace(/\s/g, ''),  // Убрать пробелы!
    specialization_id: doctorData.specialization_id,
    position: doctorData.position,
    category_id: doctorData.category_id,
    organization_id: [Number(doctorData.organization_id)]  // Массив!
  })
  return response.data
}
```

#### GET /dict/drugs/bindings
```javascript
// stores/drugs.js
const loadCompanyDrugs = async () => {
  const response = await axios.get('/dict/drugs/bindings')
  companyDrugs.value = response.data?.result || response.data || []
}
```

#### GET /documents/by-drug/{id}
```javascript
const loadDocuments = async (drugId) => {
  const response = await axios.get(`/documents/by-drug/${drugId}`)
  return response.data?.documents || []
}
```

#### POST /visits/add (ЛПУ)
```javascript
// stores/visits.js
const createVisit = async (visitData) => {
  const response = await axios.post('/visits/add', visitData)
  return response.data
}

// Пример payload для ЛПУ визита:
const visitPayload = {
  organization_id: 123,
  visit_type: 2,  // ЛПУ
  complete: true,
  latitude: 41.311081,
  longitude: 69.240562,
  doctor_ids: [456],  // Массив врачей
  talked_about_drugs: [
    {
      drug_id: 789,       // ID из /dict/drugs/bindings (binding ID!)
      status_id: 4,       // 4 = знаком, выписывает
      ball: 10,
      comment: "Назначает регулярно",
      document_ids: [111, 222]
    }
  ]
}
```

---

## Flow: Бронь в аптеке

### Компоненты

1. `OrganizationPage.vue` - детали аптеки
2. `VisitTypePage.vue` - выбор действия
3. `CartPage.vue` - корзина брони

### Последовательность

```
┌────────────────────────────────────────────────────────────────┐
│                  БРОНЬ В АПТЕКЕ (type_id=1)                    │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ЭТАП 1: ДЕТАЛИ АПТЕКИ                                         │
│  /organization/{id}/1                                          │
│  ─────────────────────────────────────────────────────────────│
│  1. Загрузка организации                                       │
│     └─► GET /organizations/{id}                                │
│                                                                │
│  2. Пользователь нажимает "Визит"                              │
│     └─► router.push(`/visit-type/${id}/1`)                     │
│                                                                │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ЭТАП 2: ВЫБОР ТИПА ВИЗИТА                                     │
│  /visit-type/{id}/1                                            │
│  ─────────────────────────────────────────────────────────────│
│  Варианты:                                                     │
│  • "Бронь" → /cart?org_id={id}&type_id=1                       │
│  • "Снятие остатков" → /inventory?org_id={id}                  │
│  • "Фарм кружок" → /pharmacy-presentation?org_id={id}          │
│                                                                │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ЭТАП 3: КОРЗИНА БРОНИ                                         │
│  /cart?org_id={id}&type_id=1                                   │
│  ─────────────────────────────────────────────────────────────│
│  1. Загрузка прайс-листа                                       │
│     └─► GET /stock/price-list                                  │
│         Response: [                                            │
│           {                                                    │
│             income_detailing_id: number,                       │
│             drug: {                                            │
│               id: number (binding ID - использовать!),         │
│               drug_id: number (НЕ использовать!),              │
│               name: string                                     │
│             },                                                 │
│             producer: { id, name },                            │
│             series: string,                                    │
│             expire_date: string,                               │
│             unique_counter: number,                            │
│             base_price: number,                                │
│             sale_price: number                                 │
│           }                                                    │
│         ]                                                      │
│                                                                │
│  2. Загрузка наценок                                           │
│     └─► GET /markups/short                                     │
│         Response: [                                            │
│           {                                                    │
│             id: number,                                        │
│             prepayment_percent: number,                        │
│             is_default: boolean                                │
│           }                                                    │
│         ]                                                      │
│                                                                │
│  3. Загрузка контрактов клиента                                │
│     └─► GET /contracts/client/{inn}                            │
│         Response: {                                            │
│           contracts: [                                         │
│             {                                                  │
│               id: number,                                      │
│               payment_variants: [                              │
│                 { id, days, name }                             │
│               ]                                                │
│             }                                                  │
│           ]                                                    │
│         }                                                      │
│                                                                │
│  4. Расчёт цены (при изменении корзины)                        │
│     └─► POST /pricing/calculate                                │
│         Body: {                                                │
│           contract_id: number,                                 │
│           margin_id: number,                                   │
│           payment_variant_id: number,                          │
│           is_wholesaler: boolean,                              │
│           drugs: [                                             │
│             {                                                  │
│               income_detailing_id: number,                     │
│               package: number (количество)                     │
│             }                                                  │
│           ]                                                    │
│         }                                                      │
│         Response: {                                            │
│           drugs: [                                             │
│             {                                                  │
│               income_detailing_id: number,                     │
│               sale_price: number (цена со скидкой)             │
│             }                                                  │
│           ],                                                   │
│           total: number                                        │
│         }                                                      │
│                                                                │
│  5. Сохранение корзины (опционально)                           │
│     └─► POST /cart                                             │
│         Body: {                                                │
│           organization_id: number,                             │
│           drugs: [                                             │
│             {                                                  │
│               income_detailing_id: number,                     │
│               drug_id: number (binding ID!),                   │
│               package: number                                  │
│             }                                                  │
│           ]                                                    │
│         }                                                      │
│                                                                │
│  6. Завершение визита (бронь)                                  │
│     └─► POST /visits/add                                       │
│         Body: {                                                │
│           organization_id: number,                             │
│           visit_type: 1,                                       │
│           complete: true,                                      │
│           latitude: number,                                    │
│           longitude: number,                                   │
│           margin_id: number,                                   │
│           contract_id: number,                                 │
│           is_wholesaler: boolean,                              │
│           payment_variant_id: number,                          │
│           comment: string,                                     │
│           drugs: [                                             │
│             {                                                  │
│               income_detailing_id: number,                     │
│               drug_id: number (binding ID!),                   │
│               package: number,                                 │
│               sale_price: number                               │
│             }                                                  │
│           ]                                                    │
│         }                                                      │
│         Response: { visit_id: number }                         │
│                                                                │
│  7. Показ Success модалки → переход на главную                 │
└────────────────────────────────────────────────────────────────┘
```

### API вызовы

#### GET /stock/price-list
```javascript
// stores/drugs.js
const loadPriceList = async () => {
  const response = await axios.get('/stock/price-list')
  priceList.value = response.data?.result || response.data || []
}
```

#### GET /markups/short
```javascript
// stores/markups.js
const fetchMarkups = async () => {
  const response = await axios.get('/markups/short')
  markups.value = response.data?.result || response.data || []
}
```

#### GET /contracts/client/{inn}
```javascript
const fetchContracts = async (inn) => {
  const response = await axios.get(`/contracts/client/${inn}`)
  contracts.value = response.data?.contracts || []
}
```

#### POST /pricing/calculate
```javascript
const calculatePrices = async (params) => {
  const response = await axios.post('/pricing/calculate', {
    contract_id: params.contractId,
    margin_id: params.marginId,
    payment_variant_id: params.paymentVariantId,
    is_wholesaler: params.isWholesaler,
    drugs: params.drugs.map(d => ({
      income_detailing_id: d.income_detailing_id,
      package: d.package
    }))
  })
  return response.data
}
```

#### POST /visits/add (Бронь)
```javascript
// Пример payload для брони:
const visitPayload = {
  organization_id: 123,
  visit_type: 1,  // Аптека
  complete: true,
  latitude: 41.311081,
  longitude: 69.240562,
  margin_id: 1,
  contract_id: 5,
  is_wholesaler: false,
  payment_variant_id: 2,
  comment: "Срочный заказ",
  drugs: [
    {
      income_detailing_id: 100,
      drug_id: 789,      // ID из drug.id (binding ID!)
      package: 10,
      sale_price: 15000
    }
  ]
}
```

### ВАЖНО: ID препарата

```javascript
// При работе с прайс-листом используй drug.id (binding ID), НЕ drug.drug_id!

// Структура item из /stock/price-list:
{
  "drug": {
    "id": 20,        // ← ЭТОТ ID отправляем как drug_id!
    "drug_id": 79,   // НЕ этот!
    "name": "Аспирин"
  }
}

// ✅ ПРАВИЛЬНО:
drug_id: item.drug?.id

// ❌ НЕПРАВИЛЬНО:
drug_id: item.drug?.drug_id
```

---

## Flow: Снятие остатков

### Компоненты

1. `VisitTypePage.vue` - выбор "Снятие остатков"
2. `InventoryPage.vue` - инвентаризация

### Последовательность

```
┌────────────────────────────────────────────────────────────────┐
│                     СНЯТИЕ ОСТАТКОВ                            │
│                 /inventory?org_id={id}                         │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  1. Загрузка прайс-листа                                       │
│     └─► GET /stock/price-list                                  │
│                                                                │
│  2. Поиск и добавление препаратов в список                     │
│     └─► Пользователь вводит количество (unique_counter)        │
│                                                                │
│  3. Завершение (снятие остатков)                               │
│     └─► POST /visits/add                                       │
│         Body: {                                                │
│           organization_id: number,                             │
│           visit_type: 4,  // Остатки!                          │
│           complete: true,                                      │
│           latitude: number,                                    │
│           longitude: number,                                   │
│           comment: string,                                     │
│           drugs: [                                             │
│             {                                                  │
│               income_detailing_id: number,                     │
│               drug_id: number (binding ID!),                   │
│               package: number (остаток)                        │
│             }                                                  │
│           ]                                                    │
│         }                                                      │
│                                                                │
│  4. Показ Success модалки                                      │
└────────────────────────────────────────────────────────────────┘
```

### API вызовы

#### POST /visits/add (Остатки)
```javascript
// Пример payload для снятия остатков:
const visitPayload = {
  organization_id: 123,
  visit_type: 4,  // Остатки
  complete: true,
  latitude: 41.311081,
  longitude: 69.240562,
  comment: "Ежемесячная инвентаризация",
  drugs: [
    {
      income_detailing_id: 100,
      drug_id: 789,      // binding ID
      package: 50        // остаток на полке
    }
  ]
}
```

---

## Flow: Фарм кружок

### Компоненты

1. `VisitTypePage.vue` - выбор "Фарм кружок"
2. `PharmacyPresentationPage.vue` - презентация

### Последовательность

```
┌────────────────────────────────────────────────────────────────┐
│                       ФАРМ КРУЖОК                              │
│             /pharmacy-presentation?org_id={id}                 │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  1. Загрузка препаратов компании                               │
│     └─► GET /dict/drugs/bindings                               │
│                                                                │
│  2. Показ списка препаратов                                    │
│     └─► Пользователь выбирает препарат                         │
│                                                                │
│  3. Загрузка материалов для препарата                          │
│     └─► GET /documents/by-drug/{drug_id}                       │
│                                                                │
│  4. Показ материала (PDF/видео/изображение)                    │
│     └─► GET /files/download/{file_uid}                         │
│     └─► Отметка просмотра (document_ids)                       │
│                                                                │
│  5. Заполнение данных участников                               │
│     └─► Имена фармацевтов (текст)                              │
│     └─► Количество участников (число)                          │
│                                                                │
│  6. Завершение фарм кружка                                     │
│     └─► POST /visits/add                                       │
│         Body: {                                                │
│           organization_id: number,                             │
│           visit_type: 1,  // Аптека                            │
│           complete: true,                                      │
│           latitude: number,                                    │
│           longitude: number,                                   │
│           visit_pharm_circle: {                                │
│             pharmacist_names: string,                          │
│             start: "2026-04-14T09:00:00",                      │
│             end: "2026-04-14T10:30:00",                        │
│             number_of_participants: number                     │
│           },                                                   │
│           talked_about_drugs: [                                │
│             {                                                  │
│               drug_id: number (binding ID!),                   │
│               document_ids: [number]                           │
│             }                                                  │
│           ]                                                    │
│         }                                                      │
│                                                                │
│  7. Показ Success модалки                                      │
└────────────────────────────────────────────────────────────────┘
```

### API вызовы

#### POST /visits/add (Фарм кружок)
```javascript
// Пример payload для фарм кружка:
const visitPayload = {
  organization_id: 123,
  visit_type: 1,  // Аптека (не 4!)
  complete: true,
  latitude: 41.311081,
  longitude: 69.240562,
  visit_pharm_circle: {
    pharmacist_names: "Иванова М.П.\nПетрова С.А.",
    start: "2026-04-14T09:00:00",
    end: "2026-04-14T10:30:00",
    number_of_participants: 5
  },
  talked_about_drugs: [
    {
      drug_id: 789,           // binding ID
      document_ids: [111, 222]  // просмотренные материалы
    }
  ]
}
```

---

## API Endpoints Reference

### Авторизация

| Метод | Endpoint | Описание |
|-------|----------|----------|
| POST | `/account/authorize` | Логин |
| GET | `/global` | Конфигурации после логина |

### Рабочий день

| Метод | Endpoint | Описание |
|-------|----------|----------|
| GET | `/workday/status` | Статус рабочего дня |
| GET | `/daytype` | Типы рабочих дней |
| POST | `/workday/start` | Начать рабочий день |
| POST | `/workday/end` | Завершить рабочий день |

### Организации

| Метод | Endpoint | Описание |
|-------|----------|----------|
| GET | `/organizations/search` | Поиск организаций |
| GET | `/organizations/{id}` | Детали организации |
| GET | `/organizations/favorites` | Избранные |
| POST | `/organizations/favorites/{id}` | Добавить в избранное |
| DELETE | `/organizations/favorites/{id}` | Убрать из избранного |

### Врачи

| Метод | Endpoint | Описание |
|-------|----------|----------|
| GET | `/doctors/by-organization/{id}` | Врачи организации |
| GET | `/doctors/specializations` | Специализации |
| GET | `/doctors/{id}` | Детали врача |
| POST | `/doctors` | Создать врача |

### Препараты

| Метод | Endpoint | Описание |
|-------|----------|----------|
| GET | `/dict/drugs/bindings` | Препараты компании (bindings) |
| GET | `/stock/price-list` | Прайс-лист |
| GET | `/documents/by-drug/{id}` | Материалы препарата |
| GET | `/files/download/{file_uid}` | Скачать файл |

### Наценки и контракты

| Метод | Endpoint | Описание |
|-------|----------|----------|
| GET | `/markups/short` | Наценки (краткий список) |
| GET | `/contracts/client/{inn}` | Контракты клиента |
| POST | `/pricing/calculate` | Расчёт цены |

### Визиты

| Метод | Endpoint | Описание |
|-------|----------|----------|
| POST | `/visits/add` | Создать визит |
| GET | `/visits/{id}` | Детали визита |
| GET | `/visits/history` | История визитов |

### Корзина

| Метод | Endpoint | Описание |
|-------|----------|----------|
| POST | `/cart` | Сохранить корзину |

---

## Stores Reference

### auth.js

```javascript
// Авторизация и права
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()

authStore.token           // JWT токен
authStore.user            // Данные пользователя
authStore.grants          // Права доступа
authStore.hasGrant(grant) // Проверка права
```

### workday.js

```javascript
// Рабочий день
import { useWorkdayStore } from '@/stores/workday'

const workdayStore = useWorkdayStore()

workdayStore.status       // 'not_started' | 'started' | 'ended'
workdayStore.dayTypes     // Типы рабочих дней
workdayStore.fetchStatus()
workdayStore.startWorkday(daytypeId, lat, lng)
workdayStore.endWorkday(lat, lng)
```

### organizations.js

```javascript
// Организации
import { useOrganizationsStore } from '@/stores/organizations'

const orgStore = useOrganizationsStore()

orgStore.searchResults    // Результаты поиска
orgStore.organization     // Текущая организация
orgStore.favorites        // Избранные
orgStore.searchOrganizations(query, typeId)
orgStore.fetchOrganization(id)
orgStore.toggleFavorite(id, isFavorite)
```

### doctors.js

```javascript
// Врачи
import { useDoctorsStore } from '@/stores/doctors'

const doctorsStore = useDoctorsStore()

doctorsStore.doctors        // Врачи организации
doctorsStore.specializations // Специализации
doctorsStore.fetchDoctorsByOrganization(orgId)
doctorsStore.fetchSpecializations()
doctorsStore.createDoctor(data)
doctorsStore.getDoctorById(id)
```

### drugs.js

```javascript
// Препараты
import { useDrugsStore } from '@/stores/drugs'

const drugsStore = useDrugsStore()

drugsStore.companyDrugs   // Препараты компании (bindings)
drugsStore.priceList      // Прайс-лист
drugsStore.loadCompanyDrugs()
drugsStore.loadPriceList()
drugsStore.calculatePrices(params)
```

### markups.js

```javascript
// Наценки и контракты
import { useMarkupsStore } from '@/stores/markups'

const markupsStore = useMarkupsStore()

markupsStore.markups      // Наценки
markupsStore.contracts    // Контракты
markupsStore.fetchMarkups()
markupsStore.fetchContracts(inn)
```

### visits.js

```javascript
// Визиты
import { useVisitsStore } from '@/stores/visits'

const visitsStore = useVisitsStore()

visitsStore.visits        // История визитов
visitsStore.createVisit(data)
visitsStore.fetchHistory()
```

---

## Диаграмма общего flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              ОБЩИЙ WORKFLOW                                 │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────┐
                              │   ЛОГИН     │
                              │  /login     │
                              └──────┬──────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │  ГЛАВНАЯ    │
                              │    /        │
                              └──────┬──────┘
                                     │
                           ┌─────────┴─────────┐
                           │ Рабочий день      │
                           │ начат?            │
                           └─────────┬─────────┘
                                     │
                    НЕТ ◄────────────┼────────────► ДА
                     │               │               │
                     ▼               │               │
              ┌─────────────┐        │               │
              │ НАЧАТЬ ДЕНЬ │        │               │
              │ (модалка)   │        │               │
              └──────┬──────┘        │               │
                     │               │               │
                     └───────────────┼───────────────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │   ПОИСК     │
                              │  /search    │
                              └──────┬──────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                │
                    ▼                ▼                ▼
             ┌──────────┐     ┌──────────┐     ┌──────────┐
             │ Аптека   │     │   ЛПУ    │     │Избранные │
             │ type=1   │     │  type=2  │     │          │
             └────┬─────┘     └────┬─────┘     └──────────┘
                  │                │
                  ▼                ▼
           ┌──────────┐     ┌──────────┐
           │ ОРГАНИЗ. │     │ ОРГАНИЗ. │
           │/org/{id} │     │/org/{id} │
           └────┬─────┘     └────┬─────┘
                │                │
                ▼                ▼
        ┌───────────────┐  ┌───────────────┐
        │ ТИП ВИЗИТА    │  │ВЫБОР ВРАЧЕЙ   │
        │ /visit-type   │  │/choose-doctor │
        └───────┬───────┘  └───────┬───────┘
                │                  │
       ┌────────┼────────┐         │
       │        │        │         │
       ▼        ▼        ▼         ▼
   ┌──────┐┌──────┐┌──────┐  ┌───────────┐
   │БРОНЬ ││ОСТАТ.││Ф.КР. │  │СТАТУС ПРЕП│
   │/cart ││/inv. ││/pres.│  │/status-dr │
   └──┬───┘└──┬───┘└──┬───┘  └─────┬─────┘
      │       │       │            │
      └───────┴───────┴────────────┘
                      │
                      ▼
               ┌─────────────┐
               │ POST /visits│
               │    /add     │
               └──────┬──────┘
                      │
                      ▼
               ┌─────────────┐
               │  SUCCESS!   │
               │  (модалка)  │
               └─────────────┘
```

---

## Заметки и best practices

### 1. Геолокация

Всегда запрашивать геолокацию перед созданием визита:

```javascript
const getCurrentPosition = () => {
  return new Promise((resolve) => {
    if (!navigator.geolocation) {
      resolve({ latitude: 0, longitude: 0 })
      return
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => resolve({
        latitude: pos.coords.latitude,
        longitude: pos.coords.longitude
      }),
      () => resolve({ latitude: 0, longitude: 0 }),
      { timeout: 5000 }
    )
  })
}
```

### 2. Формат даты для API

```javascript
const formatDateTimeForApi = (date) => {
  const d = new Date(date)
  const year = d.getFullYear()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  const hours = String(d.getHours()).padStart(2, '0')
  const minutes = String(d.getMinutes()).padStart(2, '0')
  const seconds = String(d.getSeconds()).padStart(2, '0')
  return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}`
}
```

### 3. Кэширование файлов

Используй `useFileCache` composable для кэширования PDF/видео/изображений:

```javascript
import { useFileCache } from '@/composables/useFileCache'

const { getCachedFile, cacheFile } = useFileCache()

// Проверить кэш
const cached = await getCachedFile(fileUid)
if (cached) {
  return URL.createObjectURL(cached.blob)
}

// Скачать и закэшировать
const response = await axios.get(url, { responseType: 'blob' })
await cacheFile(fileUid, response.data, fileName, mimeType)
```

### 4. Очистка blob URL

Всегда очищать blob URL при размонтировании:

```javascript
onUnmounted(() => {
  if (currentFileUrl.value) {
    URL.revokeObjectURL(currentFileUrl.value)
  }
})
```

---

> Документация создана: 2026-04-14
> Автор: Claude Code (автоматическая генерация)
