# План миграции LIMA к MVVM / Clean Architecture

Дата ревью: 15 июля 2026 года.

Базовый коммит: `d665c45 refactor: MVVM + repository layer across all screens`.

## 1. Текущее состояние

Коммит `d665c45` завершил первый инфраструктурный этап:

- добавлены feature-owned репозитории для организаций, врачей, визитов,
  препаратов, избранного, корзины и диагностики синхронизации;
- большая часть экранов больше не вызывает `LocalDatabase` и
  `RemoteApiService` напрямую;
- состояние запланированных визитов вынесено в `PlannedVisitsNotifier`;
- диалоги визитов перенесены из `core` в модуль `features/visits`;
- проект проходит `flutter analyze` и `flutter test`.

Поверх коммита есть незакоммиченное продолжение миграции: добавлены типизированные
`Organisation`, `Doctor`, `LocalVisit`, часть экранов переведена с raw-map на эти
модели и добавлены unit-тесты моделей.

После начала текущего этапа также выполнено:

- предзагрузка Home/Visits переведена с `LocalDatabase` на feature repositories;
- кэш последних визитов индексируется по пользователю;
- построение строк заказа вынесено в `BuildPharmacyOrderLines`;
- SQL для локальных итогов перенесён из диагностического репозитория в
  `LocalDatabase`;
- добавлены unit-тесты строк заказа: 0/валидное количество, binding id,
  `income_detailing_id` и расчёт цены без НДС.
- для брони добавлены typed gateway, `SubmitPharmacyOrder` и тесты сохранения
  условий 0/100% и retail/wholesale.
- для синхронизации добавлены domain-команды, typed `SyncViewState`,
  `SyncRepository` и `SyncViewModel`; экран синхронизации больше не вызывает
  `SyncNotifier` напрямую;
- push-before-pull закреплён не только для кнопок экрана, но и для
  launch/background/bootstrap entrypoints; ошибки очереди не запускают pull
  раньше push;
- разбор сохранённого push-error вынесен из экрана синхронизации в
  diagnostics repository;
- mapping профиля пользователя (регион, компания, роль и статистика) вынесен
  в `UserProfileMapper`; auth notifier пока сохраняет orchestration сессии;
- добавлен single-flight guard на уровне команд view model и core entrypoint-ов;
  повторный запуск doctor-layer также объединяется, добавлен regression-тест
  operation gate.
- локальная запись заказа переведена на typed `PharmacyOrderDraft` и
  отдельную data-реализацию `PharmacyOrderDraftRepository`; mapper оставляет
  существующий SQLite/API payload без изменений.

Текущий прогресс: завершены вертикальные срезы auth, home, sync-команд, брони,
каталогов организаций/врачей, plan, knowledge, favorites, cart и diagnostics.
Для sync завершены отдельные сервисы push pending, delta/full pull, live
refresh, diagnostics и background reconcile; в `SyncNotifier` осталась только
высокоуровневая последовательность операций и публикация UI-состояния.
Legacy raw-map границы для мигрированных callers удалены: оставшиеся raw maps
используются только внутри data mappers, typed compatibility models и
SQLite/API compatibility payloads.
Крупные visit-экраны из текущего среза разделены на view model и widgets;
оставшиеся крупные файлы перечислены ниже как отдельный UI-only migration slice.

В текущем legacy-срезе дополнительно завершены typed state/provider-границы для
`SyncScreen`, `HistoryScreen`, выбора врачей ЛПУ, `MaterialViewer`, деталей ЛПУ и
аптеки, а также transient-состояние booking/cart. Экраны больше не держат эти
данные в локальных полях `StatefulWidget` и не читают raw-map поля организации;
оставшаяся декомпозиция ниже относится к чистой разметке и небольшим widgets.

Последним вертикальным срезом также добавлена typed-граница записи завершённых
визитов: payload ЛПУ, фармкружка и снятия остатков строится в data mapper,
локальная запись, remote push, диагностика и retry-очередь находятся в
`VisitWriteRepositoryImpl`.

