# Текущий остаток работ: handoff TODO

Дата аудита: 2026-08-20

Назначение: дать следующей модели однозначный порядок работ по брони из ЛПУ,
рабочему дню и оставшимся архитектурным границам. Документ основан на
фактическом коде, а не только на первоначальных ТЗ.

## Обозначения и ограничения

- `[x]` подтверждено кодом или тестом.
- `[~]` работает частично, но не закрывает критерий полностью.
- `[ ]` требуется реализация.
- Не сбрасывать и не очищать локальную БД.
- Миграции SQLite делать только additive и с сохранением существующих данных.
- Не создавать второй pipeline заказов: бронь ЛПУ использует существующий
  pharmacy-order domain/repository/ViewModel.
- Не менять payload `/Visits/add` догадками. `prepayment_percent` не добавлять,
  пока backend-контракт использует выбранный `margin_id`.
- Не считать queued-запись отправленной и не показывать ей статус «Проведено».
- Время рабочего дня не корректировать константой `-5`: текущий workaround
  обязан использовать timezone offset устройства.

## Карта основных файлов

- Условия, цены и API брони:
  `lib/core/network/remote_api_service.dart`,
  `lib/features/visits/data/visits_repository.dart`.
- UI и state брони:
  `lib/features/visits/dialogs/payment_type_dialog.dart`,
  `lib/features/visits/screens/lpu/lpu_detail_screen.dart`,
  `lib/features/visits/screens/pharmacy/pharmacy_type_screen.dart`,
  `lib/features/visits/screens/new_bron_screen.dart`.
- История и локальный статус отправки:
  `lib/features/visits/models/history_records.dart`,
  `lib/features/visits/presentation/view_models/history_view_model.dart`,
  `lib/features/home/`.
- Очередь обычных визитов:
  `lib/core/services/pending_visit_push_service.dart`. Она уже умеет парковать
  permanent failure; менять её только для отображения статуса/диагностики.
- Рабочий день:
  `lib/core/providers/workday_provider.dart`,
  `lib/core/services/pending_workday_sync_service.dart`,
  `lib/core/services/workday_location_service.dart`,
  `lib/features/home/widgets/home_screen_widgets.dart`.
- SQLite и additive migrations:
  `lib/core/db/local_database.dart`.
- Архитектурный контроль:
  `test/architecture/layer_boundaries_test.dart`.

## Рекомендуемый порядок change set'ов

Каждый пункт ниже должен оставлять приложение собираемым и проверяемым. Не
объединять SQLite migration, API-контракт и визуальную декомпозицию в один
огромный diff.

1. **Booking terms:** typed `/Markups/short`, cache, exact mapping и тесты
   parser/repository; UI пока не менять.
2. **Booking UI:** подключить terms и feature flag к аптеке и ЛПУ, убрать
   статические/unsafe defaults, добавить ViewModel-тесты комбинаций.
3. **Contracts:** typed endpoint, выбор договора и сохранение `contract_id` в
   draft/cart/payload с тестом восстановления после restart.
4. **Pending status:** расширить history model/mapper и отрисовку главной,
   истории и синхронизации, не меняя сам payload заказа.
5. **Workday reliability:** независимый partial refresh, затем отдельным
   change set additive migration и parked/backoff queue.
6. **Workday architecture:** перенести infrastructure orchestration в
   `WorkdayRepository`, сохранив публичное поведение notifier.
7. **Architecture coverage:** автоматизировать discovery, затем выполнять
   декомпозицию крупных экранов отдельными небольшими изменениями.

## Подтверждённая база, которую не нужно переделывать

- [x] Видимость брони: только `type_id == 2 && is_budget == false`.
- [x] Прямой вход из ЛПУ в существующий order-flow с контекстом `lpu`.
- [x] `/Pricing/calculate` перед `/Visits/add` и typed результат
  `sent/queued/rejected`.
- [x] Offline draft заказа и обычная очередь визитов.
- [x] `PendingVisitPushService` уже имеет backoff, лимит попыток и парковку
  permanent failure. Не дублировать эту работу.
- [x] Workday start/end/status/day types, per-user cache, optimistic offline
  state и FIFO-очередь присутствуют.
- [x] После завершения рабочего дня карточка выглядит как до старта; повторный
  start получает ошибку API online и локальную ошибку offline.

