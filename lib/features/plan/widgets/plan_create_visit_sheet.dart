import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/providers/auth_provider.dart';
import '../../visits/domain/repositories/doctors_directory_repository.dart';
import '../../visits/providers/visits_hub_provider.dart';
import '../domain/entities/planned_visit_draft.dart';
import '../providers/planned_visits_provider.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/swallowed.dart';
import '../../../core/widgets/app_widgets.dart';

// ─── Create Visit Sheet ───────────────────────────────────────────────────────

class PlanCreateVisitSheet extends ConsumerStatefulWidget {
  final DoctorsDirectoryRepository doctorsRepository;
  final DateTime selectedDay;
  final String Function(int) monthRu;
  final void Function(PlannedVisit) onSubmit;

  const PlanCreateVisitSheet({
    super.key,
    required this.doctorsRepository,
    required this.selectedDay,
    required this.monthRu,
    required this.onSubmit,
  });

  @override
  ConsumerState<PlanCreateVisitSheet> createState() =>
      PlanCreateVisitSheetState();
}

class PlanCreateVisitSheetState extends ConsumerState<PlanCreateVisitSheet> {
  bool _isLpu = true;
  bool _submitting = false;
  List<Organisation> _lpuOrgs = [];
  List<Organisation> _pharmacyOrgs = [];

  // Visit format picker options.
  // Defaults — used until [_loadFormats] populates from the local visit_formats
  // cache (which itself is refreshed from /api/visits/formats on splash).
  // Format id=4 («Групповая презентация и двойной визит») is filtered out of
  // the picker because product wants users to pick group/double separately.
  List<_PickerOption<String>> _lpuFormats = const [];
  List<_PickerOption<String>> _pharmacyFormats = const [];

  Organisation? _selectedOrg;
  final Set<int> _selectedDoctorIds = <int>{};
  String? _selectedForm;
  List<Doctor> _doctors = [];

