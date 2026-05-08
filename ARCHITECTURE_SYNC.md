# Architecture Sync Guide

Документ описывает текущее состояние интеграции: какие данные хранятся локально, какие методы используются из API, и как работает синхронизация (pull/push).

## 1) Где что лежит

- Локальная БД: `lima.db` (SQLite)
- Основные файлы реализации:
  - `lib/core/db/local_database.dart`
  - `lib/core/network/remote_api_service.dart`
  - `lib/core/providers/sync_provider.dart`
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

## 3) API методы, используемые приложением

### Auth / профиль
- `POST /api/Account/authorize`
- `GET /api/Users/me`

### Справочники / seed
- `GET /api/dict/Organizations` (`region_id` передаётся для МП с привязкой к региону)
- `GET /api/dict/Doctors` — справочник пагинируется сервером (`page_size=30`), поэтому full seed проходит страницы и затем фильтрует врачей по связям организаций региона
- `GET /api/dict/Drugs`
- `GET /api/Documents/by-drug/{id}`

### Визиты
- `GET /api/Visits/history`
- `POST /api/Visits/add` (fallback: `/Visits/add`, `/visits/add`)
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
- `GET /Doctors/sync` (fallback `/api/Doctors/sync`)
- `GET /Doctors/relations/sync` (fallback `/api/dict/Doctors/relations/sync`) — связь врачей с организациями
- `GET /Organizations/sync` (fallback `/api/Organizations/sync`, `region_id` передаётся для МП с привязкой к региону)
- `GET /Drugs/sync` (fallback `/api/Drugs/sync`)

## 4) Как работает синхронизация

### 4.1 Pull (данные с сервера -> локальная БД)
Реализация: `SyncNotifier.pullFromRemote()`

1. Если `fullRefresh == false`:
- пытаемся дельту (`/Organizations/sync`, `/Doctors/sync`, `/Drugs/sync`)
- для организаций передаём `region_id` текущего МП; связи `/Doctors/relations/sync` фильтруются по организациям региона, затем врачи фильтруются по этим связям
- если успешно: `upsert` в SQLite
- затем sync избранных врачей из API

2. Если дельта не поддерживается/упала:
- выполняется full seed:
  - справочники + материалы + история визитов
  - организации запрашиваются с `region_id` текущего МП; связи врач-организация берутся из `/Doctors/relations/sync`, справочник врачей читается постранично, затем врачи фильтруются по связям организаций этого региона
  - запись в локальную БД

3. Если `fullRefresh == true`:
- `replaceRemoteSnapshotPreservingUnsynced()`:
  - очищает серверный срез локально
  - пересеивает свежими данными
  - сохраняет локальные `is_synced=0` визиты

4. Записывается `sync_meta.last_pull_at`.

### 4.2 Push (локальные изменения -> сервер)
Реализация: `SyncNotifier.pushToRemote()`

- Берутся `visits where is_synced = 0`
- Каждый визит отправляется отдельно через `pushUnsyncedVisit()`
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

---

Если меняется контракт API, обновляй в первую очередь:
1. `remote_api_service.dart` (path + payload)
2. `sync_provider.dart` (стратегия pull/push)
3. этот документ