## P0. Разрешённые условия брони ЛПУ

### Цель

Показывать только комбинации, которые реально разрешены сервером, одинаково
для аптек и коммерческих ЛПУ.

### Текущая проблема

- `RemoteApiService` читает legacy `/Company/markups` и имеет приблизительный
  fallback для 0%.
- `LpuDetailScreen` открывает `showPaymentTypeDialog` без загрузки условий.
- `PaymentTypeDialog` статически рисует `100%`, `0%` и принимает один boolean
  `allowWholesale`.
- При ошибке загрузки аптечный flow может разрешить опт по умолчанию.

### Шаги

- [ ] Добавить typed model, например `OrderTermOption`:
  `marginId`, `prepaymentPercent`, `wholesaler`, `retail`.
- [ ] В data-слое реализовать `GET /api/Markups/short`; parser должен принимать
  прямой массив и, для совместимости, `{result: [...]}`.
- [ ] Добавить метод domain repository для получения разрешённых вариантов.
  Presentation не должна видеть raw JSON.
- [ ] Удалить приблизительный fallback, который подменяет отсутствующую 0%
  матрицу любой наценкой `<100`.
- [ ] Перед открытием условий в `lpu_detail_screen.dart` и
  `pharmacy_type_screen.dart` загрузить варианты через ViewModel/repository.
- [ ] Передать в `payment_type_dialog.dart` список вариантов, а не два
  статических процента и небезопасный boolean.
- [ ] Если запрос недоступен online и нет валидного cache, запретить
  неподтверждённые комбинации и показать понятную ошибку. Не включать опт по
  умолчанию.
- [ ] Кешировать последний успешный справочник условий для offline-flow с
  привязкой к пользователю/компании.

### Приёмка

- UI показывает ровно варианты `/Markups/short`.
- Выбор розница/опт меняет доступные проценты динамически.
- `margin_id` в calculate/add совпадает с выбранной строкой API.
- Недоступная комбинация не проходит в следующий экран.

## P0. Feature flag предоплаты

### Шаги

- [ ] Вынести чтение `behavior.prepayment.percent.enable` в typed global-config
  repository/cache; строковые `"true"/"false"` нормализовать в data-слое.
- [ ] Добавить флаг в immutable state order-flow.
- [ ] При `true` показать выбор разрешённых процентов.
- [ ] При `false` скрыть выбор и использовать единственный server-approved
  default из `/Markups/short`; если он неоднозначен, остановить flow с
  диагностируемой ошибкой вместо догадки.
- [ ] Покрыть `true`, `false`, missing и malformed значения тестами.

## P0. Договоры коммерческого ЛПУ

### Шаги

- [ ] Добавить typed `ClientContract` и repository method для
  `GET /api/Contracts/client/{clientInn}`.
- [ ] Parser обязан поддерживать прямой массив и `{result: [...]}`.
- [ ] Загружать договоры только при непустом ИНН; пустой список является
  валидным состоянием.
- [ ] Добавить выбор договора в `PaymentTypeDialog` или отдельный компактный
  picker по существующему UI-паттерну.
- [ ] Хранить `contractId` в order draft/state/cart и передавать его в
  calculate/add там, где контракт это допускает.
- [ ] Не терять договор после offline-save, восстановления приложения и
  повторной отправки.

### Приёмка

- Direct array и wrapped response парсятся одинаково.
- При отсутствии договоров UI показывает существующий empty state.
- Выбранный `contract_id` сохраняется до фактической отправки.

## P0. Честный статус offline-заказа

### Текущая проблема

Экран завершения различает `sent` и `queued`, но mapper истории игнорирует
`is_synced/sync_failed`, поэтому pending-запись может выглядеть как обычный
запланированный или проведённый визит.

### Шаги

- [ ] Расширить typed history record sync-состоянием: `synced`, `pending`,
  `failedPermanently`.
- [ ] В `history_records_mapper.dart`/`history_records.dart` читать локальные
  `is_synced`, `sync_failed`, `last_error`, не смешивая их с server
  `visit_status`.
- [ ] На главной и в истории показывать «Ожидает отправки» для pending и
  отдельный ошибочный статус с возможностью повторить для parked записи.
