import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/models/local_visit.dart';
import 'api_client.dart';

final remoteApiServiceProvider = Provider<RemoteApiService>((ref) {
  return RemoteApiService(ref.watch(apiClientProvider));
});

class NearbySearchDebugResult {
  final List<Map<String, dynamic>> organizations;
  final Map<String, dynamic> getResponse;
  final Map<String, dynamic> postResponse;

  const NearbySearchDebugResult({
    required this.organizations,
    required this.getResponse,
    required this.postResponse,
  });
}

class SearchOrganizationsDebugResult {
  final List<Map<String, dynamic>> organizations;
  final Map<String, dynamic> debug;

  const SearchOrganizationsDebugResult({
    required this.organizations,
    required this.debug,
  });
}

class RemoteApiService {
  final ApiClient _api;

  RemoteApiService(this._api);

  Future<String> authorize({
    required String login,
    required String password,
  }) async {
    final response = await _api.dio.post(
      '/api/Account/authorize',
      data: {'login': login, 'password': password},
    );

    final token = _extractToken(response.data);
    if (token == null || token.isEmpty) {
      throw const FormatException('Token not found in authorize response');
    }
    return token;
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _api.dio.get('/api/Users/me');
    return _extractMap(response.data);
  }

  Future<Map<String, dynamic>> getDailyVisitStatistics() async {
    final response = await _api.dio.get('/api/Visits/statistics/daily');
    return _extractMap(response.data);
  }

  Future<RemoteSeedBundle> fetchOfflineSeed() async {
    final orgsRaw = await _getList(
      '/api/dict/Organizations',
      queryParameters: {'_no_limit': true},
    );
    final doctorsRaw = await _getList(
      '/api/dict/Doctors',
      queryParameters: {'_no_limit': true},
    );

    final orgs = orgsRaw
        .map(_mapOrg)
        .whereType<Map<String, dynamic>>()
        .toList();
    final doctors = doctorsRaw
        .map(_mapDoctor)
        .whereType<Map<String, dynamic>>()
        .toList();

    // Use the stock price-list endpoint so drugs have real price/stock data.
    final stockDrugs = await getStockPriceListDrugs();
    // Use the bulk Documents endpoint to get all materials + counts efficiently.
    final docsResult = await getDrugDocuments();

    final now = DateTime.now().toIso8601String();
    final drugs = stockDrugs.map((d) => <String, dynamic>{
      'id': d.id,
      'name': d.name,
      'manufacturer': d.manufacturer,
      'price': d.price,
      'serial_number': d.serialNumber ?? '',
      'expiry_date': d.expiryDate ?? '',
      'stock': d.stock ?? 0,
      'documents_count': docsResult.counts[d.id] ?? 0,
      'updated_at': now,
    }).toList();

    // ── Visit history (all types) ──────────────────────────────────────────
    final allVisitsRaw = <dynamic>[];
    for (final endpoint in [
      '/api/Visits/history',
      '/api/Visits/history/orders',
      '/api/Visits/history/remnant',
    ]) {
      try {
        allVisitsRaw.addAll(
          await _getList(
            endpoint,
            queryParameters: {'_no_limit': true},
          ),
        );
      } catch (_) {
        try {
          allVisitsRaw.addAll(await _getList(endpoint));
        } catch (_) {}
      }
    }
    final visits = allVisitsRaw
        .map(_mapVisit)
        .whereType<Map<String, dynamic>>()
        .toList();

    // ── Planned visits ─────────────────────────────────────────────────────
    final plannedVisits = <Map<String, dynamic>>[];
    try {
      final rawCurrent = await _getList(
        '/api/Visits/plans/current',
        queryParameters: {'date': DateTime.now().toIso8601String()},
      );
      for (final raw in rawCurrent) {
        final pv = mapPlannedVisitToLocal(raw);
        if (pv != null) plannedVisits.add(pv);
      }
    } catch (_) {}
    try {
      final rawAll = await _getListAny(['/visits/plans', '/api/Visits/plans']);
      for (final raw in rawAll) {
        final pv = mapPlannedVisitToLocal(raw);
        if (pv != null) {
          final key = pv['remote_id'];
          if (key == null || !plannedVisits.any((e) => e['remote_id'] == key)) {
            plannedVisits.add(pv);
          }
        }
      }
    } catch (_) {}

    // ── Favourite organisations ────────────────────────────────────────────
    final favOrgIds = <Map<String, dynamic>>[];
    try {
      final favOrgs = await getFavoriteOrganizations();
      for (final o in favOrgs) {
        final id = o['id'];
        if (id != null) favOrgIds.add({'id': id});
      }
    } catch (_) {}

    // ── Managers ───────────────────────────────────────────────────────────
    final managersRaw = <Map<String, dynamic>>[];
    try {
      final options = await getManagers();
      for (final m in options) {
        managersRaw.add({
          'full_name': m.name,
          'role': m.role,
          'initials': m.initials,
          'raw_json': jsonEncode({'name': m.name, 'role': m.role}),
        });
      }
    } catch (_) {}

    // ── Day types ──────────────────────────────────────────────────────────
    final dayTypesRaw = <Map<String, dynamic>>[];
    try {
      final dts = await getDayTypes();
      dayTypesRaw.addAll(dts.map((e) => {
        'id': e['id'],
        'name': e['name'] ?? e['title'] ?? '${e['id']}',
        'raw_json': jsonEncode(e),
      }));
    } catch (_) {}

    // ── Daily stats ────────────────────────────────────────────────────────
    Map<String, dynamic>? dailyStats;
    try {
      dailyStats = await getDailyVisitStatistics();
    } catch (_) {}

    return RemoteSeedBundle(
      orgs: orgs,
      doctors: doctors,
      drugs: drugs,
      materials: docsResult.materials,
      visits: visits,
      plannedVisits: plannedVisits,
      favOrgIds: favOrgIds,
      managers: managersRaw,
      dayTypes: dayTypesRaw,
      dailyStats: dailyStats,
    );
  }

  /// Maps a raw planned-visit API object to a flat row for [planned_visits] table.
  static Map<String, dynamic>? mapPlannedVisitToLocal(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = _toInt(m['id'] ?? m['visit_id']);
    final orgName = _toString(
      m['organization_name'] ?? m['organisation_name'] ?? m['org_name'],
    );
    if (id == null || orgName == null || orgName.isEmpty) return null;

    final orgTypeRaw = _toString(m['organization_type'] ?? m['org_type'])?.toLowerCase();
    final orgTypeId = _toInt(m['organization_type_id'] ?? m['type_id']);
    final orgType = (orgTypeId == 1 || orgTypeRaw == 'pharmacy') ? 'pharmacy' : 'lpu';

    final dateRaw = _toString(m['date'] ?? m['start_date'] ?? m['visit_date']);
    final date = (dateRaw != null ? DateTime.tryParse(dateRaw) : null) ?? DateTime.now();

    return {
      'remote_id': id,
      'org_id': _toInt(m['organization_id'] ?? m['org_id']),
      'org_name': orgName,
      'org_type': orgType,
      'doctor_id': _toInt(m['doctor_id']),
      'doctor_name': _toString(m['doctor_name'] ?? m['doctor_full_name']),
      'assigned_by': _toString(m['assigned_by'] ?? m['manager_name']) ?? '',
      'city': _toString(m['city']),
      'visit_date': date.toIso8601String(),
      'status': (_toBool(m['complete']) ?? false) ? 'completed' : 'planned',
      'comment': _toString(m['comment']),
      'raw_json': jsonEncode(m),
    };
  }

  Future<void> pushUnsyncedVisit(LocalVisit visit) async {
    await pushUnsyncedVisitDebug(visit);
  }

