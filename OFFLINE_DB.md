# Offline Mode, Local Database, and Sync

Документ описывает актуальную offline-first архитектуру LIMA и локальную SQLite-базу, которую использует Flutter-приложение.

LIMA должна сохранять основные рабочие сценарии медицинского представителя при нестабильной сети: экраны читают данные из локального хранилища, действия пользователя сразу пишутся в SQLite, а синхронизация согласует локальную базу с API при появлении интернета.

Endpoint’ы и подробный workflow API-синхронизации вынесены в `ARCHITECTURE_SYNC.md`.

## Текущая реализация

```text
REST API
  |
  v
RemoteApiService
  |
  v
SQLite lima.db
  |
  v
Riverpod providers and screens

Local writes -> SQLite first -> push unsynced rows to API -> mark as synced
```

Экраны работают со snapshot локальной БД через feature repositories и typed
view models. Pull не является условием отображения: уже сохранённые записи
показываются сразу, а `SyncDataChange` обновляет только затронутый экран.
Сетевой pull может добавлять пачки в фоне; он не должен очищать справочники при
обычном delta/bootstrap запуске.

Ключевые файлы:

- `lib/core/db/local_database.dart` — схема, миграции, seed/upsert helpers, локальные запросы.
- `lib/core/network/api_client.dart` — Dio client, токен, API base URL.
- `lib/core/network/remote_api_service.dart` — API-методы и fallback paths.
- `lib/core/providers/sync_provider.dart` — pull, push, delta sync, foreground reconciliation.
- `lib/core/providers/app_collections_provider.dart` — локальные коллекции для экранов.
- `lib/features/offline/screens/sync_screen.dart` — ручной sync и диагностика.

Текущая версия схемы `lima.db` — 10.

## Обзор базы данных

Основные таблицы:

- `organisations` — ЛПУ и аптеки.
- `doctors` — врачи.
- `drugs` — справочник препаратов.
- `drug_materials` — презентации, документы, изображения и другие материалы препаратов.
- `visits` — offline-first визиты и диагностика push-синхронизации.
- `sync_meta` — sync timestamps, cursors и служебные metadata.
- `planned_visits` — запланированные визиты с сервера.
- `day_types` — справочник типов рабочего дня.
- `managers` — кеш/справочник менеджеров.
- `cached_stats` — кеш статистики/dashboard.
- `pending_doctors` — врачи, созданные локально и ожидающие отправки на API.
- `pending_org_updates` — локальные изменения организаций, ожидающие отправки на API.

## Связи

```text
organisations ──< doctor_organisations >── doctors
drugs         ──< drug_materials     drugs.id = drug_materials.drug_id
organisations ──< visits             organisations.id = visits.org_id
doctors       ──< visits             doctors.id = visits.doctor_id, nullable
organisations ──< planned_visits     organisations.id = planned_visits.org_id
```

Связи представлены колонками и используются в запросах приложения. Схема сейчас не везде включает SQLite `FOREIGN KEY` constraints.

## Схема таблиц

### `organisations`

Хранит ЛПУ и аптеки.

| Поле | Тип | Описание |
| --- | --- | --- |
| `id` | INTEGER PK | Серверный/локальный идентификатор. |
| `name` | TEXT | Название ЛПУ или аптеки. |
| `address` | TEXT | Адрес. |
| `type` | TEXT | Обычно `lpu` или `pharmacy`. |
| `city` | TEXT | Регион/город для отображения и fallback-фильтра. |
| `region_id` | INTEGER | API id региона для фильтрации справочника по региону МП. |
| `district` | TEXT | Район. |
| `area_id` | INTEGER | API id района. |
| `inn` | TEXT | ИНН. |
| `category` | TEXT | Категория/бизнес-маркер. |
| `responsible` | TEXT | Ответственный. |
| `phone` | TEXT | Телефон. |
| `latitude` | REAL | Координата для карты. |
| `longitude` | REAL | Координата для карты. |
| `distance_m` | REAL | Кеш расстояния для карты/nearby-экранов. |
| `is_favorite` | INTEGER | 0/1, признак избранного. |
| `updated_at` | TEXT | Время обновления на сервере. |
| `sync_id` | INTEGER | Cursor/id для delta sync. |
| `raw_json` | TEXT | Исходный API payload для диагностики и будущего mapping. |

### `doctors`

Хранит врачей, связанных с организациями.

