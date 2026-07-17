import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/view_models/sync_screen_view_model.dart';
import 'sync_diagnostics_repository_provider.dart';

final syncScreenViewModelProvider =
    StateNotifierProvider.autoDispose<SyncScreenViewModel, SyncScreenViewState>(
      (ref) =>
          SyncScreenViewModel(ref.watch(syncDiagnosticsRepositoryProvider)),
    );