В текущем срезе также типизированы операции справочника организаций и врачей:
создание врача, создание организации и редактирование ЛПУ/аптеки используют
`DoctorDraft`, `OrganisationDraft` и `OrganisationUpdateDraft`. Локальные
модели, remote payload и offline-очереди для этих операций остаются внутри
data-реализаций репозиториев; экраны больше не импортируют concrete data
repository для этих действий.

Это уже рабочая repository-layer основа, но не завершённая Clean Architecture
для всего приложения:

- часть legacy presentation-кода еще импортирует конкретные data-репозитории;
- часть legacy репозиториев по-прежнему экспортирует raw-map методы для старых
  visit-flow callers;
- `SyncNotifier` сохраняет высокоуровневую orchestration sync-операций и UI
  progress, а data-операции делегирует core services;
- крупные исторические visit-экраны еще содержат payload и response mapping;
- отдельные старые экраны используют локальный `StatefulWidget` state;
- ожидаемые ошибки пока не сведены к общему `Result<T>`/`Failure`.

## 2. Целевая архитектура

Миграция должна быть прагматичной и выполняться вертикальными срезами, без
одновременного переписывания приложения и без изменения API/SQLite-контрактов.

```text
presentation
  screens/widgets -> Riverpod view model -> immutable UI state
                                      |
                                      v
domain
  use cases -> repository interfaces -> entities/value objects
                                      ^
                                      |
data
  repository implementations -> local/remote data sources -> DTO/mappers
                                      |
                                      v
                     LocalDatabase / RemoteApiService
```

Правила зависимостей:

1. `presentation` зависит только от `domain` и presentation-моделей.
2. `domain` не импортирует Flutter, Dio, sqflite, SharedPreferences и data-слой.
3. `data` реализует domain-контракты и владеет DTO/SQLite/API mapping.
4. SQLite остаётся источником истины для экранов offline-first сценариев.
5. Remote pull обновляет SQLite, а UI получает новое типизированное состояние.
6. Local write сначала сохраняется в SQLite, затем use case инициирует push.
7. Ошибки не проглатываются: view model получает типизированный `Failure`.

Рекомендуемая структура одного модуля:

```text
lib/features/visits/
  domain/
    entities/
    repositories/
    use_cases/
  data/
    datasources/
    dto/
    mappers/
    repositories/
  presentation/
    view_models/
    screens/
    widgets/
```

## 3. Этапы работ

### Этап 0. Защитить текущее поведение

- [ ] Зафиксировать незакоммиченную типизацию отдельным reviewable change set.
- [x] Добавить characterization-тесты для текущих моделей и строк заказа.
- [x] Покрыть смену сессии: stale user очищается, а login/restore берет профиль
  только из результата `AuthRepository`.
- [x] Покрыть порядок bootstrap/delta pull, локальную запись, push и retry на
  уровне `SyncViewModel`, order view model и operation gate; полный integration
  fixture core-sync остается отдельным gap.
- [x] Покрыть заказ аптеки: 0/100%, retail/wholesale, offline и server rejection.
- [x] Добавить mapping-тесты для профиля, local visit, заказа, препарата,
  материалов, корзины и sync queue records; полный API fixture corpus остается
  отдельным gap.

Критерий готовности: дальнейшие перемещения слоёв не меняют пользовательское и
sync-поведение; каждый критичный сценарий имеет автоматический regression-тест.

### Этап 1. Ввести domain-границы

- [x] Создать typed domain entities для организации, врача, визита, препарата,
  материала, плана, корзины и избранного в мигрированных vertical slices.
  Legacy `core/models` еще содержит совместимые `rawJson` поля для старых flow.
- [x] Создать интерфейсы каталогов организаций/врачей, препаратов/материалов,
  plan, favorites, cart, auth, home, sync и pharmacy order. Полный facade
  `VisitsRepository` еще требует отдельной миграции.
- [x] Переименовать текущие конкретные классы в `*RepositoryImpl`.
- [x] Вынести mapping в data для auth, home recent visits, plan, knowledge,
  cart, favorites, sync diagnostics и pharmacy order; старые visit DTO еще не
  полностью выделены.
