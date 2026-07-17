import '../../../../core/models/models.dart';

/// Maps the different profile shapes returned by the API into the stable
/// user model consumed by auth and feature permissions.
class UserProfileMapper {
  const UserProfileMapper._();

  static UserModel fromApi(Map<String, dynamic> data) {
    return UserModel(
      id:
          (data['id'] as num?)?.toInt() ??
          (data['user_id'] as num?)?.toInt() ??
          0,
      fullName: _extractFullName(data),
      role: _normalizeRole(
        data['role'] ?? data['role_name'] ?? data['user_role'],
      ),
      roleName: _extractRoleName(data),
      city: _extractCity(data),
      regionId: _extractRegionId(data),
      phone: _extractPhone(data),
      company: _extractCompany(
        data['company_name'] ??
            data['company'] ??
            data['company_title'] ??
            data['organization_name'],
      ),
      companyId: _extractCompanyId(
        data['company_id'] ??
            data['companyId'] ??
            data['company'] ??
            data['sale_company'],
      ),
      visitsCount: (data['visits_count'] as num?)?.toInt() ?? 0,
      salesAmount: (data['sales_amount'] as num?)?.toDouble() ?? 0,
      doctorsCount: (data['doctors_count'] as num?)?.toInt() ?? 0,
    );
  }

  static String? _extractCompany(dynamic value) {
    if (value == null) return null;
    if (value is Map) return value['name']?.toString();
    return value.toString();
  }

  static int? _extractCompanyId(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is Map) {
      final id = value['id'] ?? value['company_id'];
      if (id is num) return id.toInt();
      if (id is String) return int.tryParse(id);
    }
    return null;
  }

  static String _extractFullName(Map<String, dynamic> data) {
    return (data['full_name'] ??
            data['fio'] ??
            data['name'] ??
            data['user_name'] ??
            '')
        .toString()
        .trim();
  }

  static String? _extractCity(Map<String, dynamic> data) {
    return (data['city'] ??
            data['city_name'] ??
            data['region_name'] ??
            _nestedName(data['region']) ??
            data['region'] ??
            data['district_name'])
        ?.toString();
  }

  static int? _extractRegionId(Map<String, dynamic> data) {
    final direct = data['region_id'] ?? data['regionId'];
    if (direct is num) return direct.toInt();
    if (direct is String) return int.tryParse(direct);
    final region = data['region'];
    if (region is Map) {
      final id = region['id'] ?? region['region_id'];
      if (id is num) return id.toInt();
      if (id is String) return int.tryParse(id);
    }
    return null;
  }

  static String? _nestedName(dynamic value) {
    if (value is Map) {
      return (value['name'] ?? value['title'] ?? value['name_ru'])?.toString();
    }
    return null;
  }

  static String? _extractPhone(Map<String, dynamic> data) {
    final raw = (data['phone'] ?? data['phone_number'] ?? data['mobile'] ?? '')
        .toString()
        .trim();
    return raw.isEmpty ? null : raw;
  }

  static String? _extractRoleName(Map<String, dynamic> data) {
    for (final key in const ['role_name', 'role_title', 'position', 'role']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'mp' || normalized == 'rm' || normalized == 'admin') {
          continue;
        }
        return value.trim();
      }
    }
    return null;
  }

  static String _normalizeRole(dynamic rawRole) {
    final value = (rawRole ?? '').toString().trim().toLowerCase();
    if (value.isEmpty) return 'mp';
    if (value == 'admin' ||
        value == 'administrator' ||
        value.contains('админ')) {
      return 'admin';
    }
    if (value == 'rm' ||
        value == 'regional_manager' ||
        value == 'regional manager' ||
        value.contains('регион')) {
      return 'rm';
    }
    return 'mp';
  }
}
