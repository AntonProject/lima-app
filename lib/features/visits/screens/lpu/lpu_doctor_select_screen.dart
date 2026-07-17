import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/dialogs/manager_select_dialog.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/providers/form_dictionaries_provider.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/visits/providers/lpu_details_provider.dart';
import 'package:lima/features/visits/domain/entities/doctor_draft.dart';
import 'package:lima/features/visits/providers/lpu_doctor_select_provider.dart';
import 'package:lima/features/visits/presentation/view_models/lpu_doctor_select_view_model.dart';

class LpuDoctorSelectScreen extends ConsumerStatefulWidget {
  final int orgId;
  final String orgName;

  /// When set (e.g. coming from a favourite doctor), this doctor is checked on
  /// open so the user lands on the doctor-select step with a pre-selected
  /// doctor — matching the web flow.
  final int? preselectedDoctorId;

  const LpuDoctorSelectScreen({
    super.key,
    required this.orgId,
    required this.orgName,
    this.preselectedDoctorId,
  });

  @override
  ConsumerState<LpuDoctorSelectScreen> createState() =>
      _LpuDoctorSelectScreenState();
}

class _LpuDoctorSelectScreenState extends ConsumerState<LpuDoctorSelectScreen> {
  LpuDoctorSelectionState get _selection =>
      ref.read(lpuDoctorSelectViewModelProvider(widget.orgId));
  List<Doctor> get _doctors =>
      ref.read(lpuDetailsViewModelProvider(widget.orgId)).doctors;

  Map<int, int> get _visitCounts =>
      ref.read(lpuDetailsViewModelProvider(widget.orgId)).visitCounts;

  List<Doctor> get _filtered => _doctors
      .where(
        (d) =>
            d.fullName.toLowerCase().contains(_selection.query.toLowerCase()),
      )
      .toList();

  bool get _canContinue => _selection.canContinue;

  String get _visitModeTitle {
    if (_selection.mode == LpuVisitMode.manager &&
        _selection.selectedManager != null) {
      return context.l10n.t(
        'managerColon',
        args: {'name': _selection.selectedManager ?? ''},
      );
    }
    if (_selection.selectedIds.isEmpty) {
      return context.l10n.t('selectDoctorsForVisit');
    }
    if (_selection.selectedIds.length == 1) {
      return context.l10n.t('visitOneOnOne');
    }
    return context.l10n.t('groupPresentation');
  }

  @override
  void initState() {
    super.initState();
    final preselect = widget.preselectedDoctorId;
    if (preselect != null) {
      ref
          .read(lpuDoctorSelectViewModelProvider(widget.orgId).notifier)
          .selectDoctor('$preselect');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDoctors());
  }

  /// Ensures the preselected doctor (from a favourite) appears in the shared
  /// list even when it is not linked locally yet.
  Future<void> _ensurePreselectedDoctorLoaded() async {
    final preselect = widget.preselectedDoctorId;
    if (preselect == null || _selection.query.isNotEmpty) return;
    await ref
        .read(lpuDetailsViewModelProvider(widget.orgId).notifier)
        .ensureDoctorLoaded(preselect);
  }

  Future<void> _loadDoctors() async {
    await ref
        .read(lpuDetailsViewModelProvider(widget.orgId).notifier)
        .load(fetchRemote: !ref.read(isOfflineProvider));
    await _ensurePreselectedDoctorLoaded();
  }

  String _categoryLabel(Doctor d) {
    final category = d.displayCategory;
    final normalized = (category == null || category.isEmpty)
        ? 'C'
        : category.toUpperCase();
    return '${context.l10n.t('category')} $normalized';
  }

  String _visitLabel(Doctor d) {
    final count = _visitCounts[d.id] ?? 0;
    if (count <= 0) return context.l10n.t('noVisitsYet');
    return context.l10n.plural(count, 'visits');
  }

  /// Cache-first specialization list — see [FormDictionariesNotifier].
  Future<List<Map<String, dynamic>>> _loadSpecializations() =>
      ref.read(formDictionariesProvider).specializations();

