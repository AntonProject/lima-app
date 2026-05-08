// ─── User / Auth ─────────────────────────────────────────────────────────────

class UserModel {
  final int id;
  final String fullName;
  final String role; // 'mp' | 'rm' | 'admin'
  final String? city;
  final int? regionId;
  final String? phone;
  final String? company;
  final int visitsCount;
  final double salesAmount;
  final int doctorsCount;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.role,
    this.city,
    this.regionId,
    this.phone,
    this.company,
    this.visitsCount = 0,
    this.salesAmount = 0,
    this.doctorsCount = 0,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'Администратор';
      case 'rm':
        return 'Региональный менеджер';
      default:
        return 'Медицинский представитель';
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as int,
    fullName: json['full_name'] as String,
    role: json['role'] as String,
    city: json['city'] as String?,
    regionId: _toInt(json['region_id']),
    phone: json['phone'] as String?,
    company: json['company'] as String?,
    visitsCount: json['visits_count'] as int? ?? 0,
    salesAmount: (json['sales_amount'] as num?)?.toDouble() ?? 0,
    doctorsCount: json['doctors_count'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'role': role,
    'city': city,
    'region_id': regionId,
    'phone': phone,
    'company': company,
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

// ─── Organisation (ЛПУ / Аптека) ─────────────────────────────────────────────

enum OrgType { lpu, pharmacy }

class Organisation {
  final int id;
  final String name;
  final String address;
  final OrgType type;
  final String? city;

  const Organisation({
    required this.id,
    required this.name,
    required this.address,
    required this.type,
    this.city,
  });

  factory Organisation.fromJson(Map<String, dynamic> json) => Organisation(
    id: json['id'] as int,
    name: json['name'] as String,
    address: json['address'] as String,
    type: json['type'] == 'pharmacy' ? OrgType.pharmacy : OrgType.lpu,
    city: json['city'] as String?,
  );
}

// ─── Doctor ───────────────────────────────────────────────────────────────────

class Doctor {
  final int id;
  final String fullName;
  final String? specialty;
  final int organisationId;
  bool isFavorite;

  Doctor({
    required this.id,
    required this.fullName,
    this.specialty,
    required this.organisationId,
    this.isFavorite = false,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
    id: json['id'] as int,
    fullName: json['full_name'] as String,
    specialty: json['specialty'] as String?,
    organisationId: json['organisation_id'] as int,
    isFavorite: json['is_favorite'] as bool? ?? false,
  );
}

// ─── Drug (Препарат) ──────────────────────────────────────────────────────────

class Drug {
  final int id;
  final String name;
  final String manufacturer;
  final String? serialNumber;
  final String? expiryDate;
  final double price;
  final int? stock;
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
    this.stock,
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
    stock: json['stock'] as int?,
    documentsCount: json['documents_count'] as int? ?? 0,
    currentStockId: json['current_stock_id'] as int?,
    bindingDrugId: json['binding_drug_id'] as int?,
  );
}

// ─── Material (Document/Image) ────────────────────────────────────────────────

class DrugMaterial {
  final int id;
  final String title;
  final String? description;
  final String fileType; // 'image' | 'pdf'
  final String url;
  final String? uploadedAt;
  final bool isMandatory;

  const DrugMaterial({
    required this.id,
    required this.title,
    this.description,
    required this.fileType,
    required this.url,
    this.uploadedAt,
    this.isMandatory = false,
  });

  factory DrugMaterial.fromJson(Map<String, dynamic> json) => DrugMaterial(
    id: json['id'] as int,
    title: json['title'] as String,
    description: json['description'] as String?,
    fileType: json['file_type'] as String,
    url: json['url'] as String,
    uploadedAt: json['uploaded_at'] as String?,
    isMandatory: json['is_mandatory'] as bool? ?? false,
  );
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
  final DateTime date;
  final VisitStatus status;

  const PlannedVisit({
    required this.id,
    required this.organisationName,
    this.organisationId,
    this.organisationType,
    this.doctorName,
    required this.assignedBy,
    this.city,
    required this.date,
    required this.status,
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