| Поле | Тип | Описание |
| --- | --- | --- |
| `id` | INTEGER PK | Серверный/локальный идентификатор. |
| `full_name` | TEXT | ФИО врача. |
| `specialty` | TEXT | Специальность. |
| `organisation_id` | INTEGER | Legacy/локальная ссылка на `organisations.id`; API-связи хранятся в `doctor_organisations`. |
| `is_favorite` | INTEGER | 0/1, признак избранного. |
| `category` | TEXT | A/B/C или категория из API. |
| `last_visit_label` | TEXT | Display label последнего визита. |
| `updated_at` | TEXT | Время обновления на сервере. |
| `sync_id` | INTEGER | Cursor/id для delta sync. |
| `raw_json` | TEXT | Исходный API payload. |

### `doctor_organisations`

Хранит many-to-many связь врачей с организациями из API `/Doctors/relations/sync`.

| Поле | Тип | Описание |
| --- | --- | --- |
| `doctor_id` | INTEGER | id врача. |
| `organisation_id` | INTEGER | id организации/ЛПУ. |
| `sync_id` | INTEGER | Cursor/id связи для delta sync. |
| `raw_json` | TEXT | Исходный API payload связи. |

### `drugs`

Хранит справочник препаратов для базы знаний и detailing-сценариев.

| Поле | Тип | Описание |
| --- | --- | --- |
| `id` | INTEGER PK | Серверный/локальный идентификатор. |
| `name` | TEXT | Название препарата. |
| `manufacturer` | TEXT | Производитель. |
| `price` | REAL | Кеш цены. |
| `serial_number` | TEXT | Серия/номер партии, если есть. |
| `expiry_date` | TEXT | Срок годности, если есть. |
| `stock` | INTEGER | Остаток, если приходит с API. |
| `current_stock_id` | INTEGER | API id текущего остатка. |
| `binding_drug_id` | INTEGER | API binding id для документов/материалов. |
| `documents_count` | INTEGER | Количество связанных документов/материалов. |
| `updated_at` | TEXT | Время обновления на сервере. |
| `sync_id` | INTEGER | Cursor/id для delta sync. |
| `raw_json` | TEXT | Исходный API payload. |

### `drug_materials`

Хранит metadata презентаций, документов, изображений упаковок и кешированных файлов.

| Поле | Тип | Описание |
| --- | --- | --- |
| `id` | INTEGER PK AUTOINCREMENT | Локальный id строки. |
| `drug_id` | INTEGER | Ссылка на `drugs.id`. |
| `title` | TEXT | Название материала. |
| `description` | TEXT | Описание. |
| `file_type` | TEXT | Например `pdf`, `image`, `video` или тип из API. |
| `local_path` | TEXT | Локальный/относительный путь или source path. |
| `cached_path` | TEXT | Путь к скачанной локальной копии. |
| `uploaded_at` | TEXT | Время загрузки на сервер, если приходит. |
| `is_mandatory` | INTEGER | 0/1, обязательный материал для detailing. |
| `raw_json` | TEXT | Исходный API payload. |

Материалы приходят из API и могут кешироваться локально через `MaterialCacheService`. В проекте также есть bundled documents в `assets/docs/`.

### `visits`

Основная offline-first таблица для локальных и серверных визитов.

| Поле | Тип | Описание |
| --- | --- | --- |
| `id` | INTEGER PK AUTOINCREMENT | Локальный id. |
| `remote_id` | INTEGER | Серверный id визита. `NULL` означает локальную/offline запись. |
| `org_id` | INTEGER | Ссылка на `organisations.id`. |
| `org_name` | TEXT NOT NULL | Дублируется для отображения без JOIN. |
| `doctor_id` | INTEGER | Ссылка на `doctors.id`, nullable для аптечных сценариев. |
| `doctor_name` | TEXT | Дублируется для отображения. |
| `visit_type` | TEXT | Например `lpu`, `order`, `stock`, `circle`. |
| `status` | TEXT | Например `planned`, `completed`. |
| `notes` | TEXT | Комментарий/заметки по визиту. |
| `created_at` | TEXT NOT NULL | Время локального создания. |
| `updated_at` | TEXT NOT NULL | Время последнего локального/серверного обновления. |
| `is_synced` | INTEGER | 0 = нужно отправить, 1 = синхронизировано. |
| `raw_json` | TEXT | Исходный API payload. |
| `last_push_request_json` | TEXT | Последний payload, отправленный на API. |
| `last_push_response_json` | TEXT | Последний ответ API. |

Правила синхронизации визитов:

