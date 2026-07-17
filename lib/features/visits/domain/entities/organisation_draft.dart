import 'package:lima/core/models/models.dart';

class OrganisationArea {
  final int id;
  final String name;
  final double? latitude;
  final double? longitude;

  const OrganisationArea({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
  });
}

class OrganisationDraft {
  final String name;
  final String inn;
  final OrgType type;
  final int typeId;
  final int regionId;
  final String? regionName;
  final int? areaId;
  final String? areaName;
  final String? phone;
  final String? phone2;
  final String? phone3;
  final String? address;
  final int? categoryId;
  final String? categoryName;
  final int? healthCareFacilityTypeId;
  final String? healthCareFacilityTypeName;
  final String? revisionStatus;
  final String? responsible;
  final double? latitude;
  final double? longitude;

  const OrganisationDraft({
    required this.name,
    required this.inn,
    required this.type,
    required this.typeId,
    required this.regionId,
    this.regionName,
    this.areaId,
    this.areaName,
    this.phone,
    this.phone2,
    this.phone3,
    this.address,
    this.categoryId,
    this.categoryName,
    this.healthCareFacilityTypeId,
    this.healthCareFacilityTypeName,
    this.revisionStatus,
    this.responsible,
    this.latitude,
    this.longitude,
  });

  Organisation toLocalModel({required int id, required String updatedAt}) =>
      Organisation(
        id: id,
        name: name,
        address: address ?? '',
        type: type,
        typeId: typeId,
        city: regionName,
        regionId: regionId,
        district: areaName,
        areaId: areaId,
        inn: inn,
        category: categoryName,
        categoryId: categoryId,
        responsible: responsible,
        phone: phone,
        phone2: phone2,
        phone3: phone3,
        healthCareFacilityTypeId: healthCareFacilityTypeId,
        healthCareFacilityTypeName: healthCareFacilityTypeName,
        revisionStatus: revisionStatus,
        latitude: latitude,
        longitude: longitude,
        updatedAt: updatedAt,
      );
}

class OrganisationUpdateDraft {
  final int organisationId;
  final String name;
  final String address;
  final String? phone;
  final String? city;
  final String? district;
  final String? inn;
  final String? category;
  final String? responsible;
  final double? latitude;
  final double? longitude;

  const OrganisationUpdateDraft({
    required this.organisationId,
    required this.name,
    required this.address,
    this.phone,
    this.city,
    this.district,
    this.inn,
    this.category,
    this.responsible,
    this.latitude,
    this.longitude,
  });
}
