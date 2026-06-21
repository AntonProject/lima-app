import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/models/local_visit.dart';
import 'package:lima/core/utils/swallowed.dart';
import 'api_client.dart';

final remoteApiServiceProvider = Provider<RemoteApiService>((ref) {
  return RemoteApiService(ref.watch(apiClientProvider));
});

class RemotePushException implements Exception {
  final String message;
  final Map<String, dynamic>? request;
  final Map<String, dynamic> response;

  const RemotePushException({
    required this.message,
    this.request,
    required this.response,
  });

  String get displayMessage {
    final data = response['data'];
    if (data is Map) {
      final serverMessage = data['message'];
      if (serverMessage is String && serverMessage.trim().isNotEmpty) {
        return serverMessage.trim();
      }
    }
    final responseMessage = response['message'];
    if (responseMessage is String && responseMessage.trim().isNotEmpty) {
      return responseMessage.trim();
    }
    return message;
  }

  int? get statusCode {
    final status = response['status'];
    if (status is int) return status;
    if (status is num) return status.toInt();
    if (status is String) return int.tryParse(status);
    return null;
  }

  bool get isValidationFailure {
    final data = response['data'];
    if (data is Map) {
      final tag = data['tag']?.toString().trim().toUpperCase();
      if (tag == 'VALIDATION_ERROR') return true;
    }
    final status = statusCode;
    return status == 400 || status == 404 || status == 422;
  }

  @override
  String toString() => displayMessage;
}

