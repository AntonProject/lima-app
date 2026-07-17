import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/models/local_visit.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/utils/swallowed.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/offline/domain/entities/sync_queue_records.dart';
import 'package:lima/features/offline/domain/entities/sync_state.dart';
import 'package:lima/features/offline/presentation/view_models/sync_view_model.dart';
import 'package:lima/features/offline/presentation/view_models/sync_screen_view_model.dart';
import 'package:lima/features/offline/providers/sync_diagnostics_repository_provider.dart';
import 'package:lima/features/offline/providers/sync_screen_provider.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/shell/nav_bar_layout.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  SyncScreenViewState get _screenState => ref.read(syncScreenViewModelProvider);
  List<LocalVisit> get _unsyncedVisits => _screenState.unsyncedVisits;
  List<LocalVisit> get _failedVisits => _screenState.failedVisits;
  List<PendingDoctorRecord> get _pendingDoctors => _screenState.pendingDoctors;
  List<PendingDoctorRecord> get _failedPendingDoctors =>
      _screenState.failedPendingDoctors;
  List<PendingOrganisationUpdateRecord> get _pendingOrgUpdates =>
      _screenState.pendingOrgUpdates;
  SyncLocalTotals get _localTotals => _screenState.localTotals;
  bool get _hasLocalTotals => _screenState.hasLocalTotals;
  bool get _loadingVisits => _screenState.isLoadingVisits;
  int get _unsyncedPage => _screenState.unsyncedPage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData({bool refreshSyncCount = true}) async {
    if (!mounted) return;
    final screenViewModel = ref.read(syncScreenViewModelProvider.notifier);
    final syncViewModel = ref.read(syncViewModelProvider.notifier);
    await screenViewModel.load();
    if (refreshSyncCount && mounted) await syncViewModel.refreshUnsyncedCount();
  }

  int get _unsyncedTotalPages {
    return _screenState.totalUnsyncedPages;
  }

  List<LocalVisit> get _visibleUnsyncedVisits {
    return _screenState.visibleUnsyncedVisits;
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
        content: Text(_compactSnackMessage(context, message)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _compactSnackMessage(BuildContext ctx, String message) {
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
      return ctx.l10n.t('serverRejectedData');
    }
    return ctx.l10n.t('failedToSendData');
  }

  Future<void> _runDeltaPull() async {
    final viewModel = ref.read(syncViewModelProvider.notifier);
    try {
      await viewModel.runDelta();
      await _loadData();
      if (!mounted) return;
      _showSnack(
        ref.read(syncViewModelProvider).message ?? context.l10n.t('synced'),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('${context.l10n.t('syncStatus')}: $e');
    }
  }

  Future<void> _runFullRefresh() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.t('syncConfirmTitle')),
        content: Text(context.l10n.t('syncConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.t('refresh')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final viewModel = ref.read(syncViewModelProvider.notifier);
    try {
      await viewModel.runFullRefresh();
      await _loadData();
      if (!mounted) return;
      _showSnack(
        ref.read(syncViewModelProvider).message ?? context.l10n.t('synced'),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('${context.l10n.t('syncStatus')}: $e');
    }
  }

  Future<void> _runPush() async {
    final viewModel = ref.read(syncViewModelProvider.notifier);
    try {
      await viewModel.pushPending();
      await _loadData();
      if (!mounted) return;
      _showSnack(
        ref.read(syncViewModelProvider).message ?? context.l10n.t('synced'),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('${context.l10n.t('syncStatus')}: $e');
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
            : () => ref
                  .read(syncScreenViewModelProvider.notifier)
                  .setUnsyncedPage(_unsyncedPage - 1),
        icon: const Icon(Icons.chevron_left_rounded),
        tooltip: context.l10n.t('prevPage'),
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
          onTap: selected
              ? null
              : () => ref
                    .read(syncScreenViewModelProvider.notifier)
                    .setUnsyncedPage(page),
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
            : () => ref
                  .read(syncScreenViewModelProvider.notifier)
                  .setUnsyncedPage(_unsyncedPage + 1),
        icon: const Icon(Icons.chevron_right_rounded),
        tooltip: context.l10n.t('nextPage'),
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

  Widget _buildVisitCard(LocalVisit visit) {
    final isSynced = visit.isSynced;
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
                    visit.orgName.isEmpty ? '—' : visit.orgName,
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
                    isSynced
                        ? context.l10n.t('synced')
                        : context.l10n.t('notSynced'),
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
                    visit.visitType.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  visit.status,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (visit.notes != null && visit.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  visit.notes!,
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
              _formatDateTime(visit.createdAt.toIso8601String()),
              style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retryFailedVisit(int id) async {
    final db = ref.read(syncDiagnosticsRepositoryProvider);
    await db.retryFailedVisit(id);
    if (!mounted) return;
    await ref.read(syncViewModelProvider.notifier).refreshUnsyncedCount();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.t('visitReturnedToQueue'))),
    );
  }

  Future<void> _deleteFailedVisit(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.t('deleteVisitTitle')),
        content: Text(context.l10n.t('deleteVisitConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.l10n.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final db = ref.read(syncDiagnosticsRepositoryProvider);
    await db.deleteVisit(id);
    if (!mounted) return;
    await ref.read(syncViewModelProvider.notifier).refreshUnsyncedCount();
  }

  Widget _buildFailedVisitCard(LocalVisit visit) {
    final id = visit.id;
    final attempts = visit.pushAttempts;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
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
                    visit.orgName.isEmpty ? '—' : visit.orgName,
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
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.l10n.t('notSent'),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ref
                  .read(syncDiagnosticsRepositoryProvider)
                  .failedVisitMessage(
                    visit,
                    fallback: context.l10n.t('serverRejectedData'),
                  ),
              style: GoogleFonts.manrope(fontSize: 12, color: Colors.red[700]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatDateTime(visit.createdAt.toIso8601String())}'
              '${attempts > 0 ? ' · ${context.l10n.t('attemptsN', args: {'count': '$attempts'})}' : ''}',
              style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[500]),
            ),
            if (id != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _retryFailedVisit(id),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        context.l10n.t('retry'),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteFailedVisit(id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[700],
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: Text(
                        context.l10n.t('delete'),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFailedPendingDoctor(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.t('deleteDoctorTitle')),
        content: Text(context.l10n.t('deleteDoctorConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.l10n.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final db = ref.read(syncDiagnosticsRepositoryProvider);
    await db.deletePendingDoctor(id);
  }

  Widget _buildFailedPendingDoctorCard(PendingDoctorRecord doctor) {
    final id = doctor.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
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
                    doctor.fullName.isEmpty ? '—' : doctor.fullName,
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
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.l10n.t('notSent'),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.t('doctorMissingSpecialization'),
              style: GoogleFonts.manrope(fontSize: 12, color: Colors.red[700]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatDateTime(doctor.createdAt),
              style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[500]),
            ),
            if (id != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _deleteFailedPendingDoctor(id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  minimumSize: const Size(double.infinity, 36),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: Text(
                  context.l10n.t('delete'),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Collapsible diagnostics list of intentionally-swallowed errors (see
  /// [SwallowedLog]). Helps field debugging without attaching a debugger.
  Widget _buildSwallowedErrorsSection() {
    final entries = SwallowedLog.entries;
    if (entries.isEmpty) return const SizedBox.shrink();
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(
            '${context.l10n.t('hiddenErrors')} (${entries.length})',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            context.l10n.t('technicalLog'),
            style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[500]),
          ),
          children: [
            ...entries
                .take(50)
                .map(
                  (s) => ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      s.where,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${_formatDateTime(s.at.toIso8601String())} · ${s.error}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            TextButton(
              onPressed: () => setState(SwallowedLog.clear),
              child: Text(
                context.l10n.t('clearLog'),
                style: GoogleFonts.manrope(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSummaryCard(SyncViewState syncState) {
    String value(int local, List<String> debugKeys) {
      if (_hasLocalTotals) return local.toString();
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

    final lpu = value(_localTotals.lpu, const ['local_lpu_total']);
    final pharmacy = value(_localTotals.pharmacy, const [
      'local_pharmacy_total',
    ]);
    final doctors = value(_localTotals.doctors, const ['local_doctors_total']);
    final visits = value(_localTotals.visits, const [
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
            context.l10n.t('localData'),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.t(
              'lpuPharmacyCounts',
              args: {'lpu': lpu, 'pharmacy': pharmacy},
            ),
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[800]),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.t(
              'doctorsVisitsCounts',
              args: {'doctors': doctors, 'visits': visits},
            ),
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[800]),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.t('unsyncedCount', args: {'count': '$unsynced'}),
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncProgressCard(SyncViewState syncState) {
    final current = syncState.progressCurrent;
    final total = syncState.progressTotal;
    final hasProgress = current != null && total != null && total > 0;
    final progressValue = hasProgress
        ? (current / total).clamp(0.0, 1.0)
        : null;
    final percentText = hasProgress
        ? '${(progressValue! * 100).round().clamp(0, 100)}%'
        : null;
    final label = syncState.message ?? context.l10n.t('syncRunning');

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
                    fontWeight: FontWeight.w700,
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
                ? context.l10n.t('updatingData')
                : context.l10n.t('dontCloseApp'),
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncViewModelProvider);
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == 'admin';
    final activeOperation = syncState.activeOperation;
    final isSyncLoading = activeOperation != null;
    final isPullLoading = activeOperation == SyncOperationType.deltaPull;
    final isFullRefreshLoading =
        activeOperation == SyncOperationType.fullRefresh;
    final isPushLoading = activeOperation == SyncOperationType.push;

    ref.listen<SyncViewState>(syncViewModelProvider, (prev, next) {
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
                          context.l10n.t('syncStatus'),
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (lastSyncTime != null)
                          Text(
                            context.l10n.t(
                              'lastSyncTime',
                              args: {'time': lastSyncTime},
                            ),
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
                SectionLabel(text: context.l10n.t('status').toUpperCase()),
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
                      context.l10n.t('unsyncedRecords'),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      context.l10n.t(
                        'awaitingVisits',
                        args: {'count': '${syncState.unsyncedCount}'},
                      ),
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
                  SectionLabel(
                    text: context.l10n.t('changesQueue').toUpperCase(),
                  ),
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
                              context.l10n.t('newDoctors'),
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              _pendingDoctors
                                  .map(
                                    (d) =>
                                        d.fullName.isEmpty ? '—' : d.fullName,
                                  )
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
                              context.l10n.t('orgChanges'),
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              _pendingOrgUpdates
                                  .map((o) => o.name.isEmpty ? '—' : o.name)
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

                SectionLabel(text: context.l10n.t('localData').toUpperCase()),
                const SizedBox(height: 8),
                _buildSyncSummaryCard(syncState),
                const SizedBox(height: 16),

                SectionLabel(text: context.l10n.t('actions').toUpperCase()),
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
                        title: context.l10n.t('updateFromServer'),
                        subtitle: isPullLoading
                            ? (syncState.message ??
                                  context.l10n.t('syncRunning'))
                            : context.l10n.t('pullChangesDesc'),
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
                        title: context.l10n.t('sendToServer'),
                        subtitle: isPushLoading
                            ? (syncState.message ??
                                  context.l10n.t('syncRunning'))
                            : context.l10n.t(
                                'awaitingVisits',
                                args: {'count': '${_unsyncedVisits.length}'},
                              ),
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
                          title: context.l10n.t('forceFullRefresh'),
                          subtitle: isFullRefreshLoading
                              ? (syncState.message ??
                                    context.l10n.t('fullRefreshRunning'))
                              : context.l10n.t('fullRefreshDesc'),
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

                if (_failedVisits.isNotEmpty) ...[
                  SectionLabel(
                    text:
                        '${context.l10n.t('notSent').toUpperCase()} (${_failedVisits.length})',
                  ),
                  const SizedBox(height: 8),
                  ...(_failedVisits.map((v) => _buildFailedVisitCard(v))),
                  const SizedBox(height: 16),
                ],
                if (_failedPendingDoctors.isNotEmpty) ...[
                  SectionLabel(
                    text:
                        '${context.l10n.t('notSentDoctors').toUpperCase()} (${_failedPendingDoctors.length})',
                  ),
                  const SizedBox(height: 8),
                  ...(_failedPendingDoctors.map(
                    (d) => _buildFailedPendingDoctorCard(d),
                  )),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: SectionLabel(
                        text:
                            '${context.l10n.t('notSynced').toUpperCase()} (${_unsyncedVisits.length})',
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
                      context.l10n.t('noUnsyncedVisits'),
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
                _buildSwallowedErrorsSection(),
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
              context.l10n.t('createVisit'),
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
