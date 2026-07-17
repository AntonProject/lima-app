import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/form_dictionaries_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../presentation/view_models/add_pharmacy_view_model.dart';
import 'visits_hub_provider.dart';

final addPharmacyViewModelProvider = StateNotifierProvider.autoDispose
    .family<AddPharmacyViewModel, AddPharmacyViewState, bool>((ref, isLpu) {
      return AddPharmacyViewModel(
        ref.watch(formDictionariesProvider),
        ref.watch(organisationsDirectoryRepositoryProvider),
        isLpu: isLpu,
        user: ref.watch(authProvider).user,
      );
    });
