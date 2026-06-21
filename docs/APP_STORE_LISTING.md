# App Store / Google Play — тексты и метаданные LIMA

Bundle / App ID: `uz.lima.lima` · Apple App ID: `6781654387` · версия `1.0.0 (2)`.
Все тексты — заготовки, утвердить/поправить под реальную подачу. Юр-лицо: OOO "LIMA NEO TECHNO".

> ⚠️ **Про название.** Приложение в коде/иконке — **LIMA** (не «LIMA AI»), и AI-функций в этом
> билде нет. Рекомендуется в сторе называть **LIMA** (без «AI»), иначе App Review может
> запросить демонстрацию AI-возможностей, которых в приложении нет.

---

## 1. App Store Connect — App Information

| Поле | Значение | Лимит |
|------|----------|-------|
| App Name | **LIMA** | 30 симв. |
| Subtitle | **Визиты и заказы для медпредставителей** | 30 симв. |
| Primary Category | Business | — |
| Secondary Category | Medical | — |
| Copyright | © 2026 OOO "LIMA NEO TECHNO" | — |
| Privacy Policy URL | `https://lima-legal.vercel.app/privacy` | — |
| Support URL | `https://lima-legal.vercel.app/` (или t.me/PM_LIMA) | — |
| Marketing URL (опц.) | `https://lima.uz` | — |

Юр-документы (RU/UZ/EN, с переключателем языка): Privacy `https://lima-legal.vercel.app/privacy`,
Terms `https://lima-legal.vercel.app/terms`. Опубликованы на Vercel (бесплатно).

Primary language рекомендую **Russian**, добавить локализацию **English**.

## 2. Promotional Text (170 симв., можно менять без ревью)
> LIMA — рабочий инструмент медпредставителя: визиты с GPS-подтверждением, заказы, база врачей и аптек. Полноценная работа даже без интернета.

## 3. Keywords (100 симв., через запятую, без пробелов после запятой)
```
медпред,фарма,визиты,CRM,аптека,врач,заказы,детейлинг,offline,продажи,SFA,pharma
```

## 4. Description (RU)
```
LIMA — мобильное приложение для медицинских представителей фармкомпаний. Планируйте и проводите визиты в ЛПУ и аптеки, оформляйте заказы и ведите базу врачей и организаций — в одном приложении.

Ключевое: приложение работает офлайн. Все визиты, заказы и справочники доступны без связи, а данные синхронизируются с сервером автоматически, как только появляется интернет. Незавершённые или неотправленные визиты не теряются — они сохраняются локально и ждут отправки.

Возможности:
• Визиты с GPS-подтверждением присутствия в ЛПУ или аптеке
• Детейлинг (CLM) и презентационные материалы
• Оформление заказов и работа с остатками
• База врачей и организаций с избранным
• План визитов и история активности
• Сводная статистика за день
• Полная работа офлайн с фоновой синхронизацией

Приложение предназначено для сотрудников фарморганизаций, подключённых к платформе LIMA. Доступ выдаётся вашей компанией.
```

## 5. Description (EN)
```
LIMA is a mobile app for pharmaceutical sales representatives. Plan and conduct visits to clinics and pharmacies, create orders, and manage your doctor and organization database — all in one place.

Built for the field: LIMA works offline. Visits, orders, and reference data are available without a connection, and everything syncs automatically once you are back online. Unsent visits are never lost — they are kept locally until delivered.

Features:
• GPS-verified visits to clinics and pharmacies
• Detailing (CLM) and presentation materials
• Order creation and stock balances
• Doctor and organization database with favorites
• Visit planning and activity history
• Daily performance summary
• Full offline mode with background sync

LIMA is intended for staff of pharmaceutical organizations subscribed to the LIMA platform. Access is provided by your company.
```

## 6. What's New (release notes, v1.0.0)
```
Первый релиз LIMA: визиты с GPS-подтверждением, заказы, база врачей и аптек, полноценная офлайн-работа с автосинхронизацией.
```

## 7. App Review Information ⚠️ обязательно
- **Sign-In required: Yes** — Apple-ревьюеру нужен рабочий демо-аккаунт, иначе REJECT.
  - Demo login: `__________`  Demo password: `__________`
- **Бэкенд должен быть доступен во время ревью.** Текущий билд смотрит на `dev.lima.uz`
  (по договорённости). Убедиться, что демо-аккаунт на этом домене живой и наполнен данными,
  ЛИБО собрать билд под prod (`--dart-define=ENV=prod`) — это отдельное решение.
- Contact: E. Abdullaeva · +998 88 744 55 99 · info@lima.uz
- Notes для ревьюера (пример):
```
B2B app for pharmaceutical sales reps. Login is required and accounts are provisioned by the
organization. Please use the demo account above. The app supports offline mode: data is cached
locally and syncs when online. Location is used to geo-verify visits.
```

## 8. App Privacy (анкета App Store Connect) — ПО ФАКТУ ПРИЛОЖЕНИЯ
Заполнять строго по тому, что делает iOS-билд (НЕ по платформенной политике):

| Data type | Collected | Linked to user | Tracking | Назначение |
|-----------|-----------|----------------|----------|------------|
| Precise Location | Yes | Yes | No | App Functionality (гео-подтверждение визита) |
| Name | Yes | Yes | No | App Functionality |
| Email / Phone | Yes | Yes | No | App Functionality |
| User ID / Account | Yes | Yes | No | App Functionality |
| Photos (камера) | Yes* | Yes | No | App Functionality (фото в обратной связи) |
| Coarse Location | опц. | Yes | No | App Functionality |
| Diagnostics / Crash | Yes | No | No | App Functionality |
| Identifiers (IP) | Yes | No | No | App Functionality / Security |

- **App Tracking Transparency: не используется** (нет трекинга/рекламы).
- **AI-передачу данных и push НЕ указывать** — в этом билде их нет.
- *Фото — только если пользователь прикрепляет их в обратную связь.

## 9. Age Rating
В анкете возрастного рейтинга везде «None», кроме — при вопросе про
«Medical/Treatment Information» можно поставить «None» (приложение не даёт мед. рекомендаций,
а ведёт рабочие записи). Ожидаемый рейтинг **4+**.

## 10. Скриншоты (нужно подготовить)
Обязательны для размеров: **6.7"** (iPhone 15/16 Pro Max, 1290×2796) и **6.5"** (1242×2688).
Достаточно 3–5 экранов: Home, Визит/детейлинг, Заказ, План, Sync (офлайн). Без статус-бара с
посторонним содержимым. iPad-скриншоты нужны, только если приложение помечено как iPad-совместимое.

---

## Расхождения политики и приложения — УСТРАНЕНЫ ✅
Документы приведены строго под приложение (опубликованная версия на Vercel):
убраны AI Assistant, push-уведомления, «PWA»; «LIMA AI» → «LIMA». Дата обновления 18.06.2026.
App Privacy всё равно заполняем по факту приложения (см. §8 выше).
