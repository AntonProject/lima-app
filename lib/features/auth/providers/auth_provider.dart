import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/credentials_storage.dart';
import '../../../core/db/local_database.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/remote_api_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    errorMessage: errorMessage,
  );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final RemoteApiService _remoteApi;
  final CredentialsStorage _creds;
  final LocalDatabase _db;

  AuthNotifier(this._api, this._remoteApi, this._creds, this._db)
    : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      if (_api.hasToken) {
        state = state.copyWith(status: AuthStatus.loading);
        await _fetchProfile();
        return;
      }

      // No token — try silent re-auth with saved credentials
      final saved = await _creds.load();
      if (saved != null) {
        state = state.copyWith(status: AuthStatus.loading);
        final ok = await _silentReauth(saved.login, saved.password);
        if (ok) return;
      }
    } catch (_) {
      // Keychain/storage failure (common on iOS first launch) — fall through to unauthenticated
    }
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  Future<bool> silentReauth() async {
    final saved = await _creds.load();
    if (saved == null) return false;
    return _silentReauth(saved.login, saved.password);
  }

  Future<bool> _silentReauth(String login, String password) async {
    try {
      await _creds.setCurrentLogin(login);
      final token = await _remoteApi.authorize(login: login, password: password);
      await _api.saveToken(token);
      await _fetchProfile(login: login);
      return state.status == AuthStatus.authenticated;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchProfile({String? login}) async {
    try {
      final data = await _remoteApi.getCurrentUser();
      final stats = await _loadStatisticsFallback(data);
      final user = UserModel(
        id: (data['id'] as num?)?.toInt() ?? (data['user_id'] as num?)?.toInt() ?? 0,
        fullName: _extractFullName(data),
        role: _normalizeRole(data['role'] ?? data['role_name'] ?? data['user_role']),
        city: _extractCity(data),
        phone: _extractPhone(data),
        company: _extractCompany(
          data['company_name'] ?? data['company'] ?? data['company_title'] ?? data['organization_name'],
        ),
        visitsCount: stats.visitsCount,
        salesAmount: stats.salesAmount,
        doctorsCount: stats.doctorsCount,
      );

      if (user.fullName.isEmpty) throw const FormatException('User profile is empty');

      final owner = await _db.getCurrentUserOwner();
      final effectiveLogin = login ?? owner.login;
      if (effectiveLogin == null || effectiveLogin.isEmpty) {
        throw const FormatException('Login is required to bind local user data');
      }
      if (owner.login != null && owner.login != effectiveLogin) {
        await _db.clearUserScopedData();
      }

      await _db.setCurrentUserOwner(
        userId: user.id,
        login: effectiveLogin,
        role: user.role,
      );
      await _api.prefs.setString(_cachedUserKeyFor(effectiveLogin), jsonEncode(user.toJson()));

      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } on DioException catch (e) {
      final isNetworkError = e.response == null ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      if (isNetworkError) {
        // Network unavailable — use cached profile, keep token
        final loaded = await loginOfflineWithCache();
        if (!loaded) {
          await _api.clearToken();
          state = state.copyWith(status: AuthStatus.unauthenticated);
        }
      } else {
        // Auth error (401 etc.) — token is invalid
        await _api.clearToken();
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      await _api.clearToken();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> refreshProfile() => _fetchProfile();

  Future<({int visitsCount, double salesAmount, int doctorsCount})>
  _loadStatisticsFallback(Map<String, dynamic> profile) async {
    return (
      visitsCount: (profile['visits_count'] as num?)?.toInt() ?? 0,
      salesAmount: (profile['sales_amount'] as num?)?.toDouble() ?? 0,
      doctorsCount: (profile['doctors_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final token = await _remoteApi.authorize(login: username, password: password);
      await _api.saveToken(token);
      await _creds.save(username, password);
      await _fetchProfile(login: username);
    } on DioException catch (e) {
      final isNetworkError = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.response == null;

      if (isNetworkError) {
        // Offline — try to log in locally with saved credentials + cached profile
        await _tryOfflineLogin(username, password);
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Неверный логин или пароль',
        );
      }
    } on Exception {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Неверный логин или пароль',
      );
    }
  }

  Future<void> _tryOfflineLogin(String username, String password) async {
    final saved = await _creds.loadForLogin(username);
    final ownerMatches = await _db.matchesCurrentUserOwner(login: username);
    final hasOwnedData = await _db.hasUsableOfflineSessionForLogin(username);
    final cachedJson = _api.prefs.getString(_cachedUserKeyFor(username));

    if (saved == null || cachedJson == null || !ownerMatches || !hasOwnedData) {
      // No cached profile at all — need internet for first login
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Нет подключения к интернету',
      );
      return;
    }

    final credsMatch = saved.login == username && saved.password == password;

    if (!credsMatch) {
      // Different user trying to access — deny
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Неверный логин или пароль',
      );
      return;
    }

    try {
      final user = UserModel.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
      await _creds.setCurrentLogin(username);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Нет подключения к интернету',
      );
    }
  }

  static String? _extractCompany(dynamic value) {
    if (value == null) return null;
    if (value is Map) return value['name']?.toString();
    return value.toString();
  }

  static String _extractFullName(Map<String, dynamic> data) {
    return (data['full_name'] ?? data['fio'] ?? data['name'] ?? data['user_name'] ?? '')
        .toString()
        .trim();
  }

  static String? _extractCity(Map<String, dynamic> data) {
    return (data['city'] ?? data['city_name'] ?? data['region_name'] ?? data['region'] ?? data['district_name'])
        ?.toString();
  }

  static String? _extractPhone(Map<String, dynamic> data) {
    final raw = (data['phone'] ?? data['phone_number'] ?? data['mobile'] ?? '').toString().trim();
    return raw.isEmpty ? null : raw;
  }

  static String _normalizeRole(dynamic rawRole) {
    final value = (rawRole ?? '').toString().trim().toLowerCase();
    if (value.isEmpty) return 'mp';
    if (value == 'admin' || value == 'administrator' || value.contains('админ')) return 'admin';
    if (value == 'rm' || value == 'regional_manager' || value == 'regional manager' || value.contains('регион')) return 'rm';
    return 'mp';
  }

  /// Logs in using the cached profile (offline mode, no network needed).
  /// Returns true if a cached profile was found and loaded.
  Future<bool> loginOfflineWithCache() async {
    final saved = await _creds.load();
    if (saved == null) return false;
    if (!await _db.hasUsableOfflineSessionForLogin(saved.login)) return false;
    final cachedJson = _api.prefs.getString(_cachedUserKeyFor(saved.login));
    if (cachedJson == null) return false;
    try {
      final user = UserModel.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    // Credentials kept intentionally — silent re-auth on next network return
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  static String _cachedUserKeyFor(String login) => 'cached_user_profile::$login';
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  final remoteApi = ref.watch(remoteApiServiceProvider);
  final creds = ref.watch(credentialsStorageProvider);
  final db = ref.watch(localDatabaseProvider);
  return AuthNotifier(api, remoteApi, creds, db);
});
