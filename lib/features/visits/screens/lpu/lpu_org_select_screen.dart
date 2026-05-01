import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/db/local_database.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class LpuOrgSelectScreen extends ConsumerStatefulWidget {
  const LpuOrgSelectScreen({super.key});

  @override
  ConsumerState<LpuOrgSelectScreen> createState() => _LpuOrgSelectScreenState();
}

class _LpuOrgSelectScreenState extends ConsumerState<LpuOrgSelectScreen> {
  String _query = '';
  List<Organisation> _orgs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrgs());
  }

  Future<void> _loadOrgs() async {
    final db = ref.read(localDatabaseProvider);
    final rows = await db.getOrganisations(
      type: 'lpu',
      query: _query.isEmpty ? null : _query,
    );
    if (!mounted) return;
    setState(() {
      _orgs = rows.map(Organisation.fromJson).toList();
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
                12, MediaQuery.of(context).padding.top + 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppTapScale(
                      pressedScale: 0.9,
                      onTap: () => context.canPop() ? context.pop() : context.go('/visits'),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.primaryText, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Выбор ЛПУ',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Поиск по названию...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    setState(() => _query = v);
                    _loadOrgs();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _orgs.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Ничего не найдено',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: _orgs.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final org = _orgs[i];
                      return AppTapScale(
                        pressedScale: 0.95,
                        onTap: () => context.push(
                          Uri(
                            path: '/visits/lpu/org/doctors/${org.id}',
                            queryParameters: {'name': org.name},
                          ).toString(),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.secondaryBg,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: shadowSm,
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.iconBgBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.home_work_rounded,
                                    color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      org.name,
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                    if (org.address.isNotEmpty ||
                                        org.city != null)
                                      Text(
                                        '${org.address}${org.city != null ? ', ${org.city}' : ''}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: AppColors.secondaryText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.hintText, size: 18),
                            ],
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
