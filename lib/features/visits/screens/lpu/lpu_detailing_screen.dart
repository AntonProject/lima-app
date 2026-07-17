import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/visits/domain/entities/completed_visit.dart';
import 'package:lima/features/visits/domain/entities/visit_interaction.dart';
import 'package:lima/features/visits/providers/lpu_details_provider.dart';
import 'package:lima/features/visits/providers/lpu_detailing_provider.dart';
import 'package:lima/features/visits/presentation/view_models/lpu_detailing_view_model.dart';
import 'package:lima/features/visits/providers/visit_write_provider.dart';
import 'package:lima/features/visits/providers/visit_interaction_provider.dart';
import 'package:lima/features/visits/providers/visits_hub_provider.dart';
import 'package:lima/features/visits/dialogs/medical_status_sheet.dart';
import 'package:lima/features/visits/widgets/lpu_detailing_widgets.dart';
import 'package:lima/features/visits/widgets/lpu_detailing_completion_dialog.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/services/in_app_notifications_service.dart';
import 'package:lima/core/utils/swallowed.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/core/providers/dashboard_counts_provider.dart';

class LpuDetailingScreen extends ConsumerStatefulWidget {
  final int orgId;
  final int doctorId;
  final String doctorName;
  final String orgName;
  final String? doctorIds;
  final int? visitId;

  const LpuDetailingScreen({
    super.key,
    required this.orgId,
    required this.doctorId,
    required this.doctorName,
    this.orgName = '',
    this.doctorIds,
    this.visitId,
  });

  @override
  ConsumerState<LpuDetailingScreen> createState() => _LpuDetailingScreenState();
}

class _LpuDetailingScreenState extends ConsumerState<LpuDetailingScreen> {
  final InAppNotificationsService _notificationsService =
      InAppNotificationsService();

  LpuDetailingViewState get _detailState =>
      ref.read(lpuDetailingViewModelProvider(widget.orgId));

  List<Doctor> get _doctors => _detailState.doctors;
  List<Drug> get _filtered => _detailState.filteredDrugs;
  Map<String, DrugStatus> get _statuses => _detailState.statuses;
  bool get _actionLocked => _detailState.isActionLocked;

  List<int> get _allDoctorIds {
    if (widget.doctorIds != null && widget.doctorIds!.isNotEmpty) {
      return widget.doctorIds!
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
    }
    return [widget.doctorId];
  }

