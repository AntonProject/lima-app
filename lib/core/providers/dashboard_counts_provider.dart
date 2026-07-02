
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/db/local_database.dart';

class DashboardCounts {
  final int visitsTodayCount;
  final int lpuTodayCount;
  final int pharmacyTodayCount;
  final int visitsTotalCount;
  final int uniqueVisitedDoctorsCount;

  /// False when the local visits read itself failed (e.g. DB error), so the
  /// counts below are a fallback zero rather than a genuinely empty day —
  /// the UI should show that distinction instead of a plain "0".
  final bool isReliable;

  const DashboardCounts({
    required this.visitsTodayCount,
    required this.lpuTodayCount,
    required this.pharmacyTodayCount,
    required this.visitsTotalCount,
    required this.uniqueVisitedDoctorsCount,
    this.isReliable = true,
  });
}

final dashboardCountsProvider = FutureProvider.autoDispose<DashboardCounts>((ref) async {
  final db = ref.watch(localDatabaseProvider);
  int cachedToday = 0;
  int cachedLpu = 0;
  int cachedPharmacy = 0;
  int localToday = 0;
  int localLpu = 0;
  int localPharmacy = 0;
  int totalVisits = 0;
  int uniqueDoctors = 0;

  try {
    final stats = await db.getCachedStat('daily_stats');
    if (stats != null) {
      final lpu = (stats['lpu'] as num?)?.toInt() ??
          (stats['total_lpu_visits'] as num?)?.toInt() ??
          0;
      final pharmacy = (stats['pharmacy'] as num?)?.toInt() ??
          (stats['pharmacy_visits_with_orders'] as num?)?.toInt() ??
          0;
      final total = stats['total'] ?? stats['count'] ?? stats['visits_count'];
      if (total is num && lpu == 0 && pharmacy == 0) {
        cachedToday = total.toInt();
      } else {
        cachedLpu = lpu;
        cachedPharmacy = pharmacy;
        cachedToday = lpu + pharmacy;
      }
    }
  } catch (_) {}

  final localRows = <Map<String, dynamic>>[];
  var isReliable = true;
  try {
    final rows = await db.getVisits();
    localRows.addAll(rows.map((e) => Map<String, dynamic>.from(e)));
    totalVisits = rows.length;
    final now = DateTime.now();
    final todayRows = rows.where((row) {
      final dt = DateTime.tryParse('${row['created_at'] ?? ''}');
      if (dt == null) return false;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();

    localToday = todayRows.length;
    localLpu = todayRows.where((row) {
      final type = '${row['visit_type'] ?? ''}'.toLowerCase();
      return type == 'lpu' || type == 'circle';
    }).length;
    localPharmacy = todayRows.where((row) {
      final type = '${row['visit_type'] ?? ''}'.toLowerCase();
      return type != 'lpu' && type != 'circle' && type.isNotEmpty;
    }).length;

    final doctorIds = rows
        .map((row) => (row['doctor_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    uniqueDoctors = doctorIds.length;
  } catch (_) {
    // The local visits read itself failed — the zero counts below aren't a
    // genuinely empty day, they're a fallback. Surfaced via [isReliable] so
    // the UI can show "—" instead of a misleading "0".
    isReliable = false;
  }

  // Count unique doctors from local rows only
  try {
    final doctorKeys = <String>{};
    for (final row in localRows.take(500)) {
      final doctorId = (row['doctor_id'] as num?)?.toInt();
      if (doctorId != null) {
        doctorKeys.add('id:$doctorId');
        continue;
      }
      final doctorName = _safeString(row['doctor_name']);
      if (doctorName.isNotEmpty) {
        doctorKeys.add('name:${doctorName.toLowerCase()}');
      }
    }
    if (doctorKeys.isNotEmpty) uniqueDoctors = doctorKeys.length;
  } catch (_) {}

  final useLocal = localToday >= cachedToday;
  return DashboardCounts(
    visitsTodayCount: useLocal ? localToday : cachedToday,
    lpuTodayCount: useLocal ? localLpu : cachedLpu,
    pharmacyTodayCount: useLocal ? localPharmacy : cachedPharmacy,
    visitsTotalCount: totalVisits,
    uniqueVisitedDoctorsCount: uniqueDoctors,
    isReliable: isReliable,
  );
});

String _safeString(Object? v, {String fallback = ''}) {
  if (v == null) return fallback;
  final s = '$v'.trim();
  return s.isEmpty ? fallback : s;
}