- Локальный/offline визит создается с `remote_id = NULL` и `is_synced = 0`.
- Успешный push сохраняет/обновляет `remote_id` и помечает запись `is_synced = 1`.
- Любое локальное изменение payload должно снова выставлять `is_synced = 0`.
- Ошибки push фиксируются по отдельным строкам, чтобы один неуспешный визит не блокировал весь batch.

### `sync_meta`

Хранит sync metadata и cursors.

| Поле | Тип | Описание |
| --- | --- | --- |
| `key` | TEXT PK | Ключ metadata. |
| `value` | TEXT | Значение. |

Частые ключи:

- `last_pull_at`
- `last_push_at`
- `last_sync_id`
- `doctor_directory_sync_id`
- `doctor_directory_expected_total`
- `full_pull_bootstrap_v3_done`
- `doctor_directory_sync_id`
- `doctor_directory_expected_total`
- `owner_user_id`
- `owner_login`
- `owner_role`

### `planned_visits`

Хранит запланированные визиты/расписание, полученные с сервера.

| Поле | Тип | Описание |
| --- | --- | --- |
| `id` | INTEGER PK AUTOINCREMENT | Локальный id. |
| `remote_id` | INTEGER UNIQUE | Серверный id плана/визита. |
| `org_id` | INTEGER | id организации. |
| `org_name` | TEXT NOT NULL | Название организации. |
| `org_type` | TEXT | `lpu`, `pharmacy` или тип из API. |
| `doctor_id` | INTEGER | id врача, nullable. |
| `doctor_name` | TEXT | ФИО врача. |
| `assigned_by` | TEXT | Кто назначил визит. |
| `city` | TEXT | Город. |
| `visit_date` | TEXT NOT NULL | Дата планового визита. |
| `status` | TEXT | Статус плана/визита. |
| `comment` | TEXT | Комментарий. |
| `raw_json` | TEXT | Исходный API payload. |

### `day_types`

| Поле | Тип | Описание |
| --- | --- | --- |
| `id` | INTEGER PK | Серверный id. |
| `name` | TEXT | Название типа дня. |
| `raw_json` | TEXT | Исходный API payload. |

### `managers`

| Поле | Тип | Описание |
| --- | --- | --- |
| `id` | INTEGER PK AUTOINCREMENT | Локальный id. |
| `full_name` | TEXT UNIQUE | ФИО менеджера. |
| `role` | TEXT | Роль. |
| `initials` | TEXT | Инициалы для отображения. |
| `raw_json` | TEXT | Исходный API payload. |

### `cached_stats`

| Поле | Тип | Описание |
| --- | --- | --- |
| `key` | TEXT PK | Ключ статистики. |
| `value` | TEXT | JSON/string значение. |
| `updated_at` | TEXT | Время обновления кеша. |

### `pending_doctors`

Хранит врачей, созданных локально до успешной отправки на API.

| Поле | Тип | Описание |
| --- | --- | --- |
| `id` | INTEGER PK AUTOINCREMENT | Локальный id строки. |
| `temp_local_id` | INTEGER NOT NULL | Временный локальный id врача для UI. |
| `org_id` | INTEGER NOT NULL | id организации. |
| `full_name` | TEXT NOT NULL | ФИО врача. |
| `specialty` | TEXT NOT NULL | Специальность. |
| `phone` | TEXT | Телефон. |
| `created_at` | TEXT NOT NULL | Время локального создания. |

### `pending_org_updates`

Хранит локальные изменения организаций до успешной отправки на API.

| Поле | Тип | Описание |
| --- | --- | --- |
| `id` | INTEGER PK AUTOINCREMENT | Локальный id строки. |
| `org_id` | INTEGER NOT NULL UNIQUE | id организации. |
| `name` | TEXT NOT NULL | Обновленное название. |
| `address` | TEXT NOT NULL | Обновленный адрес. |
| `phone` | TEXT | Телефон. |
| `city` | TEXT | Город. |
| `district` | TEXT | Район. |
| `inn` | TEXT | ИНН. |
| `category` | TEXT | Категория. |
| `responsible` | TEXT | Ответственный. |
| `latitude` | REAL | Координата. |
| `longitude` | REAL | Координата. |
| `created_at` | TEXT NOT NULL | Время локального создания. |

## Синхронизация

### Pull: API -> SQLite

Реализация: `SyncNotifier.pullFromRemote()`.

Обычный pull сначала пробует delta sync:

