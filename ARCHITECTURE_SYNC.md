# Architecture Sync Guide

Документ описывает текущее состояние интеграции: какие данные хранятся локально, какие методы используются из API, и как работает синхронизация (pull/push).

## 1) Где что лежит

- Локальная БД: `lima.db` (SQLite)
- Основные файлы реализации:
  - `lib/core/db/local_database.dart`
  - `lib/core/network/remote_api_service.dart`
  - `lib/core/providers/sync_provider.dart`
  - `lib/core/services/doctor_directory_sync_service.dart`
  - `lib/core/services/delta_pull_service.dart`
  - `lib/core/services/organization_directory_pull_service.dart`
  - `lib/core/services/full_seed_sync_service.dart`
  - `lib/core/services/live_data_refresh_service.dart`
  - `lib/core/services/sync_diagnostics_service.dart`
  - `lib/core/services/background_reconcile_service.dart`
  - `lib/core/providers/app_collections_provider.dart`
  - `lib/features/offline/screens/sync_screen.dart`
- Подробный workflow агентской веб-версии:
  - `WORKFLOW_AGENT.md`

## 2) Локальная модель данных (SQLite)

Таблицы:
- `organisations` — ЛПУ/аптеки
- `doctors` — врачи
- `drugs` — препараты
- `drug_materials` — материалы препаратов
- `visits` — визиты (офлайн-first)
- `sync_meta` — метаданные синка (`last_pull_at`, `last_push_at`, bootstrap key)

Ключевые поля для sync:
- `visits.remote_id` — ID на сервере
- `visits.is_synced` — 0/1
- `*_updated_at` — используется для дельты (если endpoint поддерживает)

Repair справочника врачей, cursor, связи врач–ЛПУ и проверка полноты вынесены в
`DoctorDirectorySyncService`. `SyncNotifier` передает сервису только callback
прогресса и сохраняет orchestration порядка `push -> pull`.

Очередь запланированных визитов вынесена в `PendingPlanSyncService`: сервис
собирает payload, вызывает `/api/visits/plans`, сохраняет `remote_id` и
различает удаление 4xx-записей и повтор сетевых/5xx ошибок. `SyncNotifier`
только запускает этот сервис из push-before-pull и reconcile flow.

Очереди избранного, feedback, новых врачей и организаций вынесены в
`PendingMutationSyncService`. Он возвращает типизированные ошибки очереди, а
notifier объединяет их с результатом отправки визитов в один отчёт.

Отправка локальных визитов и их retry/backoff/parking вынесены в
`PendingVisitPushService`. Сервис сохраняет request/response диагностику и
возвращает IDs отправленных и припаркованных визитов без зависимости от UI.

`DeltaPullService` выбирает максимальный cursor из `sync_meta` и локальных
таблиц, получает организации, врачей, связи и препараты по `sync_id`, делает
upsert в SQLite и только после этого сохраняет новый cursor.

`OrganizationDirectoryPullService` обслуживает layered pull: выбирает полный
справочник или delta организаций по решению notifier и сохраняет результат в
SQLite до публикации итогового состояния.

`FullSeedSyncService` владеет полным seed: получает `RemoteSeedBundle`, не
принимает пустой справочник за успешную загрузку и передаёт снимок в
`replaceRemoteSnapshotPreservingUnsynced()`. Поэтому локальная очередь офлайн-
изменений не теряется при full refresh.

`LiveDataRefreshService` обновляет изменяемые данные после seed: историю визитов,
планы, избранное, материалы, статистику и небольшие справочники. Каждый слой
best-effort и записывается локально независимо от остальных.

`SyncDiagnosticsService` предоставляет typed локальные итоги, число связей
врач–ЛПУ и проверку готовности базового каталога. `SyncNotifier` больше не
содержит SQL для этих проверок. `BackgroundReconcileService` отдельно выполняет
проверку реального соединения и silent reauth перед launch/background delta.

## 3) API методы, используемые приложением

### Auth / профиль
- `POST /api/Account/authorize`
- `GET /api/Users/me`

### Справочники / seed
- `GET /api/dict/Organizations` (`region_id` передаётся для МП с привязкой к региону)
- `GET /dict/doctors/sync?sync_id={cursor}&batch_size=1000` — основной sync справочника врачей пачками по `sync_id`
- `GET /api/dict/Doctors` — fallback справочника врачей, пагинируется сервером (`page_size=30`)
- `GET /api/dict/Drugs`
- `GET /api/Documents/by-drug/{id}`

