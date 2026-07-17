import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../visits/data/visits_repository.dart';
import '../data/home_repository_impl.dart';
import '../domain/repositories/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepositoryImpl(ref.watch(visitsRepositoryProvider));
});
