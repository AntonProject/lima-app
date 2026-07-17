import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../visits/dialogs/visit_detail_dialog.dart';
import '../../visits/models/history_records.dart';
import '../presentation/view_models/plan_calendar_view_model.dart';
import '../providers/plan_calendar_provider.dart';
import '../providers/planned_visits_provider.dart';
import '../widgets/plan_calendar_section.dart';
import '../widgets/plan_create_visit_sheet.dart';
import '../widgets/plan_visit_card.dart';
import '../../visits/providers/lpu_details_provider.dart';
import 'package:lima/shell/nav_bar_layout.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
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
        SnackBar(
          content: Text(l10n.t('couldNotOpenVisit', args: {'error': '$e'})),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allVisits = ref.watch(plannedVisitsProvider);
    final calendarState = ref.watch(planCalendarProvider);
    final filteredAll = allVisits;

    final eventMap = <DateTime, List<PlannedVisit>>{};
    for (final v in filteredAll) {
      final key = DateTime(v.date.year, v.date.month, v.date.day);
      eventMap.putIfAbsent(key, () => []).add(v);
    }

    final selectedKey = DateTime(
      calendarState.selectedDay.year,
      calendarState.selectedDay.month,
      calendarState.selectedDay.day,
    );
    final selectedVisits = eventMap[selectedKey] ?? const <PlannedVisit>[];

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Stack(
        children: [
          Column(
            children: [
              PlanCalendarSection(
                focusedDay: calendarState.focusedDay,
                selectedDay: calendarState.selectedDay,
                calendarFormat: calendarState.calendarFormat,
                eventMap: eventMap,
                screenTitle: context.l10n.t('visitPlan'),
                calendarTitle: _calendarTitle(calendarState),
                weekLabel: context.l10n.t('week'),
                monthLabel: context.l10n.t('month'),
                weekdayLabel: _weekdayLabel,
                onBack: () => context.go('/home'),
                onPrevious: () =>
                    ref.read(planCalendarProvider.notifier).previous(),
                onNext: () => ref.read(planCalendarProvider.notifier).next(),
                onFormatChanged: (format) =>
                    ref.read(planCalendarProvider.notifier).setFormat(format),
                onDaySelected: (selected) =>
                    ref.read(planCalendarProvider.notifier).selectDay(selected),
                onPageChanged: (focused) => ref
                    .read(planCalendarProvider.notifier)
                    .pageChanged(focused),
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
                          return PlanVisitCard(
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
            // Standardised CTA height — same as the "Найти рядом" button.
            bottom: LimaNavBarLayout.ctaBottomOffset(context),
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

  Future<void> _openCreateVisitSheet() async {
    final doctorsRepository = ref.read(doctorsDirectoryRepositoryProvider);

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PlanCreateVisitSheet(
        doctorsRepository: doctorsRepository,
        selectedDay: ref.read(planCalendarProvider).selectedDay,
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
      ref.read(planCalendarProvider).selectedDay.year,
      ref.read(planCalendarProvider).selectedDay.month,
      ref.read(planCalendarProvider).selectedDay.day,
    );
    if (selected == today) return context.l10n.t('visitsForToday');
    final dateStr = DateFormat(
      'd MMMM',
      _localeTag,
    ).format(ref.read(planCalendarProvider).selectedDay);
    return context.l10n.t('visitsFor', args: {'date': dateStr});
  }

  String _calendarTitle(PlanCalendarViewState state) {
    final focusedDay = state.focusedDay;
    if (state.calendarFormat == CalendarFormat.week) {
      final start = focusedDay.subtract(Duration(days: focusedDay.weekday - 1));
      final end = start.add(const Duration(days: 6));
      final fmt = DateFormat('d MMM', _localeTag);
      return '${fmt.format(start).replaceAll('.', '')} — '
          '${fmt.format(end).replaceAll('.', '')}';
    }
    final month = DateFormat.MMMM(
      _localeTag,
    ).format(DateTime(focusedDay.year, focusedDay.month, 1));
    return '${_ucFirst(month)} ${focusedDay.year}';
  }
}

// ─── Create Visit Sheet ───────────────────────────────────────────────────────
