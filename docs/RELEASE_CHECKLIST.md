# LIMA — чек-лист публикации в сторы

Документ для подготовки релиза в App Store и Google Play. Что уже готово,
чего не хватает, что нужно получить от заказчика и как задеплоить.

---

## 0. Переключение dev → prod (1 место)

Домен окружения вынесен в один файл — `lib/core/config/env_config.dart`.

- Для прод-сборки: поменять `_defaultIsProd` на `true` **либо** собрать с флагом
  `--dart-define=ENV=prod` (флаг важнее дефолта).
- Это автоматически меняет и базовый URL API (`https://<host>/api`), и хост
  DNS-проверки сети. Больше нигде домен не захардкожен.
- Домены: dev — `dev.lima.uz`, prod — `crm.lima.uz`
  (prod API: `https://crm.lima.uz/api`).

---

## 1. iOS (Apple App Store)

### Что нужно получить от заказчика
| Что | Зачем | Где взять |
|-----|-------|-----------|
| **Apple Developer аккаунт** | доступ к сертификатам и App Store Connect | у заказчика |
| **Apple Distribution Certificate** | подпись релизной сборки | Apple Developer → Certificates |
| **App Store Provisioning Profile** для `uz.lima.lima` | привязка сборки к App ID | Apple Developer → Profiles |

### Что нужно сделать
- [x] **Team ID** = `5N9G35WULY` (LIMA NEO TECHNO, MCHJ) — прописан в
  `ios/Runner.xcodeproj/project.pbxproj` и `ios/ExportOptions.plist`.
- [ ] Для **Release**-таргета выставить `CODE_SIGN_STYLE = Automatic`
  (рекомендуется) и убедиться, что Xcode подтягивает cert + profile.
  Сейчас явная подпись задана только для тестовых таргетов.
- [x] Создать `ios/ExportOptions.plist` (`method: app-store`) для
  `flutter build ipa` / CI. **Создан** (teamID `5N9G35WULY`,
  `signingStyle: automatic`).
- [ ] Завести приложение в **App Store Connect** (bundle `uz.lima.lima`),
  заполнить метаданные, скриншоты, **политику конфиденциальности** (обязательна).

### App Store Connect
- **App Apple ID:** `6781654387` (bundle `uz.lima.lima`).

### Секреты iOS (хранятся в `~/Documents/lima-secrets/`, не в git)
- **App Store Connect API key:** `AuthKey_8KKGG6LX7K.p8`
  - Key ID `8KKGG6LX7K`, Issuer ID и пример команды — в
    `~/Documents/lima-secrets/appstore-api-key.txt`.
  - Нужен только для автозагрузки (CI / `xcrun altool|notarytool --apiKey ...`).
    Для ручной загрузки через Xcode/Transporter не требуется.
  - ⚠️ Скачивается у Apple один раз — это единственная копия.
- **Сертификаты:** `distribution.cer` (релиз), `development.cer` (тест).
  Перед подписью дважды кликнуть → установить в Keychain (нужен приватный ключ
  от CSR на этой машине, иначе identity будет неполным).

### Уже готово ✅
- Bundle id: `uz.lima.lima` (не example).
- Display name: **LIMA**; версия из pubspec (`CFBundleShortVersionString` /
  `CFBundleVersion` = `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)`).
- Permission-descriptions заполнены (камера, гео, фото) на русском.
- Иконки приложения и LaunchScreen на месте.
- Min iOS deployment target: **14.0** (соответствует требованиям Store).

### Не требуется (решение заказчика)
- **Push / Firebase не используются.** `aps-environment` и
  `GoogleService-Info.plist` не нужны.

---

## 2. Android (Google Play)

### Что нужно получить от заказчика
| Что | Зачем |
|-----|-------|
| **Google Play Developer аккаунт** | создать приложение и загрузить AAB |

### Что нужно сделать
- [ ] Включён R8/ProGuard (см. `android/app/build.gradle.kts` +
  `android/app/proguard-rules.pro`). **После сборки release-AAB обязательно
  прогнать ключевые экраны** — минификация может ломать рефлексию; при ошибках
  дописать keep-правила.
- [ ] Собрать `flutter build appbundle --release`.
- [ ] Создать приложение в **Play Console** (package `uz.lima.lima`), залить AAB,
  заполнить листинг + политику конфиденциальности.

### Уже готово ✅
- applicationId: `uz.lima.lima` (не example).
- **Keystore выпущен и забэкаплен:** `~/Documents/lima-secrets/lima-release.jks`
  + `android/key.properties` (alias `lima`, RSA-2048, срок ~27 лет).
  > ⚠️ Этот keystore — **единственный** способ обновлять приложение в Play.
  > Хранить копию в облаке/менеджере паролей. Потеря = невозможность апдейтов.
- Permissions, label, adaptive-иконка (`#417DF7` фон + `lima_logo_2`) на месте.

### Риск (закрыт страховкой)
- В `build.gradle.kts` стоит guard: `flutter build apk/appbundle --release`
  **падает с понятной ошибкой**, если `key.properties` отсутствует — debug-ключ
  больше не подставляется молча (Play отклонил бы такой AAB). Для локальной
  debug-подписанной release-сборки есть явный обход:
  `flutter build apk --release` c `-PallowDebugSigning=true` через
  `android/gradle.properties` либо `./gradlew assembleRelease -PallowDebugSigning=true`.

---

## 3. Процесс деплоя и версионирование

Версия едина для обеих платформ — `pubspec.yaml`, поле `version`
(сейчас `1.0.0+1`, формат `major.minor.patch+build`).

### Шаги релиза
1. Поднять версию в `pubspec.yaml` (например `1.0.1+2`).
2. Перевести окружение на prod: `EnvConfig` → prod (см. раздел 0).
3. **iOS:** `flutter build ipa --release` → загрузка через Xcode/Transporter в
   App Store Connect.
4. **Android:** `flutter build appbundle --release` → загрузка AAB в Play Console.
5. Вернуть окружение в dev в рабочей ветке (либо держать prod-флаг только в
   релизном теге).

### Git
- Перед релизом: коммит с бампом версии, тег `vX.Y.Z+B`, push.
- ⚠️ Git-операции (commit / push / tag) выполнять **только по явному запросу**.

---

## 4. Краткая сводка статуса

| Компонент | iOS | Android |
|-----------|-----|---------|
| Bundle / App ID | ✅ `uz.lima.lima` | ✅ `uz.lima.lima` |
| Версия | ✅ из pubspec | ✅ из pubspec |
| Иконки / Splash | ✅ | ✅ adaptive |
| Подпись | ❌ нужны cert + profile от заказчика | ✅ keystore готов |
| Обфускация | — | ✅ R8 включён (проверить сборку) |
| Push / Firebase | не требуется | не требуется |
| Аккаунт стора | ❌ от заказчика | ❌ от заказчика |

**Блокеры:** аккаунты сторов + iOS-сертификаты от заказчика; уточнить prod-домен.
Всё остальное в коде/конфиге подготовлено.