- `getOrganizationsSync(syncId: last_sync_id)`
- `getDoctorsSync(syncId: doctor_directory_sync_id)` через `/dict/doctors/sync?batch_size=1000`
- `getDrugsSync(syncId: last_sync_id)`

Если delta sync недоступен или завершился ошибкой, приложение откатывается на full seed:

- организации;
- врачи: initial/delta загрузка идет пачками по `sync_id` и сохраняет `doctor_directory_sync_id`; fallback `/api/dict/Doctors` используется только если batch sync недоступен;
- препараты;
- материалы препаратов;
- история визитов;
- запланированные визиты;
- избранное;
- менеджеры;
- типы дней;
- дневная статистика.

После успешного pull приложение обновляет `sync_meta.last_pull_at`, локальные totals и debug-состояние.

### Push: SQLite -> API

Реализация: `SyncNotifier.pushToRemote()`.

Алгоритм push:

1. Прочитать `visits where is_synced = 0`.
2. Отправить каждый визит в API независимо.
3. Успешные строки пометить `is_synced = 1`.
4. Неуспешные строки оставить unsynced и сохранить диагностические request/response данные.
5. Обновить `sync_meta.last_push_at`.

### Reconciliation

Реализация: `SyncNotifier.reconcileInBackground()`.

Reconciliation запускается, когда:

- пользователь стал authenticated;
- приложение увидело переход offline -> online;
- пользователь запускает sync вручную на экране синхронизации.

Сейчас это foreground/cross-platform механизм внутри запущенного приложения. Нативная периодическая фоновая синхронизация через Android WorkManager / iOS BGTaskScheduler пока не подключена как production background job.

## Конфликты

Текущая практическая стратегия:

- Серверные справочники считаются источником истины.
- Локальные unsynced визиты сохраняются при full refresh.
- Ошибки push остаются видимыми в диагностике и не приводят к тихой потере данных.
- Избранное может обновляться optimistic локально, а затем подтверждаться/откатываться по результату API в зависимости от feature area.

Если понадобится более сложный merge, стоит добавить явные revision/version поля и описать политику разрешения конфликтов здесь.

## Файлы и материалы

Материалы препаратов могут приходить из:

- bundled assets в `assets/docs/`;
- remote document endpoint’ов, например documents-by-drug;
- локального кеша через `MaterialCacheService`.

В `drug_materials` есть два пути:

- `local_path` — путь/source, известный из seed/API/bundled данных;
- `cached_path` — путь к скачанной локальной копии, если файл кеширован.

Для production крупные скачанные файлы лучше хранить в app-controlled директории через `path_provider`, например в application documents/support directory.

## Пакеты для offline mode

Уже подключены:

- `sqflite` — SQLite database.
- `path` — построение путей к БД.
- `dio` — API и downloads.
- `connectivity_plus` — состояние сети.
- `path_provider` — app storage paths.
- `open_filex` — открытие локальных файлов.
- `shared_preferences` — легкие metadata/preferences.
- `flutter_secure_storage` — чувствительные auth-данные.

Возможные production-добавления:

- `workmanager` — периодический background sync на Android.
- iOS BGTaskScheduler integration — native background refresh.
- `sqflite_sqlcipher` — шифрование БД, если локальные данные требуют encryption.
- PDF viewer package, если просмотр PDF должен быть внутри приложения вместо external/open-file поведения.

## Источники данных экранов

| Экран/область | Текущий источник |
| --- | --- |
| Поиск и выбор ЛПУ/аптек | SQLite `organisations` через providers |
| Выбор врача | SQLite `doctors` |
| База знаний | SQLite `drugs` |
| Детали препарата/материалы | SQLite `drugs` + `drug_materials` + cached files |
| История визитов | API pull + SQLite `visits`/history mapping |
| План визитов | API pull + SQLite `planned_visits` |
| Экран синхронизации | SQLite `visits`, `pending_doctors`, `pending_org_updates`, `sync_meta`, API diagnostics |
| Избранное | API как source of truth + локальный cache/optimistic updates в зависимости от области |
| Home/dashboard stats | API/cached stats/auth providers |

## Maintenance Notes

Если меняется API-контракт или offline model, обновляй вместе:

1. `lib/core/network/remote_api_service.dart`
2. `lib/core/providers/sync_provider.dart`
3. `lib/core/db/local_database.dart`
4. `ARCHITECTURE_SYNC.md`
5. `OFFLINE_DB.md`

Если добавляется новая offline write queue, лучше заводить явную `pending_*` таблицу или понятное поле `is_synced` с диагностикой, а затем показывать это на sync screen.
