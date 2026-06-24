/// Единая точка конфигурации окружения (prod ↔ dev).
///
/// По умолчанию приложение работает на ПРОДЕ (`crm.lima.uz`): `flutter run`,
/// релизные сборки и автодеплой идут на прод без каких-либо флагов запуска.
///
/// Когда нужен ТЕСТ на dev (`dev.lima.uz`) — переключается ОДНОЙ строкой в
/// коде: [_useDev] → `true`. После теста вернуть в `false`. Флаги
/// `--dart-define` намеренно не используются, чтобы «запустить» = просто
/// `flutter run`, а окружение определялось только этим файлом.
class EnvConfig {
  EnvConfig._();

  /// Единственный переключатель окружения.
  /// `false` = прод (по умолчанию), `true` = dev (только для теста).
  static const bool _useDev = false;

  static const String _prodHost = 'crm.lima.uz';
  static const String _devHost = 'dev.lima.uz';

  static bool get isProd => !_useDev;

  /// Базовый хост текущего окружения (без схемы и пути).
  static String get host => _useDev ? _devHost : _prodHost;

  /// Базовый URL REST API.
  static String get apiBaseUrl => 'https://$host/api';

  /// Хост для DNS-проверки реального доступа в интернет.
  static String get connectivityHost => host;
}