  Drug? _drugByName(String name) => _detailState.drugByName[name.toLowerCase()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDoctors());
  }

  Future<void> _loadDoctors() async {
    final ids = _allDoctorIds;
    await ref
        .read(lpuDetailingViewModelProvider(widget.orgId).notifier)
        .load(organizationId: widget.orgId, doctorIds: ids);
  }

  Future<void> _finishVisit() async {
    if (_actionLocked) return;
    ref.read(lpuDetailingViewModelProvider(widget.orgId).notifier).lockAction();
    final selectedDrugs = _statuses.keys.toList();
    final now = DateTime.now().toIso8601String();
    final comment = selectedDrugs.isEmpty
        ? context.l10n.t('noDrugsChosen')
        : context.l10n.t(
            'drugsSelectedN',
            args: {'count': '${selectedDrugs.length}'},
          );
    final medRepName = ref.read(authProvider).user?.fullName ?? '—';
    // Capture localized notification strings before async gaps.
    final visitDoneTitle = context.l10n.t('visitDone');
    final visitSentApiBody = context.l10n.t('visitSentApi');
    final visitSavedLocalBody = context.l10n.t('visitSavedLocalSync');
    final visitUnconfirmedBody = context.l10n.t('visitDoneUnconfirmed');
    int? localId;
    var apiOk = false;
    var localOk = false;

    if (widget.visitId != null) {
      try {
        final interaction = ref.read(visitInteractionRepositoryProvider);
        await interaction.completeRemoteVisit(
          VisitCompletionDraft(
            visitId: widget.visitId!,
            comment: comment,
            endedAt: DateTime.tryParse(now) ?? DateTime.now(),
          ),
        );

        final positive = _statuses.values
            .where(
              (s) =>
                  s == DrugStatus.familiarPrescribes ||
                  s == DrugStatus.familiarNotPrescribes,
            )
            .length;
        final rating = _statuses.isEmpty
            ? 0
            : ((positive / _statuses.length) * 5).round().clamp(1, 5);

        await ref
            .read(doctorsDirectoryRepositoryProvider)
            .markVisited(
              doctorId: widget.doctorId,
              organizationId: widget.orgId,
              visitId: widget.visitId,
            );

        await interaction.rateRemoteVisit(
          VisitRatingDraft(
            visitId: widget.visitId!,
            rating: rating,
            comment: comment,
          ),
        );
        apiOk = true;
      } catch (_) {
        // Keep UI flow and local completion dialog even if network failed.
      }
    } else {
      // Manual flow (without pre-created plan): persist visit locally so it
      // appears in offline history/home and can be synced later.
      try {
        final presentations = selectedDrugs.map((name) {
          final meta = _drugByName(name);
          final dbRow = _detailState.drugByName[name.toLowerCase()];
          final drugId = dbRow?.id;
          final status = _statuses[name];
          // status_id (server-confirmed): 4=ознакомлен/выписывает,
          // 5=ознакомлен/не выписывает, 6=не знаком, 2=просто ознакомлен.
          final statusId = switch (status) {
            DrugStatus.familiarPrescribes => 4,
            DrugStatus.familiarNotPrescribes => 5,
            DrugStatus.unfamiliar => 6,
            DrugStatus.other => 2,
            _ => 2,
          };
          final statusCode = switch (status) {
            DrugStatus.familiarPrescribes => 'familiar_prescribes',
            DrugStatus.familiarNotPrescribes => 'familiar_not_prescribes',
            DrugStatus.unfamiliar => 'not_familiar',
            DrugStatus.other => 'other',
            _ => '',
          };
          return LpuPresentationRecord(
            drugId: drugId,
            statusId: statusId,
            drugName: name,
            manufacturer: meta?.manufacturer ?? '',
            status: statusCode,
          );
        }).toList();

        final isGroupVisit =
            widget.doctorIds != null && widget.doctorIds!.contains(',');
        final result = await ref
            .read(visitWriteRepositoryProvider)
            .complete(
              CompletedVisitDraft(
                organizationId: widget.orgId,
                organizationName: widget.orgName,
                doctorId: widget.doctorId,
                doctorName: widget.doctorName,
                localVisitType: 'lpu',
                notes: comment,
                medicalRepName: medRepName,
                createdAt: DateTime.tryParse(now) ?? DateTime.now(),
                updatedAt: DateTime.tryParse(now) ?? DateTime.now(),
                payload: LpuCompletedVisitPayload(
                  doctorIds: _allDoctorIds,
                  doctorName: widget.doctorName,
                  groupVisit: isGroupVisit,
                  groupVisitName: isGroupVisit
                      ? context.l10n.t('groupPresentation')
                      : null,
                  presentations: List.unmodifiable(presentations),
                ),
              ),
              tryRemote: !ref.read(isOfflineProvider),
            );
        localId = result.localId;
        ref.invalidate(dashboardCountsProvider);
        localOk = true;
        apiOk = result.remoteAccepted;
      } catch (error) {
        logSwallowed(error, 'LpuDetailingScreen.saveVisit');
      }
    }

    if (ref.read(isOfflineProvider)) {
      pulseOfflineBanner(ref);
    }
    if (!mounted) return;
    if (widget.visitId == null && localId != null) {
      final localVisit = await ref
          .read(visitInteractionRepositoryProvider)
          .getLocalVisitById(localId);
      localOk = localVisit != null;
      if (localVisit == null) {
        debugPrint('Local visit row not found after insert: id=$localId');
      }
    }
    await _notificationsService.add(
      title: visitDoneTitle,
      body: apiOk
          ? visitSentApiBody
          : (localOk ? visitSavedLocalBody : visitUnconfirmedBody),
      kind: 'visit',
    );
    final org = await ref
        .read(organisationsDirectoryRepositoryProvider)
        .getModelById(widget.orgId);
    if (!mounted) return;
    final orgAddress = org?.address.trim() ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LpuDetailingCompletionDialog(
        organizationId: widget.orgId,
        organizationName: widget.orgName,
        organizationAddress: orgAddress,
        doctorName: widget.doctorName,
        doctorCount: _allDoctorIds.length,
        selectedDrugs: selectedDrugs,
        firstStatus: selectedDrugs.isEmpty
            ? null
            : _statuses[selectedDrugs.first],
      ),
    );
  }

  void _showDoctorsDialog() {
    showAppSheet(
      context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LpuDetailingDoctorsInfoSheet(doctors: _doctors),
    );
  }

  Future<void> _showDrugStatus(String drugName) async {
    final status = await showMedicalStatusSheet(context, drugName: drugName);
    if (status == null || !mounted) return;
    ref
        .read(lpuDetailingViewModelProvider(widget.orgId).notifier)
        .setStatus(drugName, status);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(
      Uri(
        path: '/visits/lpu/detail/${widget.orgId}/doctors',
        queryParameters: {'name': widget.orgName},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(lpuDetailingViewModelProvider(widget.orgId));
    final canFinish = _statuses.isNotEmpty;
    final doctorCount = _allDoctorIds.length;
    final countLabel = _pluralDoctors(context, doctorCount);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primaryBg,
        body: LpuDetailingContent(
          organizationName: widget.orgName,
          doctorCountLabel: countLabel,
          filteredDrugs: _filtered,
          statuses: _statuses,
          drugByName: _detailState.drugByName,
          onBack: _goBack,
          onDoctorsTap: _showDoctorsDialog,
          onQueryChanged: (query) => ref
              .read(lpuDetailingViewModelProvider(widget.orgId).notifier)
              .setQuery(query),
          onStatusTap: _showDrugStatus,
          onMaterialsTap: (drugId) =>
              context.push('/knowledge/drug/$drugId/materials'),
        ),
        bottomNavigationBar: Container(
          color: AppColors.secondaryBg,
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            MediaQuery.of(context).padding.bottom + 8,
          ),
          child: AppTapScale(
            pressedScale: 0.97,
            onTap: (canFinish && !_actionLocked) ? _finishVisit : null,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                disabledBackgroundColor: (canFinish && !_actionLocked)
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
              ),
              child: Text(context.l10n.t('finishVisit')),
            ),
          ),
        ),
      ),
    );
  }
}

String _pluralDoctors(BuildContext context, int n) {
  return context.l10n.t('doctorsN', args: {'n': '$n'});
}

// ── Боттом-шит "Информация о враче" ────────────────────────────────────────