- [ ] После успешного push заменить локальный временный идентификатор/состояние
  подтверждёнными server values без дубля карточки.
- [ ] Permanent 4xx не должна выглядеть как success; диагностическая причина
  остаётся доступной на экране синхронизации.

## P0. Независимое обновление рабочего дня

### Текущая проблема

`WorkdayNotifier._refreshFromRemote` использует общий `Future.wait`. Один
упавший endpoint отменяет применение остальных успешных ответов.

### Шаги

- [ ] Выполнить feature flag, status и day types независимо, сохраняя результат
  каждого запроса отдельно.
- [ ] Слить успешные значения с последним cache; ошибка day types не должна
  скрывать актуальный status, а ошибка status не должна очищать справочник.
- [ ] Разделить ошибки загрузки по секциям в immutable state или внутреннем
  result type, не переводя весь блок в пустой error.
- [ ] Не заменять content полноэкранным loader при resume; показывать cache и
  локальный action progress.

### Приёмка

- Любая комбинация одного или двух упавших endpoint сохраняет успешные данные.
- После resume карточка не исчезает и не зависает.

## P0. Парковка workday-событий

### Текущая проблема

`PendingWorkdaySyncService` увеличивает `attempts`, но повторяет любое событие
бесконечно. Это отдельная очередь; исправление обычных визитов сюда не
распространяется.

### Шаги

- [ ] Additive migration для `pending_workday_events`: `status`,
  `next_retry_at`, `parked_at`, `http_status` (или эквивалентные поля).
- [ ] Ввести состояния `pending`, `retryScheduled`, `parked`.
- [ ] Классифицировать ошибки: network/timeout/5xx/429 как transient; постоянные
  validation 4xx как permanent. 401/403 должны ждать восстановления auth, а не
  удаляться как validation error.
- [ ] Добавить exponential backoff и конечный лимит попыток.
- [ ] Permanent 4xx парковать сразу; transient парковать после лимита.
- [ ] Parked запись не блокирует следующие события FIFO, но остаётся видимой в
  диагностике/экране синхронизации.
- [ ] Не удалять событие без подтверждённого 2xx или reconciliation через
  `/WorkDay/status`.

### Приёмка

- Повреждённое событие не создаёт бесконечный сетевой цикл.
- Временная ошибка отправляется повторно после backoff.
- После перезапуска pending/parked состояния сохраняются.

## P1. WorkdayRepository и границы слоёв

### Шаги

- [ ] Создать domain-контракт `WorkdayRepository` с typed операциями:
  `loadFeatureEnabled`, `loadStatus`, `loadDayTypes`, `start`, `end`,
  `watch/readCachedStatus`, `enqueuePending`, `syncPending`.
- [ ] Создать data-реализацию, инкапсулирующую `RemoteApiService`,
  `LocalDatabase` и `SharedPreferences`.
- [ ] Оставить в `WorkdayNotifier` только orchestration UI-state и
  пользовательских действий через domain interface.
- [ ] Инъецировать interface через Riverpod provider, чтобы тесты не создавали
  concrete API/DB.
- [ ] Сохранить текущее per-user кеширование и offline-поведение без очистки
  таблиц.

## P1. Расширить архитектурный контроль

### Шаги

- [ ] Заменить ручной список в
  `test/architecture/layer_boundaries_test.dart` автоматическим discovery
  `lib/features/**/presentation/**/*.dart`, `*_screen.dart`, `*_provider.dart`
  либо поддерживаемым manifest с проверкой полноты.
- [ ] Запретить presentation imports из `core/network`, `core/db` и concrete
  data implementations, разрешив только domain/application contracts.
- [ ] Добавить Workday feature в проверку до переноса, затем сделать тест
  зелёным после `WorkdayRepository`.
- [ ] Сохранить отдельную проверку, что domain не импортирует Flutter/Dio/SQLite.
- [ ] Не считать размер файла архитектурной ошибкой. Декомпозировать крупные
  экраны отдельно и только без изменения поведения.

## P2. Maintainability backlog экранов

- [ ] `sync_screen.dart`: вынести status/action sections и pagination widgets.
- [ ] `home_screen.dart`: отделить sliver/header orchestration от sections.
- [ ] `history_screen.dart`: вынести filters, paging и details launcher.
- [ ] `fav_doctors_screen.dart` и `lpu_doctor_select_screen.dart`: переиспользовать
  typed doctor list widgets/state.
