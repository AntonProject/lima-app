import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/shell/nav_bar_layout.dart';

class FavPharmaciesScreen extends ConsumerStatefulWidget {
  const FavPharmaciesScreen({super.key});

  @override
  ConsumerState<FavPharmaciesScreen> createState() =>
      _FavPharmaciesScreenState();
}

class _FavPharmaciesScreenState extends ConsumerState<FavPharmaciesScreen> {
  String _query = '';
  bool _loading = true;
  List<Map<String, dynamic>> _pharmacies = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final db = ref.read(localDatabaseProvider);
    final pharmacies = await db.getFavoriteOrgs(type: 'pharmacy');
    if (!mounted) return;
    setState(() {
      _pharmacies = pharmacies;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _pharmacies.where((pharmacy) {
      final query = _query.toLowerCase();
      if (query.isEmpty) return true;
      final name = (pharmacy['name'] as String? ?? '').toLowerCase();
      final address = (pharmacy['address'] as String? ?? '').toLowerCase();
      return name.contains(query) || address.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(color: AppColors.secondaryBg),
            child: Column(
              children: [
                AppCenteredHeader(
                  title: 'Избранные аптеки',
                  onBack: () => context.pop(),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextFormField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Поиск аптек...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.hintText,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_pharmacy_outlined,
                          size: 56,
                          color: AppColors.hintText,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Нет избранных аптек',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Добавьте аптеку из карточки визита',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppColors.hintText,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      LimaNavBarLayout.scrollBottomPadding(context),
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final pharmacy = filtered[index];
                      final pharmacyId = pharmacy['id'] as int;
                      final name = (pharmacy['name'] as String?) ?? '';
                      final address = (pharmacy['address'] as String?) ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppTapScale(
                          onTap: () => context.push(
                            Uri(
                              path: '/visits/pharmacy/detail/$pharmacyId',
                              queryParameters: {'name': name},
                            ).toString(),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDE3EB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                12,
                                12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryBg,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: shadowSm,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.iconBgGreen,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.local_pharmacy_rounded,
                                      color: AppColors.success,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryText,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          address,
                                          style: GoogleFonts.manrope(
                                            fontSize: 13,
                                            color: AppColors.secondaryText,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      await ref
                                          .read(appCollectionsProvider.notifier)
                                          .toggleFavoritePharmacy(pharmacyId);
                                      _load();
                                    },
                                    child: const Icon(
                                      Icons.bookmark_rounded,
                                      color: AppColors.primary,
                                      size: 21,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.hintText,
                                    size: 21,
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
