import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lima/core/config/env_config.dart';

final _baseUrl = EnvConfig.apiBaseUrl;
const _tokenKey = 'auth_token';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ApiClient(prefs);
});

class ApiClient {
  late final Dio _dio;
  final SharedPreferences _prefs;

  ApiClient(this._prefs) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Support both styles in codebase:
          // baseUrl with "/api" + request paths starting with "/api/...".
          // This prevents accidental ".../api/api/..." URLs.
          options.path = _normalizeRequestPath(
            baseUrl: options.baseUrl,
            path: options.path,
          );
          final token = _prefs.getString(_tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          // 401 → clear token
          if (error.response?.statusCode == 401) {
            _prefs.remove(_tokenKey);
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    await _prefs.remove(_tokenKey);
  }

  bool get hasToken => _prefs.containsKey(_tokenKey);
  String? get token => _prefs.getString(_tokenKey);
  SharedPreferences get prefs => _prefs;

  static String _normalizeRequestPath({
    required String baseUrl,
    required String path,
  }) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final normalizedBase = baseUrl.toLowerCase();
    if (normalizedBase.endsWith('/api') && path.startsWith('/api/')) {
      return path.substring('/api'.length);
    }
    return path;
  }
}
