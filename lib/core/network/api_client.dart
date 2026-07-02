import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // In-memory cache so hasToken/token stay synchronous (many call sites,
  // including startup routing, read them without awaiting) while the token
  // itself lives in secure storage, not plaintext SharedPreferences.
  String? _cachedToken;
  bool _tokenLoaded = false;

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
          if (_cachedToken != null) {
            options.headers['Authorization'] = 'Bearer $_cachedToken';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          // 401 → clear token
          if (error.response?.statusCode == 401) {
            unawaited(clearToken());
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Loads the token into memory, one-time-migrating a legacy plaintext
  /// token from SharedPreferences into secure storage if present. Must be
  /// awaited before the app reads [hasToken]/[token] — see the bootstrap in
  /// main.dart and background_sync_service.dart.
  Future<void> init() async {
    if (_tokenLoaded) return;
    var stored = await _storage.read(key: _tokenKey);
    final legacy = _prefs.getString(_tokenKey);
    if (legacy != null) {
      stored ??= legacy;
      await _storage.write(key: _tokenKey, value: stored);
      await _prefs.remove(_tokenKey);
    }
    _cachedToken = stored;
    _tokenLoaded = true;
  }

  Dio get dio => _dio;

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    _tokenLoaded = true;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    _tokenLoaded = true;
    await _storage.delete(key: _tokenKey);
  }

  bool get hasToken => _cachedToken != null;
  String? get token => _cachedToken;
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
