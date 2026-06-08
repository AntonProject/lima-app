import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/providers/sync_provider.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/shell/nav_bar_layout.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  static const int _unsyncedPageSize = 10;

  List<Map<String, dynamic>> _unsyncedVisits = [];
  List<Map<String, dynamic>> _pendingDoctors = [];
  List<Map<String, dynamic>> _pendingOrgUpdates = [];
  Map<String, int> _localTotals = const {};
  bool _loadingVisits = true;
  bool _loadingData = false;
  int _unsyncedPage = 0;
  StreamSubscription<Set<String>>? _dbChangesSub;

  @override
  void initState() {
    super.initState();
    _dbChangesSub = ref.read(localDatabaseProvider).changes.listen((tables) {
      if (!mounted) return;
      if (tables.intersection(_localDataTables).isEmpty) return;
      unawaited(_loadData(refreshSyncCount: false));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _dbChangesSub?.cancel();
    super.dispose();
  }

  static const _localDataTables = {
    'organisations',
    'doctors',
    'doctor_organisations',
    'drugs',
    'drug_materials',
    'visits',
    'planned_visits',
    'pending_doctors',
    'pending_org_updates',
  };

  Future<void> _loadData({bool refreshSyncCount = true}) async {
    if (!mounted || _loadingData) return;
    _loadingData = true;
    final db = ref.read(localDatabaseProvider);
    final syncNotifier = ref.read(syncProvider.notifier);
    try {
      await db.deleteLegacyTestVisits();
      final unsynced = await db.getVisits(unsyncedOnly: true);
      final pendingDoctors = await db.getPendingDoctors();
      final pendingOrgUpdates = await db.getPendingOrgUpdates();
      final localTotals = await _loadLocalTotals(db);
      if (!mounted) return;
      if (refreshSyncCount) {
        await syncNotifier.refreshUnsyncedCount();
        if (!mounted) return;
      }
      setState(() {
        _unsyncedVisits = unsynced;
        _pendingDoctors = pendingDoctors;
        _pendingOrgUpdates = pendingOrgUpdates;
        _localTotals = localTotals;
        _clampUnsyncedPage();
        _loadingVisits = false;
      });
    } finally {
      _loadingData = false;
    }
  }

  Future<Map<String, int>> _loadLocalTotals(LocalDatabase db) async {
    Future<int> count(String sql) async {
      final rows = await db.db.rawQuery(sql);
      return (rows.first['c'] as int?) ?? 0;
    }

    return {
      'organizations': await count('SELECT COUNT(*) AS c FROM organisations'),
      'lpu': await count(
        "SELECT COUNT(*) AS c FROM organisations WHERE type = 'lpu'",
      ),
      'pharmacy': await count(
        "SELECT COUNT(*) AS c FROM organisations WHERE type = 'pharmacy'",
      ),
      'distributor': await count(
        "SELECT COUNT(*) AS c FROM organisations WHERE type = 'distributor'",
      ),
      'doctors': await count('SELECT COUNT(*) AS c FROM doctors'),
      'visits': await count('SELECT COUNT(*) AS c FROM visits'),
      'drugs': await count('SELECT COUNT(*) AS c FROM drugs'),
      'materials': await count('SELECT COUNT(*) AS c FROM drug_materials'),
    };
  }

  int get _unsyncedTotalPages {
    if (_unsyncedVisits.isEmpty) return 1;
    return ((_unsyncedVisits.length - 1) ~/ _unsyncedPageSize) + 1;
  }

  List<Map<String, dynamic>> get _visibleUnsyncedVisits {
    final start = _unsyncedPage * _unsyncedPageSize;
    return _unsyncedVisits.skip(start).take(_unsyncedPageSize).toList();
  }

  void _clampUnsyncedPage() {
    final lastPage = _unsyncedTotalPages - 1;
    if (_unsyncedPage > lastPage) _unsyncedPage = lastPage;
    if (_unsyncedPage < 0) _unsyncedPage = 0;
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

  void _showSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(_compactSnackMessage(message)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _compactSnackMessage(String message) {
    final trimmed = message.trim();
    if (!trimmed.contains('{') && !trimmed.contains('DioException')) {
      return trimmed;
    }

    final serverMessageMatch = RegExp(
      r'"message"\s*:\s*"([^"]+)"',
    ).firstMatch(trimmed);
    final serverMessage = serverMessageMatch?.group(1);
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }

    if (trimmed.contains('VALIDATION_ERROR') ||
        trimmed.contains('VALIDATION_ERRORS')) {
      return 'Сервер отклонил данные. Подробности сохранены в диагностике.';
    }
    return 'Не удалось отправить данные. Подробности сохранены в диагностике.';
  }

  Future<void> _runDeltaPull() async {
    final notifier = ref.read(syncProvider.notifier);
    try {
      await notifier.syncLayeredFromRemote(pushPendingFirst: false);
      await _loadData();
      if (!mounted) return;
      _showSnack(ref.read(syncProvider).message ?? 'Данные загружены');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Ошибка загрузки: $e');
    }
  }

  Future<void> _runFullRefresh() async {
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
    if (confirmed != true || !mounted) return;

    final notifier = ref.read(syncProvider.notifier);
    try {
      await notifier.syncLayeredFromRemote(
        fullRefresh: true,
        pushPendingFirst: false,
      );
      await _loadData();
      if (!mounted) return;
      _showSnack(ref.read(syncProvider).message ?? 'Выполнен full refresh');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Ошибка full refresh: $e');
    }
  }

  Future<void> _runPush() async {
    final notifier = ref.read(syncProvider.notifier);
    try {
      await notifier.pushToRemote();
      await _loadData();
      if (!mounted) return;
      _showSnack(ref.read(syncProvider).message ?? 'Синхронизация завершена');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Ошибка отправки: $e');
    }
  }

  Widget _buildSyncActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isRunning,
    required bool isDisabled,
    required VoidCallback onTap,
  }) {
    final effectiveColor = isDisabled && !isRunning ? Colors.grey : color;
    return ListTile(
      enabled: !isDisabled || isRunning,
      leading: Icon(icon, color: effectiveColor),
      title: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDisabled && !isRunning ? Colors.grey[600] : null,
        ),
      ),
      subtitle: Text(subtitle, style: GoogleFonts.manrope(fontSize: 12)),
      trailing: isRunning
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: isDisabled ? null : onTap,
    );
  }

  Widget _buildUnsyncedPager() {
    final totalPages = _unsyncedTotalPages;
    if (totalPages <= 1) return const SizedBox.shrink();

    final pageSet = <int>{
      0,
      totalPages - 1,
      _unsyncedPage - 1,
      _unsyncedPage,
      _unsyncedPage + 1,
    }..removeWhere((page) => page < 0 || page >= totalPages);
    final pages = pageSet.toList()..sort();

    final children = <Widget>[
      IconButton(
        onPressed: _unsyncedPage == 0
            ? null
            : () => setState(() => _unsyncedPage--),
        icon: const Icon(Icons.chevron_left_rounded),
        tooltip: 'Предыдущая страница',
      ),
    ];

    var previousPage = -1;
    for (final page in pages) {
      if (previousPage >= 0 && page - previousPage > 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '…',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      final selected = page == _unsyncedPage;
      children.add(
        InkWell(
          onTap: selected ? null : () => setState(() => _unsyncedPage = page),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.grey.shade300,
              ),
            ),
            child: Text(
              '${page + 1}',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        ),
      );
      previousPage = page;
    }

    children.add(
      IconButton(
        onPressed: _unsyncedPage >= totalPages - 1
            ? null
            : () => setState(() => _unsyncedPage++),
        icon: const Icon(Icons.chevron_right_rounded),
        tooltip: 'Следующая страница',
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
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
            color: Colors.black.withValues(alpha: 0.06),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isSynced
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
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
              style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSummaryCard(SyncState syncState) {
    String value(String localKey, List<String> debugKeys) {
      final local = _localTotals[localKey];
      if (local != null) return local.toString();
      final debug = syncState.lastGetDebug;
      if (debug != null) {
        for (final key in debugKeys) {
          final raw = debug[key];
          if (raw is int) return raw.toString();
          if (raw is num) return raw.round().toString();
          if (raw is String) {
            final parsed = int.tryParse(raw);
            if (parsed != null) return parsed.toString();
          }
        }
      }
      return '—';
    }

    final lpu = value('lpu', const ['local_lpu_total']);
    final pharmacy = value('pharmacy', const ['local_pharmacy_total']);
    final doctors = value('doctors', const ['local_doctors_total']);
    final visits = value('visits', const [
      'local_visits_total',
      'live_visits_count',
      'fetched_visits_count',
      'delta_visits_count',
      'visits_count',
    ]);
    final unsynced = syncState.unsyncedCount;

    return Container(
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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Локальные данные',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ЛПУ: $lpu, аптеки: $pharmacy',
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[800]),
          ),
          const SizedBox(height: 4),
          Text(
            'Врачи: $doctors, визиты: $visits',
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[800]),
          ),
          const SizedBox(height: 4),
          Text(
            'Не отправлено: $unsynced',
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncProgressCard(SyncState syncState) {
    final current = syncState.progressCurrent;
    final total = syncState.progressTotal;
    final hasProgress = current != null && total != null && total > 0;
    final progressValue = hasProgress
        ? (current / total).clamp(0.0, 1.0)
        : null;
    final percentText = hasProgress
        ? '${(progressValue! * 100).round().clamp(0, 100)}%'
        : null;
    final label = syncState.message ?? 'Синхронизация выполняется…';

    return Container(
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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (percentText != null)
                Text(
                  percentText,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progressValue),
          const SizedBox(height: 8),
          Text(
            !hasProgress
                ? 'Обновляем данные'
                : 'Не закрывайте приложение до завершения загрузки.',
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == 'admin';
    final activeOperation = syncState.activeOperation;
    final isSyncLoading = activeOperation != null;
    final isPullLoading = activeOperation == SyncOperation.pull;
    final isFullRefreshLoading = activeOperation == SyncOperation.fullRefresh;
    final isPushLoading = activeOperation == SyncOperation.push;

    ref.listen<SyncState>(syncProvider, (prev, next) {
      final prevAt = prev?.lastSyncAt;
      final nextAt = next.lastSyncAt;
      final syncTimeChanged =
          nextAt != null &&
          (prevAt == null ||
              nextAt.millisecondsSinceEpoch != prevAt.millisecondsSinceEpoch);
      if (!syncTimeChanged && prev?.unsyncedCount == next.unsyncedCount) {
        return;
      }
      unawaited(_loadData(refreshSyncCount: false));
    });

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
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
                if (isSyncLoading) ...[
                  _buildSyncProgressCard(syncState),
                  const SizedBox(height: 12),
                ],
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
                              horizontal: 8,
                              vertical: 4,
                            ),
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

                if (_pendingDoctors.isNotEmpty ||
                    _pendingOrgUpdates.isNotEmpty) ...[
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
                            leading: const Icon(
                              Icons.person_add,
                              color: Colors.orange,
                            ),
                            title: Text(
                              'Новые врачи',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              _pendingDoctors
                                  .map((d) => d['full_name'] as String? ?? '—')
                                  .join(', '),
                              style: GoogleFonts.manrope(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_pendingDoctors.length}',
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        if (_pendingDoctors.isNotEmpty &&
                            _pendingOrgUpdates.isNotEmpty)
                          const Divider(height: 1),
                        if (_pendingOrgUpdates.isNotEmpty)
                          ListTile(
                            leading: const Icon(
                              Icons.business,
                              color: Colors.orange,
                            ),
                            title: Text(
                              'Изменения ЛПУ/аптек',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              _pendingOrgUpdates
                                  .map((o) => o['name'] as String? ?? '—')
                                  .join(', '),
                              style: GoogleFonts.manrope(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_pendingOrgUpdates.length}',
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                SectionLabel(text: 'ЛОКАЛЬНЫЕ ДАННЫЕ'),
                const SizedBox(height: 8),
                _buildSyncSummaryCard(syncState),
                const SizedBox(height: 16),

                SectionLabel(text: 'ДЕЙСТВИЯ'),
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
                      _buildSyncActionTile(
                        icon: Icons.cloud_download,
                        color: Colors.blue,
                        title: 'Обновить данные с сервера',
                        subtitle: isPullLoading
                            ? (syncState.message ?? 'Загрузка выполняется…')
                            : 'Загрузить изменения из API в локальную БД',
                        isRunning: isPullLoading,
                        isDisabled: isSyncLoading,
                        onTap: () {
                          _runDeltaPull();
                        },
                      ),
                      const Divider(height: 1),
                      _buildSyncActionTile(
                        icon: Icons.cloud_upload,
                        color: Colors.green,
                        title: 'Отправить на сервер',
                        subtitle: isPushLoading
                            ? (syncState.message ?? 'Отправка выполняется…')
                            : '${_unsyncedVisits.length} визитов ожидают',
                        isRunning: isPushLoading,
                        isDisabled: isSyncLoading,
                        onTap: () {
                          _runPush();
                        },
                      ),
                      if (isAdmin) ...[
                        const Divider(height: 1),
                        _buildSyncActionTile(
                          icon: Icons.restart_alt_rounded,
                          color: Colors.deepPurple,
                          title: 'Принудительный full refresh',
                          subtitle: isFullRefreshLoading
                              ? (syncState.message ??
                                    'Full refresh выполняется…')
                              : 'Полностью обновить локальный снапшот из API',
                          isRunning: isFullRefreshLoading,
                          isDisabled: isSyncLoading,
                          onTap: () {
                            _runFullRefresh();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: SectionLabel(
                        text: 'ОФЛАЙН ВИЗИТЫ (${_unsyncedVisits.length})',
                      ),
                    ),
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
                else ...[
                  ...(_visibleUnsyncedVisits.map((v) => _buildVisitCard(v))),
                  _buildUnsyncedPager(),
                ],
                const SizedBox(height: 16),
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
