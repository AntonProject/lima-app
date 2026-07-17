import 'dart:io';

import 'package:lima/core/auth/credentials_storage.dart';
import 'package:lima/core/config/env_config.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/api_client.dart';
import 'package:lima/core/utils/swallowed.dart';
import '../domain/repositories/splash_bootstrap_repository.dart';

class SplashBootstrapRepositoryImpl implements SplashBootstrapRepository {
  final LocalDatabase _db;
  final ApiClient _apiClient;
  final CredentialsStorage _credentials;

  const SplashBootstrapRepositoryImpl({
    required LocalDatabase db,
    required ApiClient apiClient,
    required CredentialsStorage credentials,
  }) : _db = db,
       _apiClient = apiClient,
       _credentials = credentials;

  @override
  Future<void> initializeDatabase() => _db.init();

  @override
  Future<bool> hasRealInternet() async {
    try {
      final result = await InternetAddress.lookup(
        EnvConfig.connectivityHost,
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (error, stackTrace) {
      logSwallowed(
        error,
        'SplashBootstrapRepository.hasRealInternet',
        stackTrace,
      );
      return false;
    }
  }

  @override
  bool get hasApiToken => _apiClient.hasToken;

  @override
  Future<({String login, String password})?> loadCredentials() =>
      _credentials.load();

  @override
  Future<bool> hasOfflineSessionFor(String login) =>
      _db.hasUsableOfflineSessionForLogin(login);

  @override
  Future<bool> hasLocalOrganizations() async =>
      (await _db.getOrganisations()).isNotEmpty;
}