  final _commentCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lpuFormats.isEmpty) {
      _lpuFormats = [
        _PickerOption(
          value: 'group',
          label: context.l10n.t('groupPresentation'),
        ),
        _PickerOption(value: 'double', label: context.l10n.t('doubleVisit')),
      ];
      _pharmacyFormats = [
        _PickerOption(value: 'circle', label: context.l10n.t('pharmCircle')),
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadOrgs();
    _loadFormats();
  }

  /// Reads cached formats from local DB (refreshed from API on splash).
  /// Filters out id=4 so the picker shows group/double as separate items.
  Future<void> _loadFormats() async {
    try {
      final formats = await ref
          .read(plannedVisitsRepositoryProvider)
          .getVisitFormats();
      if (!mounted || formats.isEmpty) return;

      final lpuOpts = <_PickerOption<String>>[];
      final pharmOpts = <_PickerOption<String>>[];
      for (final format in formats) {
        final id = format.id;
        final name = format.name;
        if (id == 4) continue; // hide combined group+double from picker
        final internal = _fmtIdToInternal(id);
        if (internal == null) continue;
        final opt = _PickerOption<String>(value: internal, label: name);
        if (id == 1) {
          pharmOpts.add(opt);
        } else {
          lpuOpts.add(opt);
        }
      }
      if (!mounted) return;
      setState(() {
        if (lpuOpts.isNotEmpty) _lpuFormats = lpuOpts;
        if (pharmOpts.isNotEmpty) _pharmacyFormats = pharmOpts;
      });
    } catch (error) {
      logSwallowed(error, 'PlanScreen.loadVisitFormats');
    }
  }

  static String? _fmtIdToInternal(int id) => switch (id) {
    1 => 'circle',
    2 => 'double',
    3 => 'group',
    4 => 'group_double',
    _ => null,
  };

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  List<Organisation> get _allOrgs => _isLpu ? _lpuOrgs : _pharmacyOrgs;

  Future<void> _loadOrgs() async {
    final orgsRepo = ref.read(organisationsDirectoryRepositoryProvider);
    final rows = await Future.wait([
      orgsRepo.getLocalModels(type: 'lpu'),
      orgsRepo.getLocalModels(type: 'pharmacy'),
    ]);
    if (!mounted) return;
    setState(() {
      _lpuOrgs = rows[0];
      _pharmacyOrgs = rows[1];
    });
  }

  Future<void> _loadDoctors(int orgId) async {
    final doctors = await widget.doctorsRepository.getDoctorModels(
      orgId: orgId,
    );
    if (!mounted) return;
    setState(() {
      _doctors = doctors;
    });
  }

  bool get _canSubmit {
    if (_selectedOrg == null) return false;
    if (_isLpu && _selectedDoctorIds.isEmpty) return false;
    if (_selectedForm == null) return false;
    return true;
  }

  void _switchTab(bool isLpu) {
    if (_isLpu == isLpu) return;
    setState(() {
      _isLpu = isLpu;
      _selectedOrg = null;
      _selectedDoctorIds.clear();
      _selectedForm = null;
      _doctors = [];
    });
  }

  Future<T?> _openPicker<T>({
    required String title,
    required List<_PickerOption<T>> options,
    required T? selected,
    bool searchable = false,
  }) async {
    final queryCtrl = TextEditingController();
    final result = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).padding.bottom;
        final maxH = MediaQuery.of(ctx).size.height * 0.45 + bottomPad;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            List<_PickerOption<T>> filtered() {
              if (!searchable || queryCtrl.text.trim().isEmpty) return options;
              final q = queryCtrl.text.toLowerCase().trim();
              return options
                  .where((e) => e.label.toLowerCase().contains(q))
                  .toList();
            }

            return Container(
              constraints: BoxConstraints(maxHeight: maxH),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: EdgeInsets.only(bottom: bottomPad),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  if (searchable)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD6DEE8)),
                        ),
                        child: TextField(
                          controller: queryCtrl,
                          onChanged: (_) => setModalState(() {}),
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryText,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: context.l10n.t('searching'),
                            hintStyle: GoogleFonts.manrope(
                              fontSize: 12.5,
                              color: AppColors.hintText,
                              fontWeight: FontWeight.w500,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: AppColors.hintText,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Divider(height: 1, color: AppColors.divider),
                  Flexible(
                    child: Builder(
                      builder: (_) {
                        final rows = filtered();
                        if (rows.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                context.l10n.t('nothingFound'),
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: AppColors.divider,
                          ),
                          itemBuilder: (_, i) {
                            final item = rows[i];
                            final isSelected = selected == item.value;
                            return InkWell(
                              onTap: () => Navigator.pop(ctx, item.value),
                              child: Container(
                                color: isSelected
                                    ? const Color(0xFFF3F6FB)
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.radio_button_checked_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    queryCtrl.dispose();
    return result;
  }

  /// Multi-select variant of [_openPicker]. Returns the new selection set,
  /// or `null` if the user dismissed without applying.
  Future<List<T>?> _openMultiPicker<T>({
    required String title,
    required Set<T> selected,
    required List<_PickerOption<T>> options,
  }) async {
    final draft = Set<T>.of(selected);
    final result = await showModalBottomSheet<List<T>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).padding.bottom;
        final maxH = MediaQuery.of(ctx).size.height * 0.55 + bottomPad;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              constraints: BoxConstraints(maxHeight: maxH),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: EdgeInsets.only(bottom: bottomPad),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (_, i) {
                        final item = options[i];
                        final isSelected = draft.contains(item.value);
                        return InkWell(
                          onTap: () => setModalState(() {
                            if (isSelected) {
                              draft.remove(item.value);
                            } else {
                              draft.add(item.value);
                            }
                          }),
                          child: Container(
                            color: isSelected
                                ? const Color(0xFFF3F6FB)
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 20,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.hintText,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(ctx, draft.toList(growable: false)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        context.l10n.t(
                          'doneCount',
                          args: {'count': '${draft.length}'},
                        ),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    return result;
  }

  /// Doctor multi-select field: shows chips for each selected doctor (with X
  /// to remove inline) and opens the multi-picker on tap.
  Widget _selectedDoctorsField({
    required bool enabled,
    required Future<void> Function() onTap,
  }) {
    final chips = _doctors.where((d) => _selectedDoctorIds.contains(d.id)).map((
      d,
    ) {
      return _DoctorChip(
        label: d.fullName,
        onRemove: () => setState(() => _selectedDoctorIds.remove(d.id)),
      );
    }).toList();

    return AppTapScale(
      pressedScale: 0.99,
      onTap: enabled ? () => onTap() : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6DEE8), width: 0.8),
        ),
        child: Row(
          children: [
            Expanded(
              child: chips.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        context.l10n.t('selectDoctorsHint'),
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: enabled
                              ? AppColors.hintText
                              : AppColors.hintText.withValues(alpha: 0.8),
                        ),
                      ),
                    )
                  : Wrap(spacing: 6, runSpacing: 6, children: chips),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: enabled
                  ? AppColors.hintText
                  : AppColors.hintText.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectField({
    required String hint,
    required String? value,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return AppTapScale(
      pressedScale: 0.99,
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6DEE8), width: 0.8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null || value.isEmpty ? hint : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: value == null || value.isEmpty
                      ? FontWeight.w500
                      : FontWeight.w600,
                  color: enabled
                      ? (value == null || value.isEmpty
                            ? AppColors.hintText
                            : AppColors.primaryText)
                      : AppColors.hintText.withValues(alpha: 0.8),
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: enabled
                  ? AppColors.hintText
                  : AppColors.hintText.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  /// Maps the dropdown form-code to the server's visit_format_id.
  /// Confirmed from prod network traces:
  ///   pharmacy/circle → 1, lpu/double → 2.
  /// lpu/group is inferred (3) and may need adjustment if server differs.
  int? _resolveVisitFormatId() => switch (_selectedForm) {
    'circle' => 1,
    'double' => 2,
    'group' => 3,
    'group_double' => 4,
    _ => null,
  };

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    final org = _selectedOrg!;
    final orgId = org.id;
    final visitFormatId = _resolveVisitFormatId();
    if (visitFormatId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _submitting = true);

    final selectedDoctors = _doctors
        .where((d) => _selectedDoctorIds.contains(d.id))
        .toList();
    final doctorIds = _isLpu
        ? selectedDoctors.map((d) => d.id).toList(growable: false)
        : const <int>[];
    final doctorNamesCsv = selectedDoctors
        .map((d) => d.fullName.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
    final visitDate = DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
      10,
      0,
    );
    final userName =
        ref.read(authProvider).user?.fullName ?? context.l10n.t('you');
    final comment = _commentCtrl.text.trim();

    final draft = PlannedVisitDraft(
      organisationId: orgId,
      organisationName: org.name,
      organisationType: _isLpu ? 'lpu' : 'pharmacy',
      doctorId: doctorIds.length == 1 ? doctorIds.first : null,
      doctorIds: List.unmodifiable(doctorIds),
      doctorName: doctorNamesCsv.isEmpty ? null : doctorNamesCsv,
      assignedBy: userName,
      city: org.city,
      district: org.district,
      visitDate: visitDate,
      comment: comment,
      visitFormat: _selectedForm!,
      visitFormatId: visitFormatId,
    );

    int localPlanId;
    try {
      final visitsRepo = ref.read(plannedVisitsRepositoryProvider);
      localPlanId = await visitsRepo.savePlannedVisit(draft);
      await visitsRepo.enqueuePlannedVisit(
        localPlanId: localPlanId,
        draft: draft,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.t('couldNotSavePlan', args: {'error': '$e'})),
        ),
      );
      return;
    }

    // Surface the new row in the in-memory list immediately so the user
    // sees their plan card without waiting for the API round-trip.
    widget.onSubmit(
      PlannedVisit(
        id: localPlanId,
        organisationName: org.name,
        organisationId: orgId,
        organisationType: _isLpu ? OrgType.lpu : OrgType.pharmacy,
        doctorName: doctorNamesCsv.isEmpty ? null : doctorNamesCsv,
        assignedBy: userName,
        city: org.city ?? '',
        district: org.district ?? '',
        date: visitDate,
        status: VisitStatus.planned,
        visitFormat: _selectedForm,
      ),
    );

    // Reload from DB so the list also reflects the persisted row and any
    // server stamping that happens after pushPendingPlans() returns.
    unawaited(
      ref
          .read(syncProvider.notifier)
          .pushPendingPlans()
          .whenComplete(() => ref.read(plannedVisitsProvider.notifier).load()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;
    final selectedOrgId = _selectedOrg?.id;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title row
          Row(
            children: [
              Text(
                context.l10n.t('newVisit'),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.iconBgBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.selectedDay.day} ${widget.monthRu(widget.selectedDay.month)}',
                  style: GoogleFonts.manrope(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              AppTapScale(
                pressedScale: 0.9,
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          // Tabs: ЛПУ / Аптека
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _tabBtn(context.l10n.t('lpu'), _isLpu, () => _switchTab(true)),
                _tabBtn(
                  context.l10n.t('pharmacyOne'),
                  !_isLpu,
                  () => _switchTab(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Organization dropdown
          _selectField(
            hint: _isLpu
                ? context.l10n.t('orgNameHint')
                : context.l10n.t('pharmacyNameHint'),
            value: _selectedOrg?.name,
            onTap: _allOrgs.isEmpty
                ? null
                : () async {
                    final picked = await _openPicker<int>(
                      title: _isLpu
                          ? context.l10n.t('selectLpu')
                          : context.l10n.t('selectPharmacyTitle'),
                      selected: selectedOrgId,
                      searchable: true,
                      options: _allOrgs
                          .map(
                            (org) => _PickerOption<int>(
                              value: org.id,
                              label: org.name,
                            ),
                          )
                          .toList(),
                    );
                    if (!mounted || picked == null) return;
                    final org = _allOrgs
                        .where((o) => o.id == picked)
                        .firstOrNull;
                    setState(() {
                      _selectedOrg = org;
                      _selectedDoctorIds.clear();
                      _doctors = [];
                    });
                    if (_isLpu) await _loadDoctors(picked);
                  },
          ),
          const SizedBox(height: 10),

          // Doctor dropdown (LPU only, after org selected) — multi-select chips.
          if (_isLpu) ...[
            _selectedDoctorsField(
              enabled: _selectedOrg != null && _doctors.isNotEmpty,
              onTap: () async {
                final picked = await _openMultiPicker<int>(
                  title: context.l10n.t('selectDoctorsForVisit'),
                  selected: _selectedDoctorIds,
                  options: _doctors
                      .map(
                        (d) =>
                            _PickerOption<int>(value: d.id, label: d.fullName),
                      )
                      .toList(),
                );
                if (!mounted || picked == null) return;
                setState(() {
                  _selectedDoctorIds
                    ..clear()
                    ..addAll(picked);
                });
              },
            ),
            const SizedBox(height: 10),
          ],

          // Visit form type dropdown
          _selectField(
            hint: _isLpu
                ? context.l10n.t('visitFormatHint')
                : context.l10n.t('visitTypeHint'),
            value: () {
              if (_selectedForm == null) return null;
              final opts = _isLpu ? _lpuFormats : _pharmacyFormats;
              return opts
                  .cast<_PickerOption<String>?>()
                  .firstWhere(
                    (o) => o?.value == _selectedForm,
                    orElse: () => null,
                  )
                  ?.label;
            }(),
            onTap: () async {
              final options = _isLpu ? _lpuFormats : _pharmacyFormats;
              final picked = await _openPicker<String>(
                title: _isLpu
                    ? context.l10n.t('visitFormatTitle')
                    : context.l10n.t('visitType'),
                selected: _selectedForm,
                options: options,
              );
              if (!mounted || picked == null) return;
              setState(() => _selectedForm = picked);
            },
          ),
          const SizedBox(height: 10),

          // Comment
          TextField(
            controller: _commentCtrl,
            minLines: 2,
            maxLines: 3,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryText,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              hintText: context.l10n.t('commentOptional'),
              hintStyle: GoogleFonts.manrope(
                fontSize: 11.5,
                color: AppColors.hintText,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFD6DEE8),
                  width: 0.8,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFD6DEE8),
                  width: 0.8,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFD6DEE8),
                  width: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Submit button
          ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: AppColors.primary.withValues(
                alpha: 0.55,
              ),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.95),
            ),
            child: Text(context.l10n.t('schedule')),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: AppTapScale(
        pressedScale: 0.95,
        onTap: onTap,
        child: Container(
          height: 40,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF7B8596),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerOption<T> {
  final T value;
  final String label;

  const _PickerOption({required this.value, required this.label});
}

class _DoctorChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _DoctorChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD6DEE8), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.hintText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class PlanDayCell extends StatelessWidget {
  final int day;
  final Color bg;
  final Color fg;
  final bool bold;
  final Color? border;

  const PlanDayCell({
    super.key,
    required this.day,
    required this.bg,
    required this.fg,
    this.bold = false,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: border != null ? Border.all(color: border!, width: 1.4) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: TextStyle(
          color: fg,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
