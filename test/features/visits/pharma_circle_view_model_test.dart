import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/knowledge/domain/repositories/knowledge_repository.dart';
import 'package:lima/features/visits/presentation/view_models/pharma_circle_view_model.dart';

class _FakeKnowledgeRepository implements KnowledgeRepository {
  final List<Drug> drugs;
  int calls = 0;

  _FakeKnowledgeRepository(this.drugs);

  @override
  Future<List<Drug>> getKnowledgeDrugs({
    String? query,
    bool onlyWithPositivePrice = true,
    bool onlyWithDocuments = false,
  }) async {
    calls++;
    return drugs;
  }

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
  test(
    'keeps immutable catalogue state and deduplicates concurrent loads',
    () async {
      final repository = _FakeKnowledgeRepository([
        const Drug(id: 1, name: 'Aspirin', manufacturer: 'Factory', price: 1),
        const Drug(
          id: 2,
          name: 'Amoxicillin',
          manufacturer: 'Factory',
          price: 1,
        ),
      ]);
      final viewModel = PharmaCircleViewModel(repository);
      addTearDown(viewModel.dispose);

      await Future.wait([viewModel.load(), viewModel.load()]);

      expect(repository.calls, 1);
      expect(viewModel.state.filteredDrugs, hasLength(2));
      viewModel.setQuery('amox');
      expect(viewModel.state.filteredDrugs.single.id, 2);

      viewModel.markMaterialShown(
        drugId: 2,
        drugName: 'Amoxicillin',
        documentId: 9,
      );
      expect(viewModel.state.shownMaterialsCount, 1);
      expect(viewModel.state.shownDrugNamesByDrug[2], 'Amoxicillin');

      viewModel.clearShownMaterials(2);
      expect(viewModel.state.shownMaterialsCount, 0);
      expect(viewModel.state.shownDrugNamesByDrug, isEmpty);
    },
  );
}
