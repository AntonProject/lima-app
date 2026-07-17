import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

class PlanCalendarViewState {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat calendarFormat;

  const PlanCalendarViewState({
    required this.focusedDay,
    required this.selectedDay,
    this.calendarFormat = CalendarFormat.week,
  });

  factory PlanCalendarViewState.initial() {
    final today = DateTime.now();
    return PlanCalendarViewState(focusedDay: today, selectedDay: today);
  }

  PlanCalendarViewState copyWith({
    DateTime? focusedDay,
    DateTime? selectedDay,
    CalendarFormat? calendarFormat,
  }) {
    return PlanCalendarViewState(
      focusedDay: focusedDay ?? this.focusedDay,
      selectedDay: selectedDay ?? this.selectedDay,
      calendarFormat: calendarFormat ?? this.calendarFormat,
    );
  }
}

class PlanCalendarViewModel extends StateNotifier<PlanCalendarViewState> {
  PlanCalendarViewModel() : super(PlanCalendarViewState.initial());

  void setFormat(CalendarFormat format) {
    state = state.copyWith(calendarFormat: format);
  }

  void selectDay(DateTime day) {
    state = state.copyWith(selectedDay: day);
  }

  void pageChanged(DateTime focusedDay) {
    state = state.copyWith(focusedDay: focusedDay);
  }

  void previous() {
    final start = _visibleStart(state.focusedDay);
    final focusedDay = state.calendarFormat == CalendarFormat.week
        ? start.subtract(const Duration(days: 7))
        : DateTime(start.year, start.month - 1, 1);
    state = state.copyWith(focusedDay: focusedDay);
  }

  void next() {
    final start = _visibleStart(state.focusedDay);
    final focusedDay = state.calendarFormat == CalendarFormat.week
        ? start.add(const Duration(days: 7))
        : DateTime(start.year, start.month + 1, 1);
    state = state.copyWith(focusedDay: focusedDay);
  }

  DateTime _visibleStart(DateTime focusedDay) {
    return state.calendarFormat == CalendarFormat.week
        ? focusedDay.subtract(Duration(days: focusedDay.weekday - 1))
        : DateTime(focusedDay.year, focusedDay.month, 1);
  }
}
