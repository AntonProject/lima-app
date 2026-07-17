import 'dart:convert';
import 'package:lima/core/utils/swallowed.dart';

// ─── User / Auth ─────────────────────────────────────────────────────────────

class UserModel {
  final int id;
  final String fullName;
  final String role; // normalized: 'mp' | 'rm' | 'admin' (for permission logic)
  final String?
  roleName; // server's human-readable role (e.g. "Директор по маркетингу")
  final String? city;
  final int? regionId;
  final String? phone;
  final String? company;
  final int? companyId;
  final int visitsCount;
  final double salesAmount;
  final int doctorsCount;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.role,
    this.roleName,
    this.city,
    this.regionId,
    this.phone,
    this.company,
    this.companyId,
    this.visitsCount = 0,
    this.salesAmount = 0,
    this.doctorsCount = 0,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  /// The role exactly as the server reports it (e.g. "Директор по маркетингу").
  /// Falls back to a generic label only when the server sent nothing.
  String get roleLabel {
    final name = roleName?.trim() ?? '';
    return name.isNotEmpty ? name : 'Медицинский представитель';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as int,
    fullName: json['full_name'] as String,
    role: json['role'] as String,
    roleName: json['role_name'] as String?,
    city: json['city'] as String?,
    regionId: _toInt(json['region_id']),
    phone: json['phone'] as String?,
    company: json['company'] as String?,
    companyId: _toInt(json['company_id']),
    visitsCount: json['visits_count'] as int? ?? 0,
    salesAmount: (json['sales_amount'] as num?)?.toDouble() ?? 0,
    doctorsCount: json['doctors_count'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'role': role,
    'role_name': roleName,
    'city': city,
    'region_id': regionId,
    'phone': phone,
    'company': company,
    'company_id': companyId,
    'visits_count': visitsCount,
    'sales_amount': salesAmount,
    'doctors_count': doctorsCount,
  };
}

int? _toInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// SQLite has no real boolean type — flags are stored as INTEGER 0/1, but
/// the same field may arrive from the API as a JSON bool. Accept both.
bool _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return false;
}

String? _toStringOrNull(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty || s == 'null' ? null : s;
}

// ─── Organisation (ЛПУ / Аптека) ─────────────────────────────────────────────

enum OrgType { lpu, pharmacy, distributor }

OrgType _orgTypeFromRaw(dynamic raw) {
  final s = raw?.toString().toLowerCase() ?? '';
  if (s.contains('pharm') || s.contains('апт')) return OrgType.pharmacy;
  if (s.contains('distrib') || s.contains('дистриб')) {
    return OrgType.distributor;
  }
  return OrgType.lpu;
}

/// A pharmacy or LPU (ЛПУ), as stored in the local `organisations` table /
/// returned by the organisations API. Field set mirrors the SQLite schema
/// in local_database.dart — see that file for the authoritative source.
class Organisation {
  final int id;
  final String name;
  final String? nameRu;
  final String address;
  final OrgType type;
  final int? typeId;
  final String? typeName;
  final String? city;
  final int? regionId;
  final String? regionName;
  final String? district;
  final int? areaId;
  final String? areaName;
  final String? inn;
  final String? pinfl;
  final String? brand;
  final String? category;
  final int? categoryId;
  final String? responsible;
  final String? phone;
  final String? phone2;
  final String? phone3;
  final int? healthCareFacilityTypeId;
  final String? healthCareFacilityTypeName;
  final int? classificationId;
  final String? classificationName;
  final int? medRepId;
  final String? medRepName;
  final bool visited;
  final bool isBudget;
  final String? dateCreate;
  final String? revisionStatus;
  final double? latitude;
  final double? longitude;
  final double? distanceM;
  final bool isFavorite;
  final String? updatedAt;

  /// Raw server payload as last synced, decoded on demand via [rawJsonMap].
  /// The server sends extra fields not normalized into columns above (e.g.
  /// alternate phone/INN/partner-status spellings) — screens that need
  /// those should read this instead of adding one-off columns.
  final String? rawJson;

  const Organisation({
    required this.id,
    required this.name,
    this.nameRu,
    required this.address,
    required this.type,
    this.typeId,
    this.typeName,
    this.city,
    this.regionId,
    this.regionName,
    this.district,
    this.areaId,
    this.areaName,
    this.inn,
    this.pinfl,
    this.brand,
    this.category,
    this.categoryId,
    this.responsible,
    this.phone,
    this.phone2,
    this.phone3,
    this.healthCareFacilityTypeId,
    this.healthCareFacilityTypeName,
    this.classificationId,
    this.classificationName,
    this.medRepId,
    this.medRepName,
    this.visited = false,
    this.isBudget = false,
    this.dateCreate,
    this.revisionStatus,
    this.latitude,
    this.longitude,
    this.distanceM,
    this.isFavorite = false,
    this.updatedAt,
    this.rawJson,
  });

