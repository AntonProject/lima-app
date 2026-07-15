import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/features/visits/data/doctors_repository.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/dialogs/manager_select_dialog.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/providers/form_dictionaries_provider.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';

enum _VisitMode { single, manager }

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
  String _query = '';
  String? _selectedManager;
  _VisitMode _mode = _VisitMode.single;
  final Set<String> _selected = {};
  List<Map<String, dynamic>> _doctors = [];
  bool _remoteDoctorsLoaded = false;

  List<Map<String, dynamic>> get _filtered => _doctors.where((d) {
    final name = (d['full_name'] as String? ?? '').toLowerCase();
    return name.contains(_query.toLowerCase());
  }).toList();

  bool get _canContinue {
    if (_mode == _VisitMode.manager) {
      return _selectedManager != null && _selected.isNotEmpty;
    }
    return _selected.isNotEmpty;
  }

  String get _visitModeTitle {
    if (_mode == _VisitMode.manager && _selectedManager != null) {
      return context.l10n.t(
        'managerColon',
        args: {'name': _selectedManager ?? ''},
      );
    }
    if (_selected.isEmpty) return context.l10n.t('selectDoctorsForVisit');
    if (_selected.length == 1) return context.l10n.t('visitOneOnOne');
    return context.l10n.t('groupPresentation');
  }

  @override
  void initState() {
    super.initState();
    final preselect = widget.preselectedDoctorId;
    if (preselect != null) _selected.add('$preselect');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDoctors());
  }

  /// Ensures the preselected doctor (from a favourite) appears in the list even
  /// when [getDoctors] filtered it out (e.g. global doctor not org-linked).
  Future<void> _ensurePreselectedDoctorLoaded(DoctorsRepository db) async {
    final preselect = widget.preselectedDoctorId;
    if (preselect == null || _query.isNotEmpty) return;
    if (_doctors.any((d) => '${d['id']}' == '$preselect')) return;
    final row = await db.getById(preselect);
    if (row != null) _doctors.insert(0, Map<String, dynamic>.from(row));
  }

  Future<void> _loadDoctors() async {
    final db = ref.read(doctorsRepositoryProvider);
    var results = await db.getDoctors(
      orgId: widget.orgId,
      query: _query.isEmpty ? null : _query,
      includeGlobalFallback: false,
    );

    if (!_remoteDoctorsLoaded &&
        _query.isEmpty &&
        !ref.read(isOfflineProvider)) {
      _remoteDoctorsLoaded = true;
      try {
        final remoteDoctors = await ref
            .read(doctorsRepositoryProvider)
            .getByOrganizationRemote(widget.orgId);
        if (remoteDoctors.length > results.length) {
          await db.upsertLocal(remoteDoctors);
          await db.upsertOrganisationLinks(
            remoteDoctors
                .map((d) => (d['id'] as num?)?.toInt())
                .whereType<int>()
                .map(
                  (doctorId) => <String, dynamic>{
                    'doctor_id': doctorId,
                    'organisation_id': widget.orgId,
                  },
                )
                .toList(),
          );
          results = await db.getDoctors(
            orgId: widget.orgId,
            query: _query.isEmpty ? null : _query,
            includeGlobalFallback: false,
          );
        }
      } catch (_) {}
    }

    if (!mounted) return;
    final list = results.map((e) => Map<String, dynamic>.from(e)).toList();
    _doctors = list;
    await _ensurePreselectedDoctorLoaded(db);
    if (!mounted) return;
    final ids = _doctors
        .map((e) => (e['id'] as num?)?.toInt())
        .whereType<int>()
        .toList();
    final visitCounts = await db.getVisitCountsByDoctorIds(ids);
    for (final row in _doctors) {
      final id = (row['id'] as num?)?.toInt();
      if (id != null) {
        row['visit_count'] = visitCounts[id] ?? 0;
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  String _categoryLabel(Map<String, dynamic> d) {
    String? category = (d['category'] as String?)?.trim();
    if (category == null || category.isEmpty) {
      final raw = d['raw_json'] as String?;
      if (raw != null && raw.isNotEmpty) {
        try {
          final m = Map<String, dynamic>.from(
            (const JsonDecoder().convert(raw)) as Map,
          );
          category = (m['category'] ?? m['category_name'] ?? m['class'])
              ?.toString()
              .trim();
        } catch (_) {}
      }
    }
    final normalized = (category == null || category.isEmpty)
        ? 'C'
        : category.toUpperCase();
    return '${context.l10n.t('category')} $normalized';
  }

  String _visitLabel(Map<String, dynamic> d) {
    final count = (d['visit_count'] as num?)?.toInt() ?? 0;
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

    final result = await showAppSheet<Map<String, dynamic>>(
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
                      selectedSpecName = specializations.firstWhere(
                        (s) => s['id'] == v,
                        orElse: () => const {'name': ''},
                      )['name'] as String;
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
                      ? () => Navigator.pop(ctx, {
                          'name': nameCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'specialization_id': selectedSpecId,
                          'specialization_name': selectedSpecName ?? '',
                          'hobby': hobbyCtrl.text.trim(),
                          'interests': interestsCtrl.text.trim(),
                          'birthday': birthday == null
                              ? ''
                              : '${birthday!.year.toString().padLeft(4, '0')}-${birthday!.month.toString().padLeft(2, '0')}-${birthday!.day.toString().padLeft(2, '0')}',
                        })
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
    final db = ref.read(doctorsRepositoryProvider);
    final now = DateTime.now().toIso8601String();
    final specId = result['specialization_id'] as int;

    // Отрицательный temp id (не пересекается с положительными серверными id).
    final tempId = -(DateTime.now().millisecondsSinceEpoch ~/ 1000);

    // Сначала сохраняем локально, чтобы врач был доступен сразу.
    await db.insertLocal({
      'id': tempId,
      'full_name': result['name'],
      'specialty': result['specialization_name'],
      'organisation_id': widget.orgId,
      'is_favorite': 0,
      'category': 'C',
      'last_visit_label': noVisitsLabel,
      'updated_at': now,
    });

    // Пробуем отправить в API немедленно.
    int? remoteDoctorId;
    try {
      remoteDoctorId = await db.addRemote(
        organizationId: widget.orgId,
        fullName: result['name'] ?? '',
        specializationId: specId,
        phone: result['phone'],
        hobby: result['hobby'],
        interests: result['interests'],
        birthday: result['birthday'],
      );
    } catch (_) {
      remoteDoctorId = null;
    }

    if (remoteDoctorId != null) {
      await db.replaceTempId(tempId, remoteDoctorId);
    } else {
      // Оффлайн — в очередь с полным payload; temp id живёт до синхронизации.
      await db.enqueuePending(
        tempLocalId: tempId,
        orgId: widget.orgId,
        fullName: result['name'] ?? '',
        specialty: result['specialization_name'] ?? '',
        specializationId: specId,
        phone: result['phone'],
        hobby: result['hobby'],
        interests: result['interests'],
        birthday: result['birthday'],
      );
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
    setState(() {
      if (_selected.contains(idStr)) {
        _selected.remove(idStr);
      } else {
        _selected.add(idStr);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  onChanged: (v) {
                    setState(() => _query = v);
                    _loadDoctors();
                  },
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
                          _mode == _VisitMode.manager
                              ? Icons.supervisor_account_rounded
                              : _selected.length >= 2
                              ? Icons.groups_rounded
                              : _selected.isEmpty
                              ? Icons.info_outline_rounded
                              : Icons.person_rounded,
                          size: 15,
                          color: _mode == _VisitMode.manager
                              ? AppColors.primary
                              : _selected.isEmpty
                              ? AppColors.hintText
                              : _selected.length >= 2
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
                            color: _mode == _VisitMode.manager
                                ? AppColors.primary
                                : _selected.isEmpty
                                ? AppColors.hintText
                                : _selected.length >= 2
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
                  final idStr = '${d['id']}';
                  final name = d['full_name'] as String? ?? '';
                  final category = _categoryLabel(d);
                  final specialty = d['specialty'] as String?;
                  return DoctorCardCheckbox(
                    name: name,
                    category: category,
                    specialty: specialty,
                    lastVisit: _visitLabel(d),
                    isSelected: _selected.contains(idStr),
                    onTap: () => _toggleSelect(idStr),
                  );
                }),
                // Контейнер "Выбрано врачей"
                if (_selected.isNotEmpty)
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
                            args: {'count': '${_selected.length}'},
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
                        setState(() {
                          _selectedManager = manager;
                          _mode = _VisitMode.manager;
                        });
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
                _selectedManager != null
                    ? Icons.groups_rounded
                    : Icons.groups_outlined,
                size: 22,
                color: _selectedManager != null
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
                        final selectedIds = _selected.toList(growable: false);
                        final doctorIdStr = selectedIds.first;
                        final selectedDoctors = _doctors
                            .where((d) => selectedIds.contains('${d['id']}'))
                            .toList();
                        final doctorName = selectedDoctors.isEmpty
                            ? ''
                            : selectedDoctors
                                  .map((d) => d['full_name'] as String? ?? '')
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
                              'managerName': ?_selectedManager,
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
