import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/local_database.dart';
import '../../../core/network/remote_api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/my_plan_repository_impl.dart';
import '../domain/repositories/my_plan_repository.dart';

final myPlanRepositoryProvider = Provider<MyPlanRepository>((ref) {
  final userId = ref.watch(authProvider.select((state) => state.user?.id ?? 0));
  return MyPlanRepositoryImpl(
    ref.watch(remoteApiServiceProvider),
    ref.watch(localDatabaseProvider),
    userId: userId,
  );
});
