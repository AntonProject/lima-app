import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/auth/credentials_storage.dart';
import '../../../core/db/local_database.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/remote_api_service.dart';
import '../domain/mappers/user_profile_mapper.dart';
import '../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _api;
  final RemoteApiService _remoteApi;
  final CredentialsStorage _credentials;
  final LocalDatabase _db;

  const AuthRepositoryImpl(
    this._api,
    this._remoteApi,
    this._credentials,
    this._db,
  );

  @override
  Future<UserModel?> restoreSession() async {
    try {
      if (_api.hasToken) {
        return await _fetchProfile();
      }

      final saved = await _credentials.load();
      if (saved == null) return null;
      return await _reauthenticate(saved.login, saved.password);
    } on DioException catch (error) {
      if (_isNetworkError(error)) return loginOfflineWithCache();
      await _api.clearToken();
      return null;
    } catch (_) {
      await _api.clearToken();
      return null;
    }
  }

  @override
  Future<UserModel?> silentReauth() async {
    final saved = await _credentials.load();
    if (saved == null) return null;
    try {
      return await _reauthenticate(saved.login, saved.password);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserModel?> login(String username, String password) async {
    try {
      final token = await _remoteApi.authorize(
        login: username,
        password: password,
      );
      await _api.saveToken(token);
      await _credentials.save(username, password);
      return await _fetchProfile(login: username);
    } on DioException catch (error) {
      if (_isNetworkError(error)) {
        final offlineUser = await _loadCachedProfile(
          username,
          password,
          requireMatchingCredentials: true,
        );
        if (offlineUser != null) return offlineUser;
        throw const AuthRepositoryFailure('errCannotConnect');
      }
      throw const AuthRepositoryFailure('errInvalidCredentials');
    } on AuthRepositoryFailure {
      rethrow;
    } catch (_) {
      throw const AuthRepositoryFailure('errInvalidCredentials');
    }
  }

  @override
  Future<UserModel?> loginOfflineWithCache() async {
    final saved = await _credentials.load();
    if (saved == null) return null;
    return _loadCachedProfile(saved.login, saved.password);
  }

  @override
  Future<UserModel?> refreshProfile() async {
    try {
      return await _fetchProfile();
    } on DioException catch (error) {
      if (_isNetworkError(error)) return loginOfflineWithCache();
      await _api.clearToken();
      return null;
    } catch (_) {
      await _api.clearToken();
      return null;
    }
  }

  @override
  Future<void> logout() => _api.clearToken();

  Future<UserModel> _reauthenticate(String login, String password) async {
    await _credentials.setCurrentLogin(login);
    final token = await _remoteApi.authorize(login: login, password: password);
    await _api.saveToken(token);
    return _fetchProfile(login: login);
  }

  Future<UserModel> _fetchProfile({String? login}) async {
    final data = await _remoteApi.getCurrentUser();
    final user = UserProfileMapper.fromApi(data);
    if (user.fullName.isEmpty) {
      throw const FormatException('User profile is empty');
    }

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
    await _api.prefs.setString(
      _cachedUserKeyFor(effectiveLogin),
      jsonEncode(user.toJson()),
    );
    return user;
  }

  Future<UserModel?> _loadCachedProfile(
    String username,
    String password, {
    bool requireMatchingCredentials = false,
  }) async {
    final saved = await _credentials.loadForLogin(username);
    final cachedJson = _api.prefs.getString(_cachedUserKeyFor(username));
    if (saved == null || cachedJson == null) return null;
    if (requireMatchingCredentials && saved.password != password) {
      throw const AuthRepositoryFailure('errInvalidCredentials');
    }

    try {
      final user = UserModel.fromJson(
        jsonDecode(cachedJson) as Map<String, dynamic>,
      );
      final owner = await _db.getCurrentUserOwner();
      if (owner.login != null && owner.login != username) {
        await _db.clearUserScopedData();
      }
      await _db.setCurrentUserOwner(
        userId: user.id,
        login: username,
        role: user.role,
      );
      await _credentials.setCurrentLogin(username);
      return user;
    } catch (_) {
      return null;
    }
  }

  static bool _isNetworkError(DioException error) =>
      error.response == null ||
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;

  static String _cachedUserKeyFor(String login) =>
      'cached_user_profile::$login';
}
