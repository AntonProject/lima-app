import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/view_models/plan_calendar_view_model.dart';

final planCalendarProvider =
    StateNotifierProvider.autoDispose<
      PlanCalendarViewModel,
      PlanCalendarViewState
    >((ref) => PlanCalendarViewModel());
