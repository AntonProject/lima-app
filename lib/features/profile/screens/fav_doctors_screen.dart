import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/providers/sync_provider.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/features/profile/screens/profile_screen.dart';
import 'package:lima/shell/nav_bar_layout.dart';

class FavDoctorsScreen extends ConsumerStatefulWidget {
  const FavDoctorsScreen({super.key});

  @override
  ConsumerState<FavDoctorsScreen> createState() => _FavDoctorsScreenState();
}

class _FavDoctorsScreenState extends ConsumerState<FavDoctorsScreen> {
  String _query = '';
  bool _loading = true;
  List<Map<String, dynamic>> _allDoctors = [];
  int? _pressedDoctorId;
  DateTime? _lastSyncSeenAt;

  List<Map<String, dynamic>> get _filtered => _allDoctors.where((d) {
    final name = (d['full_name'] as String? ?? '').toLowerCase();
    final spec = (d['specialty'] as String? ?? '').toLowerCase();
    final q = _query.toLowerCase();
    return name.contains(q) || spec.contains(q);
  }).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDoctors());
  }

  Future<void> _loadDoctors() async {
    final db = ref.read(localDatabaseProvider);

    final doctors = await db.getFavoriteDoctors();
    final favList = doctors.map((e) => Map<String, dynamic>.from(e)).toList();
    final ids = favList
        .map((e) => (e['id'] as num?)?.toInt())
        .whereType<int>()
        .toList();
    final visitCounts = await db.getVisitCountsByDoctorIds(ids);
    for (final row in favList) {
      final id = (row['id'] as num?)?.toInt();
      if (id != null) {
        row['visit_count'] = visitCounts[id] ?? 0;
      }
    }
    if (!mounted) return;
    setState(() {
      _allDoctors = favList;
      _loading = false;
    });
  }

  String _visitLabel(Map<String, dynamic> doctor) {
    final count = (doctor['visit_count'] as num?)?.toInt() ?? 0;
    if (count <= 0) return 'Визитов не было';
    return '$count визитов';
  }

  Future<void> _onDoctorCardTap(Map<String, dynamic> doctor) async {
    final doctorId = (doctor['id'] as num?)?.toInt();
    if (doctorId == null) {
      await _openDoctorSheet(doctor);
      return;
    }
    if (!mounted) return;
    setState(() => _pressedDoctorId = doctorId);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    setState(() => _pressedDoctorId = null);
    await _openDoctorSheet(doctor);
  }

  Future<void> _removeFavorite(Map<String, dynamic> doctor) async {
    final doctorId = doctor['id'] as int?;
    if (doctorId == null) return;
    final db = ref.read(localDatabaseProvider);
    final api = ref.read(remoteApiServiceProvider);

    await db.updateDoctorFavorite(doctorId, false);
    if (!mounted) return;
    setState(() {
      _allDoctors = _allDoctors.where((d) => d['id'] != doctorId).toList();
    });

    try {
      await api.removeDoctorFromFavorites(doctorId);
      ref.invalidate(favoriteDoctorsCountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Удалено из избранного')));
    } catch (_) {
      if (ref.read(isOfflineProvider)) {
        pulseOfflineBanner(ref);
      }
      ref.invalidate(favoriteDoctorsCountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Удалено локально. Синхронизация с сервером не выполнена',
          ),
        ),
      );
    }
  }

  void _startVisitForDoctor(Map<String, dynamic> doctor, {String? orgName}) {
    final doctorId = doctor['id'] as int?;
    final orgId = (doctor['organisation_id'] is num)
        ? (doctor['organisation_id'] as num).toInt()
        : null;
    if (doctorId == null || orgId == null || orgId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Для врача не найдено ЛПУ')));
      return;
    }
    final doctorName = (doctor['full_name'] as String?) ?? '';
    context.push(
      Uri(
        path: '/visits/lpu/detail/$orgId/doctors/$doctorId/detailing',
        queryParameters: {
          'doctorName': doctorName,
          if (orgName != null && orgName.isNotEmpty) 'orgName': orgName,
        },
      ).toString(),
    );
  }

  Future<void> _openDoctorSheet(Map<String, dynamic> doctor) async {
    final db = ref.read(localDatabaseProvider);
    final orgId = (doctor['organisation_id'] is num)
        ? (doctor['organisation_id'] as num).toInt()
        : null;
    final org = (orgId == null || orgId <= 0)
        ? null
        : await db.getOrganisationById(orgId);

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final name = (doctor['full_name'] as String?) ?? '';
        final specialty = (doctor['specialty'] as String?) ?? '—';
        final category = 'Категория ${doctor['category'] ?? 'C'}';
        final city = (org?['city'] as String?) ?? '—';
        final orgName = (org?['name'] as String?) ?? 'ЛПУ не указано';
        final orgAddress = (org?['address'] as String?) ?? '';

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            MediaQuery.of(ctx).padding.bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.hintText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _SheetField(label: 'ФИО', value: name),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SheetField(
                            label: 'Специализация',
                            value: specialty,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _SheetField(
                            label: 'Категория',
                            value: category,
                            isCategoryPill: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SheetField(label: 'Регион', value: city),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Место работы',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.secondaryBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.iconBgBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orgName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (orgAddress.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              orgAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _startVisitForDoctor(doctor, orgName: orgName);
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(74, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Визит'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Закрыть'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _removeFavorite(doctor);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      child: const Text('Удалить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SyncState>(syncProvider, (prev, next) {
      final nextAt = next.lastSyncAt;
      if (nextAt == null) return;
      if (_lastSyncSeenAt != null &&
          nextAt.millisecondsSinceEpoch ==
              _lastSyncSeenAt!.millisecondsSinceEpoch) {
        return;
      }
      _lastSyncSeenAt = nextAt;
      if (mounted) _loadDoctors();
    });

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
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () => context.pop(),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.primaryText,
                                size: 24,
                              ),
                            ),
                          ),
                          Text(
                            'Избранные врачи',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Поиск',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.hintText,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(
                    child: Text(
                      'Нет избранных врачей',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      LimaNavBarLayout.scrollBottomPadding(context),
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final d = _filtered[i];
                      final name = (d['full_name'] as String?) ?? '';
                      final specialty = (d['specialty'] as String?) ?? '—';
                      final category = 'Категория ${d['category'] ?? 'C'}';
                      final lastVisit = _visitLabel(d);
                      final doctorId = (d['id'] as num?)?.toInt();
                      final pressed =
                          doctorId != null && _pressedDoctorId == doctorId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTapDown: (_) {
                            if (doctorId == null) return;
                            setState(() => _pressedDoctorId = doctorId);
                          },
                          onTapCancel: () {
                            setState(() => _pressedDoctorId = null);
                          },
                          onTapUp: (_) {
                            setState(() => _pressedDoctorId = null);
                          },
                          onTap: () => _onDoctorCardTap(d),
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 110),
                            curve: Curves.easeOutCubic,
                            scale: pressed ? 0.9 : 1.0,
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
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE9EEF4),
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                            ),
                                            child: Text(
                                              category,
                                              style: GoogleFonts.manrope(
                                                fontSize: 12,
                                                color: AppColors.secondaryText,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.work_outline_rounded,
                                                color: AppColors.hintText,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  specialty,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 13,
                                                    color:
                                                        AppColors.secondaryText,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            lastVisit,
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: AppColors.hintText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
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

class _SheetField extends StatelessWidget {
  final String label;
  final String value;
  final bool isCategoryPill;

  const _SheetField({
    required this.label,
    required this.value,
    this.isCategoryPill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        if (isCategoryPill)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEF4),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 8, color: AppColors.hintText),
                const SizedBox(width: 6),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            value.isEmpty ? '—' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
