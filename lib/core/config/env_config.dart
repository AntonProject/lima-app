/// Единая точка конфигурации окружения (dev ↔ prod).
///
/// Чтобы переключить приложение с DEV на PROD — поменяй ОДНУ строку:
/// [isProd] на `true`. Это автоматически меняет и базовый URL API,
/// и хост для проверки доступности сети.
///
/// При желании окружение можно переопределить при сборке без правки кода:
///   flutter build appbundle --release --dart-define=ENV=prod
/// (флаг `--dart-define` имеет приоритет над [isProd]).
class EnvConfig {
  EnvConfig._();

  /// Значение по умолчанию. Прод-домен (crm.lima.uz) включён по умолчанию
  /// с релиза 1.0.1 — `flutter run` и сборки идут на прод без флага.
  /// Для dev: `--dart-define=ENV=dev`.
  static const bool _defaultIsProd = true;

  /// Переопределение через --dart-define=ENV=prod|dev (опционально).
  static const String _envOverride = String.fromEnvironment('ENV');

  /// Итоговый флаг окружения. dart-define важнее дефолта.
  static bool get isProd {
    if (_envOverride == 'prod') return true;
    if (_envOverride == 'dev') return false;
    return _defaultIsProd;
  }

  static const String _devHost = 'dev.lima.uz';

  // Продовый домен API (подтверждён заказчиком): https://crm.lima.uz/api
  static const String _prodHost = 'crm.lima.uz';

  /// Базовый хост текущего окружения (без схемы и пути).
  static String get host => isProd ? _prodHost : _devHost;

  /// Базовый URL REST API.
  static String get apiBaseUrl => 'https://$host/api';

  /// Хост для DNS-проверки реального доступа в интернет.
  static String get connectivityHost => host;
}