- [x] Ввести общий тип результата (`Result<T>`/`Failure`) для ожидаемых ошибок.
  - [x] `Result<T>` и `AppFailure` применены к submit-заказа и auth failure;
    legacy exceptions остаются совместимым API до миграции остальных flow.
- [x] Настроить feature providers для migrated contracts; оставшиеся старые
  screens продолжают получать concrete repository до миграции их callers.

Критерий готовности: domain не импортирует `core/db`, `core/network`, Flutter и
Riverpod; data-реализации можно заменить fake-репозиториями в unit-тестах.

### Этап 2. Синхронизация как отдельный application-сценарий

- [x] Разделить `SyncNotifier` на use case: push pending, delta pull, full pull,
  reconcile и diagnostics.
  - [x] Команды UI для push pending, delta pull и full pull разделены на
    отдельные domain use cases; notifier оставляет только orchestration.
  - [x] `DoctorDirectorySyncService` владеет repair-решением, связями
    врач–ЛПУ, cursor `sync_id`, `batch_size=1000` и проверкой полноты каталога;
    notifier оставляет у себя orchestration и UI progress.
  - [x] `PendingPlanSyncService` владеет очередью запланированных визитов:
    payload mapping, `/api/visits/plans`, stamping `remote_id` и политикой
    удаления 4xx/повтора сетевых и 5xx ошибок.
  - [x] `PendingMutationSyncService` владеет очередями избранного, feedback,
    новых врачей и организаций и возвращает typed queue failures в notifier.
  - [x] `PendingVisitPushService` владеет отправкой визитов, repair старых
    payload, retry/backoff/parking и сохранением request/response diagnostics.
  - [x] `DeltaPullService` владеет выбором cursor, delta-запросами справочников,
    upsert в SQLite и продвижением `last_sync_id` после успешной записи.
  - [x] `OrganizationDirectoryPullService` владеет API-to-SQLite границей
    layered полного/delta pull организаций.
  - [x] `FullSeedSyncService` владеет `fetchOfflineSeed` и заменой серверного
    снимка с сохранением несинхронизированных локальных визитов.
  - [x] `LiveDataRefreshService` владеет обновлением истории, планов,
    избранного, материалов, статистики и небольших справочников.
  - [x] `SyncDiagnosticsService` владеет typed локальными итогами, числом
    связей врач–ЛПУ и проверкой готовности базового каталога.
  - [x] `BackgroundReconcileService` владеет проверкой реального интернета,
    silent reauth и запуском launch/background delta.
  - [x] Launch/background/bootstrap entrypoints preserve the same
    push-before-pull ordering.
- [x] Скрыть SQL и имена таблиц локальных итогов внутри local data source.
- [x] Для экрана синхронизации заменить `Stream<Set<String>>` на
  типизированный `SyncDataChange`.
- [x] Перенести типизированный поток ревизий на остальные feature-repository,
  которые пока проксируют имена SQLite-таблиц.
  - [x] `OrganisationsDirectoryRepository` и `VisitsRepository` публикуют
    `SyncDataChange`; экраны больше не сравнивают имена SQLite-таблиц.
- [x] Описать feature-level `SyncViewState`: idle/running/success/
  partialFailure/failure + progress.
- [x] Не проглатывать parse/push errors; сохранять диагностический контекст.
  - [x] Ошибки очередей избранного, feedback, врачей, организаций, планов и
    parse локального визита попадают в итог `lastPostDebug`; остальные записи
    продолжают отправляться.
- [x] Проверить single-flight на уровне команд `SyncViewModel`.
- [x] Довести single-flight до публичных entrypoint-ов core `SyncNotifier`,
  включая фоновые вызовы и doctor-layer.

Критерий готовности: экран синхронизации только отображает `SyncState` и вызывает
команды view model; вся стратегия push-before-pull тестируется без WidgetTester.

### Этап 3. Вертикальный срез «Бронь в аптеку»

