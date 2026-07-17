import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../knowledge/providers/knowledge_repository_provider.dart';
import '../presentation/view_models/pharma_circle_view_model.dart';

final pharmaCircleViewModelProvider =
    StateNotifierProvider.autoDispose<
      PharmaCircleViewModel,
      PharmaCircleViewState
    >((ref) {
      return PharmaCircleViewModel(ref.watch(knowledgeRepositoryProvider));
    });
