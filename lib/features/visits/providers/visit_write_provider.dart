import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/local_database.dart';
import '../../../core/network/remote_api_service.dart';
import '../data/visit_write_repository_impl.dart';
import '../domain/repositories/visit_write_repository.dart';

final visitWriteRepositoryProvider = Provider<VisitWriteRepository>((ref) {
  return VisitWriteRepositoryImpl(
    ref.watch(localDatabaseProvider),
    ref.watch(remoteApiServiceProvider),
  );
});
