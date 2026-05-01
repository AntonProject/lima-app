import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/db/local_database.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/dialogs/visit_detail_dialog.dart';
import '../../visits/models/history_records.dart';
import 'package:lima/shell/nav_bar_layout.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

class PlannedVisitsNotifier extends StateNotifier<List<PlannedVisit>> {
  final LocalDatabase _db;

  PlannedVisitsNotifier(this._db) : super(const []) {
    load();
  }

  Future<void> load() async {
    final merged = <String, PlannedVisit>{};

    // Load synced planned visits from local DB
    try {
      final dbRows = await _db.getPlannedVisits();
      for (final row in dbRows) {
        final remoteId = (row['remote_id'] as num?)?.toInt();
        final localId = (row['id'] as num?)?.toInt();
        if (localId == null) continue;
        final key = remoteId != null ? 'r_$remoteId' : 'l_$localId';
        final visitDate = DateTime.tryParse('${row['visit_date'] ?? ''}') ?? DateTime.now();
        merged[key] = PlannedVisit(
          id: remoteId ?? localId,
          organisationName: '${row['org_name'] ?? ''}',
          organisationId: (row['org_id'] as num?)?.toInt(),
          organisationType: (row['org_type'] ?? 'lpu') == 'pharmacy' ? OrgType.pharmacy : OrgType.lpu,
          doctorName: (row['doctor_name'] as String?)?.isNotEmpty == true ? row['doctor_name'] as String : null,
          assignedBy: row['assigned_by'] as String? ?? '',
          city: row['city'] as String?,
          date: visitDate,
          status: VisitStatus.planned,
        );
      }
    } catch (_) {}

    // Local DB visits (created by this user on this device)
    try {
      final localRows = await _db.getVisits();
      for (final row in localRows) {
        final localId = (row['id'] as num?)?.toInt();
        if (localId == null) continue;
        final status = '${row['status'] ?? 'planned'}'.toLowerCase();
        if (status == 'completed') continue;
        final remoteId = (row['remote_id'] as num?)?.toInt();
        final createdRaw = '${row['created_at'] ?? ''}';
        final created = DateTime.tryParse(createdRaw);
        if (created == null) continue;
        final visitType = '${row['visit_type'] ?? 'lpu'}'.toLowerCase();
        final orgName = '${row['org_name'] ?? ''}'.trim();
        if (orgName.isEmpty) continue;
        final key = remoteId != null ? 'r_$remoteId' : 'l_$localId';
        merged[key] = PlannedVisit(
          id: remoteId ?? localId,
          organisationName: orgName,
          organisationId: (row['org_id'] as num?)?.toInt(),
          organisationType:
              (visitType == 'pharmacy' ||
                  visitType == 'order' ||
                  visitType == 'circle')
              ? OrgType.pharmacy
              : OrgType.lpu,
          doctorName: '${row['doctor_name'] ?? ''}'.trim().isEmpty
              ? null
              : '${row['doctor_name']}'.trim(),
          assignedBy: 'Локально',
          city: null,
          date: created,
          status: status == 'completed'
              ? VisitStatus.completed
              : VisitStatus.planned,
        );
      }
    } catch (_) {}

    final list = merged.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    state = list;
  }

  void addPlannedVisit(PlannedVisit visit) {
    state = [...state, visit];
  }
}

final plannedVisitsProvider =
    StateNotifierProvider<PlannedVisitsNotifier, List<PlannedVisit>>((ref) {
      return PlannedVisitsNotifier(ref.watch(localDatabaseProvider));
    });

