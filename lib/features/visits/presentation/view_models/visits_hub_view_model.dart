import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/models/models.dart';

import '../../domain/repositories/organisations_directory_repository.dart';
import '../../domain/use_cases/search_organisations.dart';

class NearbyCoordinates {
  final double latitude;
  final double longitude;

  const NearbyCoordinates({required this.latitude, required this.longitude});
}

class VisitsHubViewState {
  final bool isLpu;
  final String query;
  final bool allRegions;
  final List<Organisation> organisations;
  final List<Organisation> lpuOrganisations;
  final List<Organisation> pharmacyOrganisations;
  final Map<int, double> nearbyDistances;
  final bool nearbyMode;
  final bool localCacheLoaded;
  final bool isLoading;
  final bool isFindingNearby;
  final bool isRemoteSearching;
  final String? error;

  const VisitsHubViewState({
    this.isLpu = true,
    this.query = '',
    this.allRegions = false,
    this.organisations = const [],
    this.lpuOrganisations = const [],
    this.pharmacyOrganisations = const [],
    this.nearbyDistances = const {},
    this.nearbyMode = false,
    this.localCacheLoaded = false,
    this.isLoading = false,
    this.isFindingNearby = false,
    this.isRemoteSearching = false,
    this.error,
  });

  VisitsHubViewState copyWith({
    bool? isLpu,
    String? query,
    bool? allRegions,
    List<Organisation>? organisations,
    List<Organisation>? lpuOrganisations,
    List<Organisation>? pharmacyOrganisations,
    Map<int, double>? nearbyDistances,
    bool? nearbyMode,
    bool? localCacheLoaded,
    bool? isLoading,
    bool? isFindingNearby,
    bool? isRemoteSearching,
    String? error,
    bool clearError = false,
  }) {
    return VisitsHubViewState(
      isLpu: isLpu ?? this.isLpu,
      query: query ?? this.query,
      allRegions: allRegions ?? this.allRegions,
      organisations: organisations ?? this.organisations,
      lpuOrganisations: lpuOrganisations ?? this.lpuOrganisations,
      pharmacyOrganisations:
          pharmacyOrganisations ?? this.pharmacyOrganisations,
      nearbyDistances: nearbyDistances ?? this.nearbyDistances,
      nearbyMode: nearbyMode ?? this.nearbyMode,
      localCacheLoaded: localCacheLoaded ?? this.localCacheLoaded,
      isLoading: isLoading ?? this.isLoading,
      isFindingNearby: isFindingNearby ?? this.isFindingNearby,
      isRemoteSearching: isRemoteSearching ?? this.isRemoteSearching,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VisitsHubViewModel extends StateNotifier<VisitsHubViewState> {
  final OrganisationsDirectoryRepository _repository;
  final SearchOrganisations _searchOrganisations;
  final UserModel? _user;

  Timer? _remoteSearchDebounce;
  int _loadGeneration = 0;
  int _remoteSearchGeneration = 0;
  int _nearbyGeneration = 0;
  NearbyCoordinates? _lastNearbyPosition;
  final Map<int, Organisation> _remoteSearchResults = {};

  VisitsHubViewModel(
    this._repository,
    this._user, {
    SearchOrganisations? searchOrganisations,
    bool autoLoad = true,
  }) : _searchOrganisations =
           searchOrganisations ?? SearchOrganisations(_repository),
       super(const VisitsHubViewState()) {
    if (autoLoad) unawaited(load());
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final rows =
          await Future.wait<List<Organisation>>([
            _repository.getLocalModels(type: 'lpu'),
            _repository.getLocalModels(type: 'pharmacy'),
          ]).timeout(
            const Duration(seconds: 6),
            onTimeout: () => [<Organisation>[], <Organisation>[]],
          );
      if (!mounted || generation != _loadGeneration) return;
      final next = state.copyWith(
        lpuOrganisations: List.unmodifiable(rows[0]),
        pharmacyOrganisations: List.unmodifiable(rows[1]),
        localCacheLoaded: true,
        isLoading: false,
      );
      state = next.copyWith(organisations: _buildOrgList(next));
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(isLoading: false, error: '$error');
    }
  }

  void onRepositoryChanged() {
    unawaited(load());
  }

  void resetToDefault() {
    _remoteSearchDebounce?.cancel();
    _remoteSearchGeneration++;
    _nearbyGeneration++;
    _remoteSearchResults.clear();
    _lastNearbyPosition = null;
    final next = state.copyWith(
      isLpu: true,
      query: '',
      allRegions: false,
      nearbyMode: false,
      nearbyDistances: const {},
      isRemoteSearching: false,
      clearError: true,
    );
    state = next.copyWith(organisations: _buildOrgList(next));
    if (!state.localCacheLoaded) unawaited(load());
  }

  void setTab(bool isLpu) {
    if (state.isLpu == isLpu) return;
    _remoteSearchGeneration++;
    _remoteSearchResults.clear();
    _clearNearby();
    final next = state.copyWith(
      isLpu: isLpu,
      nearbyMode: false,
      nearbyDistances: const {},
      isRemoteSearching: false,
    );
    state = next.copyWith(organisations: _buildOrgList(next));
    if (!state.localCacheLoaded) unawaited(load());
    _scheduleRemoteSearch(state.query);
  }

  void setQuery(String query) {
    _remoteSearchGeneration++;
    _remoteSearchResults.clear();
    final next = state.copyWith(query: query, isRemoteSearching: false);
    state = next.copyWith(organisations: _buildOrgList(next));
    if (_lastNearbyPosition != null) unawaited(_refreshNearby());
    _scheduleRemoteSearch(query);
  }

  void setAllRegions(bool allRegions) {
    _remoteSearchGeneration++;
    _remoteSearchResults.clear();
    final next = state.copyWith(
      allRegions: allRegions,
      isRemoteSearching: false,
    );
    state = next.copyWith(organisations: _buildOrgList(next));
    if (_lastNearbyPosition != null) unawaited(_refreshNearby());
    _scheduleRemoteSearch(state.query);
  }

  void beginNearbySearch() {
    state = state.copyWith(isFindingNearby: true, clearError: true);
  }

  void endNearbySearch() {
    if (mounted) state = state.copyWith(isFindingNearby: false);
  }

  Future<bool> applyNearby(NearbyCoordinates position) async {
    if (!state.localCacheLoaded) await load();
    if (!mounted) return false;

    final generation = ++_nearbyGeneration;
    final rows = _filteredRows(state);
    final distances = <int, double>{};
    for (final org in rows) {
      final latitude = org.latitude;
      final longitude = org.longitude;
      if (latitude == null || longitude == null) continue;
      distances[org.id] = _distanceBetween(
        position.latitude,
        position.longitude,
        latitude,
        longitude,
      );
    }
    if (!mounted || generation != _nearbyGeneration) return false;

    _lastNearbyPosition = position;
    final next = state.copyWith(
      nearbyMode: distances.isNotEmpty,
      nearbyDistances: Map.unmodifiable(distances),
    );
    state = next.copyWith(organisations: _buildOrgList(next));
    return distances.isNotEmpty;
  }

  void clearNearby() {
    _clearNearby();
    final next = state.copyWith(nearbyMode: false, nearbyDistances: const {});
    state = next.copyWith(organisations: _buildOrgList(next));
  }

  Future<void> _refreshNearby() async {
    final position = _lastNearbyPosition;
    if (position == null) return;
    await applyNearby(position);
  }

  void _scheduleRemoteSearch(String query) {
    _remoteSearchDebounce?.cancel();
    final normalized = query.trim();
    if (normalized.length < 3) return;
    _remoteSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runRemoteSearch(normalized));
    });
  }

  Future<void> _runRemoteSearch(String query) async {
    final generation = ++_remoteSearchGeneration;
    final wantLpu = state.isLpu;
    state = state.copyWith(isRemoteSearching: true);
    try {
      final results = await _searchOrganisations(
        query: query,
        isLpu: wantLpu,
        allRegions: state.allRegions,
      );
      if (!mounted ||
          generation != _remoteSearchGeneration ||
          query != state.query.trim() ||
          wantLpu != state.isLpu) {
        return;
      }
      if (!mounted || generation != _remoteSearchGeneration) return;
      _remoteSearchResults
        ..clear()
        ..addEntries(
          results
              .where((row) => row.id != 0)
              .map((row) => MapEntry(row.id, row)),
        );
      final next = state.copyWith(isRemoteSearching: false);
      state = next.copyWith(organisations: _buildOrgList(next));
    } catch (error) {
      if (!mounted || generation != _remoteSearchGeneration) return;
      state = state.copyWith(isRemoteSearching: false, error: '$error');
    }
  }

  List<Organisation> _filteredRows(VisitsHubViewState source) {
    var rows = source.isLpu
        ? source.lpuOrganisations
        : source.pharmacyOrganisations;
    final query = source.query.trim().toLowerCase();
    if (query.isNotEmpty) {
      rows = rows.where((org) {
        final haystack = [
          org.name,
          org.address,
          org.city,
          org.inn,
        ].whereType<Object>().join(' ').toLowerCase();
        return haystack.contains(query);
      }).toList();
    }
    if (!source.allRegions) {
      rows = rows.where(_belongsToUserRegion).toList();
    }
    return rows;
  }

  List<Organisation> _buildOrgList([VisitsHubViewState? source]) {
    final current = source ?? state;
    var orgs = _filteredRows(current);
    final query = current.query.trim();
    if (_remoteSearchResults.isNotEmpty && query.isNotEmpty) {
      final presentIds = orgs.map((org) => org.id).toSet();
      final merged = orgs.toList();
      for (final org in _remoteSearchResults.values) {
        if (presentIds.contains(org.id)) continue;
        if (!current.allRegions && !_belongsToUserRegion(org)) continue;
        merged.add(org);
      }
      orgs = merged;
    }

    final sorted = orgs.toList()
      ..sort((a, b) {
        if (current.nearbyMode) {
          final ad = current.nearbyDistances[a.id] ?? double.infinity;
          final bd = current.nearbyDistances[b.id] ?? double.infinity;
          final distanceCompare = ad.compareTo(bd);
          if (distanceCompare != 0) return distanceCompare;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    if (current.nearbyMode && current.nearbyDistances.isNotEmpty) {
      sorted.removeWhere((org) => !current.nearbyDistances.containsKey(org.id));
    }
    return List.unmodifiable(sorted);
  }

  bool _belongsToUserRegion(Organisation org) {
    final userRegionId = _user?.regionId;
    final orgRegionId = _orgRegionId(org);
    if (userRegionId != null && orgRegionId != null) {
      return userRegionId == orgRegionId;
    }
    return _sameRegion(org.city, _user?.city);
  }

  int? _orgRegionId(Organisation org) {
    if (org.regionId != null) return org.regionId;
    final map = org.rawJsonMap;
    final rawRegion = map['region_id'] ?? map['regionId'];
    if (rawRegion is num) return rawRegion.toInt();
    if (rawRegion is String) return int.tryParse(rawRegion);
    final region = map['region'];
    if (region is Map) {
      final id = region['id'] ?? region['region_id'];
      if (id is num) return id.toInt();
      if (id is String) return int.tryParse(id);
    }
    return null;
  }

  bool _sameRegion(String? orgCity, String? userCity) {
    final a = _normalizeRegion(orgCity);
    final b = _normalizeRegion(userCity);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b || a.contains(b) || b.contains(a);
  }

  String _normalizeRegion(String? value) {
    if (value == null) return '';
    return value
        .toLowerCase()
        .replaceAll('г.', '')
        .replaceAll('город', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _clearNearby() {
    _nearbyGeneration++;
    _lastNearbyPosition = null;
  }

  static double _distanceBetween(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadius = 6371000.0;
    final lat1 = latitude1 * math.pi / 180;
    final lat2 = latitude2 * math.pi / 180;
    final deltaLat = (latitude2 - latitude1) * math.pi / 180;
    final deltaLon = (longitude2 - longitude1) * math.pi / 180;
    final a =
        math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLon / 2), 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  void dispose() {
    _remoteSearchDebounce?.cancel();
    super.dispose();
  }
}
