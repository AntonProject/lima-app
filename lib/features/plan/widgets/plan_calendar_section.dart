import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import 'plan_create_visit_sheet.dart';

/// Calendar header and calendar grid for the plan screen.
///
/// The view model owns navigation state and selected visits; this widget only
/// renders the calendar and reports user actions back to the screen.
class PlanCalendarSection extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat calendarFormat;
  final Map<DateTime, List<PlannedVisit>> eventMap;
  final String screenTitle;
  final String calendarTitle;
  final String weekLabel;
  final String monthLabel;
  final String Function(DateTime day) weekdayLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  const PlanCalendarSection({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.eventMap,
    required this.screenTitle,
    required this.calendarTitle,
    required this.weekLabel,
    required this.monthLabel,
    required this.weekdayLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onBack,
    required this.onFormatChanged,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(Icons.arrow_back_rounded),
                  ),
                ),
                Expanded(
                  child: Text(
                    screenTitle,
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
                      _ModeButton(
                        title: weekLabel,
                        active: calendarFormat == CalendarFormat.week,
                        onTap: () => onFormatChanged(CalendarFormat.week),
                      ),
                      _ModeButton(
                        title: monthLabel,
                        active: calendarFormat == CalendarFormat.month,
                        onTap: () => onFormatChanged(CalendarFormat.month),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                _CalendarButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: onPrevious,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      calendarTitle,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ),
                _CalendarButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: onNext,
                ),
              ],
            ),
          ),
          TableCalendar<PlannedVisit>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: focusedDay,
            calendarFormat: calendarFormat,
            availableGestures: AvailableGestures.horizontalSwipe,
            eventLoader: (day) =>
                eventMap[DateTime(day.year, day.month, day.day)] ??
                const <PlannedVisit>[],
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              leftChevronVisible: false,
              rightChevronVisible: false,
              titleCentered: true,
            ),
            calendarBuilders: CalendarBuilders(
              headerTitleBuilder: (context, day) => const SizedBox.shrink(),
              dowBuilder: (context, day) => Center(
                child: Text(
                  weekdayLabel(day),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF95A3BA),
                  ),
                ),
              ),
              defaultBuilder: (context, day, focusedDay) =>
                  _dayCell(day, isSelected: isSameDay(day, selectedDay)),
              todayBuilder: (context, day, focusedDay) {
                final isSelected = isSameDay(day, selectedDay);
                return PlanDayCell(
                  day: day.day,
                  bg: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.08),
                  fg: isSelected ? Colors.white : AppColors.primary,
                  bold: true,
                  border: isSelected ? null : AppColors.primary,
                );
              },
              outsideBuilder: (context, day, focusedDay) => PlanDayCell(
                day: day.day,
                bg: isSameDay(day, selectedDay)
                    ? AppColors.primary
                    : Colors.transparent,
                fg: isSameDay(day, selectedDay)
                    ? Colors.white
                    : AppColors.hintText,
                bold: isSameDay(day, selectedDay),
              ),
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
            onDaySelected: (day, _) => onDaySelected(day),
            onPageChanged: onPageChanged,
          ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day, {required bool isSelected}) {
    return PlanDayCell(
      day: day.day,
      bg: isSelected ? AppColors.primary : Colors.transparent,
      fg: isSelected ? Colors.white : AppColors.primaryText,
      bold: isSelected,
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.primary : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _CalendarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CalendarButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
}
