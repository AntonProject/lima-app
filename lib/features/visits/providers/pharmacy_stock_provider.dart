import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../knowledge/providers/knowledge_repository_provider.dart';
import '../presentation/view_models/pharmacy_stock_view_model.dart';

final pharmacyStockViewModelProvider =
    StateNotifierProvider.autoDispose<
      PharmacyStockViewModel,
      PharmacyStockViewState
    >((ref) {
      return PharmacyStockViewModel(ref.watch(knowledgeRepositoryProvider));
    });
