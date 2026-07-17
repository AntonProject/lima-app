import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/visit_interaction_repository.dart';
import '../data/visits_repository.dart';

final visitInteractionRepositoryProvider = Provider<VisitInteractionRepository>(
  (ref) => ref.watch(visitsRepositoryProvider),
);
