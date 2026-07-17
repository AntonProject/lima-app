import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/local_database.dart';
import '../data/sync_diagnostics_repository.dart';
import '../domain/repositories/sync_diagnostics_repository.dart';

final syncDiagnosticsRepositoryProvider = Provider<SyncDiagnosticsRepository>((
  ref,
) {
  return SyncDiagnosticsRepositoryImpl(ref.watch(localDatabaseProvider));
});
