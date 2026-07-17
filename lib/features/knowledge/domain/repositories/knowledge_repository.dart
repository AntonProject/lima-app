import 'package:lima/core/models/models.dart';

/// Typed read contract for the knowledge base.
///
/// SQLite/API row conversion belongs to the data implementation. Screens use
/// this contract for both the catalogue and its local material metadata.
abstract interface class KnowledgeRepository {
  Future<List<Drug>> getKnowledgeDrugs({
    String? query,
    bool onlyWithPositivePrice = true,
    bool onlyWithDocuments = false,
  });

  Future<Drug?> getDrugModel(int drugId, {bool onlyWithPositivePrice = false});

  Future<List<DrugMaterial>> getDrugMaterialModels(int drugId);

  Future<void> clearMaterialsCache();
}
