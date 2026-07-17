import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/drugs_repository.dart';
import '../domain/repositories/knowledge_repository.dart';

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  return ref.watch(drugsRepositoryProvider);
});
