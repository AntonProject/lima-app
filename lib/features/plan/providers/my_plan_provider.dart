import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/view_models/my_plan_view_model.dart';
import 'my_plan_repository_provider.dart';

final myPlanProvider =
    StateNotifierProvider.family<MyPlanViewModel, MyPlanViewState, int>((
      ref,
      year,
    ) {
      return MyPlanViewModel(ref.watch(myPlanRepositoryProvider), year);
    });