  bool get isLpu => type == OrgType.lpu;
  bool get isPharmacy => type == OrgType.pharmacy;

  /// Normalized display fields for legacy API rows whose names differ between
  /// SQLite and the server response. Screens should use these typed getters
  /// instead of reaching into [rawJsonMap].
  String? get displayPhone => _firstText(phone, rawJsonMap, const [
    'phone',
    'phone_1',
    'phone1',
    'phone_number',
  ]);

  String? get displayInn =>
      _firstText(inn, rawJsonMap, const ['inn', 'org_inn']);

  String? get displayResponsible => _firstText(responsible, rawJsonMap, const [
    'responsible',
    'responsible_person',
  ]);

  String? get displayDistrict =>
      _firstText(district, rawJsonMap, const ['district', 'area', 'area_name']);

  String? get displayCategory => _firstText(category, rawJsonMap, const [
    'category',
    'category_name',
    'class',
  ]);

  bool? get worksWithUs {
    final raw = rawJsonMap;
    final candidate =
        raw['is_working_with_us'] ??
        raw['working_with_us'] ??
        raw['is_partner'] ??
        raw['is_active_partner'] ??
        raw['visited'];
    if (candidate is bool) return candidate;
    if (candidate is num) return candidate != 0;
    if (candidate is String) {
      final normalized = candidate.toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return visited;
  }

  static String? _firstText(
    String? direct,
    Map<String, dynamic> raw,
    List<String> keys,
  ) {
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    for (final key in keys) {
      final value = _toStringOrNull(raw[key]);
      if (value != null) return value;
    }
    return null;
  }

  /// Decoded [rawJson], or an empty map if absent/invalid. Use for fields
  /// the server sends but aren't normalized into named columns.
  Map<String, dynamic> get rawJsonMap {
    final raw = rawJson;
    if (raw == null || raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (error) {
      logSwallowed(error, 'Organisation.rawJsonMap');
    }
    return const <String, dynamic>{};
  }

  factory Organisation.fromJson(Map<String, dynamic> json) => Organisation(
    id: _toInt(json['id']) ?? 0,
    name: _toStringOrNull(json['name']) ?? '',
    nameRu: _toStringOrNull(json['name_ru']),
    address: _toStringOrNull(json['address']) ?? '',
    type: _orgTypeFromRaw(json['type'] ?? json['type_name']),
    typeId: _toInt(json['type_id']),
    typeName: _toStringOrNull(json['type_name']),
    city: _toStringOrNull(json['city']),
    regionId: _toInt(json['region_id']),
    regionName: _toStringOrNull(json['region_name']),
    district: _toStringOrNull(json['district']),
    areaId: _toInt(json['area_id']),
    areaName: _toStringOrNull(json['area_name']),
    inn: _toStringOrNull(json['inn']),
    pinfl: _toStringOrNull(json['pinfl']),
    brand: _toStringOrNull(json['brand']),
    category: _toStringOrNull(json['category']),
    categoryId: _toInt(json['category_id']),
    responsible: _toStringOrNull(json['responsible']),
    phone: _toStringOrNull(json['phone']),
    phone2: _toStringOrNull(json['phone2']),
    phone3: _toStringOrNull(json['phone3']),
    healthCareFacilityTypeId: _toInt(json['health_care_facility_type_id']),
    healthCareFacilityTypeName: _toStringOrNull(
      json['health_care_facility_type_name'],
    ),
    classificationId: _toInt(json['classification_id']),
    classificationName: _toStringOrNull(json['classification_name']),
    medRepId: _toInt(json['med_rep_id']),
    medRepName: _toStringOrNull(json['med_rep_name']),
    visited: _toBool(json['visited']),
    isBudget: _toBool(json['is_budget']),
    dateCreate: _toStringOrNull(json['date_create']),
    revisionStatus: _toStringOrNull(json['revision_status']),
    latitude: _toDouble(json['latitude']),
    longitude: _toDouble(json['longitude']),
    distanceM: _toDouble(json['distance_m']),
    isFavorite: _toBool(json['is_favorite']),
    updatedAt: _toStringOrNull(json['updated_at']),
    rawJson: _toStringOrNull(json['raw_json']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'name_ru': nameRu,
    'address': address,
    'type': type.name,
    'type_id': typeId,
    'type_name': typeName,
    'city': city,
    'region_id': regionId,
    'region_name': regionName,
    'district': district,
    'area_id': areaId,
    'area_name': areaName,
    'inn': inn,
    'pinfl': pinfl,
    'brand': brand,
    'category': category,
    'category_id': categoryId,
    'responsible': responsible,
    'phone': phone,
    'phone2': phone2,
    'phone3': phone3,
    'health_care_facility_type_id': healthCareFacilityTypeId,
    'health_care_facility_type_name': healthCareFacilityTypeName,
    'classification_id': classificationId,
    'classification_name': classificationName,
    'med_rep_id': medRepId,
    'med_rep_name': medRepName,
    'visited': visited ? 1 : 0,
    'is_budget': isBudget ? 1 : 0,
    'date_create': dateCreate,
    'revision_status': revisionStatus,
    'latitude': latitude,
    'longitude': longitude,
    'distance_m': distanceM,
    'is_favorite': isFavorite ? 1 : 0,
    'updated_at': updatedAt,
    'raw_json': rawJson,
  };
}

// ─── Doctor ───────────────────────────────────────────────────────────────────

/// A doctor, as stored in the local `doctors` table / returned by the
/// doctors API. Field set mirrors the SQLite schema in local_database.dart,
/// plus the extra add-doctor fields (specialization/hobby/interests/
/// birthday) carried on `raw_json` for entries created through the newer
/// add-doctor form.
class Doctor {
  final int id;
  final String fullName;
  final String? specialty;
  final int? specializationId;
  final int organisationId;
  final bool isFavorite;
  final String? category;
  final String? lastVisitLabel;
  final String? phone;
  final String? hobby;
  final String? interests;
  final String? birthday;
  final String? updatedAt;

  /// Raw server payload as last synced, decoded on demand via [rawJsonMap].
  final String? rawJson;

  const Doctor({
    required this.id,
    required this.fullName,
    this.specialty,
    this.specializationId,
    required this.organisationId,
    this.isFavorite = false,
    this.category,
    this.lastVisitLabel,
    this.phone,
    this.hobby,
    this.interests,
    this.birthday,
    this.updatedAt,
    this.rawJson,
  });

  String? get displayCategory {
    if (category != null && category!.trim().isNotEmpty) {
      return category!.trim();
    }
    final raw = rawJsonMap;
    for (final key in const ['category', 'category_name', 'class']) {
      final value = _toStringOrNull(raw[key]);
      if (value != null) return value;
    }
    return null;
  }

  /// Decoded [rawJson], or an empty map if absent/invalid. Use for fields
  /// the server sends but aren't normalized into named columns.
  Map<String, dynamic> get rawJsonMap {
    final raw = rawJson;
    if (raw == null || raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (error) {
      logSwallowed(error, 'Doctor.rawJsonMap');
    }
    return const <String, dynamic>{};
  }

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
    id: _toInt(json['id']) ?? 0,
    fullName: _toStringOrNull(json['full_name'] ?? json['name']) ?? '',
    specialty: _toStringOrNull(json['specialty'] ?? json['position']),
    specializationId: _toInt(json['specialization_id']),
    organisationId:
        _toInt(json['organisation_id'] ?? json['organization_id']) ?? 0,
    isFavorite: _toBool(json['is_favorite']),
    category: _toStringOrNull(json['category']),
    lastVisitLabel: _toStringOrNull(json['last_visit_label']),
    phone: _toStringOrNull(json['phone']),
    hobby: _toStringOrNull(json['hobby']),
    interests: _toStringOrNull(json['interests']),
    birthday: _toStringOrNull(json['birthday']),
    updatedAt: _toStringOrNull(json['updated_at']),
    rawJson: _toStringOrNull(json['raw_json']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'specialty': specialty,
    'specialization_id': specializationId,
    'organisation_id': organisationId,
    'is_favorite': isFavorite ? 1 : 0,
    'category': category,
    'last_visit_label': lastVisitLabel,
    'phone': phone,
    'hobby': hobby,
    'interests': interests,
    'birthday': birthday,
    'updated_at': updatedAt,
    'raw_json': rawJson,
  };
}

// ─── Drug (Препарат) ──────────────────────────────────────────────────────────

class Drug {
  final int id;
  final String name;
  final String manufacturer;
  final String? serialNumber;
  final String? expiryDate;
  final double price;

  /// Общий остаток на основном складе.
  final int? mainStock;

  /// Доступный остаток по конкретной складской позиции/серии.
  final int? stock;
  final int? remainsStock;
  final int documentsCount;

  /// income_detailing_id from the price-list (= current_stock_id in cart).
  /// Used when creating a Бронь order via POST /api/Visits/add.
  final int? currentStockId;

  /// Binding-level drug ID (drug_binding.drug.id, not the dict drug_id).
  final int? bindingDrugId;

  const Drug({
    required this.id,
    required this.name,
    required this.manufacturer,
    this.serialNumber,
    this.expiryDate,
    required this.price,
    this.mainStock,
    this.stock,
    this.remainsStock,
    this.documentsCount = 0,
    this.currentStockId,
    this.bindingDrugId,
  });

  factory Drug.fromJson(Map<String, dynamic> json) => Drug(
    id: json['id'] as int,
    name: json['name'] as String,
    manufacturer: json['manufacturer'] as String,
    serialNumber: json['serial_number'] as String?,
    expiryDate: json['expiry_date'] as String?,
    price: (json['price'] as num).toDouble(),
    mainStock: (json['main_stock'] as num?)?.toInt(),
    stock: (json['stock'] as num?)?.toInt(),
    remainsStock: (json['remains_stock'] as num?)?.toInt(),
    documentsCount: json['documents_count'] as int? ?? 0,
    currentStockId: json['current_stock_id'] as int?,
    bindingDrugId: json['binding_drug_id'] as int?,
  );
}

// ─── Material (Document/Image) ────────────────────────────────────────────────

class DrugMaterial {
  final int id;
  final int? drugId;
  final int? documentId;
  final String title;
  final String? description;
  final String fileType; // 'image' | 'pdf'
  final String? documentTypeName;
  final String url;
  final String? fileName;
  final String? cachedPath;
  final String? uploadedAt;
  final bool isMandatory;

  const DrugMaterial({
    required this.id,
    this.drugId,
    this.documentId,
    required this.title,
    this.description,
    required this.fileType,
    this.documentTypeName,
    required this.url,
    this.fileName,
    this.cachedPath,
    this.uploadedAt,
    this.isMandatory = false,
  });

  factory DrugMaterial.fromJson(Map<String, dynamic> json) => DrugMaterial(
    id: _toInt(json['id']) ?? 0,
    drugId: _toInt(json['drug_id']),
    documentId: _toInt(json['document_id'] ?? json['remote_id'] ?? json['id']),
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString(),
    fileType: json['file_type']?.toString() ?? '',
    documentTypeName: json['document_type_name']?.toString(),
    url: (json['url'] ?? json['local_path'])?.toString() ?? '',
    fileName: json['file_name']?.toString(),
    cachedPath: json['cached_path']?.toString(),
    uploadedAt: json['uploaded_at']?.toString(),
    isMandatory: _toBool(json['is_mandatory']) ?? false,
  );

  static int? _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static bool? _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value == null) return null;
    final normalized = value.toString().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }
}

// ─── Visit Plan ───────────────────────────────────────────────────────────────

enum VisitStatus { planned, completed }

class PlannedVisit {
  final int id;
  final String organisationName;
  final int? organisationId;
  final OrgType? organisationType;
  final String? doctorName;
  final String assignedBy;
  final String? city;
  final String? district;
  final DateTime date;
  final VisitStatus status;
  // 'circle' | 'double' | 'group' | null
  final String? visitFormat;

  const PlannedVisit({
    required this.id,
    required this.organisationName,
    this.organisationId,
    this.organisationType,
    this.doctorName,
    required this.assignedBy,
    this.city,
    this.district,
    required this.date,
    required this.status,
    this.visitFormat,
  });

  factory PlannedVisit.fromJson(Map<String, dynamic> json) => PlannedVisit(
    id: json['id'] as int,
    organisationName: json['organisation_name'] as String,
    organisationId: json['organisation_id'] as int?,
    organisationType: (json['organisation_type'] as String?) == null
        ? null
        : ((json['organisation_type'] as String) == 'pharmacy'
              ? OrgType.pharmacy
              : OrgType.lpu),
    doctorName: json['doctor_name'] as String?,
    assignedBy: json['assigned_by'] as String,
    city: json['city'] as String?,
    district: json['district'] as String?,
    date: DateTime.parse(json['date'] as String),
    status: json['status'] == 'completed'
        ? VisitStatus.completed
        : VisitStatus.planned,
  );
}

// ─── Order (Бронь) ────────────────────────────────────────────────────────────

class OrderItem {
  final Drug drug;
  int quantity;

  OrderItem({required this.drug, required this.quantity});

  double get total => drug.price * quantity;
}

// ─── Stock Item (Снятие остатков) ─────────────────────────────────────────────

class StockItem {
  final Drug drug;
  int? quantity;

  StockItem({required this.drug, this.quantity});
}