bool isPermanentVisitPushFailure(Object error) {
  if (error is FormatException) return true;
  if (error is RemotePushException) return error.isValidationFailure;
  return false;
}

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

  Future<RemoteSeedBundle> fetchOfflineSeed({
    int? regionId,
    int? companyId,
    bool includeDoctors = true,
    void Function(String message, {int? current, int? total})? onProgress,
  }) async {
    onProgress?.call(AppI18n.tr('apiLoadingOrgs'));
    final orgsRaw = await _getList(
      '/api/dict/Organizations',
      queryParameters: {'_no_limit': true},
    );
    final orgs = orgsRaw
        .map(_mapOrg)
        .whereType<Map<String, dynamic>>()
        .toList();
    final orgIds = orgs
        .map((e) => (e['id'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    var doctorOrgLinks = <Map<String, dynamic>>[];
    var scopedDoctors = <Map<String, dynamic>>[];
    if (includeDoctors) {
      final relationRows = await getDoctorOrganisationRelations(syncId: 0);
      doctorOrgLinks = relationRows.where((row) {
        final orgId = (row['organisation_id'] as num?)?.toInt();
        return orgId != null && orgIds.contains(orgId);
      }).toList();
      final doctors = await getDoctorsDictionary(
        onPage: (currentPage, totalPages, loaded, totalCount) {
          final progressCurrent = totalCount == null ? currentPage : loaded;
          final progressTotal = totalCount ?? totalPages;
          final percent = _progressPercent(progressCurrent, progressTotal);
          onProgress?.call(
            percent == null
                ? AppI18n.tr('syncLoadingDoctors')
                : AppI18n.tr('syncLoadingDoctorsPct', args: {'percent': '$percent'}),
            current: progressCurrent,
            total: progressTotal,
          );
        },
      );
      scopedDoctors = doctors;
    }

    onProgress?.call(AppI18n.tr('apiLoadingDrugs'));
    // Use the stock price-list endpoint so drugs have real price/stock data.
    final stockDrugs = await getStockPriceListDrugs();
    // Use the bulk Documents endpoint to get all materials + counts efficiently.
    final docsResult = await getDrugDocuments(companyId: companyId);

    final now = DateTime.now().toIso8601String();
    final stockDrugIds = <int>{};
    final drugs = stockDrugs.map((d) {
      stockDrugIds.add(d.id);
      return <String, dynamic>{
        'id': d.id,
        'name': d.name,
        'manufacturer': d.manufacturer,
        'price': d.price,
        'serial_number': d.serialNumber ?? '',
        'expiry_date': d.expiryDate ?? '',
        'main_stock': d.mainStock ?? d.stock ?? 0,
        'stock': d.stock ?? 0,
        'remains_stock': d.remainsStock ?? d.stock ?? 0,
        'current_stock_id': d.currentStockId,
        'binding_drug_id': d.bindingDrugId,
        'documents_count': docsResult.counts[d.id] ?? 0,
        'updated_at': now,
      };
    }).toList();
    for (final entry in docsResult.counts.entries) {
      if (stockDrugIds.contains(entry.key)) continue;
      drugs.add({
        'id': entry.key,
        'name':
            docsResult.drugNames[entry.key] ??
            AppI18n.tr('drugNumbered', args: {'n': '${entry.key}'}),
        'manufacturer': '',
        'price': 0,
        'serial_number': '',
        'expiry_date': '',
        'main_stock': 0,
        'stock': 0,
        'remains_stock': 0,
        'current_stock_id': null,
        'binding_drug_id': entry.key,
        'documents_count': entry.value,
        'updated_at': now,
      });
    }

    // ── Visit history (all types) ──────────────────────────────────────────
    final allVisitsRaw = <dynamic>[];
    for (final endpoint in [
      '/api/Visits/history',
      '/api/Visits/history/orders',
      '/api/Visits/history/remnant',
    ]) {
      try {
        allVisitsRaw.addAll(
          await _getList(endpoint, queryParameters: {'_no_limit': true}),
        );
      } catch (_) {
        try {
          allVisitsRaw.addAll(await _getList(endpoint));
        } catch (e) {
          logSwallowed(e, 'RemoteApi.fetchOfflineSeed');
        }
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
    } catch (e) {
      logSwallowed(e, 'RemoteApi.fetchOfflineSeed');
    }
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
    } catch (e) {
      logSwallowed(e, 'RemoteApi.fetchOfflineSeed');
    }

    // ── Favourite organisations ────────────────────────────────────────────
    final favOrgIds = <Map<String, dynamic>>[];
    try {
      final favOrgs = await getFavoriteOrganizations();
      for (final o in favOrgs) {
        final id = o['id'];
        if (id != null) favOrgIds.add({'id': id});
      }
    } catch (e) {
      logSwallowed(e, 'RemoteApi.fetchOfflineSeed');
    }

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
    } catch (e) {
      logSwallowed(e, 'RemoteApi.fetchOfflineSeed');
    }

    // ── Day types ──────────────────────────────────────────────────────────
    final dayTypesRaw = <Map<String, dynamic>>[];
    try {
      final dts = await getDayTypes();
      dayTypesRaw.addAll(
        dts.map(
          (e) => {
            'id': e['id'],
            'name': e['name'] ?? e['title'] ?? '${e['id']}',
            'raw_json': jsonEncode(e),
          },
        ),
      );
    } catch (e) {
      logSwallowed(e, 'RemoteApi.fetchOfflineSeed');
    }

    // ── Daily stats ────────────────────────────────────────────────────────
    Map<String, dynamic>? dailyStats;
    try {
      dailyStats = await getDailyVisitStatistics();
    } catch (e) {
      logSwallowed(e, 'RemoteApi.fetchOfflineSeed');
    }

    return RemoteSeedBundle(
      orgs: orgs,
      doctors: scopedDoctors,
      doctorOrgLinks: doctorOrgLinks,
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

    // GET /api/visits/plans returns nested objects
    final orgObj = m['organization'] is Map
        ? Map<String, dynamic>.from(m['organization'] as Map)
        : const <String, dynamic>{};
    final medRepObj = m['medrep'] is Map
        ? Map<String, dynamic>.from(m['medrep'] as Map)
        : const <String, dynamic>{};

    final orgName = _toString(
      orgObj['organization_name'] ??
          orgObj['name'] ??
          m['organization_name'] ??
          m['organisation_name'] ??
          m['org_name'],
    );
    if (id == null || orgName == null || orgName.isEmpty) return null;

    final orgTypeId = _toInt(
      orgObj['type_id'] ?? m['organization_type_id'] ?? m['type_id'],
    );
    final orgTypeRaw = _toString(
      orgObj['organization_type'] ??
          orgObj['type'] ??
          m['organization_type'] ??
          m['org_type'],
    )?.toLowerCase();
    final orgType = (orgTypeId == 1 || orgTypeRaw == 'pharmacy')
        ? 'pharmacy'
        : 'lpu';

    // Doctors: nested array (GET) or flat field (older endpoints)
    final doctorsArr = m['doctors'];
    String? doctorNamesCsv;
    if (doctorsArr is List && doctorsArr.isNotEmpty) {
      doctorNamesCsv = doctorsArr
          .whereType<Map>()
          .map(
            (d) =>
                _toString(d['doctor_name'] ?? d['full_name'] ?? d['name']) ??
                '',
          )
          .where((s) => s.isNotEmpty)
          .join(', ');
      if (doctorNamesCsv.isEmpty) doctorNamesCsv = null;
    }
    doctorNamesCsv ??= _toString(m['doctor_name'] ?? m['doctor_full_name']);

    final assignedBy =
        _toString(medRepObj['name'] ?? m['assigned_by'] ?? m['manager_name']) ??
        '';

    final city = _toString(
      orgObj['region_name'] ?? orgObj['city'] ?? m['city'],
    );
    final district = _toString(
      orgObj['area_name'] ??
          orgObj['district'] ??
          m['district'] ??
          m['area'] ??
          m['area_name'],
    );

    final dateRaw = _toString(m['start_date'] ?? m['date'] ?? m['visit_date']);
    final date =
        (dateRaw != null ? DateTime.tryParse(dateRaw) : null) ?? DateTime.now();

    // visit_status: 1=planned, 2=completed; also support `complete` bool
    final visitStatus = _toInt(m['visit_status']);
    final isCompleted =
        _toBool(m['complete']) ??
        (visitStatus != null && visitStatus != 1 && visitStatus != 0);

    final visitFormatId = _toInt(
      m['visit_format'] ?? m['visit_format_id'] ?? m['format_id'],
    );

    return {
      'remote_id': id,
      'org_id': _toInt(
        orgObj['organization_id'] ??
            orgObj['id'] ??
            m['organization_id'] ??
            m['org_id'],
      ),
      'org_name': orgName,
      'org_type': orgType,
      'doctor_id': null,
      'doctor_name': (doctorNamesCsv?.isEmpty ?? true) ? null : doctorNamesCsv,
      'assigned_by': assignedBy,
      'city': city,
      'district': district,
      'visit_date': date.toIso8601String(),
      'status': isCompleted ? 'completed' : 'planned',
      'comment': _toString(m['comment']),
      'raw_json': jsonEncode(m),
      'visit_format': _resolveServerVisitFormat(m, orgType, visitFormatId),
    };
  }

  static String? _resolveServerVisitFormat(
    Map<String, dynamic> m,
    String orgType, [
    int? preResolvedFmtId,
  ]) {
    final fmtName = _toString(
      m['visit_format_name'] ?? m['format_name'] ?? m['visit_type_name'],
    )?.toLowerCase();
    if (fmtName != null) {
      if (fmtName.contains('фармкруж') || fmtName.contains('pharm')) {
        return 'circle';
      }
      if (fmtName.contains('груп') || fmtName.contains('group')) return 'group';
      if (fmtName.contains('двойн') || fmtName.contains('double')) {
        return 'double';
      }
    }
    final fmtId =
        preResolvedFmtId ??
        _toInt(m['visit_format_id'] ?? m['format_id'] ?? m['visit_format']);
    if (fmtId != null) {
      if (fmtId == 1) return 'circle';
      if (fmtId == 2) return 'double';
      if (fmtId == 3) return 'group';
      if (fmtId == 4) return 'group_double';
    }
    return null;
  }

  Future<void> pushUnsyncedVisit(LocalVisit visit) async {
    await pushUnsyncedVisitDebug(visit);
  }

  Future<Map<String, dynamic>> pushUnsyncedVisitDebug(LocalVisit visit) async {
    if (visit.visitType == 'order') {
      final visitPayload = await _buildOrderVisitPayloadFromLocalVisit(visit);
      if (visitPayload == null) {
        throw const FormatException('В API нет ценовой матрицы для заказа');
      }
      return _postVisitAddDebug(visitPayload);
    }

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
    return _postVisitAddDebug(body);
  }

  Future<Map<String, dynamic>> _postVisitAddDebug(
    Map<String, dynamic> body,
  ) async {
    final paths = ['/api/Visits/add', '/Visits/add', '/visits/add'];
    Object? lastError;
    Map<String, dynamic>? lastResponse;
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
        if (e is DioException) {
          lastResponse = {
            'path': path,
            'status': e.response?.statusCode,
            'data': e.response?.data,
            'message': e.message,
          };
        } else {
          lastResponse = {'path': path, 'error': '$e'};
        }
      }
    }
    if (lastError != null) {
      throw RemotePushException(
        message: 'Visit push failed',
        request: body,
        response:
            lastResponse ??
            {'error': '$lastError', 'message': 'Unknown visit push error'},
      );
    }
    return {'ok': false, 'request': body, 'error': 'Unknown visit push error'};
  }

  /// POST /api/visits/plans — schedule a planned visit.
  /// Returns the parsed response map (server should echo the new plan with id).
  Future<Map<String, dynamic>> pushPlannedVisit({
    required int organizationId,
    required List<int> doctorIds,
    required int visitFormatId,
    required DateTime startDate,
    DateTime? endDate,
    String? comment,
  }) async {
    final body = <String, dynamic>{
      'start_date': _ymd(startDate),
      'end_date': _ymd(endDate ?? startDate),
      'organization_id': organizationId,
      'doctor_ids': doctorIds,
      'visit_format_id': visitFormatId,
      'comment': comment ?? '',
    };
    const path = '/api/visits/plans';
    debugPrint('[PLAN PUSH] POST $path body=${jsonEncode(body)}');
    try {
      final response = await _api.dio.post(path, data: body);
      debugPrint(
        '[PLAN PUSH] ← ${response.statusCode} ${jsonEncode(response.data)}',
      );
      return {
        'ok': true,
        'path': path,
        'status': response.statusCode,
        'request': body,
        'response': response.data,
      };
    } catch (e) {
      Map<String, dynamic> errResponse;
      if (e is DioException) {
        errResponse = {
          'path': path,
          'status': e.response?.statusCode,
          'data': e.response?.data,
          'message': e.message,
        };
        debugPrint(
          '[PLAN PUSH] ← ${e.response?.statusCode} ${jsonEncode(e.response?.data)}',
        );
      } else {
        errResponse = {'path': path, 'error': '$e'};
        debugPrint('[PLAN PUSH] ← ERROR $e');
      }
      throw RemotePushException(
        message: 'Plan push failed',
        request: body,
        response: errResponse,
      );
    }
  }

  static String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<List<Map<String, dynamic>>> getCompanyMarkups() async {
    List<dynamic> rows;
    try {
      rows = await _getListAny(['/api/Company/markups', '/Company/markups']);
    } catch (_) {
      rows = await _getListAny(['/api/Markups/sync', '/Markups/sync']);
    }
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => _toBool(e['is_deleted']) != true)
        .toList();
  }

  Future<Set<String>> getSupportedOrderTermKeys({int? companyId}) async {
    final markups = await getCompanyMarkups();
    final keys = <String>{};
    for (final markup in markups) {
      final markupCompanyId = _toInt(markup['company_id']);
      if (companyId != null && markupCompanyId != null) {
        if (markupCompanyId != companyId) continue;
      }
      final prepayment = _toInt(markup['prepayment_percent']);
      if (prepayment == null) continue;
      final detailings = _extractMarkupDetailings(
        markup,
      ).where((detail) => _toBool(detail['is_deleted']) != true).toList();
      if (detailings.isEmpty) {
        keys.add('$prepayment:0');
        continue;
      }
      for (final detail in detailings) {
        final buyerType = (_toBool(detail['is_wholesaler']) ?? false) ? 1 : 0;
        keys.add('$prepayment:$buyerType');
      }
    }
    return keys;
  }

  Future<bool> supportsWholesaleOrders({int? companyId}) async {
    final markups = await getCompanyMarkups();
    for (final markup in markups) {
      final markupCompanyId = _toInt(markup['company_id']);
      if (companyId != null &&
          markupCompanyId != null &&
          markupCompanyId != companyId) {
        continue;
      }
      final detailings = _extractMarkupDetailings(markup);
      if (detailings.any(
        (detail) =>
            _toBool(detail['is_deleted']) != true &&
            (_toBool(detail['is_wholesaler']) ?? false),
      )) {
        return true;
      }
    }
    return false;
  }

  Future<Map<String, dynamic>?> resolveOrderPricingTerms({
    required int prepaymentPercent,
    required bool isWholesaler,
    double orderTotal = 0,
    int paymentVariantId = 1,
    int? companyId,
  }) async {
    final markups = await getCompanyMarkups();
    final scopedMarkups = markups.where((markup) {
      final markupCompanyId = _toInt(markup['company_id']);
      if (companyId != null && markupCompanyId != null) {
        return markupCompanyId == companyId;
      }
      return true;
    }).toList();

    final exactMatches = scopedMarkups.where((markup) {
      final percent = _toInt(markup['prepayment_percent']);
      return percent == prepaymentPercent;
    }).toList();

    final candidateMarkups = exactMatches.isNotEmpty
        ? exactMatches
        : (prepaymentPercent == 0
              ? (scopedMarkups.where((markup) {
                  final percent = _toInt(markup['prepayment_percent']);
                  return percent != null && percent < 100;
                }).toList()..sort((a, b) {
                  final ap = _toInt(a['prepayment_percent']) ?? 999999;
                  final bp = _toInt(b['prepayment_percent']) ?? 999999;
                  return ap.compareTo(bp);
                }))
              : const <Map<String, dynamic>>[]);

    for (final markup in candidateMarkups) {
      final markupCompanyId = _toInt(markup['company_id']);
      final percent = _toInt(markup['prepayment_percent']);

      final detailings = _extractMarkupDetailings(markup);
      final activeDetailings = detailings
          .where((detail) => _toBool(detail['is_deleted']) != true)
          .toList();
      final filtered = activeDetailings.where((detail) {
        final start = _toDouble(detail['sum_start']);
        final end = _toDouble(detail['sum_end']);
        final inRange =
            (start == null || orderTotal >= start) &&
            (end == null || end <= 0 || orderTotal <= end);
        if (!inRange) return false;

        final variant = _toInt(detail['payment_variant_id']);
        return variant == null || variant == paymentVariantId;
      }).toList();

      Map<String, dynamic> detail = filtered.firstWhere(
        (detail) => (_toBool(detail['is_wholesaler']) ?? false) == isWholesaler,
        orElse: () => const <String, dynamic>{},
      );
      if (detail.isEmpty && filtered.isNotEmpty) {
        detail = filtered.first;
      }
      if (detail.isEmpty && activeDetailings.isNotEmpty) {
        detail = activeDetailings.first;
      }

      return {
        'company_id': markupCompanyId,
        'payment_variant_id':
            _toInt(detail['payment_variant_id']) ?? paymentVariantId,
        'margin_id': _toInt(markup['id'] ?? markup['margin_id']),
        'margin_percent': _toInt(detail['margin_percent']),
        'prepayment_percent': percent ?? prepaymentPercent,
        'requested_prepayment_percent': prepaymentPercent,
        'is_wholesaler': isWholesaler,
      };
    }
    return null;
  }

  Future<Map<String, dynamic>> createOrderDebug({
    required int orderUserId,
    required int organizationId,
    int? organizationInn,
    int? companyId,
    int? paymentVariantId,
    int? marginId,
    int? marginPercent,
    int? prepaymentPercent,
    required bool isWholesaler,
    String? orderComment,
    String? orderExpireDate,
    required List<Map<String, dynamic>> drugs,
  }) async {
    final sanitizedDrugs = _sanitizeOrderDrugs(
      drugs,
      defaultMarginPercent: marginPercent,
    );
    if (sanitizedDrugs.isEmpty) {
      throw const FormatException('Order requires at least one valid drug');
    }

    final body = <String, dynamic>{
      'company_id': ?companyId,
      'payment_variant_id': ?paymentVariantId,
      'margin_id': ?marginId,
      'margin_percent': ?marginPercent,
      'prepayment_percent': ?prepaymentPercent,
      'is_wholesaler': isWholesaler,
      'order_user_id': orderUserId,
      'organization_id': organizationId,
      'organization_inn': ?organizationInn,
      'order_expire_date': ?orderExpireDate,
      'order_comment': orderComment ?? '',
      'drugs': sanitizedDrugs,
    };
    return _postCreateOrderDebug(body);
  }

  Future<Map<String, dynamic>> createOrderVisitDebug({
    required int orderUserId,
    required int organizationId,
    int? companyId,
    int? paymentVariantId,
    int? marginId,
    int? marginPercent,
    int? prepaymentPercent,
    required bool isWholesaler,
    String? orderComment,
    String? orderExpireDate,
    required List<Map<String, dynamic>> drugs,
    bool pricesAlreadyCalculated = false,
  }) async {
    final sanitizedDrugs = _sanitizeOrderDrugs(
      drugs,
      defaultMarginPercent: marginPercent,
    );
    if (sanitizedDrugs.isEmpty) {
      throw const FormatException('Order visit requires at least one drug');
    }

    var resolvedPaymentVariantId = paymentVariantId ?? 1;
    var resolvedMarginId = marginId;
    if (resolvedMarginId == null && prepaymentPercent != null) {
      final orderTotal = sanitizedDrugs.fold<double>(0, (sum, item) {
        final price = _toDouble(item['sale_price']) ?? 0;
        final qty = _toInt(item['package']) ?? 0;
        return sum + price * qty;
      });
      final terms = await resolveOrderPricingTerms(
        prepaymentPercent: prepaymentPercent,
        isWholesaler: isWholesaler,
        orderTotal: orderTotal,
        paymentVariantId: resolvedPaymentVariantId,
        companyId: companyId,
      );
      if (terms != null) {
        resolvedPaymentVariantId =
            _toInt(terms['payment_variant_id']) ?? resolvedPaymentVariantId;
        resolvedMarginId = _toInt(terms['margin_id']);
      }
    }
    if (resolvedMarginId == null) {
      throw const FormatException('Order visit requires margin_id');
    }

    final calculatedDrugs = pricesAlreadyCalculated
        ? sanitizedDrugs
        : await _applyServerPricingToOrderDrugs(
            sanitizedDrugs,
            marginId: resolvedMarginId,
            paymentVariantId: resolvedPaymentVariantId,
            isWholesaler: isWholesaler,
          );

    final body = <String, dynamic>{
      'complete': true,
      'organization_id': organizationId,
      'visit_type': 1,
      'latitude': 0,
      'longitude': 0,
      'payment_variant_id': resolvedPaymentVariantId,
      'margin_id': resolvedMarginId,
      'is_wholesaler': isWholesaler,
      'contract_id': null,
      'comment': orderComment ?? '',
      'drugs': calculatedDrugs
          .map(
            (drug) => <String, dynamic>{
              'income_detailing_id': _toInt(drug['income_detailing_id']),
              'drug_id': _toInt(drug['drug_id']),
              'package': _toInt(drug['package']) ?? 0,
              'sale_price': _toDouble(drug['sale_price']) ?? 0,
            },
          )
          .toList(),
    };
    return _postVisitAddDebug(body);
  }

  Future<Map<String, dynamic>?> prepareOrderVisitDraft({
    required int prepaymentPercent,
    required bool isWholesaler,
    required List<Map<String, dynamic>> drugs,
    int? companyId,
    int paymentVariantId = 1,
    double? orderTotal,
  }) async {
    final sanitizedDrugs = _sanitizeOrderDrugs(drugs);
    if (sanitizedDrugs.isEmpty) return null;
    final effectiveOrderTotal =
        orderTotal ??
        sanitizedDrugs.fold<double>(0, (sum, item) {
          final price = _toDouble(item['sale_price']) ?? 0;
          final qty = _toInt(item['package']) ?? 0;
          return sum + price * qty;
        });
    final pricingTerms = await resolveOrderPricingTerms(
      prepaymentPercent: prepaymentPercent,
      isWholesaler: isWholesaler,
      orderTotal: effectiveOrderTotal,
      paymentVariantId: paymentVariantId,
      companyId: companyId,
    );
    if (pricingTerms == null) return null;
    final resolvedPaymentVariantId =
        _toInt(pricingTerms['payment_variant_id']) ?? paymentVariantId;
    final resolvedMarginId = _toInt(pricingTerms['margin_id']);
    if (resolvedMarginId == null) return null;
    final pricedDrugs = await _applyServerPricingToOrderDrugs(
      sanitizedDrugs,
      marginId: resolvedMarginId,
      paymentVariantId: resolvedPaymentVariantId,
      isWholesaler: isWholesaler,
    );
    return {
      'company_id': pricingTerms['company_id'],
      'payment_variant_id': resolvedPaymentVariantId,
      'margin_id': resolvedMarginId,
      'margin_percent': pricingTerms['margin_percent'],
      'prepayment_percent': prepaymentPercent,
      'is_wholesaler': isWholesaler,
      'drugs': pricedDrugs,
    };
  }

  Future<Map<String, dynamic>> _postCreateOrderDebug(
    Map<String, dynamic> body,
  ) async {
    final paths = ['/api/Orders/add', '/Orders/add'];
    Object? lastError;
    Map<String, dynamic>? lastResponse;
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
        if (e is DioException) {
          lastResponse = {
            'path': path,
            'status': e.response?.statusCode,
            'data': e.response?.data,
            'message': e.message,
          };
        } else {
          lastResponse = {'path': path, 'error': '$e'};
        }
      }
    }
    if (lastError != null) {
      throw RemotePushException(
        message: 'Order push failed',
        request: body,
        response:
            lastResponse ??
            {'error': '$lastError', 'message': 'Unknown order push error'},
      );
    }
    return {'ok': false, 'request': body, 'error': 'Unknown order push error'};
  }

  Future<List<Map<String, dynamic>>> _applyServerPricingToOrderDrugs(
    List<Map<String, dynamic>> drugs, {
    required int marginId,
    required int paymentVariantId,
    required bool isWholesaler,
  }) async {
    if (drugs.isEmpty) return drugs;
    final pricing = await _postPricingCalculateDebug({
      'margin_id': marginId,
      'payment_variant_id': paymentVariantId,
      'is_wholesaler': isWholesaler,
      'calculate_sale_price_details': drugs
          .map(
            (drug) => <String, dynamic>{
              'income_detail_id': _toInt(drug['income_detailing_id']),
              'drug_id': _toInt(drug['drug_id']),
              'package': _toInt(drug['package']) ?? 0,
            },
          )
          .toList(),
    });

    final responseMap = _coerceMap(pricing['response']);
    final responseMarginPercent = _toDouble(responseMap['margin_percent']);
    final rawPrices = responseMap['prices'];
    if (rawPrices is! List || rawPrices.isEmpty) return drugs;

    final byIncomeDetailingId = <int, Map<String, dynamic>>{};
    final byDrugId = <int, Map<String, dynamic>>{};
    for (final row in rawPrices.whereType<Map>()) {
      final priceRow = Map<String, dynamic>.from(row);
      final incomeDetailingId = _toInt(
        priceRow['income_detailing_id'] ?? priceRow['income_detail_id'],
      );
      final drugId = _toInt(priceRow['drug_id']);
      if (incomeDetailingId != null) {
        byIncomeDetailingId[incomeDetailingId] = priceRow;
      }
      if (drugId != null) {
        byDrugId[drugId] = priceRow;
      }
    }

    return drugs.map((drug) {
      final incomeDetailingId = _toInt(drug['income_detailing_id']);
      final drugId = _toInt(drug['drug_id']);
      final calculated =
          (incomeDetailingId != null
              ? byIncomeDetailingId[incomeDetailingId]
              : null) ??
          (drugId != null ? byDrugId[drugId] : null);
      if (calculated == null) return drug;
      return {
        ...drug,
        'sale_price':
            _toDouble(calculated['sale_price']) ??
            _toDouble(drug['sale_price']) ??
            0,
        'sale_price_without_nds':
            _toDouble(calculated['sale_price_without_nds']) ??
            _toDouble(drug['sale_price_without_nds']),
        'margin_percent':
            _toDouble(calculated['margin_percent']) ??
            responseMarginPercent ??
            _toDouble(drug['margin_percent']),
      };
    }).toList();
  }

  Future<Map<String, dynamic>> _postPricingCalculateDebug(
    Map<String, dynamic> body,
  ) async {
    final paths = [
      '/api/pricing/calculate',
      '/pricing/calculate',
      '/api/Pricing/calculate',
      '/Pricing/calculate',
    ];
    Object? lastError;
    Map<String, dynamic>? lastResponse;
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
        if (e is DioException) {
          lastResponse = {
            'path': path,
            'status': e.response?.statusCode,
            'data': e.response?.data,
            'message': e.message,
          };
        } else {
          lastResponse = {'path': path, 'error': '$e'};
        }
      }
    }
    if (lastError != null) {
      throw RemotePushException(
        message: 'Pricing calculate failed',
        request: body,
        response:
            lastResponse ??
            {
              'error': '$lastError',
              'message': 'Unknown pricing calculate error',
            },
      );
    }
    return {
      'ok': false,
      'request': body,
      'error': 'Unknown pricing calculate error',
    };
  }

  Future<Map<String, dynamic>?> _buildOrderVisitPayloadFromLocalVisit(
    LocalVisit visit,
  ) async {
    final raw = _decodeJsonMap(visit.rawJson);
    if (raw == null) return null;
    final drugs = _sanitizeOrderDrugs(raw['drugs'] ?? raw['items']);
    if (drugs.isEmpty) return null;

    final isWholesaler = _toBool(raw['is_wholesaler']) ?? false;
    var paymentVariantId = _toInt(raw['payment_variant_id']) ?? 1;
    var marginId = _toInt(raw['margin_id']);
    final prepayment = _toInt(raw['prepayment_percent'] ?? raw['prepayment']);
    var companyId = _toInt(raw['company_id']);
    companyId ??= await _getCurrentCompanyIdSafe();

    if (prepayment != null && marginId == null) {
      final orderTotal = drugs.fold<double>(0, (sum, item) {
        final price = _toDouble(item['sale_price']) ?? 0;
        final qty = _toInt(item['package']) ?? 0;
        return sum + price * qty;
      });
      try {
        final terms = await resolveOrderPricingTerms(
          prepaymentPercent: prepayment,
          isWholesaler: isWholesaler,
          orderTotal: orderTotal,
          paymentVariantId: paymentVariantId,
          companyId: companyId,
        );
        if (terms != null) {
          paymentVariantId =
              _toInt(terms['payment_variant_id']) ?? paymentVariantId;
          marginId = _toInt(terms['margin_id']);
        }
      } catch (e) {
        logSwallowed(e, 'RemoteApi._buildOrderVisitPayloadFromLocalVisit');
      }
    }

    if (marginId == null) return null;

    final calculatedDrugs = await _applyServerPricingToOrderDrugs(
      drugs,
      marginId: marginId,
      paymentVariantId: paymentVariantId,
      isWholesaler: isWholesaler,
    );

    return {
      'complete': true,
      'organization_id': visit.orgId,
      'visit_type': 1,
      'latitude': 0,
      'longitude': 0,
      'margin_id': marginId,
      'contract_id': null,
      'is_wholesaler': isWholesaler,
      'payment_variant_id': paymentVariantId,
      'comment': _toString(raw['order_comment'] ?? raw['comment']) ?? '',
      'drugs': calculatedDrugs
          .map(
            (drug) => <String, dynamic>{
              'income_detailing_id': _toInt(drug['income_detailing_id']),
              'drug_id': _toInt(drug['drug_id']),
              'package': _toInt(drug['package']) ?? 0,
              'sale_price': _toDouble(drug['sale_price']) ?? 0,
            },
          )
          .toList(),
    };
  }

  Future<int?> _getCurrentCompanyIdSafe() async {
    try {
      final user = await getCurrentUser();
      final rawCompany = user['company_id'] ?? user['companyId'];
      final id = _toInt(rawCompany);
      if (id != null) return id;
      final company = user['company'];
      if (company is Map) {
        final companyMap = Map<String, dynamic>.from(company);
        return _toInt(companyMap['id'] ?? companyMap['company_id']);
      }
    } catch (e) {
      logSwallowed(e, 'RemoteApi._getCurrentCompanyIdSafe');
    }
    return null;
  }

  static Map<String, dynamic>? _decodeJsonMap(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      logSwallowed(e, 'RemoteApi._decodeJsonMap');
    }
    return null;
  }

  static Map<String, dynamic> _coerceMap(dynamic data) {
    if (data is Map<String, dynamic>) return _extractMap(data);
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return _extractMap(decoded);
    }
    throw const FormatException('Expected JSON object response');
  }

  static List<Map<String, dynamic>> _extractMarkupDetailings(
    Map<String, dynamic> markup,
  ) {
    final raw =
        markup['markup_detailings'] ??
        markup['detailings'] ??
        markup['details'] ??
        markup['items'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static List<Map<String, dynamic>> _sanitizeOrderDrugs(
    dynamic raw, {
    int? defaultMarginPercent,
  }) {
    final rows = raw is List ? raw : _extractList(raw);
    return rows
        .whereType<Map>()
        .map(
          (row) => _sanitizeOrderDrug(
            row,
            defaultMarginPercent: defaultMarginPercent,
          ),
        )
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static Map<String, dynamic>? _sanitizeOrderDrug(
    Map raw, {
    int? defaultMarginPercent,
  }) {
    final m = Map<String, dynamic>.from(raw);
    final incomeDetailingId = _toInt(
      m['income_detailing_id'] ?? m['current_stock_id'],
    );
    final drugId = _toInt(m['drug_id'] ?? m['binding_drug_id']);
    final qty = _toInt(m['package'] ?? m['quantity'] ?? m['amount']) ?? 1;
    if (incomeDetailingId == null || drugId == null || qty <= 0) return null;

    final salePrice = _toDouble(m['sale_price'] ?? m['price']);
    final withoutNds =
        _toDouble(m['sale_price_without_nds']) ??
        (salePrice == null ? null : _withoutNds(salePrice));

    return {
      'visit_detailing_id': ?_toInt(m['visit_detailing_id']),
      'income_detailing_id': incomeDetailingId,
      'drug_id': drugId,
      'drug_one_c_guid': ?_toString(m['drug_one_c_guid']),
      'package': qty,
      'margin_percent':
          ?(_toDouble(m['margin_percent']) ?? defaultMarginPercent?.toDouble()),
      'sale_price': ?salePrice,
      'sale_price_without_nds': ?withoutNds,
      'serial_no': ?_toString(m['serial_no'] ?? m['serial_number']),
      'expire_date': ?_toString(m['expire_date'] ?? m['expiry_date']),
      'is_deleted': ?_toBool(m['is_deleted']),
      'storage_id': ?_toInt(m['storage_id']),
    };
  }

  static double _withoutNds(double value) {
    return double.parse((value / 1.12).toStringAsFixed(2));
  }

  static Map<String, dynamic> _extractVisitPayloadFromRawJson(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) return const <String, dynamic>{};
      final m = Map<String, dynamic>.from(decoded);
      final allowedKeys = <String>{
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
        'visit_pharm_circle',
        'talked_about_drugs',
        'presentations',
        'medical_representative_name',
        // Group LPU: override single doctor_id with the full array stored in raw_json,
        // and tell the server the visit format (group=3, double=2).
        'doctor_ids',
        'visit_format_id',
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

  Future<List<PlannedVisit>> getCurrentVisitPlans([DateTime? date]) async {
    final d = date ?? DateTime.now();
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final rows = await _getList(
      '/api/Visits/plans/current',
      queryParameters: {'date': dateStr},
    );
    return rows.map(_mapPlannedVisit).whereType<PlannedVisit>().toList();
  }

  /// Returns plans for [date] already mapped to local DB row format.
  /// Used for background upsert when calendar dots show unloaded API days.
  Future<List<Map<String, dynamic>>> getPlansForDate(DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final rows = await _getList(
      '/api/Visits/plans/current',
      queryParameters: {'date': dateStr},
    );
    return rows
        .map(mapPlannedVisitToLocal)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<PlannedVisit>> getVisitPlans() async {
    final rows = await _getListAny(['/visits/plans', '/api/Visits/plans']);
    return rows.map(_mapPlannedVisit).whereType<PlannedVisit>().toList();
  }

  /// Returns per-day visit counts for the month calendar from GET /api/Visits/plans/month.
  /// Response shape: [{date: "2026-05-18T00:00:00", visit_count: 2}, ...]
  Future<List<Map<String, dynamic>>> getMonthVisitPlanCounts(
    int year,
    int month,
  ) async {
    try {
      final resp = await _api.dio.get(
        '/api/Visits/plans/month',
        queryParameters: {'year': year, 'month': month},
      );
      final list = _extractList(resp.data);
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Returns available visit formats from GET /api/visits/formats.
  /// Shape: [{id: 1, name: "Фармкружок"}, ...]
  Future<List<Map<String, dynamic>>> getVisitFormats() async {
    try {
      final resp = await _api.dio.get('/api/visits/formats');
      final list = _extractList(resp.data);
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
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

  Future<List<Map<String, dynamic>>> getFavoriteOrganizations({
    bool allowDictionaryFallback = true,
  }) async {
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
      if (!allowDictionaryFallback) return const <Map<String, dynamic>>[];
      final all = await _getList(
        '/api/dict/Organizations',
        queryParameters: {'_no_limit': true},
      );
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
      } catch (e) {
        // Try next endpoint.
        logSwallowed(e, 'RemoteApi.getManagers');
      }
    }
    return const <ManagerOption>[];
  }

  Future<List<Map<String, dynamic>>> getDoctorsByOrganization(
    int organizationId,
  ) async {
    final endpoints =
        <({String path, Map<String, dynamic>? query, bool scopedPath})>[
          (
            path: '/api/dict/Organizations/$organizationId/doctors',
            query: null,
            scopedPath: true,
          ),
          (
            path: '/dict/Organizations/$organizationId/doctors',
            query: null,
            scopedPath: true,
          ),
          (
            path: '/api/dict/Doctors',
            query: {
              'organization_id': [organizationId],
              '_no_limit': true,
            },
            scopedPath: false,
          ),
          (
            path: '/api/dict/Doctors',
            query: {'organization_id': organizationId, '_no_limit': true},
            scopedPath: false,
          ),
          (
            path: '/doctors/by-organization/$organizationId',
            query: null,
            scopedPath: true,
          ),
          (
            path: '/Doctors/by-organization/$organizationId',
            query: null,
            scopedPath: true,
          ),
          (
            path: '/api/doctors/by-organization/$organizationId',
            query: null,
            scopedPath: true,
          ),
          (
            path: '/api/Doctors/by-organization/$organizationId',
            query: null,
            scopedPath: true,
          ),
        ];
    Object? lastError;
    for (final e in endpoints) {
      try {
        final rows = await _getList(e.path, queryParameters: e.query);
        final mapped = rows
            .map(_mapDoctor)
            .whereType<Map<String, dynamic>>()
            .toList();
        final filtered = e.scopedPath
            ? mapped.map((row) {
                final doctor = Map<String, dynamic>.from(row);
                if (((doctor['organisation_id'] as num?)?.toInt() ?? 0) == 0) {
                  doctor['organisation_id'] = organizationId;
                }
                return doctor;
              }).toList()
            : mapped
                  .where(
                    (row) =>
                        (row['organisation_id'] as num?)?.toInt() ==
                        organizationId,
                  )
                  .toList();
        if (filtered.isNotEmpty) return filtered;
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

  Future<List<Map<String, dynamic>>> getFavoriteDoctors({
    bool allowDictionaryFallback = true,
  }) async {
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
      if (!allowDictionaryFallback) return const <Map<String, dynamic>>[];
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
    } catch (e) {
      logSwallowed(e, 'RemoteApi.updateVisit');
    }
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
    return getDoctorsSyncBatched(syncId: syncId);
  }

  Future<List<Map<String, dynamic>>> getDoctorsSyncBatched({
    int? syncId,
    int batchSize = 1000,
    bool collectRows = true,
    FutureOr<void> Function(
      List<Map<String, dynamic>> doctors,
      int loadedCount,
      int cursor,
    )?
    onBatch,
  }) async {
    try {
      return _getDoctorsSyncBatchedFromPaths(
        const [
          '/dict/doctors/sync',
          '/dict/Doctors/sync',
          '/Doctors/sync',
          '/api/Doctors/sync',
        ],
        syncId: syncId,
        batchSize: batchSize,
        collectRows: collectRows,
        onBatch: onBatch,
      );
    } catch (_) {
      if (syncId != null) rethrow;
      return getDoctorsDictionary();
    }
  }

  Future<List<Map<String, dynamic>>> _getDoctorsSyncBatchedFromPaths(
    List<String> paths, {
    int? syncId,
    required int batchSize,
    required bool collectRows,
    FutureOr<void> Function(
      List<Map<String, dynamic>> doctors,
      int loadedCount,
      int cursor,
    )?
    onBatch,
  }) async {
    Object? lastError;
    for (final path in paths) {
      try {
        return await _getDoctorsSyncBatchedFromPath(
          path,
          syncId: syncId,
          batchSize: batchSize,
          collectRows: collectRows,
          onBatch: onBatch,
        );
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> _getDoctorsSyncBatchedFromPath(
    String path, {
    int? syncId,
    required int batchSize,
    required bool collectRows,
    FutureOr<void> Function(
      List<Map<String, dynamic>> doctors,
      int loadedCount,
      int cursor,
    )?
    onBatch,
  }) async {
    final out = <Map<String, dynamic>>[];
    var cursor = syncId ?? 0;
    var loaded = 0;

    for (var guard = 0; guard < 500; guard++) {
      final response = await _api.dio.get(
        path,
        queryParameters: {'sync_id': cursor, 'batch_size': batchSize},
      );
      final data = response.data;
      final rawRows = _extractList(data);
      if (rawRows.isEmpty) break;

      final doctors = rawRows
          .map(_mapDoctor)
          .whereType<Map<String, dynamic>>()
          .toList();
      loaded += doctors.length;
      if (collectRows) out.addAll(doctors);

      final responseCursor = data is Map<String, dynamic>
          ? _toInt(
              data['max_sync_id'] ??
                  data['maxSyncId'] ??
                  data['last_sync_id'] ??
                  data['lastSyncId'],
            )
          : null;
      final rowsCursor = doctors
          .map((row) => _toInt(row['sync_id']))
          .whereType<int>()
          .fold<int>(cursor, (max, value) => value > max ? value : max);
      final nextCursor = [
        cursor,
        responseCursor ?? 0,
        rowsCursor,
      ].fold<int>(0, (max, value) => value > max ? value : max);

      await onBatch?.call(doctors, loaded, nextCursor);
      if (nextCursor <= cursor || rawRows.length < batchSize) break;
      cursor = nextCursor;
    }

    return out;
  }

  Future<List<Map<String, dynamic>>> getDoctorsDictionary({
    int? regionId,
    int startPage = 1,
    int initialLoadedCount = 0,
    void Function(
      int currentPage,
      int? totalPages,
      int loadedCount,
      int? totalCount,
    )?
    onPage,
    FutureOr<void> Function(
      List<Map<String, dynamic>> doctors,
      int currentPage,
      int? totalPages,
      int loadedCount,
      int? totalCount,
    )?
    onRows,
  }) async {
    final rows = await _getListAnyPaged(
      ['/api/dict/Doctors', '/dict/Doctors'],
      queryParameters: {'region_id': ?regionId, 'batch_size': 1000},
      startPage: startPage,
      initialLoadedCount: initialLoadedCount,
      onPage: onPage,
      onPageItems: onRows == null
          ? null
          : (items, currentPage, totalPages, loadedCount, totalCount) async {
              final mapped = items
                  .map(_mapDoctor)
                  .whereType<Map<String, dynamic>>()
                  .toList();
              if (mapped.isNotEmpty) {
                await onRows(
                  mapped,
                  currentPage,
                  totalPages,
                  loadedCount,
                  totalCount,
                );
              }
            },
    );
    return rows.map(_mapDoctor).whereType<Map<String, dynamic>>().toList();
  }

  Future<int?> getDoctorsDictionaryTotal({int? regionId}) async {
    Object? lastError;
    for (final path in ['/api/dict/Doctors', '/dict/Doctors']) {
      try {
        final response = await _api.dio.get(
          path,
          queryParameters: {
            'region_id': ?regionId,
            'batch_size': 1000,
            'page': 1,
          },
        );
        final data = response.data;
        if (data is Map<String, dynamic> && data['page'] is Map) {
          final pageInfo = Map<String, dynamic>.from(data['page'] as Map);
          return _toInt(
            pageInfo['total_items'] ??
                pageInfo['total_count'] ??
                pageInfo['total'] ??
                pageInfo['count'],
          );
        }
        final list = _extractList(data);
        if (list.isNotEmpty) return list.length;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
    return null;
  }

  Future<List<Map<String, dynamic>>> getOrganizationsDictionary() async {
    final rows = await _getListAnyWithQuery(
      ['/api/dict/Organizations', '/dict/Organizations'],
      queryParameters: {'_no_limit': true},
    );
    return rows.map(_mapOrg).whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getDoctorOrganisationRelations({
    int? syncId,
  }) async {
    final rows = await _getListAnyWithQuery(
      ['/api/dict/Doctors/relations/sync', '/Doctors/relations/sync'],
      queryParameters: {'sync_id': ?syncId},
    );
    return rows
        .whereType<Map>()
        .map((raw) {
          final m = Map<String, dynamic>.from(raw);
          final doctorId = _toInt(m['doctor_id']);
          final organisationId = _toInt(
            m['organization_id'] ?? m['organisation_id'] ?? m['org_id'],
          );
          if (doctorId == null || doctorId <= 0 || organisationId == null) {
            return null;
          }
          return <String, dynamic>{
            'doctor_id': doctorId,
            'organisation_id': organisationId,
            'sync_id': _toInt(m['sync_id']),
            'raw_json': jsonEncode(m),
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();
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

  Future<List<Map<String, dynamic>>> getOrganizationsSync({
    int? syncId,
    int? regionId,
  }) async {
    final rows = await _getListAnyWithQuery(
      ['/api/dict/Organizations/sync', '/dict/Organizations/sync'],
      queryParameters: {'sync_id': ?syncId, 'region_id': ?regionId},
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
            buf.writeln(
              '  First item keys: ${(data.first as Map?)?.keys.toList()}',
            );
            buf.writeln('  First item: ${jsonEncode(data.first)}');
          }
        } else if (data is Map) {
          buf.writeln('  Map keys: ${data.keys.toList()}');
          final preview = jsonEncode(data);
          buf.writeln(
            '  ${preview.length > 500 ? preview.substring(0, 500) : preview}',
          );
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
      debugPrint(
        '[PriceList] first row keys: ${(rows.first as Map?)?.keys.toList()}',
      );
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
          serialNumber: _toString(
            m['serial_no'] ?? m['series'] ?? m['serial_number'],
          ),
          expiryDate: _toString(m['expire_date'] ?? m['expiry_date']),
          price: price,
          mainStock: _toInt(m['actual_balance'] ?? m['main_stock']),
          stock: _toInt(
            m['remains_amount'] ?? m['stock'] ?? m['actual_balance'],
          ),
          remainsStock: _toInt(m['remains_amount'] ?? m['stock']),
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
  Future<
    ({
      List<Map<String, dynamic>> materials,
      Map<int, int> counts,
      Map<int, String> drugNames,
    })
  >
  getDrugDocuments({int? companyId}) async {
    final materials = <Map<String, dynamic>>[];
    final counts = <int, int>{};
    final drugNames = <int, String>{};
    int page = 1;
    bool hasMore = true;
    while (hasMore) {
      try {
        final response = await _api.dio.get(
          '/api/Documents',
          queryParameters: {
            'page': page,
            'page_size': 50,
            'company_id': ?companyId,
          },
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
          if (drugName != null && drugName.isNotEmpty) {
            drugNames[drugId] = drugName;
          }
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
              'description': _toString(doc['description']),
              'uploaded_at': _toString(doc['date_of_creation']),
              'is_mandatory': (_toBool(doc['must_see']) == true) ? 1 : 0,
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
      final createdAt =
          _toString(c['date_of_creation']) ?? DateTime.now().toIso8601String();
      final isWholesaler = _toBool(c['is_wholesaler']);
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
          'main_stock': _toInt(stock['actual_balance'] ?? stock['amount']),
          'stock': _toInt(stock['amount']),
          'remains_stock': _toInt(stock['amount']),
          'quantity': _toInt(it['amount']) ?? 1,
          'pharmacy_id': pharmacyId,
          'pharmacy_name': pharmacyName,
          'added_at': createdAt,
          'cart_id': _toInt(c['id']),
          'prepayment_percent': _toInt(
            c['prepayment_percent'] ?? c['prepayment'],
          ),
          'buyer_type':
              _toInt(c['buyer_type']) ??
              (isWholesaler == null ? null : (isWholesaler ? 1 : 0)),
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
    return rows.map(_mapVisit).whereType<Map<String, dynamic>>().toList();
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
    return rows.map(_mapVisit).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>?> getVisitHistoryRemnantById(int visitId) async {
    final rows = await getVisitHistoryRemnant();
    for (final row in rows) {
      final id = _toInt(row['remote_id'] ?? row['id']);
      if (id == visitId) return row;
    }
    return null;
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
    int startPage = 1,
    int initialLoadedCount = 0,
    void Function(
      int currentPage,
      int? totalPages,
      int loadedCount,
      int? totalCount,
    )?
    onPage,
    FutureOr<void> Function(
      List<dynamic> rows,
      int currentPage,
      int? totalPages,
      int loadedCount,
      int? totalCount,
    )?
    onPageItems,
  }) async {
    Object? lastError;
    for (final path in paths) {
      try {
        final out = <dynamic>[];
        var page = startPage < 1 ? 1 : startPage;
        var hasMore = true;
        while (hasMore) {
          final qp = <String, dynamic>{...?queryParameters, 'page': page};
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
            final totalCount = _toInt(
              pageInfo['count'] ??
                  pageInfo['total_count'] ??
                  pageInfo['total_items'] ??
                  pageInfo['total'] ??
                  pageInfo['items_count'],
            );
            await onPageItems?.call(
              list,
              page,
              totalPages,
              initialLoadedCount + out.length,
              totalCount,
            );
            onPage?.call(
              page,
              totalPages,
              initialLoadedCount + out.length,
              totalCount,
            );
            hasMore = hasNext || page < totalPages;
            page++;
            continue;
          }
          await onPageItems?.call(
            list,
            page,
            null,
            initialLoadedCount + out.length,
            null,
          );
          onPage?.call(page, null, initialLoadedCount + out.length, null);
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
    final isDistributor =
        (typeText?.contains('distributor') ?? false) ||
        (typeText?.contains('дистриб') ?? false) ||
        typeId == 3;

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
      'type': isPharmacy ? 'pharmacy' : (isDistributor ? 'distributor' : 'lpu'),
      'city': _toString(
        m['city'] ?? m['region_name'] ?? _nestedName(m['region']),
      ),
      'region_id': _toInt(
        m['region_id'] ?? m['regionId'] ?? _nestedId(m['region']),
      ),
      'district': _toString(
        m['district'] ?? m['area'] ?? m['area_name'] ?? _nestedName(m['area']),
      ),
      'area_id': _toInt(m['area_id'] ?? m['areaId'] ?? _nestedId(m['area'])),
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
      'is_favorite':
          (_toBool(
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
      'is_deleted': _toBool(m['is_deleted']) == true ? 1 : null,
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
      'is_favorite':
          (_toBool(
                m['is_favorite'] ??
                    m['isFavorite'] ??
                    m['favorite'] ??
                    m['in_favorites'],
              ) ??
              false)
          ? 1
          : 0,
      'category':
          _toString(m['category'] ?? m['category_name'] ?? m['class']) ?? 'C',
      'last_visit_label': _toString(m['last_visit_label']) ?? '',
      'updated_at': _toIso(m['updated_at']) ?? DateTime.now().toIso8601String(),
      'sync_id': _toInt(m['sync_id']),
      'is_deleted': _toBool(m['is_deleted']) == true ? 1 : null,
      'raw_json': jsonEncode(m),
    };
  }

  static dynamic _nestedId(dynamic raw) {
    if (raw is Map) return raw['id'] ?? raw['region_id'] ?? raw['area_id'];
    return null;
  }

  static dynamic _nestedName(dynamic raw) {
    if (raw is Map) return raw['name'] ?? raw['name_ru'] ?? raw['title'];
    return null;
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
      'main_stock':
          _toInt(
            m['main_stock'] ??
                m['actual_balance'] ??
                m['total_stock'] ??
                m['warehouse_stock'],
          ) ??
          0,
      'stock':
          _toInt(
            m['stock'] ??
                m['remains_stock'] ??
                m['balance'] ??
                m['quantity'] ??
                m['remainder'] ??
                m['unique_counter'],
          ) ??
          0,
      'remains_stock':
          _toInt(
            m['remains_stock'] ??
                m['remains_amount'] ??
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
    final orgId =
        _toInt(
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
      final hasCircle =
          m['visit_pharm_circle'] != null ||
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

  static int? _progressPercent(int current, int? total) {
    if (total == null || total <= 0) return null;
    final normalized = current.clamp(0, total);
    return ((normalized / total) * 100).round().clamp(0, 100);
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
        return DateTime(
          year,
          month,
          day,
          hour,
          minute,
          second,
        ).toIso8601String();
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
  final List<Map<String, dynamic>> doctorOrgLinks;
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
    this.doctorOrgLinks = const [],
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
