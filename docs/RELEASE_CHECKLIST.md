# LIMA — чек-лист публикации в сторы

Документ для подготовки релиза в App Store и Google Play. Что уже готово,
чего не хватает, что нужно получить от заказчика и как задеплоить.

---

## 0. Окружение: ВСЕГДА прод по умолчанию

Домен вынесен в один файл — `lib/core/config/env_config.dart`. По умолчанию
**прод** (`crm.lima.uz`): `flutter run`, релизные сборки и автодеплой идут на
прод без каких-либо флагов. **`--dart-define=ENV=...` больше не используется.**

- Для теста на dev (`dev.lima.uz`): поменять одну строку
  `static const bool _useDev = false;` → `true`, после теста вернуть в `false`.
- Меняет и базовый URL API (`https://<host>/api`), и хост DNS-проверки сети.
  Больше нигде домен не захардкожен.
- prod API: `https://crm.lima.uz/api`, dev: `https://dev.lima.uz/api`.

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

Деплой автоматизирован через **GitHub Actions** (`.github/workflows/release.yml`,
подробности и список секретов — `docs/CICD.md`). Сборку и загрузку в сторы
делает CI, локально билдить не нужно.

Версия едина для обеих платформ — `pubspec.yaml`, поле `version`
(формат `major.minor.patch+build`). **Перед каждым релизом обязательно поднять
build-номер** — сторы отклоняют уже использованный.

### Авто-релиз по push в `main`
1. Поднять версию в `pubspec.yaml` (например `1.0.2+7`).
2. `git push` в `main`.
3. CI собирает и заливает: **Android → Google Play (internal)**,
   **iOS → TestFlight**.
   - Запускается только та платформа, чьи файлы менялись (path-фильтр):
     правка только в `ios/` не пересобирает Android, и наоборот. Общий код
     (`lib/`, `assets/`, `pubspec.yaml`, сам workflow) → собираются обе.

### Раздельный релиз вручную (только Apple / только Google)
GitHub → **Actions → Release → Run workflow** → выбрать `target`:
- `ios` — собрать и залить только в TestFlight,
- `android` — только в Google Play,
- `both` — обе платформы.

То есть можно «пуш только в Apple», потом отдельно «пуш только в Google».

### После загрузки
- **Google Play:** билд прилетает в *Внутреннее тестирование*; продвижение в
  рабочую дорожку — вручную в Play Console.
- **TestFlight:** билд появляется после обработки; раздать тестерам / отправить
  на ревью — вручную в App Store Connect.

### Ручной аплоад (fallback, если CI недоступен) ✅ проверено 2026-06-23

Запускать **в своём терминале** (не из агента/фона — иначе codesign выбьет
бесконечный keychain-popup; в GUI-сессии подпись проходит без окон).

**iOS → TestFlight:**
```sh
cd /Users/a123/a123-dev/lima
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
# → build/ios/ipa/LIMA.ipa
xcrun altool --upload-app --type ios -f build/ios/ipa/LIMA.ipa \
  --apiKey 8KKGG6LX7K --apiIssuer 436c2549-a4f7-4dad-99af-59a2773629ea
# ждём "UPLOAD SUCCEEDED with no errors"
```
Ключ `.p8` лежит в `~/.config/lima` / `~/Documents/lima-secrets/AuthKey_8KKGG6LX7K.p8`
(altool ищет в `~/.appstoreconnect/private_keys/`). Альтернатива — перетащить
ipa в **Transporter.app**.

**Android → Google Play:**
```sh
flutter build appbundle --release   # нужен android/key.properties + keystore
# → build/app/outputs/bundle/release/app-release.aab
```
Залить AAB в Play Console → Внутреннее тестирование (или через
`android` fastlane lane с service-account JSON).

После загрузки: TestFlight обработает билд (~5–15 мин) → выбрать его в версии
App Store и **Submit for Review**; в Play — продвинуть в нужную дорожку.

### Git
- Перед релизом: коммит с бампом версии, push в `main`.
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