- [x] Вынести выбор товара и проверку остатков в `PharmacyOrderViewModel`.
- [x] Вынести запрос условий ценовой матрицы в typed order gateway.
- [x] Вынести формирование и отправку remote-визита в `SubmitPharmacyOrder`.
- [x] Вынести local draft/pending/retry в репозиторий и mapper.
  - [x] Сохранение локального typed draft вынесено.
  - [x] Завершение submitted draft, привязка `remote_id`, push diagnostics и
    обновление canonical history вынесены в отдельную data repository;
    pending/retry операции больше не принадлежат remote gateway.
  - [x] Ошибки remote submit нормализуются в typed failure; diagnostics и
    `sync_failed` записываются repository-методом.
- [x] Вынести построение и проверку строк заказа в `BuildPharmacyOrderLines`.
  - [x] Предпросмотр цен типизирован как `PharmacyOrderPricingPreview`, при
    этом последовательность API `pricing/calculate` → `/Visits/add` сохранена.
- [x] Удалить API payload, `raw_json` и response parsing из экранов.
  - [x] Экран больше не разбирает response для получения `remote_id` и не
    обновляет SQLite после успешной отправки.
  - [x] Основные переходы каталог → бронь и корзина → checkout передают
    `PharmacyOrderRouteData` через `GoRouter.extra`, без JSON в URL.
  - [x] Экран синхронизации больше не разбирает сохранённый push-error JSON;
    сообщение строится в diagnostics repository.
  - [x] Экран каталога последних визитов Home получает typed `RecentVisit` из
    `HomeRepository`; JSON/SQLite mapping перенесён в data mapper.
- [x] Представить UI единым immutable `PharmacyOrderState`.
  - [x] Каталог, количества, сумма и stock-validation представлены immutable
    `PharmacyOrderViewState`.
  - [x] Статусы отправки (`loading`, `sent`, `queued`, `rejected`, ошибка и
    отсутствие ценовой матрицы) вынесены в typed view model state; экран оставляет
    у себя только comment controller и навигационные side effects.

Критерий готовности: экран не знает `margin_id`, `payment_variant_id`,
`income_detailing_id`, SQLite-колонки и формат ответа `/Visits/add`.

### Этап 4. Каталоги организаций и врачей

- [x] Создать `VisitsHubViewModel` с query, region scope и nearby sorting.
- [x] Убрать static-кэши из `VisitsHubScreen`.
- [x] Источник списка — наблюдаемый локальный query и typed repository contract;
  remote search не подменяет локальный источник истины.
- [x] Вынести remote search из view model в отдельный use case после стабилизации
  общего каталожного контракта.
- [x] Создать `LpuDetailsViewModel` с единым списком врачей для detail/start visit;
  remote repair, visit-counts и favorite state теперь общие для обоих экранов.
- [x] Перенести фильтрацию по региону и связи врач-ЛПУ из widget-кода.
  - [x] Region scope, nearby sorting и merge remote search находятся в
    `VisitsHubViewModel`; список врачей detail/start visit читается через
    `LpuDetailsViewModel`.

Критерий готовности: повторный вход на экран не создаёт пустой/loading кадр,
данные другого пользователя не видны, offline-списки работают без API.

### Этап 5. Остальные модули

- [x] `auth`: notifier зависит от `AuthRepository`, а не от API/DB/storage.
  - [x] API profile mapping вынесен в domain mapper `UserProfileMapper`;
    token/profile/cache/owner orchestration вынесен в `AuthRepositoryImpl`.
- [x] `home`: отдельный dashboard/recent-visits view model.
  - [x] Recent-visits repository contract, entity и data mapper вынесены из
    `HomeScreen`; lifecycle/cache orchestration вынесен в
    `HomeRecentVisitsViewModel`.
- [x] `plan`: типизированный repository + use case merge/deduplication.
- [x] `knowledge`: typed модели препаратов/материалов и material access service.
- [x] `profile/favorites`: единый optimistic-update use case с rollback.
- [x] `cart`: typed cart/order draft вместо raw map и JSON в presentation.
  - [x] Репозитории корзины и избранного получили domain-контракты; экраны и
    `AppCollectionsNotifier` получают их через feature provider.
