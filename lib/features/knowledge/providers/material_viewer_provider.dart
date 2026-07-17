import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/view_models/material_viewer_view_model.dart';
import 'knowledge_repository_provider.dart';
import 'material_access_provider.dart';

typedef MaterialViewerKey = ({int drugId, int initialIndex});

final materialViewerViewModelProvider = StateNotifierProvider.autoDispose
    .family<
      MaterialViewerViewModel,
      MaterialViewerViewState,
      MaterialViewerKey
    >(
      (ref, key) => MaterialViewerViewModel(
        ref.watch(knowledgeRepositoryProvider),
        ref.watch(materialAccessServiceProvider),
        drugId: key.drugId,
        initialIndex: key.initialIndex,
      ),
    );
