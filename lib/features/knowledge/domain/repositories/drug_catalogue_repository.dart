import 'package:lima/core/models/models.dart';

abstract interface class DrugCatalogueRepository {
  Future<List<Drug>> getOrderDrugs();
}
