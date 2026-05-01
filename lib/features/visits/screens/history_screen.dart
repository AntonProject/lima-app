import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/dialogs/visit_detail_dialog.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/visits/models/history_records.dart';
import 'package:lima/shell/nav_bar_layout.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const int _pageSize = 10;
  int _filterIndex = 0;
  int _pageIndex = 0;
  String _query = '';
  bool _todayOnly = false;
  bool _routeParamsApplied = false;
  bool _didAutoOpen = false;
  int? _orgIdFilter;
  String? _visitIdToOpen;
  bool _autoOpenFirst = false;
  List<HistoryVisitRecord> _records = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVisits());
  }

  Future<void> _loadVisits() async {
    final db = ref.read(localDatabaseProvider);
    final rows = (await db.getVisits())
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final localRecords = rows.map(HistoryVisitRecord.fromVisitMap).toList();

    final merged = <String, HistoryVisitRecord>{};
    void mergeRecord(HistoryVisitRecord r) {
      final key = r.id != '—' && r.id.trim().isNotEmpty
          ? '${r.id}_${r.type}_${r.subType}'
          : '${r.type}_${r.orgId}_${r.dateTime}';
      final prev = merged[key];
      if (prev == null) {
        merged[key] = r;
        return;
      }
      int score(HistoryVisitRecord v) {
        var s = 0;
        if (v.status == 'completed') s += 6;
        if (v.dateTime != '—') s += 4;
        if (v.doctor != '—') s += 3;
        if (v.presentations.isNotEmpty) s += 5;
        if (v.stockItems.isNotEmpty) s += 5;
        if (v.orderTotal > 0) s += 6;
        if (v.serialNumber.isNotEmpty) s += 2;
        if (v.type == 'stock' || v.type == 'pharmacy') s += 1;
        return s;
      }

      final prevScore = score(prev);
      final nextScore = score(r);
      if (nextScore >= prevScore) {
        merged[key] = r;
      }
    }

    for (final r in localRecords) {
      mergeRecord(r);
    }

    if (!mounted) return;
    setState(() {
      final values = merged.values.toList();
      DateTime parse(HistoryVisitRecord r) {
        final raw = r.dateTime.trim();
        final m = RegExp(
          r'^(\d{2})\.(\d{2})\.(\d{4}),\s*(\d{2}):(\d{2})$',
        ).firstMatch(raw);
        if (m == null) return DateTime.fromMillisecondsSinceEpoch(0);
        final day = int.tryParse(m.group(1) ?? '') ?? 1;
        final month = int.tryParse(m.group(2) ?? '') ?? 1;
        final year = int.tryParse(m.group(3) ?? '') ?? 1970;
        final hour = int.tryParse(m.group(4) ?? '') ?? 0;
        final min = int.tryParse(m.group(5) ?? '') ?? 0;
        return DateTime(year, month, day, hour, min);
      }

      values.sort((a, b) => parse(b).compareTo(parse(a)));
      _records = values;
    });
    _tryAutoOpenVisit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeParamsApplied) return;
    final params = GoRouterState.of(context).uri.queryParameters;
    final range = params['range'];
    final type = params['type'];
    if (range == 'today') {
      _todayOnly = true;
    }
    if (type == 'lpu') _filterIndex = 1;
    if (type == 'pharmacy') _filterIndex = 2;
    if (type == 'stock') _filterIndex = 3;
    final orgId = params['orgId'];
    if (orgId != null) _orgIdFilter = int.tryParse(orgId);
    _visitIdToOpen = params['visitId'];
    _autoOpenFirst =
        params['openFirst'] == '1' || params['openFirst'] == 'true';
    if (_orgIdFilter != null && !_autoOpenFirst) {
      // By default, when opening history from a specific organisation
      // we show details immediately for the latest record.
      _autoOpenFirst = true;
    }
    _routeParamsApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoOpenVisit());
  }

  bool _isTodayRecord(HistoryVisitRecord visit) {
    try {
      final parts = visit.date.split('.');
      if (parts.length != 3) return false;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final parsed = DateTime(year, month, day);
      final now = DateTime.now();
      return parsed.year == now.year &&
          parsed.month == now.month &&
          parsed.day == now.day;
    } catch (_) {
      return false;
    }
  }

  List<HistoryVisitRecord> get _filtered {
    var list = _records.where((visit) {
      if (_orgIdFilter != null && visit.orgId != _orgIdFilter) return false;
      if (_filterIndex == 1) return visit.type == 'lpu';
      if (_filterIndex == 2) return visit.type == 'pharmacy';
      if (_filterIndex == 3) return visit.type == 'stock';
      return true;
    });

    if (_todayOnly) {
      list = list.where(_isTodayRecord);
    }

    if (_query.isNotEmpty) {
      list = list.where(
        (visit) =>
            visit.org.toLowerCase().contains(_query.toLowerCase()) ||
            visit.id.contains(_query),
      );
    }

    return list.toList();
  }

  int _totalPages(int total) {
    if (total <= 0) return 1;
    return (total / _pageSize).ceil();
  }

  List<HistoryVisitRecord> _pageItems(
    List<HistoryVisitRecord> source,
    int pageIndex,
  ) {
    if (source.isEmpty) return const <HistoryVisitRecord>[];
    final start = pageIndex * _pageSize;
    if (start >= source.length) return const <HistoryVisitRecord>[];
    final end = math.min(start + _pageSize, source.length);
    return source.sublist(start, end);
  }

  void _tryAutoOpenVisit() {
    if (!mounted || _didAutoOpen || _records.isEmpty) return;
    final list = _filtered;
    if (list.isEmpty) return;

    HistoryVisitRecord? target;
    if (_visitIdToOpen != null && _visitIdToOpen!.trim().isNotEmpty) {
      final raw = _visitIdToOpen!.trim();
      for (final v in list) {
        if (v.id == raw) {
          target = v;
          break;
        }
      }
    }
    if (target == null && _autoOpenFirst) {
      target = list.first;
    }
    if (target == null) return;

    _didAutoOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showVisitDetailDialog(context, visit: target!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalPages = _totalPages(filtered.length);
    final effectivePage = _pageIndex.clamp(0, totalPages - 1);
    final paged = _pageItems(filtered, effectivePage);
    final filters = [
      context.l10n.t('all'),
      context.l10n.t('lpu'),
      context.l10n.t('pharmacies'),
      context.l10n.t('stockRests'),
    ];

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              boxShadow: shadowSm,
            ),
            padding: EdgeInsets.fromLTRB(
              12,
              MediaQuery.of(context).padding.top + 8,
              12,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppTapScale(
                      onTap: () => context.pop(),
                      pressedScale: 0.9,
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.primaryText,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.t('visitHistoryTitle'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_todayOnly) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.iconBgBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.today_rounded,
                          color: AppColors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.t('filterToday'),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final active = _filterIndex == i;
                      return AppTapScale(
                        onTap: () => setState(() {
                          _filterIndex = i;
                          _pageIndex = 0;
                        }),
                        pressedScale: 0.93,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary
                                : AppColors.primaryBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            filters[i],
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: active
                                  ? Colors.white
                                  : AppColors.secondaryText,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  onChanged: (value) => setState(() {
                    _query = value;
                    _pageIndex = 0;
                  }),
                  decoration: InputDecoration(
                    hintText: context.l10n.t('searchByNameOrId'),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.hintText,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 56,
                          color: AppColors.hintText,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.t('noResults'),
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            12,
                            12,
                            LimaNavBarLayout.scrollBottomPadding(context) + 40,
                          ),
                          itemCount: paged.length + (totalPages > 1 ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (totalPages > 1 && i == paged.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Column(
                                  children: [
                                    Text(
                                      '${filtered.length} записей',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: AppColors.hintText,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _pageBtn(
                                          icon: Icons.chevron_left_rounded,
                                          enabled: effectivePage > 0,
                                          onTap: () => setState(
                                            () =>
                                                _pageIndex = effectivePage - 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${effectivePage + 1}/$totalPages',
                                          style: GoogleFonts.manrope(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.secondaryText,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        _pageBtn(
                                          icon: Icons.chevron_right_rounded,
                                          enabled:
                                              effectivePage < totalPages - 1,
                                          onTap: () => setState(
                                            () =>
                                                _pageIndex = effectivePage + 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }
                            final visit = paged[i];
                            return _VisitItem(
                              visit: visit,
                              onTap: () =>
                                  showVisitDetailDialog(context, visit: visit),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _pageBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return AppTapScale(
      onTap: enabled ? onTap : null,
      pressedScale: 0.9,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : AppColors.primaryBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.secondaryText : AppColors.hintText,
          size: 20,
        ),
      ),
    );
  }
}

class _VisitItem extends StatelessWidget {
  final HistoryVisitRecord visit;
  final VoidCallback onTap;

  const _VisitItem({required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isStock = visit.type == 'stock';
    final isCircle = visit.subType == 'circle';
    final isPharmacy = visit.type == 'pharmacy';
    final isLpu = visit.type == 'lpu';
    final isGroupPresentation = isLpu && visit.subType == 'group';
    final labelText = isCircle
        ? 'Фармкружок'
        : isStock
        ? 'Снятие остатков'
        : isPharmacy
        ? 'Бронь'
        : isGroupPresentation
        ? 'Групповая презентация'
        : 'Презентация';
    final labelBg = isCircle
        ? const Color(0xFFDDF5E6)
        : isStock
        ? const Color(0xFFFFF3DB)
        : isPharmacy
        ? const Color(0xFFDDF5E6)
        : isGroupPresentation
        ? const Color(0xFFEFE9FF)
        : const Color(0xFFEAF0FF);
    final labelFg = isCircle
        ? const Color(0xFF34A36A)
        : isStock
        ? const Color(0xFFE3A335)
        : isPharmacy
        ? const Color(0xFF34A36A)
        : isGroupPresentation
        ? const Color(0xFF7A63E8)
        : const Color(0xFF5B84F4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppTapScale(
        onTap: onTap,
        pressedScale: 0.95,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBg,
            borderRadius: BorderRadius.circular(AppUi.cardRadius),
            boxShadow: shadowSm,
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCircle
                      ? const Color(0xFFE6F7EE)
                      : isStock
                      ? const Color(0xFFFEF5E6)
                      : isPharmacy
                      ? AppColors.iconBgGreen
                      : AppColors.iconBgBlue,
                  borderRadius: BorderRadius.circular(10),
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
                  size: 20,
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
                            visit.org,
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
                            '#${visit.id}',
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
                    if (isCircle) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: labelBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          labelText,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: labelFg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: labelBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          labelText,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: labelFg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      isLpu && visit.doctor != '—'
                          ? '${visit.date}  •  ${visit.doctor}'
                          : visit.date,
                      maxLines: isLpu ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.hintText,
                      ),
                    ),
                    if (isCircle && visit.pharmacistsFio != '—') ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.groups_2_rounded,
                            size: 14,
                            color: Color(0xFF6AAE87),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: GoogleFonts.manrope(fontSize: 12),
                                children: [
                                  TextSpan(
                                    text: visit.pharmacistsFio,
                                    style: const TextStyle(
                                      color: Color(0xFF6AAE87),
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' (${visit.participantsCount} чел.)',
                                    style: const TextStyle(
                                      color: Color(0xFF8390A3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.hintText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
