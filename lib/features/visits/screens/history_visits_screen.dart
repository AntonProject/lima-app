import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/dialogs/visit_detail_dialog.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/visits/models/history_records.dart';

class HistoryVisitsScreen extends ConsumerStatefulWidget {
  const HistoryVisitsScreen({super.key});

  @override
  ConsumerState<HistoryVisitsScreen> createState() =>
      _HistoryVisitsScreenState();
}

class _HistoryVisitsScreenState extends ConsumerState<HistoryVisitsScreen> {
  List<HistoryVisitRecord> _visits = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVisits());
  }

  Future<void> _loadVisits() async {
    final db = ref.read(localDatabaseProvider);
    final rows = await db.getVisits();
    if (!mounted) return;
    setState(() {
      _visits = rows
          .map(HistoryVisitRecord.fromVisitMap)
          .where((visit) => visit.type != 'stock')
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
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
              AppUi.screenHorizontal,
              MediaQuery.of(context).padding.top + 8,
              AppUi.screenHorizontal,
              12,
            ),
            child: Row(
              children: [
                AppTapScale(
                  onTap: () => context.pop(),
                  pressedScale: 0.93,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.primaryText,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'История визитов',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppUi.screenHorizontal,
                12,
                AppUi.screenHorizontal,
                24,
              ),
              itemCount: _visits.length,
              itemBuilder: (_, index) {
                final visit = _visits[index];
                final isPharmacy = visit.type == 'pharmacy';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppTapScale(
                    onTap: () => showVisitDetailDialog(context, visit: visit),
                    pressedScale: 0.95,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(AppUi.cardRadius),
                        boxShadow: shadowSm,
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isPharmacy
                                  ? AppColors.iconBgGreen
                                  : AppColors.iconBgBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isPharmacy
                                  ? Icons.local_pharmacy_rounded
                                  : Icons.medication_rounded,
                              color: isPharmacy
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
                                Text(
                                  visit.org,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  visit.date,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: AppColors.hintText,
                                  ),
                                ),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