- [ ] `material_viewer_screen.dart`: отделить viewer controls и loading/error.
- [ ] `new_bron_screen.dart`: вынести final action/result orchestration.

Каждый пункт делать отдельным небольшим change set. Не совмещать UI-декомпозицию
с миграцией SQLite или изменением API payload.

## Необходимые тесты

- [ ] Unit: parser `/Markups/short`, exact matrix mapping, no approximate 0%.
- [ ] Unit: contracts direct/wrapped/empty/malformed.
- [ ] ViewModel: LPU retail/wholesale/prepayment/flag combinations.
- [ ] ViewModel: `sent`, `queued`, permanent `rejected` и восстановление draft.
- [ ] Mapper/widget: pending/parked status в главной и истории.
- [ ] Workday: partial refresh всех комбинаций endpoint failures.
- [ ] Workday: transient retry, permanent 4xx, auth failure, retry limit,
  reconciliation и persistence после restart.
- [ ] Architecture: новый Workday slice и автоматическая полнота списка.
- [ ] Widget smoke: bottom sheets рабочего дня и условий брони без нижнего
  navbar, disabled/selected/error состояния.

## Команды проверки

На машине аудита `flutter test` 2026-08-20 не стартовал из-за неполного
`~/.pub-cache`: отсутствовали пакеты `async`, `vector_math`, `characters` и
`source_span`. Перед оценкой результатов тестов восстановить зависимости
штатным `flutter pub get`/`flutter pub cache repair` в используемом Flutter SDK
и убедиться, что `flutter --version` указывает на ожидаемый SDK. Не трактовать
эту ошибку загрузки пакетов как падение бизнес-логики.

```bash
dart format <только изменённые Dart-файлы>
flutter analyze
flutter test test/architecture/layer_boundaries_test.dart
flutter test test/core/providers/workday_provider_test.dart
flutter test test/core/services/pending_visit_push_service_test.dart
flutter test test/features/visits/pharmacy_order_view_model_test.dart
flutter test test/features/visits/submit_pharmacy_order_test.dart
flutter test test/features/visits/history_records_mapper_test.dart
flutter test
```

## Definition of Done текущего цикла

- [ ] ЛПУ и аптека используют один typed источник разрешённых условий.
- [ ] Опт/розница, предоплата и договор отражают только server-approved данные.
- [ ] Offline-заказ нигде не называется проведённым до успешной отправки.
- [ ] Workday partial refresh не теряет успешные секции.
- [ ] Неисправимое workday-событие паркуется и не зацикливает очередь.
- [ ] `WorkdayNotifier` не зависит от API/SQLite/SharedPreferences напрямую.
- [ ] Architecture test охватывает все заявленные presentation/provider файлы.
- [ ] `flutter analyze` и полный `flutter test` проходят.

## Аудит текущего цикла 2026-08-21

Кодовая часть шести блоков завершена и проверена. Старые чекбоксы выше оставлены
как исторический план; фактический статус фиксируется здесь.

- [x] `/Markups/short`, feature flag предоплаты и typed договоры подключены к
  аптечному, прямому ЛПУ, историческому и cart/draft booking flow.
- [x] Pending order status отделён от server status: до успешного push UI
  показывает ожидание/ошибку, а не «Проведено».
- [x] `WorkdayRepository` выделен, refresh секций независим, очередь имеет
  retry/backoff, диагностируемую parking после permanent 4xx или лимита.
- [x] Offline image cache препаратов добавлен additive-миграцией v24 с
  сохранением cached paths при snapshot/upsert.
- [x] Architecture test перешёл на discovery presentation/screen файлов и
  включает Workday domain/repository boundary.
- [x] Узкие тесты и полный `flutter test` проходят; `flutter analyze --no-pub`
  компилируется без ошибок (остались только существующие lint/info в API и
  legacy warning).

### Не входит в локальную кодовую проверку

- [ ] Ручная dev-проверка реальных ответов Markups/Contracts/WorkDay и всех
  HTTP-классов ошибок.
- [ ] Ручной cold-start/offline smoke для файловых изображений и проверки
  поведения backend при выключенном prepayment flag.
