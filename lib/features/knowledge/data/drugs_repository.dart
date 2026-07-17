import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/local_database.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/material_cache_service.dart';
import '../domain/repositories/drug_catalogue_repository.dart';
import '../domain/repositories/knowledge_repository.dart';

/// Drug catalogue + materials. Owned by the knowledge feature, but visit
/// screens (orders, detailing, фармкружок) read the same local drug list
/// through this repository too.
class DrugsRepositoryImpl
    implements DrugCatalogueRepository, KnowledgeRepository {
  final LocalDatabase _db;
  final ApiClient _apiClient;

  DrugsRepositoryImpl(this._db, this._apiClient);

  Future<List<Map<String, dynamic>>> getDrugs({
    String? query,
    bool onlyWithPositivePrice = true,
    bool onlyWithDocuments = false,
  }) => _db.getDrugs(
    query: query,
    onlyWithPositivePrice: onlyWithPositivePrice,
    onlyWithDocuments: onlyWithDocuments,
  );

  @override
  Future<List<Drug>> getOrderDrugs() async {
    final rows = await getDrugs();
    return rows.map(_mapOrderDrug).whereType<Drug>().toList(growable: false);
  }

  @override
  Future<List<Drug>> getKnowledgeDrugs({
    String? query,
    bool onlyWithPositivePrice = true,
    bool onlyWithDocuments = false,
  }) async {
    final rows = await getDrugs(
      query: query,
      onlyWithPositivePrice: onlyWithPositivePrice,
      onlyWithDocuments: onlyWithDocuments,
    );
    return rows.map(_mapOrderDrug).whereType<Drug>().toList(growable: false);
  }

  @override
  Future<Drug?> getDrugModel(
    int drugId, {
    bool onlyWithPositivePrice = false,
  }) async {
    final drugs = await getKnowledgeDrugs(
      onlyWithPositivePrice: onlyWithPositivePrice,
    );
    for (final drug in drugs) {
      if (drug.id == drugId) return drug;
    }
    return null;
  }

  static Drug? _mapOrderDrug(Map<String, dynamic> row) {
    final id = _toInt(row['id']);
    if (id == null) return null;
    return Drug(
      id: id,
      name: row['name']?.toString() ?? '—',
      manufacturer: row['manufacturer']?.toString() ?? '',
      serialNumber: row['serial_number']?.toString(),
      expiryDate: row['expiry_date']?.toString(),
      price: _toDouble(row['price']),
      mainStock: _toInt(row['main_stock']),
      stock: _toInt(row['stock']),
      remainsStock: _toInt(row['remains_stock']),
      documentsCount: _toInt(row['documents_count']) ?? 0,
      currentStockId: _toInt(row['current_stock_id']),
      bindingDrugId: _toInt(row['binding_drug_id']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value == null) return null;
    final normalized = value.toString().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }

  Future<List<Map<String, dynamic>>> getDrugMaterials(int drugId) =>
      _db.getDrugMaterials(drugId);

  @override
  Future<List<DrugMaterial>> getDrugMaterialModels(int drugId) async {
    final rows = await getDrugMaterials(drugId);
    return rows.map(_mapMaterial).toList(growable: false);
  }

  @override
  Future<void> clearMaterialsCache() async {
    final cacheService = MaterialCacheService(
      dio: _apiClient.dio,
      authToken: _apiClient.token,
    );
    await cacheService.clearCache(_db);
    await _db.clearCachedStats();
  }

  static DrugMaterial _mapMaterial(Map<String, dynamic> row) {
    String? fileName;
    int? documentId = _toInt(row['document_id'] ?? row['remote_id']);
    String? documentTypeName = row['document_type_name']?.toString();
    final raw = row['raw_json'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          fileName ??= decoded['file_name']?.toString();
          documentId ??= _toInt(
            decoded['id'] ?? decoded['document_id'] ?? decoded['remote_id'],
          );
          documentTypeName ??= decoded['document_type_name']?.toString();
        }
      } catch (_) {
        // Optional metadata must not hide an otherwise valid material.
      }
    }
    return DrugMaterial(
      id: _toInt(row['id']) ?? 0,
      drugId: _toInt(row['drug_id']),
      documentId: documentId,
      title: row['title']?.toString() ?? '',
      description: row['description']?.toString(),
      fileType: row['file_type']?.toString() ?? '',
      documentTypeName: documentTypeName,
      url: row['local_path']?.toString() ?? '',
      fileName: fileName,
      cachedPath: row['cached_path']?.toString(),
      uploadedAt: row['uploaded_at']?.toString(),
      isMandatory: _toBool(row['is_mandatory']) ?? false,
    );
  }
}

final drugsRepositoryProvider = Provider<DrugsRepositoryImpl>((ref) {
  return DrugsRepositoryImpl(
    ref.watch(localDatabaseProvider),
    ref.watch(apiClientProvider),
  );
});

final drugCatalogueRepositoryProvider = Provider<DrugCatalogueRepository>(
  (ref) => ref.watch(drugsRepositoryProvider),
);
