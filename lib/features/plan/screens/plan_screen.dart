import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/db/local_database.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/dialogs/visit_detail_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../visits/models/history_records.dart';
import 'package:lima/shell/nav_bar_layout.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

class PlannedVisitsNotifier extends StateNotifier<List<PlannedVisit>> {
  final LocalDatabase _db;

  PlannedVisitsNotifier(this._db) : super(const []) {
    load();
  }

  // Composite signature for matching a locally-created plan against its
  // server-synced twin: same organisation + same calendar day. Used to drop
  // un-stamped local duplicates once the server row for the same plan arrives
  // (the push response sometimes omits the remote id, leaving the local row
  // un-stamped — without this, a second "ghost" card appears after restart).
  static String _planSignature(int? orgId, DateTime date) =>
      '${orgId ?? 0}_${date.year}-${date.month}-${date.day}';

  Future<void> load() async {
    final merged = <String, PlannedVisit>{};
    // Signatures of server-stamped planned rows (have a remote_id).
    final serverSignatures = <String>{};
    // Local-keyed entries we may need to drop if a server twin exists.
    final localKeyToSignature = <String, String>{};

    // Load synced planned visits from local DB
    try {
      final dbRows = await _db.getPlannedVisits();
      for (final row in dbRows) {
        final remoteId = (row['remote_id'] as num?)?.toInt();
        final localId = (row['id'] as num?)?.toInt();
        if (localId == null) continue;
        final key = remoteId != null ? 'r_$remoteId' : 'l_$localId';
        final visitDate =
            DateTime.tryParse('${row['visit_date'] ?? ''}') ?? DateTime.now();
        final orgId = (row['org_id'] as num?)?.toInt();
        final signature = _planSignature(orgId, visitDate);
        if (remoteId != null) {
          serverSignatures.add(signature);
        } else {
          localKeyToSignature[key] = signature;
        }
        merged[key] = PlannedVisit(
          id: remoteId ?? localId,
          organisationName: '${row['org_name'] ?? ''}',
          organisationId: (row['org_id'] as num?)?.toInt(),
          organisationType: (row['org_type'] ?? 'lpu') == 'pharmacy'
              ? OrgType.pharmacy
              : OrgType.lpu,
          doctorName: (row['doctor_name'] as String?)?.isNotEmpty == true
              ? row['doctor_name'] as String
              : null,
          assignedBy: row['assigned_by'] as String? ?? '',
          city: row['city'] as String?,
          district: row['district'] as String?,
          date: visitDate,
          status: VisitStatus.planned,
          visitFormat: row['visit_format'] as String?,
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

    // Drop un-stamped local planned rows whose server twin (same org + day)
    // is already present, so a failed remote-id stamp doesn't surface a
    // doctorless/wrong-type duplicate card after the next pull/restart.
    localKeyToSignature.forEach((key, signature) {
      if (serverSignatures.contains(signature)) {
        merged.remove(key);
      }
    });

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

  // Convert a PlannedVisit → HistoryVisitRecord for the shared card / dialog
  HistoryVisitRecord _toHistoryRecord(PlannedVisit v) {
    final dd = v.date.day.toString().padLeft(2, '0');
    final mm = v.date.month.toString().padLeft(2, '0');
    final yyyy = v.date.year.toString();
    final isPharmacy = v.organisationType == OrgType.pharmacy;
    // Map visit_format → (type, subType) for the detail dialog
    final String type;
    final String subType;
    switch (v.visitFormat) {
      case 'circle':
        type = 'pharmacy';
        subType = 'circle';
      case 'double':
        type = 'lpu';
        subType = 'double';
      case 'group':
      case 'group_double':
        type = 'lpu';
        subType = 'group';
      case 'stock':
        type = 'pharmacy';
        subType = 'stock';
      default:
        type = isPharmacy ? 'pharmacy' : 'lpu';
        subType = isPharmacy ? 'order' : 'lpu';
    }
    return HistoryVisitRecord(
      id: '${v.id}',
      orgId: v.organisationId,
      org: v.organisationName,
      date: '$dd.$mm.$yyyy',
      dateTime: '$dd.$mm.$yyyy',
      type: type,
      subType: subType,
      doctor: v.doctorName ?? '—',
      medicalRep: v.assignedBy,
      status: v.status == VisitStatus.completed ? 'completed' : 'planned',
    );
  }

  Future<void> _openVisitDetail(PlannedVisit v) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final record = _toHistoryRecord(v);
      if (!mounted) return;
      await showVisitDetailDialog(context, visit: record);
    } catch (e, st) {
      debugPrint('Plan: openVisitDetail failed: $e\n$st');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('couldNotOpenVisit', args: {'error': '$e'}))),
      );
    }
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