  Future<void> _openAddDoctorSheet() async {
    final specializations = await _loadSpecializations();
    if (!mounted) return;

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+998 ');
    final hobbyCtrl = TextEditingController();
    final interestsCtrl = TextEditingController();
    int? selectedSpecId;
    String? selectedSpecName;
    DateTime? birthday;

    final result = await showAppSheet<DoctorDraft>(
      context,
      useRootNavigator: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final canSubmit =
              nameCtrl.text.trim().isNotEmpty && selectedSpecId != null;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).padding.bottom +
                  16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      context.l10n.t('addDoctor'),
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                _field(
                  context.l10n.t('fullNameField'),
                  nameCtrl,
                  onChanged: (_) => setModal(() {}),
                ),
                _field(context.l10n.t('phoneNumber'), phoneCtrl),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<int>(
                    initialValue: selectedSpecId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.t('specialization'),
                    ),
                    items: specializations
                        .map(
                          (s) => DropdownMenuItem<int>(
                            value: s['id'] as int,
                            child: Text(
                              s['name'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setModal(() {
                      selectedSpecId = v;
                      selectedSpecName =
                          specializations.firstWhere(
                                (s) => s['id'] == v,
                                orElse: () => const {'name': ''},
                              )['name']
                              as String;
                    }),
                  ),
                ),
                _field(context.l10n.t('hobby'), hobbyCtrl),
                _field(context.l10n.t('interests'), interestsCtrl),
                InkWell(
                  onTap: () async {
                    FocusScope.of(ctx).unfocus();
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: birthday ?? DateTime(now.year - 30),
                      firstDate: DateTime(1930),
                      lastDate: now,
                    );
                    if (picked != null) setModal(() => birthday = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.l10n.t('birthDate'),
                    ),
                    child: Text(
                      birthday == null
                          ? '—'
                          : '${birthday!.day.toString().padLeft(2, '0')}.${birthday!.month.toString().padLeft(2, '0')}.${birthday!.year}',
                      style: GoogleFonts.manrope(
                        color: birthday == null
                            ? AppColors.hintText
                            : AppColors.primaryText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: canSubmit
                      ? () => Navigator.pop(
                          ctx,
                          DoctorDraft(
                            organizationId: widget.orgId,
                            fullName: nameCtrl.text.trim(),
                            specialty: selectedSpecName ?? '',
                            specializationId: selectedSpecId!,
                            phone: phoneCtrl.text.trim(),
                            hobby: hobbyCtrl.text.trim(),
                            interests: interestsCtrl.text.trim(),
                            birthday: birthday == null
                                ? null
                                : '${birthday!.year.toString().padLeft(4, '0')}-${birthday!.month.toString().padLeft(2, '0')}-${birthday!.day.toString().padLeft(2, '0')}',
                          ),
                        )
                      : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.hintText,
                  ),
                  child: Text(context.l10n.t('addDoctor')),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result == null) return;
    if (!mounted) return;
    final noVisitsLabel = context.l10n.t('noVisitsYet');
    final now = DateTime.now().toIso8601String();

    // Отрицательный temp id (не пересекается с положительными серверными id).
    final tempId = -(DateTime.now().millisecondsSinceEpoch ~/ 1000);

    // Сначала сохраняем локально, чтобы врач был доступен сразу.
    final repository = ref.read(doctorsDirectoryRepositoryProvider);
    await repository.insertLocalDoctor(
      Doctor(
        id: tempId,
        fullName: result.fullName,
        specialty: result.specialty,
        specializationId: result.specializationId,
        organisationId: result.organizationId,
        category: 'C',
        lastVisitLabel: noVisitsLabel,
        phone: result.phone,
        hobby: result.hobby,
        interests: result.interests,
        birthday: result.birthday,
        updatedAt: now,
      ),
    );

    // Пробуем отправить в API немедленно.
    int? remoteDoctorId;
    try {
      remoteDoctorId = await repository.createRemoteDoctor(result);
    } catch (_) {
      remoteDoctorId = null;
    }

    if (remoteDoctorId != null) {
      await repository.replaceDoctorTempId(tempId, remoteDoctorId);
    } else {
      // Оффлайн — в очередь с полным payload; temp id живёт до синхронизации.
      await repository.enqueueNewDoctor(tempLocalId: tempId, draft: result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.t('doctorSavedLocally')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    await _loadDoctors();
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  void _toggleSelect(String idStr) {
    ref
        .read(lpuDoctorSelectViewModelProvider(widget.orgId).notifier)
        .toggleDoctor(idStr);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(lpuDetailsViewModelProvider(widget.orgId));
    final selection = ref.watch(lpuDoctorSelectViewModelProvider(widget.orgId));
    // Directory editing (add doctor) is no longer gated by role — the server
    // enforces permissions on the add endpoint.
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Column(
        children: [
          // ── Фиксированный AppBar ──────────────────────────────────────────
          AppCenteredHeader(
            title: context.l10n.t('doctorSelect'),
            subtitle: widget.orgName,
            leftAlign: true,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(
                  Uri(
                    path: '/visits/lpu/detail/${widget.orgId}',
                    queryParameters: {'name': widget.orgName},
                  ).toString(),
                );
              }
            },
            trailing: GestureDetector(
              onTap: _openAddDoctorSheet,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ),
          // ── Скроллируемое содержимое ──────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                // Поиск
                TextFormField(
                  onChanged: (v) => ref
                      .read(
                        lpuDoctorSelectViewModelProvider(widget.orgId).notifier,
                      )
                      .setQuery(v),
                  decoration: InputDecoration(
                    hintText: context.l10n.t('searchDoctor'),
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                // Бейдж режима — всегда показывается, не прыгает
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          selection.mode == LpuVisitMode.manager
                              ? Icons.supervisor_account_rounded
                              : selection.selectedIds.length >= 2
                              ? Icons.groups_rounded
                              : selection.selectedIds.isEmpty
                              ? Icons.info_outline_rounded
                              : Icons.person_rounded,
                          size: 15,
                          color: selection.mode == LpuVisitMode.manager
                              ? AppColors.primary
                              : selection.selectedIds.isEmpty
                              ? AppColors.hintText
                              : selection.selectedIds.length >= 2
                              ? const Color(0xFFAD6B09)
                              : AppColors.primary,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _visitModeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: selection.mode == LpuVisitMode.manager
                                ? AppColors.primary
                                : selection.selectedIds.isEmpty
                                ? AppColors.hintText
                                : selection.selectedIds.length >= 2
                                ? const Color(0xFFAD6B09)
                                : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Заголовок списка
                Text(
                  context.l10n.t(
                    'doctorsCountCaps',
                    args: {'count': '${_filtered.length}'},
                  ),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.hintText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                // Карточки врачей
                ..._filtered.map((d) {
                  final idStr = '${d.id}';
                  final name = d.fullName;
                  final category = _categoryLabel(d);
                  final specialty = d.specialty;
                  return DoctorCardCheckbox(
                    name: name,
                    category: category,
                    specialty: specialty,
                    lastVisit: _visitLabel(d),
                    isSelected: selection.selectedIds.contains(idStr),
                    onTap: () => _toggleSelect(idStr),
                  );
                }),
                // Контейнер "Выбрано врачей"
                if (selection.selectedIds.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: shadowSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.t(
                            'selectedDoctors',
                            args: {'count': '${selection.selectedIds.length}'},
                          ),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          MediaQuery.of(context).padding.bottom + 8,
        ),
        color: AppColors.secondaryBg,
        child: Row(
          children: [
            OutlinedButton(
              onPressed: () async {
                final manager = await showManagerSelectDialog(context);
                if (!mounted) return;
                if (manager != null) {
                  ref
                      .read(
                        lpuDoctorSelectViewModelProvider(widget.orgId).notifier,
                      )
                      .setManager(manager);
                }
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(46, 46),
                maximumSize: const Size(46, 46),
                padding: EdgeInsets.zero,
                backgroundColor: const Color(0xFFF0F2F5),
                side: const BorderSide(color: Color(0xFFADB5BD), width: 1.5),
                foregroundColor: AppColors.secondaryText,
              ),
              child: Icon(
                selection.selectedManager != null
                    ? Icons.groups_rounded
                    : Icons.groups_outlined,
                size: 22,
                color: selection.selectedManager != null
                    ? AppColors.primary
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: !_canContinue
                    ? null
                    : () {
                        final selectedIds = selection.selectedIds.toList(
                          growable: false,
                        );
                        final doctorIdStr = selectedIds.first;
                        final selectedDoctors = _doctors
                            .where((d) => selectedIds.contains('${d.id}'))
                            .toList();
                        final doctorName = selectedDoctors.isEmpty
                            ? ''
                            : selectedDoctors
                                  .map((d) => d.fullName)
                                  .where((n) => n.isNotEmpty)
                                  .join(', ');
                        context.push(
                          Uri(
                            path:
                                '/visits/lpu/detail/${widget.orgId}/doctors/$doctorIdStr/detailing',
                            queryParameters: {
                              'doctorName': doctorName,
                              'orgName': widget.orgName,
                              'doctorIds': selectedIds.join(','),
                              'managerName': ?selection.selectedManager,
                            },
                          ).toString(),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.4,
                  ),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(context.l10n.t('continue')),
                    if (_canContinue) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
