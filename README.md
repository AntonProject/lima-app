# LIMA

LIMA — Flutter-приложение для медицинских представителей. Приложение помогает вести ежедневную полевую работу: планировать и проводить визиты, работать с ЛПУ и аптеками, выбирать врачей, показывать материалы по препаратам, фиксировать заказы/остатки и сохранять данные даже при нестабильном интернете.

Проект построен как offline-first приложение: справочники и рабочие данные кешируются в SQLite, действия пользователя сначала сохраняются локально, а затем синхронизируются с API при появлении сети.

## Текущее состояние

Это не шаблонный Flutter-проект, а рабочее приложение LIMA. Сейчас реализовано:

- Авторизация через LIMA API.
- Локальная SQLite-база `lima.db` для организаций, врачей, препаратов, материалов, визитов, планов, менеджеров, статистики и pending-изменений.
- Pull-синхронизация из API в SQLite: полный seed и delta sync.
- Push-синхронизация несинхронизированных локальных визитов.
- Автоматическая reconciliation-синхронизация при логине и восстановлении сети, пока приложение запущено.
- Сценарии визитов в ЛПУ и аптеки.
- База знаний по препаратам, экран препарата и просмотр материалов.
- Профиль, избранное, уведомления, план, история, карта, корзина/черновики и экран диагностики синхронизации.

## Архитектура

Основной стек:

- Flutter + Dart
- Riverpod для состояния
- GoRouter для навигации
- Dio для HTTP API
- SQLite через `sqflite`
- SharedPreferences и secure storage для локального состояния и авторизации
- `connectivity_plus` для отслеживания сети
- `path_provider` и локальные assets для работы с файлами/материалами

Ключевые файлы:

- `lib/main.dart` — bootstrap приложения и SharedPreferences override.
- `lib/app.dart` — корневой `MaterialApp.router`, локализация, listeners авторизации/сети.
- `lib/core/router/app_router.dart` — роутинг и protected navigation.
- `lib/core/network/api_client.dart` — Dio client, токен, нормализация base URL.
- `lib/core/network/remote_api_service.dart` — API-методы и fallback endpoint’ы.
- `lib/core/db/local_database.dart` — SQLite-схема, миграции, локальные read/write операции.
- `lib/core/providers/sync_provider.dart` — pull, push, delta sync, foreground reconciliation.
- `lib/features/offline/screens/sync_screen.dart` — ручная синхронизация и диагностика.

## Offline-First Data Flow

```text
REST API  ->  RemoteApiService  ->  SQLite lima.db  ->  providers/screens
   ^                                      |
   |                                      v
   +-------- push локальных изменений ----+
```

При логине, старте рабочих сценариев и восстановлении сети приложение выполняет reconciliation:

1. Отправляет локальные несинхронизированные изменения.
2. Загружает обновления из API в SQLite.
3. Обновляет sync metadata и диагностическое состояние.
4. Продолжает показывать данные из локальной базы, если API недоступен.

Подробная схема локальной БД и offline-first логика описаны в [OFFLINE_DB.md](OFFLINE_DB.md). Текущий workflow API-синхронизации и список endpoint’ов описаны в [ARCHITECTURE_SYNC.md](ARCHITECTURE_SYNC.md).

## Основные модули

- `features/auth` — login и состояние авторизации.
- `features/home` — главный экран/dashboard.
- `features/plan` — план визитов.
- `features/visits` — ЛПУ/аптеки, визиты, история, карта, order/stock/circle-сценарии.
- `features/knowledge` — база знаний, препараты и материалы.
- `features/offline` — экран синхронизации.
- `features/profile` — профиль и избранное.
- `features/cart` — корзина/черновики.
- `features/notifications` — уведомления.

## Локальная база данных

Приложение открывает `lima.db`, текущая версия схемы — 8. Основные таблицы:

- `organisations`
- `doctors`
- `drugs`
- `drug_materials`
- `visits`
- `sync_meta`
- `planned_visits`
- `day_types`
- `managers`
- `cached_stats`
- `pending_doctors`
- `pending_org_updates`

Полная схема и правила синхронизации описаны в [OFFLINE_DB.md](OFFLINE_DB.md).

## API

Base URL по умолчанию задан в `lib/core/network/api_client.dart`:

```text
https://dev.lima.uz/api
```

`RemoteApiService` содержит fallback-варианты путей для окружений, где endpoint’ы отличаются префиксом `/api` или регистром. При изменении API-контракта обновляй:

1. `lib/core/network/remote_api_service.dart`
2. `lib/core/providers/sync_provider.dart`
3. `ARCHITECTURE_SYNC.md`
4. `OFFLINE_DB.md`, если меняется локальная схема или offline-поведение

## Запуск

Установить зависимости:

```sh
flutter pub get
```

Запустить анализ:

```sh
flutter analyze
```

Запустить тесты:

```sh
flutter test
```

Запустить приложение:

```sh
flutter run
```

## Документация

- [OFFLINE_DB.md](OFFLINE_DB.md) — offline mode, SQLite-схема, local-first запись, кеш файлов.
- [ARCHITECTURE_SYNC.md](ARCHITECTURE_SYNC.md) — текущая API-синхронизация, endpoint’ы, диагностика.
- [WORKFLOW_AGENT.md](WORKFLOW_AGENT.md) — workflow агентской веб-версии, если он нужен в текущей задаче.
