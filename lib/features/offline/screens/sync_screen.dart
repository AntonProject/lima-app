import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/api_client.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/providers/sync_provider.dart';
import 'package:lima/shell/nav_bar_layout.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  List<Map<String, dynamic>> _unsyncedVisits = [];
  List<Map<String, dynamic>> _allVisits = [];
  List<Map<String, dynamic>> _pendingDoctors = [];
  List<Map<String, dynamic>> _pendingOrgUpdates = [];
  bool _loadingVisits = true;
  bool _runningApiDiagnostics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final db = ref.read(localDatabaseProvider);
    final syncNotifier = ref.read(syncProvider.notifier);
    await db.deleteLegacyTestVisits();
    final unsynced = await db.getVisits(unsyncedOnly: true);
    final all = await db.getVisits();
    final pendingDoctors = await db.getPendingDoctors();
    final pendingOrgUpdates = await db.getPendingOrgUpdates();
    if (!mounted) return;
    await syncNotifier.refreshUnsyncedCount();
    if (!mounted) return;
    setState(() {
      _unsyncedVisits = unsynced;
      _allVisits = all;
      _pendingDoctors = pendingDoctors;
      _pendingOrgUpdates = pendingOrgUpdates;
      _loadingVisits = false;
    });
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final y = dt.year.toString();
      final mo = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$d.$mo.$y $h:$mi';
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _showJsonDialog({
    required String title,
    required Map<String, dynamic> payload,
  }) async {
    final jsonText = const JsonEncoder.withIndent('  ').convert(payload);
    final ok = payload['ok'] == true;
    final hasOk = payload.containsKey('ok');
    final statusCode = payload['status'];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (hasOk)
              Text(
                ok ? 'OK' : 'ERROR',
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: ok ? Colors.green[700] : Colors.red[700],
                ),
              ),
            if (statusCode != null)
              Text(
                'HTTP: $statusCode',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonText,
              style: GoogleFonts.robotoMono(fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonText));
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('JSON скопирован')),
              );
            },
            child: const Text('Копировать'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _runApiDiagnostics() async {
    if (_runningApiDiagnostics) return;
    setState(() => _runningApiDiagnostics = true);
    final api = ref.read(remoteApiServiceProvider);
    final startedAt = DateTime.now().toIso8601String();

    final report = <String, dynamic>{
      'started_at': startedAt,
      'checks': <String, dynamic>{},
    };
    final checks = report['checks'] as Map<String, dynamic>;

    // Cart — probe known candidate endpoints to find the server-side cart
    final dio = ref.read(apiClientProvider).dio;
    final cartPaths = [
      '/api/Cart',
      '/api/cart',
      '/api/Orders/cart',
      '/api/Orders',
      '/api/Basket',
      '/api/basket',
      '/api/Visits/cart',
      '/api/Orders/active',
      '/api/Orders/pending',
    ];
    final cartProbe = <String, dynamic>{};
    for (final path in cartPaths) {
      final sw = Stopwatch()..start();
      try {
        final resp = await dio.get(path);
        sw.stop();
        cartProbe[path] = {
          'ok': true,
          'status': resp.statusCode,
          'elapsed_ms': sw.elapsedMilliseconds,
          'data': resp.data,
        };
      } catch (e) {
        sw.stop();
        cartProbe[path] = {
          'ok': false,
          'elapsed_ms': sw.elapsedMilliseconds,
          'error': '$e',
        };
      }
    }
    checks['cart_probe'] = cartProbe;

    // Last 10 orders (compact) — fastest way to compare "correct vs incorrect"
    // order payload/flags directly from API.
    try {
      final sw = Stopwatch()..start();
      final resp = await dio.get(
        '/api/Orders',
        queryParameters: const {'page': 1, 'page_size': 10},
      );
      sw.stop();
      final data = resp.data;
      final rows = (data is Map<String, dynamic> && data['result'] is List)
          ? (data['result'] as List)
          : <dynamic>[];
      final compact = rows.whereType<Map>().take(10).map((e) {
        final m = Map<String, dynamic>.from(e);
        final org = m['organization'];
        final drugs = m['drugs'];
        return <String, dynamic>{
          'visit_id': m['visit_id'] ?? m['id'],
          'date_create': m['date_create'],
          'visit_type': m['visit_type'],
          'visit_status': m['visit_status'],
          'order_status': m['order_status'],
          'order_status_name': m['order_status_name'],
          'org_type_id': m['organization_type_id'] ??
              (org is Map ? org['type_id'] : null),
          'organization_name': m['organization_name'] ??
              (org is Map ? org['organization_name'] : null),
          'prepayment_percent': m['prepayment_percent'],
          'is_wholesaler': m['is_wholesaler'],
          'position_count': m['position_count'],
          'drugs_count': drugs is List ? drugs.length : 0,
          'total_sum': m['total_sum'],
          'comment': m['comment'],
        };
      }).toList();
      checks['last_10_orders'] = {
        'ok': true,
        'status': resp.statusCode,
        'elapsed_ms': sw.elapsedMilliseconds,
        'count': compact.length,
        'rows': compact,
      };
    } catch (e) {
      checks['last_10_orders'] = {
        'ok': false,
        'error': '$e',
      };
    }

    Future<Map<String, dynamic>> probeHistoryPath(String path) async {
      final sw = Stopwatch()..start();
      try {
        final resp = await dio.get(
          path,
          queryParameters: const {'_no_limit': true, 'page': 1},
        );
        sw.stop();
        final data = resp.data;
        List<dynamic> rows = const <dynamic>[];
        if (data is List) {
          rows = data;
        } else if (data is Map<String, dynamic>) {
          final candidates = ['items', 'data', 'result', 'results', 'rows'];
          for (final key in candidates) {
            final v = data[key];
            if (v is List) {
              rows = v;
              break;
            }
          }
        }
        final summary = rows
            .whereType<Map>()
            .take(5)
            .map((e) {
              final m = Map<String, dynamic>.from(e);
              final items = m['items'];
              final org = m['organization'];
              final visitType = (m['visit_type'] ?? '').toString();
              final orgTypeId =
                  m['organization_type_id'] ??
                  m['org_type_id'] ??
                  (org is Map ? org['type_id'] : null);
              final orderStatus = m['order_status'];
              final hasItems = items is List && items.isNotEmpty;
              final normalizedGuess = () {
                if (visitType == '4') return 'stock';
                if (visitType == '1' && orgTypeId == 1) {
                  return 'pharmacy_order';
                }
                if (visitType == '2') return 'lpu_presentation';
                if (hasItems || orderStatus == 1) return 'pharmacy_order';
                return 'unknown';
              }();
              return <String, dynamic>{
                'id': m['id'] ?? m['visit_id'],
                'visit_type': m['visit_type'],
                'visit_type_name': m['visit_type_name'],
                'visit_format_name': m['visit_format_name'],
                'organization_type_id': orgTypeId,
                'organization_name':
                    m['organization_name'] ??
                        m['org_name'] ??
                        (org is Map ? org['name'] : null),
                'doctor_id': m['doctor_id'],
                'doctor_name': m['doctor_name'],
                'items_count': items is List ? items.length : 0,
                'has_items': hasItems,
                'prepayment': m['prepayment'],
                'buyer_type': m['buyer_type'],
                'order_status': orderStatus ?? m['order_status_name'],
                'normalized_guess': normalizedGuess,
              };
            })
            .toList();
        return {
          'ok': true,
          'status': resp.statusCode,
          'elapsed_ms': sw.elapsedMilliseconds,
          'count': rows.length,
          'sample_5': summary,
          'raw_first': rows.isNotEmpty ? rows.first : null,
        };
      } catch (e) {
        sw.stop();
        return {
          'ok': false,
          'elapsed_ms': sw.elapsedMilliseconds,
          'error': '$e',
        };
      }
    }

    // Orders (bron) — check raw API response and mapping
    final ordersRaw = <Map<String, dynamic>>[];
    final ordersSw = Stopwatch()..start();
    try {
      ordersRaw.addAll(await api.getVisitHistoryOrders());
      ordersSw.stop();
      checks['getVisitHistoryOrders'] = {
        'ok': true,
        'elapsed_ms': ordersSw.elapsedMilliseconds,
        'count': ordersRaw.length,
        'sample_3': ordersRaw.take(3).toList(),
      };
    } catch (e) {
      ordersSw.stop();
      checks['getVisitHistoryOrders'] = {
        'ok': false,
        'elapsed_ms': ordersSw.elapsedMilliseconds,
        'error': '$e',
      };
    }

    // Remnant (stock) — check raw API response and mapping
    final remnantRaw = <Map<String, dynamic>>[];
    final remnantSw = Stopwatch()..start();
    try {
      remnantRaw.addAll(await api.getVisitHistoryRemnant());
      remnantSw.stop();
    checks['getVisitHistoryRemnant'] = {
        'ok': true,
        'elapsed_ms': remnantSw.elapsedMilliseconds,
        'count': remnantRaw.length,
        'sample_3': remnantRaw.take(3).toList(),
      };
    } catch (e) {
      remnantSw.stop();
      checks['getVisitHistoryRemnant'] = {
        'ok': false,
        'elapsed_ms': remnantSw.elapsedMilliseconds,
        'error': '$e',
      };
    }

    checks['history_type_probe'] = {
      '/api/Visits/history': await probeHistoryPath('/api/Visits/history'),
      '/api/Visits/history/orders': await probeHistoryPath(
        '/api/Visits/history/orders',
      ),
      '/api/Visits/history/remnant': await probeHistoryPath(
        '/api/Visits/history/remnant',
      ),
    };
    final focusIds = <int>{51589, 51591, 51595, 51597, 51598};
    final focusPaths = [
      '/api/Visits/history',
      '/api/Visits/history/orders',
      '/api/Visits/history/remnant',
    ];
    final focus = <String, dynamic>{};
    for (final path in focusPaths) {
      try {
        final resp = await dio.get(
          path,
          queryParameters: const {'_no_limit': true, 'page': 1},
        );
        final data = resp.data;
        List<dynamic> rows = const <dynamic>[];
        if (data is List) {
          rows = data;
        } else if (data is Map<String, dynamic>) {
          final candidates = ['items', 'data', 'result', 'results', 'rows'];
          for (final key in candidates) {
            final v = data[key];
            if (v is List) {
              rows = v;
              break;
            }
          }
        }
        final selected = rows
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((m) {
              final id = (m['id'] as num?)?.toInt() ??
                  (m['visit_id'] as num?)?.toInt();
              return id != null && focusIds.contains(id);
            })
            .map((m) {
              final org = m['organization'];
              final drugs = m['drugs'];
              return {
                'id': (m['id'] as num?)?.toInt() ??
                    (m['visit_id'] as num?)?.toInt(),
                'visit_type': m['visit_type'],
                'order_status': m['order_status'],
                'order_status_name': m['order_status_name'],
                'organization_type_id':
                    m['organization_type_id'] ??
                    (org is Map ? org['type_id'] : null),
                'organization_name':
                    m['organization_name'] ??
                    (org is Map ? org['organization_name'] : null),
                'drugs_count': drugs is List ? drugs.length : 0,
                'date_create': m['date_create'],
              };
            })
            .toList();
        focus[path] = selected;
      } catch (e) {
        focus[path] = {'ok': false, 'error': '$e'};
      }
    }
    checks['focus_visits_51589_51591_51595_51597_51598'] = focus;
    try {
      final db = ref.read(localDatabaseProvider);
      final localRows = await db.getVisits();
      final localFocus = localRows
          .where((r) {
            final rid = (r['remote_id'] as num?)?.toInt();
            return rid != null && focusIds.contains(rid);
          })
          .map((r) => {
                'id': r['id'],
                'remote_id': r['remote_id'],
                'visit_type': r['visit_type'],
                'status': r['status'],
                'created_at': r['created_at'],
                'last_push_request_json': r['last_push_request_json'],
                'last_push_response_json': r['last_push_response_json'],
              })
          .toList();
      checks['focus_local_push_payload_51589_51591_51595_51597_51598'] = localFocus;
    } catch (e) {
      checks['focus_local_push_payload_51589_51591_51595_51597_51598'] = {
        'ok': false,
        'error': '$e',
      };
    }

    report['finished_at'] = DateTime.now().toIso8601String();
    if (!mounted) return;
    setState(() => _runningApiDiagnostics = false);
    await _showJsonDialog(title: 'API диагностика', payload: report);
  }

  Widget _buildVisitCard(Map<String, dynamic> visit) {
    final isSynced = visit['is_synced'] == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    visit['org_name'] ?? '—',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSynced
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isSynced ? 'Синхронизировано' : 'Не синхронизировано',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSynced ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (visit['visit_type'] != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      visit['visit_type'].toString().toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (visit['status'] != null)
                  Text(
                    visit['status'].toString(),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            if (visit['notes'] != null && visit['notes'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  visit['notes'].toString(),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatDateTime(visit['created_at']?.toString()),
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSummaryCard(SyncState syncState) {
    final debug = syncState.lastGetDebug;
    if (debug == null) return const SizedBox.shrink();

    final mode = (debug['mode'] ?? '').toString();
    final isDelta = mode == 'delta';
    final isFull = mode == 'full_refresh' || mode == 'seed_pull';

    String title = 'Итог загрузки';
    if (isDelta) title = 'Итог дельта-синхронизации';
    if (mode == 'full_refresh') title = 'Итог full refresh';

    final fetchedOrg = (debug['delta_organizations_count'] ??
            debug['fetched_organizations_count'])
        ?.toString();
    final fetchedDoctors =
        (debug['delta_doctors_count'] ?? debug['fetched_doctors_count'])
            ?.toString();
    final fetchedDrugs =
        (debug['delta_drugs_count'] ?? debug['fetched_drugs_count'])?.toString();
    final fetchedVisits =
        (debug['delta_visits_count'] ??
                debug['fetched_visits_count'] ??
                debug['live_visits_count'])
            ?.toString();
    final fetchedMaterials =
        (debug['delta_materials_count'] ??
                debug['fetched_materials_count'] ??
                debug['live_materials_count'])
            ?.toString();

    final localOrg = debug['local_organizations_total']?.toString() ?? '—';
    final localDoctors = debug['local_doctors_total']?.toString() ?? '—';
    final localDrugs = debug['local_drugs_total']?.toString() ?? '—';

    final beforeSyncId = debug['last_sync_id_before']?.toString();
    final afterSyncId = debug['last_sync_id_after']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (isDelta || isFull) ...[
            Text(
              'Получено с API: ЛПУ $fetchedOrg, врачи $fetchedDoctors, препараты $fetchedDrugs, визиты ${fetchedVisits ?? "—"}, материалы ${fetchedMaterials ?? "—"}',
              style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Локально сейчас: ЛПУ $localOrg, врачи $localDoctors, препараты $localDrugs',
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[800]),
          ),
          if (isDelta && (beforeSyncId != null || afterSyncId != null)) ...[
            const SizedBox(height: 4),
            Text(
              'sync_id: ${beforeSyncId ?? "—"} → ${afterSyncId ?? "—"}',
              style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);

    String? lastSyncTime;
    if (syncState.lastSyncAt != null) {
      final dt = syncState.lastSyncAt!.toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      lastSyncTime = '$h:$m';
    }

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Синхронизация',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (lastSyncTime != null)
                          Text(
                            'Последняя синхр.: $lastSyncTime',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Body
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                LimaNavBarLayout.scrollBottomPadding(context) + 64,
              ),
              children: [
                // Section: СТАТУС
                SectionLabel(text: 'СТАТУС'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Icon(
                      syncState.unsyncedCount == 0
                          ? Icons.check_circle
                          : Icons.sync_problem,
                      color: syncState.unsyncedCount == 0
                          ? Colors.green
                          : Colors.orange,
                    ),
                    title: Text(
                      'Несинхронизированных записей',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${syncState.unsyncedCount} визитов',
                      style: GoogleFonts.manrope(fontSize: 13),
                    ),
                    trailing: syncState.unsyncedCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${syncState.unsyncedCount}',
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                if (_pendingDoctors.isNotEmpty || _pendingOrgUpdates.isNotEmpty) ...[
                  SectionLabel(text: 'ОЧЕРЕДЬ ИЗМЕНЕНИЙ'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_pendingDoctors.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.person_add, color: Colors.orange),
                            title: Text(
                              'Новые врачи',
                              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              _pendingDoctors.map((d) => d['full_name'] as String? ?? '—').join(', '),
                              style: GoogleFonts.manrope(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_pendingDoctors.length}',
                                style: GoogleFonts.manrope(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        if (_pendingDoctors.isNotEmpty && _pendingOrgUpdates.isNotEmpty)
                          const Divider(height: 1, indent: 16),
                        if (_pendingOrgUpdates.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.business, color: Colors.orange),
                            title: Text(
                              'Изменения организаций',
                              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              _pendingOrgUpdates.map((o) => o['name'] as String? ?? '—').join(', '),
                              style: GoogleFonts.manrope(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_pendingOrgUpdates.length}',
                                style: GoogleFonts.manrope(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (syncState.lastGetDebug != null) ...[
                  SectionLabel(text: 'ИТОГ ЗАГРУЗКИ'),
                  const SizedBox(height: 8),
                  _buildSyncSummaryCard(syncState),
                  const SizedBox(height: 16),
                ],

                // Section: ДЕЙСТВИЯ
                SectionLabel(text: 'ДЕЙСТВИЯ'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.cloud_download,
                            color: Colors.blue),
                        title: Text(
                          'Загрузить с сервера',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Перезаписать локальные данные из API',
                          style: GoogleFonts.manrope(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          if (!mounted) return;
                          final notifier = ref.read(syncProvider.notifier);
                          try {
                            await notifier.pullFromRemote();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Ошибка загрузки: $e'),
                              ),
                            );
                            return;
                          }
                          await _loadData();
                          if (!mounted) return;
                          final latest = ref.read(syncProvider);
                          if (latest.lastGetDebug != null && mounted) {
                            await _showJsonDialog(
                              title: 'GET sync response',
                              payload: latest.lastGetDebug!,
                            );
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Данные загружены')),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.restart_alt_rounded,
                            color: Colors.deepPurple),
                        title: Text(
                          'Принудительный full refresh',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Полностью обновить локальный снапшот из API',
                          style: GoogleFonts.manrope(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Подтвердите full refresh'),
                              content: const Text(
                                'Будет выполнено полное обновление локальной БД из API. '
                                'Несинхронизированные визиты будут сохранены.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Отмена'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Обновить'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          if (!mounted) return;
                          final notifier = ref.read(syncProvider.notifier);
                          try {
                            await notifier.pullFromRemote(fullRefresh: true);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Ошибка full refresh: $e'),
                              ),
                            );
                            return;
                          }
                          await _loadData();
                          if (!mounted) return;
                          final latest = ref.read(syncProvider);
                          if (latest.lastGetDebug != null && mounted) {
                            await _showJsonDialog(
                              title: 'GET sync response',
                              payload: latest.lastGetDebug!,
                            );
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Выполнен full refresh'),
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.cloud_upload,
                            color: Colors.green),
                        title: Text(
                          'Отправить на сервер',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${_unsyncedVisits.length} визитов ожидают',
                          style: GoogleFonts.manrope(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          if (!mounted) return;
                          final notifier = ref.read(syncProvider.notifier);
                          await notifier.pushToRemote();
                          await _loadData();
                          if (!mounted) return;
                          final latest = ref.read(syncProvider);
                          if (latest.lastPostDebug != null && mounted) {
                            await _showJsonDialog(
                              title: 'POST sync response',
                              payload: latest.lastPostDebug!,
                            );
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  latest.message ??
                                      'Синхронизация завершена',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.science_outlined,
                          color: _runningApiDiagnostics
                              ? Colors.orange
                              : Colors.indigo,
                        ),
                        title: Text(
                          'Диагностика API',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _runningApiDiagnostics
                              ? 'Выполняются API вызовы...'
                              : 'Прогнать ключевые API и показать ответы',
                          style: GoogleFonts.manrope(fontSize: 12),
                        ),
                        trailing: _runningApiDiagnostics
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _runningApiDiagnostics ? null : _runApiDiagnostics,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Section: ОФЛАЙН ВИЗИТЫ
                Row(
                  children: [
                    Expanded(child: SectionLabel(text: 'ОФЛАЙН ВИЗИТЫ')),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loadingVisits)
                  const Center(child: CircularProgressIndicator())
                else if (_unsyncedVisits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Нет несинхронизированных визитов',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  )
                else
                  ...(_unsyncedVisits.map((v) => _buildVisitCard(v))),
                const SizedBox(height: 16),

                // Section: ВСЕ ВИЗИТЫ
                SectionLabel(text: 'ВСЕ ВИЗИТЫ (${_allVisits.length})'),
                const SizedBox(height: 8),
                ...(_allVisits.map((v) => _buildVisitCard(v))),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => context.go('/visits'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Создать визит',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