### Визиты
- `GET /api/Visits/history`
- `POST /api/Visits/add` (fallback: `/Visits/add`, `/visits/add`)
- `GET /api/Company/markups` — подбор `margin_id` для выбранной предоплаты/типа покупателя
- `PUT /api/Visits/{visitId}` (fallback `/Visits/{visitId}`)
- `POST /Visits/rating` (fallback `/api/Visits/rating`)
- `GET /api/Visits/plans/current`
- `GET /visits/plans` (fallback `/api/Visits/plans`)
- `GET /api/Visits/plans/month`
- `GET /api/Visits/plans/{visitId}/details` (fallback `/Visits/...`)
- `GET /api/Visits/history/orders` (fallback `/Visits/...`)
- `GET /api/Visits/history/remnant` (fallback `/Visits/...`)
- `GET /api/Visits/count` (fallback `/visits/count`)
- `GET /Visits/organization/{orgId}/visited-doctors` (fallback `/api/...`)

### Workday
- `GET /api/workday/status`
- `GET /api/daytype`
- `POST /api/workday/start`
- `POST /api/workday/end`

### Личный план продаж
- `GET /api/planning/my-plan?year={YYYY}` — годовой план/факт и
  помесячная детализация препаратов для текущего пользователя. Ответ может
  прийти как `text/plain`, поэтому строковое тело дополнительно декодируется
  как JSON. Последний успешный ответ хранится локально по пользователю и году,
  чтобы таскбар и экран «Мой план» были доступны без сети.

### Favorites / doctors / organizations
- Doctors favorites:
  - `POST /Doctors/favorites/add` (fallback `/api/...`)
  - `DELETE /Doctors/{id}/favorites/remove` (fallback `/api/...`)
  - `GET /Doctors/favorites` (fallback `/api/...`)
- Doctors extra:
  - `POST /Doctors/add` (fallback `/api/...`)
  - `POST /Doctors/visited` (fallback `/api/...`)
- Organizations favorites:
  - `GET /organizations/favorites` (+ case/prefix fallbacks)
  - `POST /organizations/favorites/{id}` (+ fallbacks)
  - `DELETE /organizations/favorites/{id}` (+ fallbacks)

### Delta sync endpoints
- `GET /dict/doctors/sync` (`batch_size=1000`, cursor `sync_id`; fallback `/dict/Doctors/sync`, `/Doctors/sync`, `/api/Doctors/sync`)
- `GET /Doctors/relations/sync` (fallback `/api/dict/Doctors/relations/sync`) — связь врачей с организациями
- `GET /Organizations/sync` (fallback `/api/Organizations/sync`, `region_id` передаётся для МП с привязкой к региону)
- `GET /Drugs/sync` (fallback `/api/Drugs/sync`)

## 4) Как работает синхронизация

### 4.1 Pull (данные с сервера -> локальная БД)
Оркестрация: `SyncNotifier.pullFromRemote()`; операции seed/live/directory
делегируются соответствующим sync services.

Перед любой ручной загрузкой приложение сначала пытается отправить локальную очередь `is_synced = 0`. Если очередь не отправилась, загрузка справочников откладывается, чтобы не маскировать ошибку локальных записей долгим pull.

1. Если `fullRefresh == false`:
- пытаемся дельту (`/Organizations/sync`, `/Doctors/sync`, `/Drugs/sync`)
- для организаций передаём `region_id` текущего МП; связи `/Doctors/relations/sync` фильтруются по организациям региона, затем врачи фильтруются по этим связям
- если успешно: `upsert` в SQLite
- затем sync избранных врачей из API

2. Если дельта не поддерживается/упала:
- выполняется full seed:
  - справочники + материалы + история визитов
  - организации запрашиваются с `region_id` текущего МП; связи врач-организация берутся из `/Doctors/relations/sync`, справочник врачей читается постранично, затем врачи фильтруются по связям организаций этого региона
  - серверный срез в локальной БД заменяется свежим с сохранением локальных `is_synced = 0` визитов
  - легкий sync с `includeDoctors=false` не очищает локальные `doctors` и `doctor_organisations`
  - `sync_meta.last_sync_id` выставляется в максимум `sync_id` из свежих организаций/врачей/связей/препаратов, чтобы следующая дельта не начиналась с нуля

3. Если `fullRefresh == true`:
- `replaceRemoteSnapshotPreservingUnsynced()`:
  - очищает серверный срез локально
  - пересеивает свежими данными
  - сохраняет локальные `is_synced=0` визиты

