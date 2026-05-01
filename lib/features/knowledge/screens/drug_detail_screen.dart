import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import 'package:lima/core/db/local_database.dart';

class DrugDetailScreen extends ConsumerStatefulWidget {
  final int drugId;

  const DrugDetailScreen({super.key, required this.drugId});

  @override
  ConsumerState<DrugDetailScreen> createState() => _DrugDetailScreenState();
}

class _DrugDetailScreenState extends ConsumerState<DrugDetailScreen> {
  Map<String, dynamic>? _drug;
  List<Map<String, dynamic>> _materials = [];
  bool _loading = true;
  int _tab = 0; // 0 docs, 1 info

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final db = ref.read(localDatabaseProvider);
    final drugs = await db.getDrugs();
    final drug = drugs.where((d) => d['id'] == widget.drugId).firstOrNull;
    final materials = await db.getDrugMaterials(widget.drugId);
    if (!mounted) return;
    setState(() {
      _drug = drug;
      _materials = materials;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_drug == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Препарат')),
        body: const EmptyState(
          icon: Icons.medication_rounded,
          title: 'Препарат не найден',
        ),
      );
    }

    final name = (_drug!['name'] as String?) ?? '';
    final manufacturer = ((_drug!['manufacturer'] as String?) ?? '').trim().isEmpty
        ? '—'
        : ((_drug!['manufacturer'] as String?) ?? '').trim();

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
              16,
              MediaQuery.of(context).padding.top + 8,
              16,
              12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTapScale(
                  onTap: () => context.pop(),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.arrow_back_rounded, color: AppColors.primaryText),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        manufacturer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _TopTab(
                    active: _tab == 0,
                    title: 'Документы',
                    badge: _materials.length,
                    onTap: () => setState(() => _tab = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TopTab(
                    active: _tab == 1,
                    title: 'Информация',
                    onTap: () => setState(() => _tab = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _tab == 0
                ? _DocumentsTab(drugId: widget.drugId, materials: _materials)
                : _InfoTab(name: name, manufacturer: manufacturer),
          ),
        ],
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  final bool active;
  final String title;
  final int? badge;
  final VoidCallback onTap;

  const _TopTab({
    required this.active,
    required this.title,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapScale(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: active ? AppColors.secondaryBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.divider : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.primary : AppColors.secondaryText,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$badge',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  final int drugId;
  final List<Map<String, dynamic>> materials;

  const _DocumentsTab({required this.drugId, required this.materials});

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return const EmptyState(
        icon: Icons.description_outlined,
        title: 'Нет документов',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: materials.length,
      itemBuilder: (_, i) {
        final m = materials[i];
        final title = (m['title'] as String?) ?? 'Документ';
        final uploaded = (m['uploaded_at'] as String?) ?? '';
        final dateLabel = uploaded.length >= 10
            ? '${uploaded.substring(8, 10)}.${uploaded.substring(5, 7)}.${uploaded.substring(0, 4)}'
            : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppTapScale(
            onTap: () => context.push(
              Uri(
                path: '/knowledge/drug/$drugId/materials',
                queryParameters: {'index': '$i'},
              ).toString(),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: shadowSm,
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEAEA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'PDF',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  color: AppColors.secondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (dateLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                dateLabel,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD28533),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '!',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.hintText),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoTab extends StatelessWidget {
  final String name;
  final String manufacturer;

  const _InfoTab({required this.name, required this.manufacturer});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: shadowSm,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'НАЗВАНИЕ ПРЕПАРАТА',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: shadowSm,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ПРОИЗВОДИТЕЛЬ',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                manufacturer,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
