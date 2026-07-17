import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/doctors_repository.dart';
import '../domain/repositories/doctors_directory_repository.dart';
import '../presentation/view_models/lpu_details_view_model.dart';

final doctorsDirectoryRepositoryProvider = Provider<DoctorsDirectoryRepository>(
  (ref) => ref.watch(doctorsRepositoryProvider),
);

final lpuDetailsViewModelProvider = StateNotifierProvider.autoDispose
    .family<LpuDetailsViewModel, LpuDetailsViewState, int>((
      ref,
      organizationId,
    ) {
      return LpuDetailsViewModel(
        ref.watch(doctorsDirectoryRepositoryProvider),
        organizationId,
      );
    });
