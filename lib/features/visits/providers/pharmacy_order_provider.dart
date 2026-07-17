import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pharmacy_order_draft_repository_impl.dart';
import '../data/visits_repository.dart';
import '../presentation/view_models/pharmacy_order_view_model.dart';
import '../domain/repositories/pharmacy_order_draft_repository.dart';
import '../domain/repositories/pharmacy_order_repository.dart';
import '../domain/use_cases/submit_pharmacy_order.dart';
import '../../knowledge/data/drugs_repository.dart';
import '../../knowledge/domain/repositories/drug_catalogue_repository.dart';
import '../../../core/db/local_database.dart';
import '../../../core/network/remote_api_service.dart';

final submitPharmacyOrderProvider = Provider<SubmitPharmacyOrder>((ref) {
  return SubmitPharmacyOrder(ref.watch(visitsRepositoryProvider));
});

final pharmacyOrderRepositoryProvider = Provider<PharmacyOrderRepository>(
  (ref) => ref.watch(visitsRepositoryProvider),
);

final pharmacyOrderDraftRepositoryProvider =
    Provider<PharmacyOrderDraftRepository>((ref) {
      return PharmacyOrderDraftRepositoryImpl(
        ref.watch(localDatabaseProvider),
        ref.watch(remoteApiServiceProvider),
      );
    });

final pharmacyOrderDrugRepositoryProvider = Provider<DrugCatalogueRepository>(
  (ref) => ref.watch(drugCatalogueRepositoryProvider),
);

final pharmacyOrderViewModelProvider = StateNotifierProvider.autoDispose
    .family<
      PharmacyOrderViewModel,
      PharmacyOrderViewState,
      PharmacyOrderViewModelConfig
    >(
      (ref, config) => PharmacyOrderViewModel(
        ref.watch(pharmacyOrderDrugRepositoryProvider),
        ref.watch(submitPharmacyOrderProvider),
        ref.watch(pharmacyOrderDraftRepositoryProvider),
        config,
      ),
    );