4. Записывается `sync_meta.last_pull_at`.

### 4.1.1 Локальный источник для экранов

После записи результата pull экран не ждёт завершения всей синхронизации:
списки организаций, врачей, препаратов, материалов и визитов читаются из
SQLite через feature repository. Фоновая синхронизация публикует typed
`SyncDataChange`, после чего соответствующий view model перечитывает только
свой локальный набор. Повторный вход на экран не должен делать сетевой запрос
для обычного каталога.

Для doctor-directory используется cursor `doctor_directory_sync_id` и
`/dict/doctors/sync?batch_size=1000`; очередная пачка добавляется в SQLite, а не
заменяет уже загруженных врачей. При обрыве процесса следующий запуск
продолжает pull с сохранённого cursor.

### 4.2 Push (локальные изменения -> сервер)
Оркестрация: `SyncNotifier.pushToRemote()`; отправка очередей делегируется
pending-* services.

- Берутся `visits where is_synced = 0`
- Каждый визит отправляется отдельно через `pushUnsyncedVisit()`: ЛПУ, бронь аптеки, остатки и фармкружки идут в `Visits/add`.
- Для брони аптеки мобильное приложение повторяет web-контракт: условия заказа кодируются через `margin_id`, `payment_variant_id`, `is_wholesaler` и рассчитанный `sale_price`, без отдельного `prepayment_percent` в payload.
- Для снятия остатков используется Swagger-контракт `VisitRequest`: `visit_type = 4`, позиции передаются в `drugs` как `DrugRequest[]`; локальное поле `stock_items` хранится только для отображения истории.
- Успешные помечаются `is_synced=1`
- Ошибки по отдельным визитам не валят весь пакет
- Статус содержит: сколько отправлено, сколько ошибок, первая ошибка
- Записывается `sync_meta.last_push_at`

### 4.3 Автосинк
Реализация: `lib/shell/main_shell.dart`

- При переходе offline -> online запускается:
  - `pushToRemote()`
  - затем `pullFromRemote()`

## 5) Избранное: источник истины

### Врачи
- Источник истины: API
- Pull в локалку выполняется:
  - при открытии `FavDoctorsScreen`
  - при `pullFromRemote()` (фоновый refresh favorites doctors)
- Toggle из выбора врача пушится в API, локалка обновляется сразу

### Аптеки
- Источник истины: API + локальный кэш в prefs
- При загрузке `AppCollectionsNotifier`:
  - читается prefs
  - затем пробуется API `organizations/favorites`
  - при успехе prefs/state перезаписываются из API
- Toggle favorites аптек:
  - optimistic update локально
  - push в API
  - при ошибке rollback

## 6) Что важно для «как на боевом»

- На разных окружениях часть endpoint’ов может отличаться по:
  - префиксу (`/api` vs без `/api`)
  - регистру пути (`/Doctors` vs `/doctors`)
- В сервисе добавлены fallback-варианты путей.
- Если endpoint возвращает HTML/404 вместо JSON, синк по этому endpoint на стенде считается недоступным и приложение откатывается на локальный кэш/альтернативный путь.

## 7) Диагностика

- Экран sync: `lib/features/offline/screens/sync_screen.dart`
  - `Загрузить с сервера`
  - `Принудительный full refresh`
  - `Отправить на сервер`
- Быстрая проверка локальной БД (пример):
  - `select count(*) from visits where is_synced=0;`
  - `select * from sync_meta;`

## 8) Текущие ограничения

- Не все endpoint’ы гарантированно одинаково доступны на каждом домене/стенде.
- Для части сценариев нужен подтверждённый production-compatible base URL API.

## 9) Архитектурные границы

- `features/*/domain` содержит typed entities, repository contracts и use cases;
  он не зависит от Flutter, Dio, SQLite или Riverpod.
- `features/*/data` владеет DTO/row mapping, JSON и API/SQLite adapters.
- `features/*/presentation` получает typed state через Riverpod view model.
- Для новых экранов запрещены прямые импорты `LocalDatabase`, `ApiClient`,
  `RemoteApiService` и raw JSON mapping; текущий набор мигрированных экранов
  проверяется архитектурным тестом.

---

Если меняется контракт API, обновляй в первую очередь:
1. `remote_api_service.dart` (path + payload)
2. `sync_provider.dart` (стратегия pull/push)
3. этот документ
