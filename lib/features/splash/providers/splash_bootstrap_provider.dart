import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/auth/credentials_storage.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/api_client.dart';
import '../data/splash_bootstrap_repository_impl.dart';
import '../domain/repositories/splash_bootstrap_repository.dart';

final splashBootstrapRepositoryProvider = Provider<SplashBootstrapRepository>((
  ref,
) {
  return SplashBootstrapRepositoryImpl(
    db: ref.watch(localDatabaseProvider),
    apiClient: ref.watch(apiClientProvider),
    credentials: ref.watch(credentialsStorageProvider),
  );
});
