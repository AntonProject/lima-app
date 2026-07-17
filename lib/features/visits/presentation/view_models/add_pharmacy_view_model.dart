import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/form_dictionaries_provider.dart';
import '../../domain/entities/organisation_draft.dart';
import '../../domain/repositories/organisations_directory_repository.dart';

class AddPharmacyViewState {
  final List<Map<String, dynamic>> regions;
  final List<OrganisationArea> areas;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> facilityTypes;
  final int? regionId;
  final String? regionName;
  final int? areaId;
  final String? areaName;
  final int? categoryId;
  final String? categoryName;
  final int? facilityTypeId;
  final String? facilityTypeName;
  final String revisionStatus;
  final double? latitude;
  final double? longitude;
  final bool isLoading;
  final bool isLoadingAreas;
  final bool isSubmitting;
  final String? error;

  const AddPharmacyViewState({
    this.regions = const [],
    this.areas = const [],
    this.categories = const [],
    this.facilityTypes = const [],
    this.regionId,
    this.regionName,
    this.areaId,
    this.areaName,
    this.categoryId,
    this.categoryName,
    this.facilityTypeId,
    this.facilityTypeName,
    this.revisionStatus = 'none',
    this.latitude,
    this.longitude,
    this.isLoading = true,
    this.isLoadingAreas = false,
    this.isSubmitting = false,
    this.error,
  });

  AddPharmacyViewState copyWith({
    List<Map<String, dynamic>>? regions,
    List<OrganisationArea>? areas,
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? facilityTypes,
    int? regionId,
    String? regionName,
    int? areaId,
    String? areaName,
    int? categoryId,
    String? categoryName,
    int? facilityTypeId,
    String? facilityTypeName,
    String? revisionStatus,
    double? latitude,
    double? longitude,
    bool? isLoading,
    bool? isLoadingAreas,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    bool clearArea = false,
    bool clearLocation = false,
  }) {
    return AddPharmacyViewState(
      regions: regions ?? this.regions,
      areas: areas ?? this.areas,
      categories: categories ?? this.categories,
      facilityTypes: facilityTypes ?? this.facilityTypes,
      regionId: regionId ?? this.regionId,
      regionName: regionName ?? this.regionName,
      areaId: clearArea ? null : (areaId ?? this.areaId),
      areaName: clearArea ? null : (areaName ?? this.areaName),
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      facilityTypeId: facilityTypeId ?? this.facilityTypeId,
      facilityTypeName: facilityTypeName ?? this.facilityTypeName,
      revisionStatus: revisionStatus ?? this.revisionStatus,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      isLoading: isLoading ?? this.isLoading,
      isLoadingAreas: isLoadingAreas ?? this.isLoadingAreas,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AddPharmacyViewModel extends StateNotifier<AddPharmacyViewState> {
  final FormDictionariesNotifier _dictionaries;
  final OrganisationsDirectoryRepository _organisations;
  final UserModel? _user;
  final bool isLpu;

  AddPharmacyViewModel(
    this._dictionaries,
    this._organisations, {
    required this.isLpu,
    UserModel? user,
  }) : _user = user,
       super(const AddPharmacyViewState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final regions = await _dictionaries.regions();
      final categories = await _dictionaries.orgCategories();
      final facilityTypes = isLpu
          ? await _dictionaries.healthcareFacilityTypes()
          : const <Map<String, dynamic>>[];
      state = state.copyWith(
        regions: regions,
        categories: categories,
        facilityTypes: facilityTypes,
        isLoading: false,
      );
      _prefillRegion();
    } catch (error) {
      state = state.copyWith(isLoading: false, error: '$error');
    }
  }

  Future<void> selectRegion(int id, String name) async {
    state = state.copyWith(
      regionId: id,
      regionName: name,
      areas: const [],
      isLoadingAreas: true,
      clearArea: true,
      clearLocation: true,
    );
    try {
      final areas = await _organisations.getAreas(id);
      state = state.copyWith(areas: areas, isLoadingAreas: false);
    } catch (error) {
      state = state.copyWith(isLoadingAreas: false, error: '$error');
    }
  }

  void setArea(OrganisationArea area) {
    state = state.copyWith(
      areaId: area.id,
      areaName: area.name,
      clearLocation: true,
    );
  }

  void setCategory(Map<String, dynamic> item) {
    state = state.copyWith(
      categoryId: item['id'] as int?,
      categoryName: '${item['name']}',
    );
  }

  void setFacilityType(Map<String, dynamic> item) {
    state = state.copyWith(
      facilityTypeId: item['id'] as int?,
      facilityTypeName: '${item['name']}',
    );
  }

  void setRevisionStatus(String value) {
    state = state.copyWith(revisionStatus: value);
  }

  void setLocation({required double latitude, required double longitude}) {
    state = state.copyWith(latitude: latitude, longitude: longitude);
  }

  void setSubmitting(bool value) {
    state = state.copyWith(isSubmitting: value);
  }

  void _prefillRegion() {
    if (state.regionId != null || state.regions.isEmpty || _user == null) {
      return;
    }
    Map<String, dynamic>? match;
    if (_user.regionId != null) {
      for (final region in state.regions) {
        if ((region['id'] as num?)?.toInt() == _user.regionId) {
          match = region;
          break;
        }
      }
    }
    if (match == null && (_user.city ?? '').trim().isNotEmpty) {
      final city = _user.city!.trim().toLowerCase();
      for (final region in state.regions) {
        if ('${region['name']}'.trim().toLowerCase() == city) {
          match = region;
          break;
        }
      }
    }
    if (match != null) {
      final id = (match['id'] as num?)?.toInt();
      if (id != null) selectRegion(id, '${match['name']}');
    }
  }
}