// ─── Screen ───────────────────────────────────────────────────────────────────

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  DateTime _visibleStart(DateTime focused) =>
      _calendarFormat == CalendarFormat.week
      ? focused.subtract(Duration(days: focused.weekday - 1))
      : DateTime(focused.year, focused.month, 1);

  List<PlannedVisit> _visitsForDay(
    List<PlannedVisit> all,
    DateTime day,
  ) {
    final key = DateTime(day.year, day.month, day.day);
    return all.where((v) {
      final vKey = DateTime(v.date.year, v.date.month, v.date.day);
      return vKey == key;
    }).toList();
  }

  // Convert a PlannedVisit → HistoryVisitRecord for the shared card / dialog
  HistoryVisitRecord _toHistoryRecord(PlannedVisit v) {
    final dd = v.date.day.toString().padLeft(2, '0');
    final mm = v.date.month.toString().padLeft(2, '0');
    final yyyy = v.date.year.toString();
    return HistoryVisitRecord(
      id: '${v.id}',
      orgId: v.organisationId,
      org: v.organisationName,
      date: '$dd.$mm.$yyyy',
      dateTime: '$dd.$mm.$yyyy',
      type: v.organisationType == OrgType.pharmacy ? 'pharmacy' : 'lpu',
      subType: v.organisationType == OrgType.pharmacy ? 'order' : 'lpu',
      doctor: v.doctorName ?? '—',
      medicalRep: v.assignedBy,
      status: v.status == VisitStatus.completed ? 'completed' : 'planned',
    );
  }

  Future<void> _openVisitDetail(PlannedVisit v) async {
    final record = _toHistoryRecord(v);
    if (!mounted) return;
    await showVisitDetailDialog(context, visit: record);
  }

  @override
  Widget build(BuildContext context) {
    final allVisits = ref.watch(plannedVisitsProvider);
    final filteredAll = allVisits;

    final eventMap = <DateTime, List<PlannedVisit>>{};
    for (final v in filteredAll) {
      final key = DateTime(v.date.year, v.date.month, v.date.day);
      eventMap.putIfAbsent(key, () => []).add(v);
    }

    final selectedVisits = _visitsForDay(filteredAll, _selectedDay);

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.secondaryBg,
                  boxShadow: shadowSm,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        MediaQuery.of(context).padding.top + 10,
                        16,
                        8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => context.go('/home'),
                            child: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'План визитов',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primaryBg,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                _modeBtn(
                                  'Неделя',
                                  _calendarFormat == CalendarFormat.week,
                                  () => setState(
                                    () => _calendarFormat = CalendarFormat.week,
                                  ),
                                ),
                                _modeBtn(
                                  'Месяц',
                                  _calendarFormat == CalendarFormat.month,
                                  () => setState(
                                    () =>
                                        _calendarFormat = CalendarFormat.month,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Month nav + calendar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Row(
                        children: [
                          _navBtn(Icons.chevron_left_rounded, () {
                            setState(() {
                              final base = _visibleStart(_focusedDay);
                              _focusedDay = _calendarFormat == CalendarFormat.week
                                  ? base.subtract(const Duration(days: 7))
                                  : DateTime(base.year, base.month - 1, 1);
                            });
                          }),
                          Expanded(
                            child: Center(
                              child: Text(
                                _calendarTitle(),
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ),
                          ),
                          _navBtn(Icons.chevron_right_rounded, () {
                            setState(() {
                              final base = _visibleStart(_focusedDay);
                              _focusedDay = _calendarFormat == CalendarFormat.week
                                  ? base.add(const Duration(days: 7))
                                  : DateTime(base.year, base.month + 1, 1);
                            });
                          }),
                        ],
                      ),
                    ),
                    TableCalendar<PlannedVisit>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                      eventLoader: (d) =>
                          _visitsForDay(filteredAll, d),
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        leftChevronVisible: false,
                        rightChevronVisible: false,
                        titleCentered: true,
                      ),
                      calendarBuilders: CalendarBuilders(
                        headerTitleBuilder: (context, day) =>
                            const SizedBox.shrink(),
                        dowBuilder: (context, day) => Center(
                          child: Text(
                            _weekdayLabel(day),
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF95A3BA),
                            ),
                          ),
                        ),
                      ),
                      daysOfWeekHeight: 26,
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekendStyle: TextStyle(color: Color(0xFF95A3BA)),
                        weekdayStyle: TextStyle(color: Color(0xFF95A3BA)),
                      ),
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        selectedTextStyle:
                            const TextStyle(color: Colors.white),
                        todayDecoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        todayTextStyle: const TextStyle(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                        markerDecoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // ── List ───────────────────────────────────────────────────────
              Expanded(
                child: selectedVisits.isEmpty
                    ? Column(
                        children: [
                          const SizedBox(height: 18),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _visitsTitle(),
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          const EmptyState(
                            icon: Icons.calendar_month_rounded,
                            title: 'На эту дату визитов нет',
                          ),
                          const Spacer(),
                        ],
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          18,
                          16,
                          // extra room for the sticky "+ создать визит" button
                          LimaNavBarLayout.scrollBottomPadding(context) + 64,
                        ),
                        itemCount: selectedVisits.length + 1,
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _visitsTitle(),
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ),
                            );
                          }
                          final v = selectedVisits[i - 1];
                          final record = _toHistoryRecord(v);
                          return _PlanVisitCard(
                            record: record,
                            onTap: () => _openVisitDetail(v),
                          );
                        },
                      ),
              ),
            ],
          ),

          // ── Sticky "+ создать визит" button above navbar ───────────────────
          Positioned(
            left: 12,
            right: 12,
            bottom: LimaNavBarLayout.totalBarHeight(context) + 8,
            child: AppTapScale(
              pressedScale: 0.97,
              onTap: () => _openCreateVisitSheet(),
              child: ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Создать визит'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  disabledBackgroundColor: AppColors.primary,
                  disabledForegroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeBtn(String title, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.primary : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primaryBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.secondaryText),
      ),
    );
  }

  Future<void> _openCreateVisitSheet() async {
    final db = ref.read(localDatabaseProvider);

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CreateVisitSheet(
        db: db,
        selectedDay: _selectedDay,
        monthRu: _monthRu,
        onSubmit: (visit) {
          ref.read(plannedVisitsProvider.notifier).addPlannedVisit(visit);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  String get _localeTag {
    final locale = Localizations.localeOf(context);
    final country = locale.countryCode;
    return country == null || country.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_$country';
  }

  String _monthRu(int m) {
    final text = DateFormat.MMMM(_localeTag).format(DateTime(2026, m, 1));
    return _lcFirst(text);
  }

  String _monthShort(int m) => _lcFirst(
    DateFormat.MMM(_localeTag).format(DateTime(2026, m, 1)).replaceAll('.', ''),
  );

  String _weekdayLabel(DateTime day) {
    var label = DateFormat.E(_localeTag).format(day).replaceAll('.', '').trim();
    if (label.length > 2) label = label.substring(0, 2);
    return label.toUpperCase();
  }

  String _lcFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toLowerCase() + text.substring(1);
  }

  String _ucFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _visitsTitle() {
    final now = DateTime.now();
    final isToday = _selectedDay.year == now.year &&
        _selectedDay.month == now.month &&
        _selectedDay.day == now.day;
    if (isToday) return 'Визиты на сегодня';
    return 'Визиты на ${_selectedDay.day} ${_monthRu(_selectedDay.month)}';
  }

  String _calendarTitle() {
    if (_calendarFormat == CalendarFormat.week) {
      final start = _focusedDay.subtract(
        Duration(days: _focusedDay.weekday - 1),
      );
      final end = start.add(const Duration(days: 6));
      return '${start.day} ${_monthShort(start.month)} — '
          '${end.day} ${_monthShort(end.month)}';
    }
    final month = DateFormat.MMMM(_localeTag).format(
      DateTime(_focusedDay.year, _focusedDay.month, 1),
    );
    return '${_ucFirst(month)} ${_focusedDay.year}';
  }
}

// ─── Plan visit card (same style as history screen) ───────────────────────────

class _PlanVisitCard extends StatelessWidget {
  final HistoryVisitRecord record;
  final VoidCallback onTap;

  const _PlanVisitCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isStock = record.type == 'stock';
    final isCircle = record.subType == 'circle';
    final isPharmacy = record.type == 'pharmacy';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: shadowSm,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCircle
                      ? const Color(0xFFE6F7EE)
                      : isStock
                      ? const Color(0xFFFEF5E6)
                      : isPharmacy
                          ? AppColors.iconBgGreen
                          : AppColors.iconBgBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCircle
                      ? Icons.add_circle_outline_rounded
                      : isStock
                      ? Icons.inventory_2_rounded
                      : isPharmacy
                          ? Icons.local_pharmacy_rounded
                          : Icons.home_work_rounded,
                  color: isCircle
                      ? const Color(0xFF34A36A)
                      : isStock
                      ? const Color(0xFFCC7A22)
                      : isPharmacy
                          ? AppColors.success
                          : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.org,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${record.id}',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (record.doctor != '—') ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 13,
                            color: AppColors.hintText,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              record.doctor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      record.date,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.hintText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Status pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(record.statusColor.bgHex),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  record.status == 'completed' ? 'Проведён' : 'План',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(record.statusColor.fgHex),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Create Visit Sheet ───────────────────────────────────────────────────────

class _CreateVisitSheet extends StatefulWidget {
  final LocalDatabase db;
  final DateTime selectedDay;
  final String Function(int) monthRu;
  final void Function(PlannedVisit) onSubmit;

  const _CreateVisitSheet({
    required this.db,
    required this.selectedDay,
    required this.monthRu,
    required this.onSubmit,
  });

  @override
  State<_CreateVisitSheet> createState() => _CreateVisitSheetState();
}

class _CreateVisitSheetState extends State<_CreateVisitSheet> {
  bool _isLpu = true;
  List<Map<String, dynamic>> _lpuOrgs = [];
  List<Map<String, dynamic>> _pharmacyOrgs = [];

  Map<String, dynamic>? _selectedOrg;
  int? _selectedDoctorId;
  String? _selectedForm;
  List<Map<String, dynamic>> _doctors = [];

  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOrgs();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _allOrgs => _isLpu ? _lpuOrgs : _pharmacyOrgs;

  Future<void> _loadOrgs() async {
    final rows = await Future.wait([
      widget.db.getOrganisations(type: 'lpu'),
      widget.db.getOrganisations(type: 'pharmacy'),
    ]);
    if (!mounted) return;
    setState(() {
      _lpuOrgs = rows[0];
      _pharmacyOrgs = rows[1];
    });
  }

  Future<void> _loadDoctors(int orgId) async {
    final rows = await widget.db.getDoctors(orgId: orgId);
    if (!mounted) return;
    setState(() {
      _doctors = rows;
    });
  }

  bool get _canSubmit {
    if (_selectedOrg == null) return false;
    if (_isLpu && _selectedDoctorId == null) return false;
    if (_selectedForm == null) return false;
    return true;
  }

  void _switchTab(bool isLpu) {
    if (_isLpu == isLpu) return;
    setState(() {
      _isLpu = isLpu;
      _selectedOrg = null;
      _selectedDoctorId = null;
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
        final maxH = MediaQuery.of(ctx).size.height * 0.45;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            List<_PickerOption<T>> filtered() {
              if (!searchable || queryCtrl.text.trim().isEmpty) return options;
              final q = queryCtrl.text.toLowerCase().trim();
              return options.where((e) => e.label.toLowerCase().contains(q)).toList();
            }

            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(maxHeight: maxH),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
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
                              hintText: 'Поиск...',
                              hintStyle: GoogleFonts.manrope(
                                fontSize: 12.5,
                                color: AppColors.hintText,
                                fontWeight: FontWeight.w500,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.hintText),
                              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
                                  'Ничего не найдено',
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
                            separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
                            itemBuilder: (_, i) {
                              final item = rows[i];
                              final isSelected = selected == item.value;
                              return InkWell(
                                onTap: () => Navigator.pop(ctx, item.value),
                                child: Container(
                                  color: isSelected ? const Color(0xFFF3F6FB) : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: GoogleFonts.manrope(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
              ),
            );
          },
        );
      },
    );
    queryCtrl.dispose();
    return result;
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
                  fontWeight: value == null || value.isEmpty ? FontWeight.w500 : FontWeight.w600,
                  color: enabled
                      ? (value == null || value.isEmpty ? AppColors.hintText : AppColors.primaryText)
                      : AppColors.hintText.withValues(alpha: 0.8),
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: enabled ? AppColors.hintText : AppColors.hintText.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_canSubmit) return;
    final org = _selectedOrg!;
    final doctor = _doctors.where((d) => d['id'] == _selectedDoctorId).firstOrNull;
    widget.onSubmit(
      PlannedVisit(
        id: DateTime.now().millisecondsSinceEpoch,
        organisationName: (org['name'] ?? '').toString(),
        organisationId: org['id'] as int?,
        organisationType: _isLpu ? OrgType.lpu : OrgType.pharmacy,
        doctorName: doctor?['full_name']?.toString(),
        assignedBy: 'Вы',
        date: DateTime(
          widget.selectedDay.year,
          widget.selectedDay.month,
          widget.selectedDay.day,
          10,
          0,
        ),
        status: VisitStatus.planned,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;
    final selectedOrgId = _selectedOrg?['id'] as int?;

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
                'Новый визит',
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
                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.secondaryText),
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
                _tabBtn('ЛПУ', _isLpu, () => _switchTab(true)),
                _tabBtn('Аптека', !_isLpu, () => _switchTab(false)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Organization dropdown
          _selectField(
            hint: _isLpu ? 'Название организации...' : 'Название аптеки...',
            value: _selectedOrg?['name']?.toString(),
            onTap: _allOrgs.isEmpty
                ? null
                : () async {
                    final picked = await _openPicker<int>(
                      title: _isLpu ? 'Выберите ЛПУ' : 'Выберите аптеку',
                      selected: selectedOrgId,
                      searchable: true,
                      options: _allOrgs
                          .map((org) => _PickerOption<int>(
                                value: org['id'] as int,
                                label: (org['name'] ?? '').toString(),
                              ))
                          .toList(),
                    );
                    if (!mounted || picked == null) return;
                    final org = _allOrgs.where((o) => o['id'] == picked).firstOrNull;
                    setState(() {
                      _selectedOrg = org;
                      _selectedDoctorId = null;
                      _doctors = [];
                    });
                    if (_isLpu) await _loadDoctors(picked);
                  },
          ),
          const SizedBox(height: 10),

          // Doctor dropdown (LPU only, after org selected)
          if (_isLpu) ...[
            _selectField(
              hint: 'Выберите врачей...',
              value: _doctors
                  .where((d) => d['id'] == _selectedDoctorId)
                  .firstOrNull?['full_name']
                  ?.toString(),
              onTap: _selectedOrg == null || _doctors.isEmpty
                  ? null
                  : () async {
                      final picked = await _openPicker<int>(
                        title: 'Выберите врача',
                        selected: _selectedDoctorId,
                        options: _doctors
                            .map((d) => _PickerOption<int>(
                                  value: d['id'] as int,
                                  label: (d['full_name'] ?? '').toString(),
                                ))
                            .toList(),
                      );
                      if (!mounted || picked == null) return;
                      setState(() => _selectedDoctorId = picked);
                    },
            ),
            const SizedBox(height: 10),
          ],

          // Visit form type dropdown
          _selectField(
            hint: _isLpu ? 'Форма визита...' : 'Тип визита...',
            value: () {
              if (_selectedForm == null) return null;
              final labels = _isLpu
                  ? <String, String>{
                      'single': 'Визит 1 на 1',
                      'group': 'Групповая презентация',
                      'double': 'С менеджером',
                    }
                  : <String, String>{
                      'order': 'Бронь',
                      'stock': 'Снятие остатков',
                      'circle': 'Фарм кружок',
                    };
              return labels[_selectedForm!];
            }(),
            onTap: () async {
              final options = _isLpu
                  ? const [
                      _PickerOption<String>(value: 'single', label: 'Визит 1 на 1'),
                      _PickerOption<String>(value: 'group', label: 'Групповая презентация'),
                      _PickerOption<String>(value: 'double', label: 'С менеджером'),
                    ]
                  : const [
                      _PickerOption<String>(value: 'order', label: 'Бронь'),
                      _PickerOption<String>(value: 'stock', label: 'Снятие остатков'),
                      _PickerOption<String>(value: 'circle', label: 'Фарм кружок'),
                    ];
              final picked = await _openPicker<String>(
                title: _isLpu ? 'Форма визита' : 'Тип визита',
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              hintText: 'Комментарий (необязательно)',
              hintStyle: GoogleFonts.manrope(
                fontSize: 11.5,
                color: AppColors.hintText,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD6DEE8), width: 0.8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD6DEE8), width: 0.8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD6DEE8), width: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Submit button
          ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.95),
            ),
            child: const Text('Запланировать'),
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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
