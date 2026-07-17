import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/view_models/lpu_doctor_select_view_model.dart';

final lpuDoctorSelectViewModelProvider = StateNotifierProvider.autoDispose
    .family<LpuDoctorSelectViewModel, LpuDoctorSelectionState, int>(
      (ref, _) => LpuDoctorSelectViewModel(),
    );
