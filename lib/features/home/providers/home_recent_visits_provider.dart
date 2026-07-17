import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/view_models/home_recent_visits_view_model.dart';
import 'home_repository_provider.dart';

final homeRecentVisitsProvider =
    StateNotifierProvider<HomeRecentVisitsViewModel, HomeRecentVisitsState>(
      (ref) => HomeRecentVisitsViewModel(ref.watch(homeRepositoryProvider)),
    );