- [x] `plan`: выбор организаций и врачей в форме нового плана переведён на
  `OrganisationsDirectoryRepository` и `DoctorsDirectoryRepository`; legacy
  contract для форматов и записи pending-плана пока остаётся отдельным gap.

Критерий готовности: migrated screens/dialogs не импортируют `LocalDatabase`,
`RemoteApiService`, `ApiClient` или конкретный data repository. Legacy visit
flows перечислены в этапе 6 и остаются следующим migration slice.

### Этап 6. Завершить типизацию и декомпозицию UI

- [x] Удалить raw-map API из публичных методов репозиториев после миграции всех
  legacy visit callers. Мигрированные knowledge/catalog screens уже используют
  typed методы; raw maps остались только во внутренних data-mappers и в
  SQLite/API compatibility payloads.
  - [x] Завершение визита в ЛПУ, фармкружке и снятии остатков переведено на
    `CompletedVisitDraft`/`VisitWriteRepository`; экран больше не собирает
    API JSON и не разбирает remote response.
  - [x] Добавление врача переведено на `DoctorDraft`; локальная запись,
    remote-create, temp-id и retry-очередь скрыты за
    `DoctorsDirectoryRepository`.
  - [x] Создание организации и редактирование ЛПУ/аптеки переведены на
    `OrganisationDraft`/`OrganisationUpdateDraft`; области региона, локальная
    модель, remote-update и retry-очередь скрыты за
    `OrganisationsDirectoryRepository`.
- [x] Добавить architecture test, запрещающий `raw_json`/`jsonDecode` и прямую
  инфраструктуру в выбранных migrated presentation files; расширить список до
  всех legacy экранов после их миграции.
- [x] Вынести загрузку, обновление по `SyncDataChange` и immutable state истории
  визитов в `HistoryViewModel`; `HistoryScreen` оставляет фильтры, пагинацию и UI.
- [x] Вынести diagnostics/локальные списки, пагинацию и loading-state
  `SyncScreen` в `SyncScreenViewModel`; orchestration sync по-прежнему живёт в
  `SyncViewModel`.
- [x] Вынести загрузку и кэширование материалов, текущий индекс и ошибки
  `MaterialViewer` в `MaterialViewerViewModel`; PageView/VideoPlayer остаются
  UI-ресурсами экрана.
- [x] Вынести загрузку typed организации и fallback-нормализацию display-полей
  деталей ЛПУ/аптеки в `OrganisationDetailsViewModel` и `Organisation`.
- [x] Вынести query/confirm/action-lock состояния booking и checkout в
  `PharmacyOrderViewModel` и `CartViewModel`.
- [x] Вынести категорию врача из legacy raw-map lookup в typed `Doctor` getter.
- [x] Разделить все legacy-экраны больше 500 строк на view model и небольшие
  widgets. Основной текущий slice завершён:
  - [x] Состояние каталога и выбранных материалов фармкружка вынесено в
    `PharmaCircleViewModel`; finish-sheet и keypad находятся в
    `pharma_circle_finish_sheet.dart`.
  - [x] Каталог, поиск и количества снятия остатков вынесены в
    `PharmacyStockViewModel`; confirm-screen, quantity dialogs и keypad
    находятся в `pharmacy_stock_widgets.dart`.
  - [x] Состояние справочников, региона, района, геопозиции и revision-status
    формы добавления организации вынесено в `AddPharmacyViewModel`.
  - [x] Календарь, режимы отображения и карточка визита `PlanScreen` вынесены
    в `plan_calendar_section.dart` и `plan_visit_card.dart`.
  - [x] Итоговый диалог завершения `LpuDetailingScreen` вынесен в
    `lpu_detailing_completion_dialog.dart`.
  - [x] Picker справочников и телефонный блок `AddPharmacyScreen` вынесены в
    `organisation_form_widgets.dart`.
  - [x] Оставшаяся разметка `LpuDetailingScreen` и `AddPharmacyScreen` разделена
    на `LpuDetailingContent` и `OrganisationFormBody`/поля формы.
  - [x] Визуальная декомпозиция `HomeScreen`, `ProfileScreen`,
    `NewBronScreen`, `PharmacyOrderScreen`, `CartScreen`,
    `PharmacyDetailScreen`, `LpuDetailScreen` и `VisitsHubScreen` завершена.
    Крупные UI-блоки вынесены в feature widgets через отдельные part-library
    файлы; state, submit и navigation остаются на экранах/ViewModel.
  - [x] Основной UI `PharmaCircleScreen` и `PharmacyStockScreen` также вынесен
    в отдельные screen-widget part-файлы поверх существующих finish/confirm
    widgets.
  - [x] Для `SyncScreen`, `HistoryScreen`, `MaterialViewerScreen`,
    `LpuDoctorSelectScreen`, `PharmaCircleScreen` и `PharmacyStockScreen`
    состояние уже вынесено; их оставшаяся часть является UI-only и не содержит
    отдельной бизнес-логики.
