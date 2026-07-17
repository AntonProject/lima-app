import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/knowledge/domain/repositories/knowledge_repository.dart';
import 'package:lima/features/visits/presentation/view_models/pharmacy_stock_view_model.dart';

class _FakeKnowledgeRepository implements KnowledgeRepository {
  @override
  Future<List<Drug>> getKnowledgeDrugs({
    String? query,
    bool onlyWithPositivePrice = true,
    bool onlyWithDocuments = false,
  }) async => const [
    Drug(
      id: 1,
      name: 'Drug',
      manufacturer: 'Factory',
      price: 10,
      stock: 5,
      remainsStock: 5,
    ),
  ];

  @override
  Future<Drug?> getDrugModel(
    int drugId, {
    bool onlyWithPositivePrice = false,
  }) async => null;

  @override
  Future<List<DrugMaterial>> getDrugMaterialModels(int drugId) async => [];

  @override
  Future<void> clearMaterialsCache() async {}
}

void main() {
  test('keeps quantity validation in immutable stock state', () async {
    final viewModel = PharmacyStockViewModel(_FakeKnowledgeRepository());
    addTearDown(viewModel.dispose);

    await viewModel.load();
    viewModel.setQuantity(1, 6);
    expect(viewModel.state.selectedCount, 6);
    expect(viewModel.state.hasInvalidSelectedQty, isTrue);

    viewModel.setQuantity(1, 5);
    expect(viewModel.state.hasInvalidSelectedQty, isFalse);
    viewModel.setQuery('drug');
    expect(viewModel.state.filteredDrugs.single.id, 1);
  });
}
