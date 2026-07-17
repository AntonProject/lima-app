# Checklist нового feature-модуля

Использовать при добавлении или миграции feature в LIMA.

## Границы

- `domain/entities` не импортирует Flutter, Riverpod, Dio, SQLite или data-слой.
- `domain/repositories` описывает typed операции, а не SQLite-таблицы и raw API rows.
- `domain/use_cases` содержит бизнес-правила и не знает о виджетах.
- `data` владеет DTO, JSON/SQLite mapping и реализациями repository contracts.
- `presentation` получает repository/use case через feature provider.

## Offline-first

- Чтение экрана идет из локальной базы.
- Запись сначала сохраняется локально и получает pending/sync status.
- Push повторяемый и не создает дубликат при retry.
- Ошибка push отображается typed сообщением и остается в диагностике.
- Delta/full pull не перетирает локальные pending writes.

## UI и тесты

- Loading, data, empty и failure состояния описаны immutable state или `AsyncValue`.
- Screen не строит API payload и не разбирает `raw_json`.
- Есть unit-тесты entity/mapper/use case.
- Есть тест на offline или rejected-server сценарий, если feature пишет данные.
- `flutter analyze` и `flutter test` проходят.

## Code review

- [ ] Нет прямых импортов `LocalDatabase`, `ApiClient`, `RemoteApiService` из UI.
- [ ] Нет новых публичных raw-map методов без migration note.
- [ ] Provider возвращает domain interface, когда он уже существует.
- [ ] Документация обновлена при изменении API, SQLite или sync flow.