- [x] Стандартизировать `AsyncValue` или собственный immutable UI-state в
  migrated slices.
  - [x] Для фармкружка введён immutable `PharmaCircleViewState` с typed
    каталогом, поиском, single-flight загрузкой и выбранными материалами.
  - [x] Для снятия остатков введён immutable `PharmacyStockViewState` с
    typed quantities и проверкой доступного остатка.
  - [x] Для добавления организации введён immutable `AddPharmacyViewState` с
    typed справочниками, выбором региона/района, координатами и ошибкой.
  - [x] Для детализации ЛПУ и календаря плана state разделён от extracted
    widgets; календарь использует `PlanCalendarViewState`, а отправка формы
    организации хранится в `AddPharmacyViewState`.
- [x] Удалить пустые `catch (_) {}` и добавить наблюдаемую обработку ошибок.
  Ошибки best-effort flow попадают в `SwallowedLog` и доступны диагностике.

Критерий готовности: presentation отвечает за отображение и пользовательские
события, а не за data mapping, бизнес-правила или orchestration.

### Этап 7. Документация и контроль границ

- [x] Обновить `README.md`, `ARCHITECTURE_SYNC.md` и `OFFLINE_DB.md`.
- [x] Добавить dependency rules через architecture tests.
- [x] Добавить шаблон нового feature-модуля и checklist для code review.
- [x] В CI запускать analyze и полный unit/repository/provider test suite;
  widget smoke tests остаются отдельным следующим шагом.

## 4. Рекомендуемый порядок pull request

1. Тестовый каркас и characterization tests без production-изменений.
2. Domain contracts + data implementations для одного read-only каталога.
3. `VisitsHubViewModel` и удаление static-кэша.
4. Sync use cases и `SyncViewModel`.
5. Pharmacy order vertical slice.
6. LPU/doctor flow.
7. Auth, profile/favorites, plan, knowledge и cart.
8. Удаление legacy raw-map API и включение архитектурных ограничений.

Каждый PR должен быть небольшим, сохранять SQLite/API contract и содержать тесты
на мигрируемое поведение. Изменения схемы БД и API-контрактов не следует смешивать
с перемещением архитектурных границ.

## 5. Definition of Done

- [ ] Все UI-экраны не обращаются к SQLite/Dio/API client напрямую; это выполнено
  для migrated slices, но legacy visit flows всё ещё используют concrete
  compatibility methods.
- [ ] Все UI-экраны не строят API payload и не разбирают raw maps; migrated
  slices выполнены, legacy visit flows остаются.
- [x] Migrated view models не зависят от concrete data implementation.
- [x] Domain не зависит от Flutter и инфраструктуры; это проверяется
  `test/architecture/layer_boundaries_test.dart`.
- [x] Критичные offline-first write/push/retry сценарии покрыты unit-тестами;
  полный core-sync integration test остается gap.
- [x] Смена пользователя очищает user-scoped state и stale UI/cache profile.
- [x] `flutter analyze` и полный `flutter test` проходят локально и запускаются
  в CI.
- [x] Архитектурные документы обновлены под фактический data flow.