  Future<Map<String, dynamic>> pushUnsyncedVisitDebug(LocalVisit visit) async {
    // For LPU visits backend expects at least one doctor id.
    if (visit.visitType == 'lpu' && visit.doctorId == null) {
      throw const FormatException(
        'LPU visit requires doctor_id for remote sync',
      );
    }

    final body = <String, dynamic>{
      if (visit.remoteId != null) 'visit_id': visit.remoteId,
      'organization_id': visit.orgId,
      'doctor_ids': visit.doctorId == null ? <int>[] : <int>[visit.doctorId!],
      'visit_type': _toVisitTypeCode(visit.visitType),
      'complete': visit.status == 'completed',
      'comment': visit.notes,
      'start_date': visit.createdAt.toIso8601String(),
      'end_date': visit.updatedAt.toIso8601String(),
      'is_planned': false,
    };
    final extraPayload = _extractVisitPayloadFromRawJson(visit.rawJson);
    if (extraPayload.isNotEmpty) {
      body.addAll(extraPayload);
    }
    final paths = ['/api/Visits/add', '/Visits/add', '/visits/add'];
    Object? lastError;
    for (final path in paths) {
      try {
        final response = await _api.dio.post(path, data: body);
        return {
          'ok': true,
          'path': path,
          'status': response.statusCode,
          'request': body,
          'response': response.data,
        };
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
    return {'ok': false, 'request': body, 'error': 'Unknown push error'};
  }

  static Map<String, dynamic> _extractVisitPayloadFromRawJson(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) return const <String, dynamic>{};
      final m = Map<String, dynamic>.from(decoded);
      final allowedKeys = <String>{
        'items',
        'drugs',
        'prepayment',
        'prepayment_percent',
        'payment_variant_id',
        'margin_id',
        'contract_id',
        'buyer_type',
        'is_wholesaler',
        'pharmacists_fio',
        'participants_count',
        'discussed_drugs_count',
        'materials_shown_count',
        'presentations',
        'medical_representative_name',
      };
      final out = <String, dynamic>{};
      for (final key in allowedKeys) {
        if (m.containsKey(key)) {
          out[key] = m[key];
        }
      }
      return out;
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Future<String> getWorkdayStatus() async {
    final response = await _api.dio.get('/api/WorkDay/status');
    final map = _extractMap(response.data);
    return _toString(map['status']) ?? 'not_started';
  }

  Future<List<Map<String, dynamic>>> getDayTypes() async {
    final response = await _api.dio.get('/api/DayType');
    final rows = _extractList(response.data);
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> startWorkday({
    required int dayTypeId,
    double latitude = 0,
    double longitude = 0,
  }) async {
    await _api.dio.post(
      '/api/WorkDay/start',
      data: {
        'day_type_id': dayTypeId,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  Future<void> endWorkday({double latitude = 0, double longitude = 0}) async {
    await _api.dio.post(
      '/api/WorkDay/end',
      data: {'latitude': latitude, 'longitude': longitude},
    );
  }

  Future<List<PlannedVisit>> getCurrentVisitPlans() async {
    final rows = await _getList(
      '/api/Visits/plans/current',
      queryParameters: {'date': DateTime.now().toIso8601String()},
    );
    return rows.map(_mapPlannedVisit).whereType<PlannedVisit>().toList();
  }

  Future<List<PlannedVisit>> getVisitPlans() async {
    final rows = await _getListAny(['/visits/plans', '/api/Visits/plans']);
    return rows.map(_mapPlannedVisit).whereType<PlannedVisit>().toList();
  }

  Future<List<PlannedVisit>> getMonthVisitPlans(DateTime month) async {
    final rows = await _getList(
      '/api/Visits/plans/month',
      queryParameters: {'date': month.toIso8601String()},
    );
    return rows.map(_mapPlannedVisit).whereType<PlannedVisit>().toList();
  }

  Future<int> getVisitsCount() async {
    final paths = ['/visits/count', '/api/Visits/count'];
    Object? lastError;
    for (final path in paths) {
      try {
        final response = await _api.dio.get(path);
        final data = response.data;
        if (data is num) return data.toInt();
        if (data is Map<String, dynamic>) {
          final m = _extractMap(data);
          return _toInt(m['count'] ?? m['visits_count'] ?? m['total']) ?? 0;
        }
        final list = _extractList(data);
        if (list.isNotEmpty && list.first is num) {
          return (list.first as num).toInt();
        }
        return 0;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
    return 0;
  }

  Future<int> getFavoriteDoctorsCount() async {
    return _getCountAny([
      '/dict/doctors/favorites/count',
      '/api/dict/Doctors/favorites/count',
    ]);
  }

  Future<int> getFavoriteOrganizationsCount() async {
    return _getCountAny([
      '/dict/organizations/favorites/count',
      '/api/dict/Organizations/favorites/count',
    ]);
  }

  Future<List<Map<String, dynamic>>> getFavoriteOrganizations() async {
    try {
      final rows = await _getListAny([
        '/organizations/favorites',
        '/Organizations/favorites',
        '/api/organizations/favorites',
        '/api/Organizations/favorites',
        '/dict/organizations/favorites',
        '/dict/Organizations/favorites',
        '/api/dict/organizations/favorites',
        '/api/dict/Organizations/favorites',
      ]);
      return rows.map(_mapOrg).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      final all = await _getList('/api/dict/Organizations', queryParameters: {'_no_limit': true});
      return all
          .map(_mapOrg)
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['is_favorite'] ?? 0) == 1)
          .toList();
    }
  }

  Future<void> addOrganizationToFavorites(int organizationId) async {
    final paths = [
      '/api/dict/Organizations/$organizationId/favorite',
      '/dict/Organizations/$organizationId/favorite',
      '/organizations/favorites/$organizationId',
      '/Organizations/favorites/$organizationId',
      '/api/organizations/favorites/$organizationId',
      '/api/Organizations/favorites/$organizationId',
    ];
    Object? lastError;
    for (final path in paths) {
      try {
        await _api.dio.post(path);
        return;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
  }

  Future<void> removeOrganizationFromFavorites(int organizationId) async {
    final paths = [
      '/api/dict/Organizations/$organizationId/favorite',
      '/dict/Organizations/$organizationId/favorite',
      '/organizations/favorites/$organizationId',
      '/Organizations/favorites/$organizationId',
      '/api/organizations/favorites/$organizationId',
      '/api/Organizations/favorites/$organizationId',
    ];
    Object? lastError;
    for (final path in paths) {
      try {
        await _api.dio.delete(path);
        return;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
  }

  Future<Map<String, dynamic>> updateOrganization({
    required int organizationId,
    required String name,
    required String address,
    String? phone,
    String? city,
    String? district,
    String? inn,
    String? category,
    String? responsiblePerson,
    double? latitude,
    double? longitude,
  }) async {
    final payloads = <Map<String, dynamic>>[
      {
        'name': name,
        'address': address,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (city != null && city.isNotEmpty) 'city': city,
        if (district != null && district.isNotEmpty) 'district': district,
        if (inn != null && inn.isNotEmpty) 'org_inn': int.tryParse(inn) ?? inn,
        if (category != null && category.isNotEmpty) 'category': category,
        if (responsiblePerson != null && responsiblePerson.isNotEmpty)
          'responsible_person': responsiblePerson,
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
      {
        'organization_name': name,
        'address_ru': address,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (city != null && city.isNotEmpty) 'region_name': city,
        if (district != null && district.isNotEmpty) 'area_name': district,
        if (inn != null && inn.isNotEmpty) 'org_inn': int.tryParse(inn) ?? inn,
        if (category != null && category.isNotEmpty) 'category': category,
        if (responsiblePerson != null && responsiblePerson.isNotEmpty)
          'responsible_person': responsiblePerson,
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
    ];
    final paths = [
      '/api/dict/Organizations/update/$organizationId',
      '/dict/Organizations/update/$organizationId',
      '/api/Organizations/update/$organizationId',
      '/Organizations/update/$organizationId',
    ];

    Object? lastError;
    for (final path in paths) {
      for (final payload in payloads) {
        try {
          final response = await _api.dio.post(path, data: payload);
          if (response.data is Map<String, dynamic>) {
            return Map<String, dynamic>.from(
              response.data as Map<String, dynamic>,
            );
          }
          return {
            'ok': true,
            'path': path,
            'request': payload,
            'response': response.data,
          };
        } catch (e) {
          lastError = e;
        }
      }
    }
    if (lastError != null) throw lastError;
    return {'ok': false};
  }

  Future<List<ManagerOption>> getManagers() async {
    final endpoints = [
      '/api/Users',
      '/api/users',
      '/api/Managers',
      '/api/managers',
    ];

    for (final endpoint in endpoints) {
      try {
        final rows = await _getList(
          endpoint,
          queryParameters: {'_no_limit': true},
        );
        final managers = rows
            .map(_mapManager)
            .whereType<ManagerOption>()
            .toList();
        if (managers.isNotEmpty) return managers;
      } catch (_) {
        // Try next endpoint.
      }
    }
    return const <ManagerOption>[];
  }

  Future<List<Map<String, dynamic>>> getDoctorsByOrganization(
    int organizationId,
  ) async {
    final endpoints = <({String path, Map<String, dynamic>? query})>[
      (path: '/api/dict/Organizations/$organizationId/doctors', query: null),
      (path: '/dict/Organizations/$organizationId/doctors', query: null),
      (
        path: '/api/dict/Doctors',
        query: {
          'organization_id': [organizationId],
          '_no_limit': true,
        },
      ),
      (
        path: '/api/dict/Doctors',
        query: {'organization_id': organizationId, '_no_limit': true},
      ),
      (path: '/doctors/by-organization/$organizationId', query: null),
      (path: '/Doctors/by-organization/$organizationId', query: null),
      (path: '/api/doctors/by-organization/$organizationId', query: null),
      (path: '/api/Doctors/by-organization/$organizationId', query: null),
    ];
    Object? lastError;
    for (final e in endpoints) {
      try {
        final rows = await _getList(e.path, queryParameters: e.query);
        final mapped = rows
            .map(_mapDoctor)
            .whereType<Map<String, dynamic>>()
            .toList();
        if (mapped.isNotEmpty) return mapped;
      } catch (err) {
        lastError = err;
      }
    }
    if (lastError != null) throw lastError;
    return const <Map<String, dynamic>>[];
  }

  Future<void> addDoctorToFavorites(int doctorId) async {
    final payloads = <Map<String, dynamic>>[
      {'data': doctorId},
      {'doctor_id': doctorId},
      {'doctorId': doctorId},
      {'id': doctorId},
      const <String, dynamic>{},
    ];
    final postPaths = <String>[
      '/api/dict/Doctors/favorites/add',
      '/dict/Doctors/favorites/add',
      '/Doctors/favorites/add',
      '/api/Doctors/favorites/add',
      '/Doctors/$doctorId/favorites',
      '/api/Doctors/$doctorId/favorites',
      '/Doctors/favorites/$doctorId',
      '/api/Doctors/favorites/$doctorId',
      '/Doctors/favorites/$doctorId/add',
      '/api/Doctors/favorites/$doctorId/add',
    ];

    Object? lastError;
    for (final path in postPaths) {
      for (final payload in payloads) {
        try {
          await _api.dio.post(path, data: payload);
          return;
        } catch (e) {
          lastError = e;
        }
      }
    }

    final putPaths = <String>[
      '/Doctors/$doctorId/favorites',
      '/api/Doctors/$doctorId/favorites',
      '/Doctors/favorites/$doctorId',
      '/api/Doctors/favorites/$doctorId',
    ];
    for (final path in putPaths) {
      try {
        await _api.dio.put(path);
        return;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) throw lastError;
  }

  Future<int?> addDoctor({
    required int organizationId,
    required String fullName,
    required String specialty,
    String? phone,
  }) async {
    final payloads = <Map<String, dynamic>>[
      {
        'organization_id': organizationId,
        'full_name': fullName,
        'specialty': specialty,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
      {
        'org_id': organizationId,
        'name': fullName,
        'position': specialty,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    ];
    final paths = [
      '/api/dict/Doctors/add',
      '/dict/Doctors/add',
      '/Doctors/add',
      '/api/Doctors/add',
    ];
    Object? lastError;
    for (final path in paths) {
      for (final payload in payloads) {
        try {
          final response = await _api.dio.post(path, data: payload);
          final map = _extractMap(response.data);
          return _toInt(
            map['id'] ??
                map['doctor_id'] ??
                (map['doctor'] is Map ? (map['doctor'] as Map)['id'] : null),
          );
        } catch (e) {
          lastError = e;
        }
      }
    }
    if (lastError != null) throw lastError;
    return null;
  }

  Future<void> markDoctorVisited({
    required int doctorId,
    int? organizationId,
    int? visitId,
  }) async {
    final payloads = <Map<String, dynamic>>[
      {
        'doctor_id': doctorId,
        'organization_id': ?organizationId,
        'visit_id': ?visitId,
      },
      {'id': doctorId, 'org_id': ?organizationId, 'visit_id': ?visitId},
    ];
    final paths = [
      '/api/dict/Doctors/visited',
      '/dict/Doctors/visited',
      '/Doctors/visited',
      '/api/Doctors/visited',
    ];
    Object? lastError;
    for (final path in paths) {
      for (final payload in payloads) {
        try {
          await _api.dio.post(path, data: payload);
          return;
        } catch (e) {
          lastError = e;
        }
      }
    }
    if (lastError != null) throw lastError;
  }

  Future<void> removeDoctorFromFavorites(int doctorId) async {
    final deletePaths = [
      '/api/dict/Doctors/$doctorId/favorites/remove',
      '/dict/Doctors/$doctorId/favorites/remove',
      '/Doctors/$doctorId/favorites/remove',
      '/api/Doctors/$doctorId/favorites/remove',
      '/Doctors/$doctorId/favorites',
      '/api/Doctors/$doctorId/favorites',
      '/Doctors/favorites/$doctorId',
      '/api/Doctors/favorites/$doctorId',
    ];
    Object? lastError;
    for (final path in deletePaths) {
      try {
        await _api.dio.delete(path);
        return;
      } catch (e) {
        lastError = e;
      }
    }

    final postPaths = <String>[
      '/api/dict/Doctors/$doctorId/favorites/remove',
      '/dict/Doctors/$doctorId/favorites/remove',
      '/Doctors/$doctorId/favorites/remove',
      '/api/Doctors/$doctorId/favorites/remove',
      '/Doctors/favorites/$doctorId/remove',
      '/api/Doctors/favorites/$doctorId/remove',
    ];
    for (final path in postPaths) {
      try {
        await _api.dio.post(path);
        return;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) throw lastError;
  }

  Future<List<Map<String, dynamic>>> getFavoriteDoctors() async {
    try {
      final rows = await _getListAny([
        '/Doctors/favorites',
        '/api/Doctors/favorites',
        '/dict/doctors/favorites',
        '/dict/Doctors/favorites',
        '/api/dict/doctors/favorites',
        '/api/dict/Doctors/favorites',
      ]);
      return rows
          .map((e) {
            if (e is Map && e['doctor'] is Map) {
              return _mapDoctor(e['doctor']);
            }
            return _mapDoctor(e);
          })
          .whereType<Map<String, dynamic>>()
          .map((e) => {...e, 'is_favorite': 1})
          .toList();
    } catch (_) {
      final dictRows = await _getList(
        '/api/dict/Doctors',
        queryParameters: {'_no_limit': true},
      );
      return dictRows
          .map(_mapDoctor)
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['is_favorite'] ?? 0) == 1)
          .toList();
    }
  }

  Future<void> updateVisit(
    int visitId, {
    required Map<String, dynamic> data,
  }) async {
    try {
      await _api.dio.put('/api/Visits/$visitId', data: data);
      return;
    } catch (_) {}
    await _api.dio.put('/Visits/$visitId', data: data);
  }

  Future<Map<String, dynamic>> getVisitPlanDetails(int visitId) async {
    try {
      final response = await _api.dio.get('/api/Visits/plans/$visitId/details');
      return _extractMap(response.data);
    } catch (_) {
      final response = await _api.dio.get('/Visits/plans/$visitId/details');
      return _extractMap(response.data);
    }
  }

  Future<void> rateVisit({
    required int visitId,
    required int rating,
    String? comment,
  }) async {
    final payloads = <Map<String, dynamic>>[
      {
        'visit_id': visitId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
      {
        'VisitId': visitId,
        'Rating': rating,
        if (comment != null && comment.isNotEmpty) 'Comment': comment,
      },
    ];
    final paths = ['/Visits/rating', '/api/Visits/rating'];
    Object? lastError;
    for (final path in paths) {
      for (final payload in payloads) {
        try {
          await _api.dio.post(path, data: payload);
          return;
        } catch (e) {
          lastError = e;
        }
      }
    }
    if (lastError != null) throw lastError;
  }

  Future<List<Map<String, dynamic>>> getVisitedDoctorsByOrganization(
    int organizationId,
  ) async {
    final rows = await _getListAny([
      '/Visits/organization/$organizationId/visited-doctors',
      '/api/Visits/organization/$organizationId/visited-doctors',
    ]);
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getDoctorsSync({int? syncId}) async {
    try {
      final rows = await _getListAnyWithQuery(
        ['/Doctors/sync', '/api/Doctors/sync'],
        queryParameters: {'sync_id': ?syncId},
      );
      return rows.map(_mapDoctor).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      final rows = await _getList(
        '/api/dict/Doctors',
        queryParameters: {'_no_limit': true},
      );
      return rows.map(_mapDoctor).whereType<Map<String, dynamic>>().toList();
    }
  }

  Future<List<Map<String, dynamic>>> getOrganizationsNearby({
    required double latitude,
    required double longitude,
    List<int>? typeIds,
    int? radius,
  }) async {
    final debug = await getOrganizationsNearbyDebug(
      latitude: latitude,
      longitude: longitude,
      typeIds: typeIds,
      radius: radius,
    );
    return debug.organizations;
  }

  Future<List<Map<String, dynamic>>> getOrganizationsRankedByLocationAll({
    required double latitude,
    required double longitude,
    List<int>? typeIds,
  }) async {
    final rows = await _getListAnyWithQuery(
      ['/api/dict/Organizations/find', '/dict/Organizations/find'],
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        '_no_limit': true,
        if (typeIds != null && typeIds.isNotEmpty) 'type_id': typeIds,
      },
    );
    return rows.map(_mapOrg).whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getOrganizationsAll({
    List<int>? typeIds,
    String? query,
  }) async {
    final attempts = <Map<String, dynamic>>[
      {
        'path': '/api/dict/Organizations/find',
        'params': {
          '_no_limit': true,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          if (typeIds != null && typeIds.isNotEmpty) 'type_id': typeIds,
        },
      },
      {
        'path': '/api/dict/Organizations',
        'params': {
          '_no_limit': true,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          if (typeIds != null && typeIds.isNotEmpty) 'type_id': typeIds,
        },
      },
      {
        'path': '/api/dict/Organizations/find',
        'params': {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      },
      {
        'path': '/api/dict/Organizations',
        'params': {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      },
    ];

    Object? lastError;
    for (final attempt in attempts) {
      final rawPath = attempt['path'] as String;
      final params = Map<String, dynamic>.from(attempt['params'] as Map);
      for (final prefix in ['']) {
        try {
          final response = await _api.dio.get(
            '$prefix$rawPath',
            queryParameters: params,
          );
          final rows = _extractList(response.data);
          final mapped = rows
              .map(_mapOrg)
              .whereType<Map<String, dynamic>>()
              .toList();
          if (mapped.isNotEmpty) return mapped;
        } catch (e) {
          lastError = e;
        }
      }
    }
    if (lastError != null) {
      throw lastError;
    }
    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> searchOrganizations({
    required String query,
    List<int>? typeIds,
    bool global = false,
    int page = 1,
  }) async {
    final debug = await searchOrganizationsDebug(
      query: query,
      typeIds: typeIds,
      global: global,
      page: page,
    );
    return debug.organizations;
  }

  Future<SearchOrganizationsDebugResult> searchOrganizationsDebug({
    required String query,
    List<int>? typeIds,
    bool global = false,
    int page = 1,
  }) async {
    final encoded = Uri.encodeComponent(query.trim());
    final attempts = <({String path, Map<String, dynamic> params})>[
      (
        path: '/api/dict/Organizations/find/$encoded',
        params: {
          'page': page,
          '_no_limit': true,
          'global': global,
          if (typeIds != null && typeIds.isNotEmpty) 'type_id': typeIds,
        },
      ),
      (
        path: '/api/dict/Organizations/find',
        params: {
          'q': query,
          'page': page,
          '_no_limit': true,
          'global': global,
          if (typeIds != null && typeIds.isNotEmpty) 'type_id': typeIds,
        },
      ),
      (
        path: '/api/dict/Organizations',
        params: {
          'q': query,
          'page': page,
          '_no_limit': true,
          'global': global,
          if (typeIds != null && typeIds.isNotEmpty) 'type_id': typeIds,
        },
      ),
    ];

    Object? lastError;
    Map<String, dynamic>? lastOkDebug;
    for (final attempt in attempts) {
      for (final prefix in ['']) {
        final path = '$prefix${attempt.path}';
        try {
          final response = await _api.dio.get(
            path,
            queryParameters: attempt.params,
          );
          final rows = _extractList(response.data);
          final mapped = rows
              .map(_mapOrg)
              .whereType<Map<String, dynamic>>()
              .toList();
          final currentDebug = {
            'ok': true,
            'path': path,
            'status': response.statusCode,
            'query': attempt.params,
            'mapped_count': mapped.length,
          };
          if (mapped.isNotEmpty) {
            return SearchOrganizationsDebugResult(
              organizations: mapped,
              debug: currentDebug,
            );
          }
          lastOkDebug = currentDebug;
        } catch (e) {
          lastError = e;
        }
      }
    }
    if (lastOkDebug != null) {
      return SearchOrganizationsDebugResult(
        organizations: const [],
        debug: {
          ...lastOkDebug,
          'ok': false,
          'reason': 'all_attempts_returned_empty',
          if (lastError != null) 'last_error': '$lastError',
        },
      );
    }
    return SearchOrganizationsDebugResult(
      organizations: const [],
      debug: {
        'ok': false,
        'error': '$lastError',
        'query': query,
        'global': global,
      },
    );
  }

  Future<NearbySearchDebugResult> getOrganizationsNearbyDebug({
    required double latitude,
    required double longitude,
    List<int>? typeIds,
    int? radius,
  }) async {
    final typeParam = (typeIds != null && typeIds.length == 1)
        ? typeIds.first
        : typeIds;
    final query = {
      'latitude': latitude,
      'longitude': longitude,
      'top': 100,
      'type_id': ?typeParam,
      'radius': ?radius,
    };
    final body = {
      'latitude': latitude,
      'longitude': longitude,
      if (typeIds != null && typeIds.isNotEmpty) 'type_id': typeIds,
      'radius': ?radius,
    };
    final getPaths = [
      '/api/dict/Organizations/find-around',
      '/dict/Organizations/find-around',
      '/api/dict/Organizations/find',
      '/dict/Organizations/find',
    ];
    final postPaths = [
      '/api/dict/Organizations/find',
      '/dict/Organizations/find',
    ];

    List<Map<String, dynamic>>? getMapped;
    Map<String, dynamic> getResponse = {'ok': false, 'method': 'GET'};
    Object? getError;
    for (final path in getPaths) {
      try {
        final response = await _api.dio.get(path, queryParameters: query);
        final rows = _extractList(response.data);
        getMapped = rows
            .map(_mapOrg)
            .whereType<Map<String, dynamic>>()
            .toList();
        getResponse = {
          'ok': true,
          'method': 'GET',
          'path': path,
          'status': response.statusCode,
          'query': query,
          'response': response.data,
          'mapped_count': getMapped.length,
        };
        break;
      } catch (e) {
        getError = e;
      }
    }
    if (getMapped == null) {
      getResponse = {
        'ok': false,
        'method': 'GET',
        'query': query,
        'error': '$getError',
      };
    }

    List<Map<String, dynamic>>? postMapped;
    Map<String, dynamic> postResponse = {'ok': false, 'method': 'POST'};
    Object? postError;
    for (final path in postPaths) {
      try {
        final response = await _api.dio.post(path, data: body);
        final rows = _extractList(response.data);
        postMapped = rows
            .map(_mapOrg)
            .whereType<Map<String, dynamic>>()
            .toList();
        postResponse = {
          'ok': true,
          'method': 'POST',
          'path': path,
          'status': response.statusCode,
          'request': body,
          'response': response.data,
          'mapped_count': postMapped.length,
        };
        break;
      } catch (e) {
        postError = e;
      }
    }
    if (postMapped == null) {
      postResponse = {
        'ok': false,
        'method': 'POST',
        'request': body,
        'error': '$postError',
      };
    }

    final chosen = (getMapped != null && getMapped.isNotEmpty)
        ? getMapped
        : (postMapped ?? getMapped ?? <Map<String, dynamic>>[]);

    return NearbySearchDebugResult(
      organizations: chosen,
      getResponse: getResponse,
      postResponse: postResponse,
    );
  }

  Future<List<Map<String, dynamic>>> getOrganizationsSync({int? syncId}) async {
    final rows = await _getListAnyWithQuery(
      ['/api/dict/Organizations/sync', '/dict/Organizations/sync'],
      queryParameters: {'sync_id': ?syncId},
    );
    return rows.map(_mapOrg).whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getDrugsSync({int? syncId}) async {
    try {
      final rows = await _getListAnyWithQuery(
        ['/Drugs/sync', '/api/Drugs/sync'],
        queryParameters: {'sync_id': ?syncId},
      );
      return rows.map(_mapDrug).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      final rows = await _getListAny([
        '/api/dict/Drugs',
        '/dict/Drugs',
        '/api/dict/drugs/bindings',
      ]);
      return rows.map(_mapDrug).whereType<Map<String, dynamic>>().toList();
    }
  }

  Future<String> debugGetStockPriceListRaw() async {
    // binding_id=109 (drug binding from /api/dict/drugs/bindings)
    const bindingId = 109;
    final endpoints = [
      '/api/Documents/by-drug/$bindingId',
      '/api/documents/by-drug/$bindingId',
      '/api/Documents',
    ];
    final buf = StringBuffer();
    for (final path in endpoints) {
      try {
        final response = await _api.dio.get(path);
        final data = response.data;
        final isHtml = data is String && data.trimLeft().startsWith('<');
        if (isHtml) {
          buf.writeln('✗ $path  [${response.statusCode}] → HTML (not API)');
          continue;
        }
        buf.writeln('✓ $path  [${response.statusCode}]');
        if (data is List) {
          buf.writeln('  List[${data.length}]');
          if (data.isNotEmpty) {
            buf.writeln('  First item keys: ${(data.first as Map?)?.keys.toList()}');
            buf.writeln('  First item: ${jsonEncode(data.first)}');
          }
        } else if (data is Map) {
          buf.writeln('  Map keys: ${data.keys.toList()}');
          final preview = jsonEncode(data);
          buf.writeln('  ${preview.length > 500 ? preview.substring(0, 500) : preview}');
        } else {
          buf.writeln('  $data');
        }
        buf.writeln();
      } catch (e) {
        buf.writeln('✗ $path  error: $e');
      }
    }
    return buf.toString();
  }

  Future<List<Drug>> getStockPriceListDrugs() async {
    final rows = await _getListAny([
      '/stock/price-list',
      '/Stock/price-list',
      '/api/stock/price-list',
      '/api/Stock/price-list',
    ]);

    if (rows.isNotEmpty) {
      debugPrint('[PriceList] first row keys: ${(rows.first as Map?)?.keys.toList()}');
      debugPrint('[PriceList] first row: ${rows.first}');
    }
    final seen = <int>{};
    final result = <Drug>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final drugMap = m['drug'] is Map
          ? Map<String, dynamic>.from(m['drug'] as Map)
          : const <String, dynamic>{};
      final producerMap = m['producer'] is Map
          ? Map<String, dynamic>.from(m['producer'] as Map)
          : const <String, dynamic>{};

      // drug.id is the binding ID — used by Documents API
      // drug.drug_id is the dict drug ID
      final id =
          _toInt(drugMap['id']) ??
          _toInt(drugMap['drug_id']) ??
          _toInt(m['income_detailing_id']);
      final name = _toString(drugMap['name']) ?? _toString(m['name']);
      if (id == null || name == null || name.isEmpty) continue;
      if (seen.contains(id)) continue;
      seen.add(id);

      // sale_price can be 0 (not null) — fall back to base_price
      final salePrice = _toDouble(m['sale_price']);
      final price = (salePrice != null && salePrice > 0)
          ? salePrice
          : (_toDouble(m['base_price']) ?? _toDouble(drugMap['price']) ?? 0);

      result.add(
        Drug(
          id: id,
          name: name,
          manufacturer:
              _toString(producerMap['name']) ??
              _toString(m['manufacturer']) ??
              '',
          serialNumber: _toString(m['serial_no'] ?? m['series'] ?? m['serial_number']),
          expiryDate: _toString(m['expire_date'] ?? m['expiry_date']),
          price: price,
          stock: _toInt(m['actual_balance'] ?? m['remains_amount'] ?? m['stock']),
          documentsCount: 0,
          // income_detailing_id is needed when creating a Бронь order.
          currentStockId: _toInt(m['income_detailing_id']),
          bindingDrugId: _toInt(drugMap['id']),
        ),
      );
    }
    return result;
  }

  /// Fetches all drug documents from KBase API (paginated).
  /// Returns list of drug_materials rows ready to insert into DB.
  /// Also returns a map of drugId → documentsCount.
  Future<({List<Map<String, dynamic>> materials, Map<int, int> counts, Map<int, String> drugNames})> getDrugDocuments() async {
    final materials = <Map<String, dynamic>>[];
    final counts = <int, int>{};
    final drugNames = <int, String>{};
    int page = 1;
    bool hasMore = true;
    while (hasMore) {
      try {
        final response = await _api.dio.get(
          '/api/Documents',
          queryParameters: {'page': page, 'page_size': 50},
        );
        final data = response.data;
        if (data is! Map) break;
        final resultList = data['result'];
        if (resultList is! List || resultList.isEmpty) break;
        for (final item in resultList) {
          if (item is! Map) continue;
          final drugMap = item['drug'] is Map ? item['drug'] as Map : null;
          if (drugMap == null) continue;
          final drugId = _toInt(drugMap['id']);
          if (drugId == null) continue;
          final drugName = _toString(drugMap['name']);
          if (drugName != null && drugName.isNotEmpty) drugNames[drugId] = drugName;
          final docs = item['documents'];
          if (docs is! List) continue;
          counts[drugId] = (counts[drugId] ?? 0) + docs.length;
          for (final doc in docs) {
            if (doc is! Map) continue;
            materials.add({
              'drug_id': drugId,
              'title': _toString(doc['title'] ?? doc['file_name']) ?? '',
              'local_path': _toString(doc['file_url']),
              'file_type': _toString(doc['document_type_name']),
              'raw_json': jsonEncode(doc),
            });
          }
        }
        final pageInfo = data['page'];
        hasMore = pageInfo is Map && (pageInfo['has_next_page'] == true);
        page++;
      } catch (_) {
        break;
      }
    }
    return (materials: materials, counts: counts, drugNames: drugNames);
  }

  /// Loads the current agent's server-side cart from GET /api/Cart.
  /// Returns a list of [CartItemSnapshot]-compatible maps.
  Future<List<Map<String, dynamic>>> getServerCart() async {
    final resp = await _api.dio.get('/api/Cart');
    final carts = _extractList(resp.data);
    final result = <Map<String, dynamic>>[];
    for (final cart in carts) {
      if (cart is! Map) continue;
      final c = Map<String, dynamic>.from(cart);
      final org = c['organization'] is Map
          ? Map<String, dynamic>.from(c['organization'] as Map)
          : const <String, dynamic>{};
      final pharmacyId = _toInt(org['id']);
      final pharmacyName = _toString(org['name']) ?? '';
      final createdAt = _toString(c['date_of_creation']) ?? DateTime.now().toIso8601String();
      final items = c['items'];
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        final it = Map<String, dynamic>.from(item);
        final stock = it['current_stock'] is Map
            ? Map<String, dynamic>.from(it['current_stock'] as Map)
            : const <String, dynamic>{};
        final binding = stock['drug_binding'] is Map
            ? Map<String, dynamic>.from(stock['drug_binding'] as Map)
            : const <String, dynamic>{};
        final drug = binding['drug'] is Map
            ? Map<String, dynamic>.from(binding['drug'] as Map)
            : const <String, dynamic>{};
        final producer = binding['producer'] is Map
            ? Map<String, dynamic>.from(binding['producer'] as Map)
            : const <String, dynamic>{};
        final drugId = _toInt(drug['id']);
        if (drugId == null) continue;
        result.add({
          'drug_id': drugId,
          'name': _toString(drug['name']) ?? '',
          'manufacturer': _toString(producer['name']) ?? '',
          'price': (_toDouble(it['sale_price']) ?? 0.0),
          'serial_number': null,
          'expiry_date': _toString(stock['expire_date']),
          'stock': _toInt(stock['amount']),
          'quantity': _toInt(it['amount']) ?? 1,
          'pharmacy_id': pharmacyId,
          'pharmacy_name': pharmacyName,
          'added_at': createdAt,
          'cart_id': _toInt(c['id']),
          // current_stock_id = income_detailing_id — needed for Бронь order creation.
          'current_stock_id': _toInt(stock['current_stock_id']),
          // binding_drug_id = drug_binding.drug.id (not dict drug_id).
          'binding_drug_id': drugId,
        });
      }
    }
    return result;
  }

  /// Deletes the server-side cart with the given [cartId].
  Future<void> clearServerCart(int cartId) async {
    try {
      await _api.dio.delete('/api/Cart/$cartId');
    } catch (_) {
      // Try without trailing id as fallback.
      await _api.dio.delete('/api/Cart');
    }
  }

  Future<List<Map<String, dynamic>>> getVisitHistoryOrders() async {
    final rows = await _getListAnyPaged(
      ['/api/Visits/history/orders', '/Visits/history/orders'],
      queryParameters: {'_no_limit': true},
    );
    return rows
        .map(_mapVisit)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>?> getVisitHistoryOrderById(int visitId) async {
    final rows = await getVisitHistoryOrders();
    for (final row in rows) {
      final id = _toInt(row['remote_id'] ?? row['id']);
      if (id == visitId) return row;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getLatestOrderDefaultsForOrganization(
    int organizationId,
  ) async {
    final response = await _api.dio.get(
      '/api/Orders',
      queryParameters: const {'page': 1, 'page_size': 100},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) return null;
    final result = data['result'];
    if (result is! List) return null;
    Map<String, dynamic>? weakFallback;
    for (final item in result) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final org = m['organization'] is Map
          ? Map<String, dynamic>.from(m['organization'] as Map)
          : const <String, dynamic>{};
      final orgId = _toInt(m['organization_id'] ?? org['organization_id']);
      if (orgId != organizationId) continue;
      final visitType = _toInt(m['visit_type']);
      if (visitType != null && visitType != 1) continue;
      final defaults = {
        'payment_variant_id': _toInt(m['payment_variant_id']),
        'margin_id': _toInt(m['margin_id']),
        'contract_id': _toInt(m['contract_id']),
        'is_wholesaler': _toBool(m['is_wholesaler']) ?? false,
        'prepayment_percent': _toInt(m['prepayment_percent']),
      };
      // Keep first matching row as weak fallback (even if incomplete),
      // but prefer the latest row that has full pricing defaults.
      weakFallback ??= defaults;
      final hasPricingDefaults =
          defaults['payment_variant_id'] != null &&
          defaults['margin_id'] != null &&
          defaults['prepayment_percent'] != null;
      if (hasPricingDefaults) return defaults;
    }
    return weakFallback;
  }

  Future<List<Map<String, dynamic>>> getVisitHistoryRemnant() async {
    final rows = await _getListAnyPaged(
      ['/api/Visits/history/remnant', '/Visits/history/remnant'],
      queryParameters: {'_no_limit': true},
    );
    return rows
        .map(_mapVisit)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> getVisitHistoryGeneral() async {
    final rows = await _getListAnyPaged(
      ['/api/Visits/history', '/Visits/history'],
      queryParameters: {'_no_limit': true},
    );
    return rows
        .map(_mapVisit)
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => <String, dynamic>{
            ...e,
            if ((e['visit_type'] as String?) == null ||
                (e['visit_type'] as String?)?.isEmpty == true)
              'visit_type': 'lpu',
          },
        )
        .toList();
  }

  Future<void> sendFeedback({
    required String message,
    required List<String> photoPaths,
  }) async {
    final files = <MultipartFile>[];
    for (final path in photoPaths) {
      if (path.isEmpty) continue;
      final f = File(path);
      if (!await f.exists()) continue;
      files.add(await MultipartFile.fromFile(path));
    }

    final formData = FormData.fromMap({'Message': message, 'Photos': files});
    await _api.dio.post('/api/Feedback', data: formData);
  }

  Future<List<dynamic>> _getList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _api.dio.get(path, queryParameters: queryParameters);
    final data = response.data;
    if (data is String && data.trimLeft().startsWith('<')) {
      throw const FormatException('Expected JSON but received HTML');
    }
    return _extractList(data);
  }

  Future<List<dynamic>> _getListAny(List<String> paths) async {
    Object? lastError;
    for (final path in paths) {
      try {
        return await _getList(path);
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
    return const <dynamic>[];
  }

  Future<List<dynamic>> _getListAnyWithQuery(
    List<String> paths, {
    Map<String, dynamic>? queryParameters,
  }) async {
    Object? lastError;
    for (final path in paths) {
      try {
        return await _getList(path, queryParameters: queryParameters);
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
    return const <dynamic>[];
  }

  Future<List<dynamic>> _getListAnyPaged(
    List<String> paths, {
    Map<String, dynamic>? queryParameters,
  }) async {
    Object? lastError;
    for (final path in paths) {
      try {
        final out = <dynamic>[];
        var page = 1;
        var hasMore = true;
        while (hasMore) {
          final qp = <String, dynamic>{
            ...?queryParameters,
            'page': page,
          };
          final response = await _api.dio.get(path, queryParameters: qp);
          final data = response.data;
          if (data is String && data.trimLeft().startsWith('<')) {
            throw const FormatException('Expected JSON but received HTML');
          }
          final list = _extractList(data);
          if (list.isEmpty) break;
          out.addAll(list);
          if (data is Map<String, dynamic> && data['page'] is Map) {
            final pageInfo = Map<String, dynamic>.from(data['page'] as Map);
            final hasNext = pageInfo['has_next_page'] == true;
            final totalPages = _toInt(pageInfo['total_pages']) ?? page;
            hasMore = hasNext || page < totalPages;
            page++;
            continue;
          }
          hasMore = false;
        }
        if (out.isNotEmpty) return out;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
    return const <dynamic>[];
  }

  Future<int> _getCountAny(List<String> paths) async {
    Object? lastError;
    for (final path in paths) {
      try {
        final response = await _api.dio.get(path);
        final data = response.data;
        if (data is num) return data.toInt();
        if (data is List) return data.length;
        if (data is Map<String, dynamic>) {
          final count = _toInt(
            data['count'] ??
                data['total'] ??
                data['value'] ??
                data['result'] ??
                data['data'],
          );
          if (count != null) return count;
          final list = _extractList(data);
          if (list.isNotEmpty) return list.length;
        }
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
    return 0;
  }

  static String? _extractToken(dynamic data) {
    if (data is String) return data;
    if (data is Map<String, dynamic>) {
      final candidates = <dynamic>[
        data['access_token'],
        data['token'],
        data['jwt'],
      ];

      final result = data['result'];
      if (result is Map<String, dynamic>) {
        candidates.addAll([
          result['access_token'],
          result['token'],
          result['jwt'],
        ]);
      }

      for (final c in candidates) {
        if (c is String && c.isNotEmpty) return c;
      }
    }
    return null;
  }

  static Map<String, dynamic> _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final result = data['result'];
      if (result is Map<String, dynamic>) return result;
      final payload = data['data'];
      if (payload is Map<String, dynamic>) return payload;
      return data;
    }
    throw const FormatException('Expected JSON object response');
  }

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;

    if (data is Map<String, dynamic>) {
      final keys = ['items', 'data', 'result', 'results', 'rows', 'payload'];
      for (final key in keys) {
        final value = data[key];
        if (value is List) return value;
        if (value is Map<String, dynamic>) {
          for (final nested in keys) {
            final nestedValue = value[nested];
            if (nestedValue is List) return nestedValue;
          }
        }
      }

      for (final value in data.values) {
        if (value is List) return value;
      }
    }

    return const <dynamic>[];
  }

  static Map<String, dynamic>? _mapOrg(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);

    final id = _toInt(m['id'] ?? m['organization_id'] ?? m['org_id']);
    final name = _toString(
      m['name_ru'] ??
          m['organization_name_ru'] ??
          m['name'] ??
          m['org_name'] ??
          m['organization_name'],
    );
    if (id == null || name == null || name.isEmpty) return null;

    final typeText = _toString(
      m['type'] ?? m['organization_type'] ?? m['type_name'],
    )?.toLowerCase();
    final typeId = _toInt(m['type_id']);
    final isPharmacy =
        (typeText?.contains('pharm') ?? false) ||
        (typeText?.contains('апт') ?? false) ||
        typeId == 1;

    return {
      'id': id,
      'name': name,
      'address':
          _toString(
            m['address_ru'] ??
                m['location_ru'] ??
                m['address'] ??
                m['location'] ??
                m['address_line'],
          ) ??
          '',
      'type': isPharmacy ? 'pharmacy' : 'lpu',
      'city': _toString(m['city'] ?? m['region_name']),
      'district': _toString(m['district'] ?? m['area'] ?? m['area_name']),
      'inn': _toString(m['inn'] ?? m['org_inn']),
      'category': _toString(m['category'] ?? m['category_name'] ?? m['class']),
      'responsible': _toString(m['responsible_person'] ?? m['responsible']),
      'phone': _toString(
        m['phone'] ?? m['phone_1'] ?? m['phone1'] ?? m['phone_number'],
      ),
      'latitude': _toDouble(
        m['latitude'] ?? m['lat'] ?? m['geo_lat'] ?? m['y'],
      ),
      'longitude': _toDouble(
        m['longitude'] ?? m['lng'] ?? m['geo_lng'] ?? m['x'],
      ),
      'distance_m': _toDouble(
        m['distance_m'] ?? m['distance'] ?? m['distance_meter'],
      ),
      'is_favorite': (_toBool(
            m['is_favorite'] ??
                m['isFavorite'] ??
                m['favorite'] ??
                m['in_favorites'],
          ) ??
          false)
          ? 1
          : 0,
      'updated_at': _toIso(m['updated_at']) ?? DateTime.now().toIso8601String(),
      'sync_id': _toInt(m['sync_id']),
      'raw_json': jsonEncode(m),
    };
  }

  static Map<String, dynamic>? _mapDoctor(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);

    final id = _toInt(m['id'] ?? m['doctor_id']);
    final fullName = _toString(
      m['full_name'] ?? m['name'] ?? m['doctor_name'] ?? m['fio'],
    );
    if (id == null || fullName == null || fullName.isEmpty) return null;

    return {
      'id': id,
      'full_name': fullName,
      'specialty': _toString(
        m['specialty'] ?? m['position'] ?? m['doctor_position'],
      ),
      'organisation_id':
          _toInt(m['organisation_id'] ?? m['organization_id'] ?? m['org_id']) ??
          0,
      'is_favorite': (_toBool(
            m['is_favorite'] ?? m['isFavorite'] ?? m['favorite'] ?? m['in_favorites'],
          ) ??
          false)
          ? 1
          : 0,
      'category':
          _toString(m['category'] ?? m['category_name'] ?? m['class']) ?? 'C',
      'last_visit_label': _toString(m['last_visit_label']) ?? '',
      'updated_at': _toIso(m['updated_at']) ?? DateTime.now().toIso8601String(),
      'sync_id': _toInt(m['sync_id']),
      'raw_json': jsonEncode(m),
    };
  }

  static Map<String, dynamic>? _mapDrug(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);

    final id = _toInt(m['id'] ?? m['drug_id']);
    final name = _toString(m['name'] ?? m['drug_name']);
    if (id == null || name == null || name.isEmpty) return null;

    final producer = m['producer'];
    final producerName = producer is Map
        ? _toString(producer['name'] ?? producer['title'])
        : _toString(producer);

    return {
      'id': id,
      'name': name,
      'manufacturer':
          _toString(m['manufacturer'] ?? m['producer_name']) ??
          producerName ??
          '',
      'price':
          _toDouble(
            m['price'] ??
                m['sale_price'] ??
                m['base_price'] ??
                m['retail_price'] ??
                m['cost'] ??
                m['price_uzs'],
          ) ??
          0,
      'serial_number':
          _toString(
            m['serial_number'] ??
                m['series'] ??
                m['series_number'] ??
                m['serialNo'],
          ) ??
          '',
      'expiry_date':
          _toString(
            m['expiry_date'] ??
                m['expire_date'] ??
                m['expiry'] ??
                m['expired_at'],
          ) ??
          '',
      'stock':
          _toInt(
            m['stock'] ??
                m['balance'] ??
                m['quantity'] ??
                m['remainder'] ??
                m['unique_counter'],
          ) ??
          0,
      'documents_count': _toInt(m['documents_count'] ?? m['docs_count']) ?? 0,
      'updated_at': _toIso(m['updated_at']) ?? DateTime.now().toIso8601String(),
      'sync_id': _toInt(m['sync_id']),
      'raw_json': jsonEncode(m),
    };
  }

  static Map<String, dynamic>? _mapVisit(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final orgMap = m['organization'] is Map
        ? Map<String, dynamic>.from(m['organization'] as Map)
        : const <String, dynamic>{};

    final remoteId = _toInt(m['id'] ?? m['visit_id']);
    final orgId = _toInt(
          m['organization_id'] ??
              m['org_id'] ??
              orgMap['organization_id'] ??
              orgMap['id'],
        ) ??
        0;
    final orgName = _toString(
      m['organization_name'] ??
          m['org_name'] ??
          m['organisation_name'] ??
          m['pharmacy_name'] ??
          m['lpu_name'] ??
          orgMap['name'] ??
          orgMap['organization_name'] ??
          orgMap['name_ru'],
    );
    if (orgName == null || orgName.isEmpty) return null;

    final medRep = m['medrep'] is Map
        ? Map<String, dynamic>.from(m['medrep'] as Map)
        : const <String, dynamic>{};
    final doctors = m['doctors'];
    int? doctorId = _toInt(m['doctor_id']);
    String? doctorName = _toString(m['doctor_name']);
    if (doctorName == null && doctors is List && doctors.isNotEmpty) {
      final first = doctors.first;
      if (first is Map) {
        final d = Map<String, dynamic>.from(first);
        doctorId ??= _toInt(d['id'] ?? d['doctor_id']);
        doctorName = _toString(
          d['full_name'] ?? d['doctor_name'] ?? d['name'] ?? d['fio'],
        );
      }
    }
    final typeRaw = _toString(m['visit_type'])?.toLowerCase();
    final formatRaw = _toString(m['visit_format_name'])?.toLowerCase();
    final createdAtIso =
        _toIso(
          m['date_create'] ??
              m['start_date'] ??
              m['created_at'] ??
              m['date'] ??
              m['visit_date'] ??
              m['datetime'],
        ) ??
        DateTime.now().toIso8601String();
    final updatedAtIso =
        _toIso(
          m['end_date'] ??
              m['updated_at'] ??
              m['date_create'] ??
              m['finish_date'] ??
              m['closed_at'] ??
              m['start_date'] ??
              m['created_at'] ??
              m['date'],
        ) ??
        createdAtIso;

    final completeFromBool = _toBool(m['complete']) ?? false;
    final statusRaw = _toString(
      m['status'] ??
          m['status_name'] ??
          m['visit_status_name'] ??
          m['order_status_name'] ??
          m['visit_status'],
    )?.toLowerCase();
    final visitStatusCode = _toInt(m['visit_status']) ?? 0;
    final isCompletedByStatus =
        statusRaw == 'completed' ||
        statusRaw == 'done' ||
        statusRaw == 'success' ||
        statusRaw == 'проведено' ||
        statusRaw == 'проведен' ||
        visitStatusCode == 3;
    final visitType = () {
      if (typeRaw == '4' || typeRaw == 'stock' || typeRaw == 'remnant') {
        return 'stock';
      }
      final hasCircle = m['visit_pharm_circle'] != null ||
          (formatRaw?.contains('фармкруж') ?? false);
      if (hasCircle) return 'circle';
      return _fromVisitType(typeRaw);
    }();

    return {
      'remote_id': ?remoteId,
      'org_id': orgId,
      'org_name': orgName,
      'doctor_id': ?doctorId,
      'doctor_name': ?doctorName,
      'visit_type': visitType,
      'status': (completeFromBool || isCompletedByStatus)
          ? 'completed'
          : 'planned',
      'notes': _toString(m['comment']),
      'created_at': createdAtIso,
      'updated_at': updatedAtIso,
      'medical_rep_name': _toString(
        m['medical_rep_name'] ??
            m['medrep_name'] ??
            medRep['name'] ??
            m['assigned_by'] ??
            m['manager_name'],
      ),
      'raw_json': jsonEncode(m),
    };
  }

  static PlannedVisit? _mapPlannedVisit(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);

    final id = _toInt(m['id'] ?? m['visit_id']);
    final orgName = _toString(
      m['organization_name'] ?? m['organisation_name'] ?? m['org_name'],
    );
    if (id == null || orgName == null || orgName.isEmpty) return null;

    final orgTypeId = _toInt(m['organization_type_id'] ?? m['type_id']);
    final orgTypeRaw = _toString(
      m['organization_type'] ?? m['org_type'],
    )?.toLowerCase();
    final orgType = orgTypeId == 1 || orgTypeRaw == 'pharmacy'
        ? OrgType.pharmacy
        : OrgType.lpu;

    return PlannedVisit(
      id: id,
      organisationName: orgName,
      organisationId: _toInt(m['organization_id'] ?? m['org_id']),
      organisationType: orgType,
      doctorName: _toString(m['doctor_name']),
      assignedBy: _toString(m['assigned_by'] ?? m['manager_name']) ?? '',
      city: _toString(m['city']),
      date:
          DateTime.tryParse(_toString(m['date'] ?? m['start_date']) ?? '') ??
          DateTime.now(),
      status: (_toBool(m['complete']) ?? false)
          ? VisitStatus.completed
          : VisitStatus.planned,
    );
  }

  static ManagerOption? _mapManager(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final name = _toString(
      m['full_name'] ?? m['name'] ?? m['username'] ?? m['login'],
    );
    if (name == null || name.isEmpty) return null;
    final rawRole = _toString(m['role_name'] ?? m['role']);
    // Only include users with an explicitly set manager-like role.
    if (rawRole == null || rawRole.isEmpty) return null;
    final roleLower = rawRole.toLowerCase();
    final isManager =
        roleLower.contains('менедж') ||
        roleLower.contains('manager') ||
        roleLower.contains('rm') ||
        roleLower.contains('supervisor');
    if (!isManager) return null;
    final role = rawRole;
    final initials = name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return ManagerOption(
      name: name,
      role: role,
      initials: initials.isEmpty ? '?' : initials,
    );
  }

  static int? _toVisitTypeCode(String type) {
    switch (type) {
      // According to WORKFLOW_AGENT.md:
      // 1 = pharmacy visit (booking + pharm circle), 2 = LPU, 4 = stock.
      case 'order':
      case 'circle':
        return 1;
      case 'lpu':
        return 2;
      case 'stock':
        return 4;
      default:
        return 2;
    }
  }

  static String _fromVisitType(String? typeRaw) {
    if (typeRaw == null || typeRaw.isEmpty) return 'lpu';

    switch (typeRaw) {
      case '1':
      case 'pharmacy':
      case 'order':
        return 'order';
      case 'circle':
      case 'pharmcircle':
        return 'circle';
      case '2':
      case 'lpu':
      case 'presentation':
        return 'lpu';
      case '4':
      case '3':
      case 'stock':
      case 'remnant':
        return 'stock';
      default:
        return 'lpu';
    }
  }

  static String? _toString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return null;
  }

  static String? _toIso(dynamic value) {
    final s = _toString(value);
    if (s == null) return null;
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt.toIso8601String();

    // Common backend format: dd.MM.yyyy or dd.MM.yyyy, HH:mm[:ss]
    final m = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:[,\s]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(s);
    if (m != null) {
      final day = int.tryParse(m.group(1)!);
      final month = int.tryParse(m.group(2)!);
      final year = int.tryParse(m.group(3)!);
      final hour = int.tryParse(m.group(4) ?? '0') ?? 0;
      final minute = int.tryParse(m.group(5) ?? '0') ?? 0;
      final second = int.tryParse(m.group(6) ?? '0') ?? 0;
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day, hour, minute, second).toIso8601String();
      }
    }
    return null;
  }
}

class ManagerOption {
  final String name;
  final String role;
  final String initials;

  const ManagerOption({
    required this.name,
    required this.role,
    required this.initials,
  });
}

class RemoteSeedBundle {
  final List<Map<String, dynamic>> orgs;
  final List<Map<String, dynamic>> doctors;
  final List<Map<String, dynamic>> drugs;
  final List<Map<String, dynamic>> materials;
  final List<Map<String, dynamic>> visits;
  final List<Map<String, dynamic>> plannedVisits;
  final List<Map<String, dynamic>> favOrgIds;
  final List<Map<String, dynamic>> managers;
  final List<Map<String, dynamic>> dayTypes;
  final Map<String, dynamic>? dailyStats;

  const RemoteSeedBundle({
    required this.orgs,
    required this.doctors,
    required this.drugs,
    required this.materials,
    required this.visits,
    this.plannedVisits = const [],
    this.favOrgIds = const [],
    this.managers = const [],
    this.dayTypes = const [],
    this.dailyStats,
  });
}
