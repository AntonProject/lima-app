import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../knowledge/providers/knowledge_repository_provider.dart';
import '../presentation/view_models/lpu_detailing_view_model.dart';
import 'lpu_details_provider.dart';

final lpuDetailingViewModelProvider = StateNotifierProvider.autoDispose
    .family<LpuDetailingViewModel, LpuDetailingViewState, int>((ref, orgId) {
      return LpuDetailingViewModel(
        ref.watch(doctorsDirectoryRepositoryProvider),
        ref.watch(knowledgeRepositoryProvider),
      );
    });