    final selectedKey = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final selectedVisits = eventMap[selectedKey] ?? const <PlannedVisit>[];

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
                        12,
                        MediaQuery.of(context).padding.top + 12,
                        12,
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
                              context.l10n.t('visitPlan'),
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
                                  context.l10n.t('week'),
                                  _calendarFormat == CalendarFormat.week,
                                  () => setState(
                                    () => _calendarFormat = CalendarFormat.week,
                                  ),
                                ),
                                _modeBtn(
                                  context.l10n.t('month'),
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
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Row(
                        children: [
                          _navBtn(Icons.chevron_left_rounded, () {
                            setState(() {
                              final base = _visibleStart(_focusedDay);
                              _focusedDay =
                                  _calendarFormat == CalendarFormat.week
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
                              _focusedDay =
                                  _calendarFormat == CalendarFormat.week
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
                      availableGestures: AvailableGestures.horizontalSwipe,
                      eventLoader: (d) =>
                          eventMap[DateTime(d.year, d.month, d.day)] ??
                          const <PlannedVisit>[],
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
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF95A3BA),
                            ),
                          ),
                        ),
                        defaultBuilder: (context, day, focusedDay) {
                          final isSelected = isSameDay(day, _selectedDay);
                          return _DayCell(
                            day: day.day,
                            bg: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            fg: isSelected
                                ? Colors.white
                                : AppColors.primaryText,
                            bold: isSelected,
                          );
                        },
                        todayBuilder: (context, day, focusedDay) {
                          final isSelected = isSameDay(day, _selectedDay);
                          return _DayCell(
                            day: day.day,
                            bg: isSelected
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.08),
                            fg: isSelected ? Colors.white : AppColors.primary,
                            bold: true,
                            border: isSelected ? null : AppColors.primary,
                          );
                        },
                        outsideBuilder: (context, day, focusedDay) {
                          final isSelected = isSameDay(day, _selectedDay);
                          return _DayCell(
                            day: day.day,
                            bg: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            fg: isSelected ? Colors.white : AppColors.hintText,
                            bold: isSelected,
                          );
                        },
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return null;
                          return Positioned(
                            bottom: 2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${events.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      daysOfWeekHeight: 26,
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekendStyle: TextStyle(color: Color(0xFF95A3BA)),
                        weekdayStyle: TextStyle(color: Color(0xFF95A3BA)),
                      ),
                      calendarStyle: const CalendarStyle(
                        markersAlignment: Alignment.bottomCenter,
                      ),
                      onDaySelected: (selected, _) {
                        setState(() => _selectedDay = selected);
                      },
                      onPageChanged: (focused) {
                        if (!mounted) return;
                        // Swipe = same effect as the ← / → buttons:
                        // update _focusedDay so the header title and the
                        // calendar page stay in sync.
                        setState(() => _focusedDay = focused);
                      },
                    ),
                  ],
                ),
              ),

              // ── List ───────────────────────────────────────────────────────
              Expanded(
                child: selectedVisits.isEmpty
                    ? SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          18,
                          12,
                          LimaNavBarLayout.scrollBottomPadding(context) + 64,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
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
                            const SizedBox(height: 24),
                            EmptyState(
                              icon: Icons.calendar_month_rounded,
                              title: context.l10n.t('noVisitsForDate'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          18,
                          12,
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
                          return _PlanVisitCard(
                            visit: v,
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
                label: Text(context.l10n.t('createVisit')),
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
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    if (selected == today) return context.l10n.t('visitsForToday');
    final dateStr = DateFormat('d MMMM', _localeTag).format(_selectedDay);
    return context.l10n.t('visitsFor', args: {'date': dateStr});
  }

  String _calendarTitle() {
    final ref = _focusedDay;
    if (_calendarFormat == CalendarFormat.week) {
      final start = ref.subtract(Duration(days: ref.weekday - 1));
      final end = start.add(const Duration(days: 6));
      final fmt = DateFormat('d MMM', _localeTag);
      return '${fmt.format(start).replaceAll('.', '')} — '
          '${fmt.format(end).replaceAll('.', '')}';
    }
    final month = DateFormat.MMMM(
      _localeTag,
    ).format(DateTime(ref.year, ref.month, 1));
    return '${_ucFirst(month)} ${ref.year}';
  }
}

// ─── Plan visit card — matches prod web layout ─────────────────────────────
//
// Layout (top-to-bottom inside the left column):
//   • Org name (bold, primary text)
//   • Doctor names CSV (primary blue, link-like)
//   • Executor / assigned-by (gray)
//   • Address: "г. {city}, {district}" (light gray)
// Right side: status pill ("Запланировано" / "Проведено") + chevron arrow.

class _PlanVisitCard extends StatelessWidget {
  final PlannedVisit visit;
  final VoidCallback onTap;

  const _PlanVisitCard({required this.visit, required this.onTap});

  String _formatAddress(BuildContext context) {
    final c = (visit.city ?? '').trim();
    final d = (visit.district ?? '').trim();
    if (c.isEmpty && d.isEmpty) return '';
    if (c.isEmpty) return d;
    final cs = context.l10n.t('cityShort');
    if (d.isEmpty) return '$cs $c';
    return '$cs $c, $d';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = visit.status == VisitStatus.completed;
    final statusText = isCompleted ? context.l10n.t('conducted') : context.l10n.t('planned');
    // Cream/orange palette for "Запланировано", green-ish for "Проведено".
    final statusBg = isCompleted
        ? const Color(0xFFE6F7EE)
        : const Color(0xFFFCEFD9);
    final statusFg = isCompleted
        ? const Color(0xFF1F8A4C)
        : const Color(0xFFB46A1B);
    final doctorCsv = (visit.doctorName ?? '').trim();
    final address = _formatAddress(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.organisationName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctorCsv.isEmpty ? context.l10n.t('doctorNotAssigned') : doctorCsv,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontStyle: doctorCsv.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: doctorCsv.isEmpty
                            ? AppColors.hintText
                            : AppColors.primary,
                      ),
                    ),
                    if (visit.assignedBy.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        visit.assignedBy,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.hintText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: AppColors.hintText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Create Visit Sheet ───────────────────────────────────────────────────────

class _CreateVisitSheet extends ConsumerStatefulWidget {
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
  ConsumerState<_CreateVisitSheet> createState() => _CreateVisitSheetState();
}

class _CreateVisitSheetState extends ConsumerState<_CreateVisitSheet> {
  bool _isLpu = true;
  bool _submitting = false;
  List<Map<String, dynamic>> _lpuOrgs = [];
  List<Map<String, dynamic>> _pharmacyOrgs = [];

  // Visit format picker options.
  // Defaults — used until [_loadFormats] populates from the local visit_formats
  // cache (which itself is refreshed from /api/visits/formats on splash).
  // Format id=4 («Групповая презентация и двойной визит») is filtered out of
  // the picker because product wants users to pick group/double separately.
  List<_PickerOption<String>> _lpuFormats = const [];
  List<_PickerOption<String>> _pharmacyFormats = const [];

  Map<String, dynamic>? _selectedOrg;
  final Set<int> _selectedDoctorIds = <int>{};
  String? _selectedForm;
  List<Map<String, dynamic>> _doctors = [];

  final _commentCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lpuFormats.isEmpty) {
      _lpuFormats = [
        _PickerOption(value: 'group', label: context.l10n.t('groupPresentation')),
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
      final rows = await widget.db.getVisitFormats();
      if (!mounted || rows.isEmpty) return;

      final lpuOpts = <_PickerOption<String>>[];
      final pharmOpts = <_PickerOption<String>>[];
      for (final r in rows) {
        final id = (r['id'] as num?)?.toInt();
        final name = (r['name'] as String?)?.trim() ?? '';
        if (id == null || name.isEmpty) continue;
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
    } catch (_) {}
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
                        context.l10n.t('doneCount', args: {'count': '${draft.length}'}),
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
    final chips = _doctors
        .where((d) => _selectedDoctorIds.contains(d['id'] as int?))
        .map((d) {
          final id = d['id'] as int;
          final name = (d['full_name'] ?? '').toString();
          return _DoctorChip(
            label: name,
            onRemove: () => setState(() => _selectedDoctorIds.remove(id)),
          );
        })
        .toList();

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
    final orgId = org['id'] as int?;
    final visitFormatId = _resolveVisitFormatId();
    if (orgId == null || visitFormatId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _submitting = true);

    final selectedDoctors = _doctors
        .where((d) => _selectedDoctorIds.contains(d['id'] as int?))
        .toList();
    final doctorIds = _isLpu
        ? selectedDoctors
              .map((d) => d['id'] as int?)
              .whereType<int>()
              .toList(growable: false)
        : const <int>[];
    final doctorNamesCsv = selectedDoctors
        .map((d) => (d['full_name'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
    final visitDate = DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
      10,
      0,
    );
    final userName = ref.read(authProvider).user?.fullName ?? context.l10n.t('you');
    final comment = _commentCtrl.text.trim();

    final localRow = <String, dynamic>{
      'org_id': orgId,
      'org_name': (org['name'] ?? '').toString(),
      'org_type': _isLpu ? 'lpu' : 'pharmacy',
      'doctor_id': doctorIds.length == 1 ? doctorIds.first : null,
      'doctor_name': doctorNamesCsv.isEmpty ? null : doctorNamesCsv,
      'assigned_by': userName,
      'city': (org['city'] ?? '').toString(),
      'district': (org['district'] ?? '').toString(),
      'visit_date': visitDate.toIso8601String(),
      'status': 'planned',
      'comment': comment,
      'visit_format': _selectedForm,
    };

    int localPlanId;
    try {
      localPlanId = await widget.db.insertLocalPlannedVisit(localRow);
      await widget.db.enqueuePendingPlan(
        localPlanId: localPlanId,
        orgId: orgId,
        orgType: _isLpu ? 'lpu' : 'pharmacy',
        doctorIds: doctorIds,
        visitFormatId: visitFormatId,
        visitDate: visitDate,
        comment: comment,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('couldNotSavePlan', args: {'error': '$e'}))),
      );
      return;
    }

    // Surface the new row in the in-memory list immediately so the user
    // sees their plan card without waiting for the API round-trip.
    widget.onSubmit(
      PlannedVisit(
        id: localPlanId,
        organisationName: (org['name'] ?? '').toString(),
        organisationId: orgId,
        organisationType: _isLpu ? OrgType.lpu : OrgType.pharmacy,
        doctorName: doctorNamesCsv.isEmpty ? null : doctorNamesCsv,
        assignedBy: userName,
        city: (org['city'] ?? '').toString(),
        district: (org['district'] ?? '').toString(),
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
                _tabBtn(context.l10n.t('pharmacyOne'), !_isLpu, () => _switchTab(false)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Organization dropdown
          _selectField(
            hint: _isLpu ? context.l10n.t('orgNameHint') : context.l10n.t('pharmacyNameHint'),
            value: _selectedOrg?['name']?.toString(),
            onTap: _allOrgs.isEmpty
                ? null
                : () async {
                    final picked = await _openPicker<int>(
                      title: _isLpu ? context.l10n.t('selectLpu') : context.l10n.t('selectPharmacyTitle'),
                      selected: selectedOrgId,
                      searchable: true,
                      options: _allOrgs
                          .map(
                            (org) => _PickerOption<int>(
                              value: org['id'] as int,
                              label: (org['name'] ?? '').toString(),
                            ),
                          )
                          .toList(),
                    );
                    if (!mounted || picked == null) return;
                    final org = _allOrgs
                        .where((o) => o['id'] == picked)
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
                        (d) => _PickerOption<int>(
                          value: d['id'] as int,
                          label: (d['full_name'] ?? '').toString(),
                        ),
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
            hint: _isLpu ? context.l10n.t('visitFormatHint') : context.l10n.t('visitTypeHint'),
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
                title: _isLpu ? context.l10n.t('visitFormatTitle') : context.l10n.t('visitType'),
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

class _DayCell extends StatelessWidget {
  final int day;
  final Color bg;
  final Color fg;
  final bool bold;
  final Color? border;

  const _DayCell({
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
