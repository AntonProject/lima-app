import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/visits_repository.dart';
import '../domain/repositories/history_repository.dart';
import '../presentation/view_models/history_view_model.dart';

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => ref.watch(visitsRepositoryProvider),
);

final historyViewModelProvider =
    StateNotifierProvider.autoDispose<HistoryViewModel, HistoryViewState>(
      (ref) => HistoryViewModel(ref.watch(historyRepositoryProvider)),
    );
