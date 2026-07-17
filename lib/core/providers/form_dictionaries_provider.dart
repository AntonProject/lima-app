import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/remote_api_service.dart';
import 'connectivity_provider.dart';
import '../utils/swallowed.dart';

/// Cache-first small reference lists used by forms (regions, org
/// categories, health-care facility types, doctor specializations). These
/// are not part of the main organisations/doctors/drugs SQLite sync — they're
/// small dropdown sources fetched ad-hoc by screens, so a lightweight
/// SharedPreferences cache is enough to keep those forms usable offline.
class FormDictionariesNotifier {
  FormDictionariesNotifier(this._ref);

  final Ref _ref;

  static const _regionsCacheKey = 'cached_form_regions_v1';
  static const _categoriesCacheKey = 'cached_form_org_categories_v1';
  static const _facilityTypesCacheKey = 'cached_form_facility_types_v1';
  static const _specializationsCacheKey = 'cached_specializations_v1';

  Future<List<Map<String, dynamic>>> regions() =>
      _cached(_regionsCacheKey, () => _api.getRegions());

  Future<List<Map<String, dynamic>>> orgCategories() =>
      _cached(_categoriesCacheKey, () => _api.getOrgCategories());

  Future<List<Map<String, dynamic>>> healthcareFacilityTypes() =>
      _cached(_facilityTypesCacheKey, () => _api.getHealthcareFacilityTypes());

  Future<List<Map<String, dynamic>>> specializations() =>
      _cached(_specializationsCacheKey, () => _api.getSpecializations());

  /// Warms every cache in the background (best-effort, ignores failures).
  /// Call on app start / resume / reconnect, same trigger points as the
  /// main sync, so forms stay usable if connectivity drops right after.
  Future<void> prefetchAll() async {
    if (_ref.read(isOfflineProvider)) return;
    await Future.wait([
      regions(),
      orgCategories(),
      healthcareFacilityTypes(),
      specializations(),
    ], eagerError: false).catchError((_) => const <Never>[]);
  }

  RemoteApiService get _api => _ref.read(remoteApiServiceProvider);

  Future<List<Map<String, dynamic>>> _cached(
    String cacheKey,
    Future<List<Map<String, dynamic>>> Function() fetch,
  ) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    var list = <Map<String, dynamic>>[];
    final raw = prefs.getString(cacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        list = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (error) {
        logSwallowed(error, 'FormDictionariesNotifier.decodeCache:$cacheKey');
      }
    }
    if (!_ref.read(isOfflineProvider)) {
      try {
        final fresh = await fetch();
        if (fresh.isNotEmpty) {
          list = fresh;
          await prefs.setString(cacheKey, jsonEncode(fresh));
        }
      } catch (error) {
        logSwallowed(error, 'FormDictionariesNotifier.fetch:$cacheKey');
      }
    }
    return list;
  }
}

final formDictionariesProvider = Provider<FormDictionariesNotifier>((ref) {
  return FormDictionariesNotifier(ref);
});
