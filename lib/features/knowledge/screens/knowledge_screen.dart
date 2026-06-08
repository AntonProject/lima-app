import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import 'package:lima/core/services/app_actions.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/shell/nav_bar_layout.dart';

class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen> {
  String _query = '';
  List<Map<String, dynamic>> _drugs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = ref.read(localDatabaseProvider);

    // Show local data immediately
    final localResults = await db.getDrugs(
      query: _query.isEmpty ? null : _query,
      onlyWithPositivePrice: false,
      onlyWithDocuments: true,
    );
    if (mounted) {
      setState(() {
        _drugs = localResults;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              boxShadow: shadowSm,
            ),
            padding: EdgeInsets.fromLTRB(
              AppUi.screenHorizontal,
              MediaQuery.of(context).padding.top + 12,
              AppUi.screenHorizontal,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'База знаний',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  onChanged: (v) {
                    setState(() => _query = v);
                    _load();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Поиск препаратов...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.hintText,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Drug list ────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _drugs.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Ничего не найдено',
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      AppUi.screenHorizontal,
                      12,
                      AppUi.screenHorizontal,
                      LimaNavBarLayout.scrollBottomPadding(context),
                    ),
                    itemCount: _drugs.length,
                    itemBuilder: (_, i) {
                      final drug = _drugs[i];
                      final drugId = drug['id'] as int;
                      final drugName = drug['name'] as String;
                      final documentsCount =
                          drug['documents_count'] as int? ?? 0;
                      final manufacturer =
                          ((drug['manufacturer'] as String?) ?? '').trim();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppTapScale(
                          onTap: () =>
                              context.push('/knowledge/drug/$drugId/materials'),
                          pressedScale: 0.95,
                          child: GestureDetector(
                            onLongPress: () =>
                                copyToClipboard(context, drugName),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.secondaryBg,
                                borderRadius: BorderRadius.circular(
                                  AppUi.cardRadius,
                                ),
                                boxShadow: shadowSm,
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.iconBgBlue,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.medication_rounded,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          drugName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            height: 1.2,
                                            color: AppColors.primaryText,
                                          ),
                                        ),
                                        if (manufacturer.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            manufacturer,
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: AppColors.secondaryText,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.description_outlined,
                                              size: 12,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$documentsCount документов',
                                              style: GoogleFonts.manrope(
                                                color: AppColors.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
