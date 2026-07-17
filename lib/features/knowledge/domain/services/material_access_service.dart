import 'package:lima/core/models/models.dart';

abstract interface class MaterialAccessService {
  Future<String> ensureLocal(
    DrugMaterial material, {
    required String cacheName,
  });
}
