import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/credentials_storage.dart';
import '../../../core/db/local_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/remote_api_service.dart';
import '../data/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(apiClientProvider),
    ref.watch(remoteApiServiceProvider),
    ref.watch(credentialsStorageProvider),
    ref.watch(localDatabaseProvider),
  );
});
