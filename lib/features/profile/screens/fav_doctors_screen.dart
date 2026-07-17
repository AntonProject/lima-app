import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/providers/sync_provider.dart';
import 'package:lima/features/collections/providers/collections_repository_providers.dart';
import 'package:lima/features/visits/providers/lpu_details_provider.dart';
import 'package:lima/features/visits/providers/visits_hub_provider.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/profile/screens/profile_screen.dart';
import 'package:lima/shell/nav_bar_layout.dart';

/// Favourite doctor + its visit count. The count is a derived, screen-local
/// stat (from getVisitCountsByDoctorIds), not part of the Doctor entity, so
/// it's kept separate rather than bolted onto the model.
class _FavDoctorVm {
  final Doctor doctor;
  final int visitCount;

  const _FavDoctorVm({required this.doctor, required this.visitCount});
}

class FavDoctorsScreen extends ConsumerStatefulWidget {
  const FavDoctorsScreen({super.key});

  @override
  ConsumerState<FavDoctorsScreen> createState() => _FavDoctorsScreenState();
}

class _FavDoctorsScreenState extends ConsumerState<FavDoctorsScreen> {
  String _query = '';
  bool _loading = true;
  List<_FavDoctorVm> _allDoctors = [];
  int? _pressedDoctorId;
  DateTime? _lastSyncSeenAt;

  List<_FavDoctorVm> get _filtered => _allDoctors.where((vm) {
    final q = _query.toLowerCase();
    return vm.doctor.fullName.toLowerCase().contains(q) ||
        (vm.doctor.specialty ?? '').toLowerCase().contains(q);
  }).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDoctors());
  }

  Future<void> _loadDoctors() async {
    final favorites = ref.read(favoritesRepositoryProvider);
    final doctorsRepo = ref.read(doctorsDirectoryRepositoryProvider);

    final doctors = await favorites.getFavoriteDoctorModels();
    final visitCounts = await doctorsRepo.getVisitCountsByDoctorIds(
      doctors.map((d) => d.id).toList(),
    );
    final favList = doctors
        .map((d) => _FavDoctorVm(doctor: d, visitCount: visitCounts[d.id] ?? 0))
        .toList();
    if (!mounted) return;
    setState(() {
      _allDoctors = favList;
      _loading = false;
    });
  }

  String _visitLabel(BuildContext context, int visitCount) {
    if (visitCount <= 0) return context.l10n.t('noVisitsYet');
    return context.l10n.plural(visitCount, 'visits');
  }

  Future<void> _onDoctorCardTap(Doctor doctor) async {
    final doctorId = doctor.id;
    if (!mounted) return;
    setState(() => _pressedDoctorId = doctorId);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    setState(() => _pressedDoctorId = null);
    await _openDoctorSheet(doctor);
  }

  Future<void> _removeFavorite(Doctor doctor) async {
    final doctorId = doctor.id;
    final favorites = ref.read(favoritesRepositoryProvider);

    await favorites.setDoctorFavoriteLocal(doctorId, false);
    if (!mounted) return;
    setState(() {
      _allDoctors = _allDoctors
          .where((vm) => vm.doctor.id != doctorId)
          .toList();
    });

    try {
      await favorites.removeDoctorRemote(doctorId);
      ref.invalidate(favoriteDoctorsCountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.t('removedFromFav'))));
    } catch (_) {
      if (ref.read(isOfflineProvider)) {
        pulseOfflineBanner(ref);
      }
      ref.invalidate(favoriteDoctorsCountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('removedLocallyNoSync'))),
      );
    }
  }

  void _startVisitForDoctor(Doctor doctor, {int? orgId, String? orgName}) {
    final doctorId = doctor.id;
    if (orgId == null || orgId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.t('noLpuForDoctor'))));
      return;
    }
    // Match the web flow: land on the doctor-select step with the ЛПУ already
    // resolved and this doctor pre-selected (instead of jumping straight into
    // detailing).
    context.push(
      Uri(
        path: '/visits/lpu/detail/$orgId/doctors',
        queryParameters: {
          if (orgName != null && orgName.isNotEmpty) 'name': orgName,
          'preselect': '$doctorId',
        },
      ).toString(),
    );
  }

  Future<void> _openDoctorSheet(Doctor doctor) async {
    final doctorsRepo = ref.read(doctorsDirectoryRepositoryProvider);
    final orgsRepo = ref.read(organisationsDirectoryRepositoryProvider);
    final doctorId = doctor.id;
    // The doctor row's own organisation_id is often 0/NULL for globally-synced
    // doctors. Resolve the real org via the link table / past visits so the
    // workplace (region + ЛПУ name) and the "Визит" action both work.
    var orgId = doctor.organisationId > 0 ? doctor.organisationId : null;
    orgId ??= await doctorsRepo.getPrimaryOrgId(doctorId);
    final org = (orgId == null || orgId <= 0)
        ? null
        : await orgsRepo.getModelById(orgId);
    final resolvedOrgId = orgId;

    if (!mounted) return;
    await showAppSheet<void>(
      context,
      useRootNavigator: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final name = doctor.fullName;
        final specialty = doctor.specialty ?? '—';
        final category = ctx.l10n.t(
          'categoryN',
          args: {'cat': doctor.category ?? 'C'},
        );
        final city = org?.city ?? '—';
        final orgName = org?.name ?? ctx.l10n.t('lpuNotSet');
        final orgAddress = org?.address ?? '';

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
                          child: _SheetField(
                            label: ctx.l10n.t('fullName'),
                            value: name,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SheetField(
                            label: ctx.l10n.t('specialization'),
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
                            label: ctx.l10n.t('category'),
                            value: category,
                            isCategoryPill: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SheetField(
                            label: ctx.l10n.t('region'),
                            value: city,
                          ),
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
                  ctx.l10n.t('workplace'),
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
                          _startVisitForDoctor(
                            doctor,
                            orgId: resolvedOrgId,
                            orgName: orgName,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(74, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(ctx.l10n.t('visit')),
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
                      child: Text(ctx.l10n.t('close')),
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
                      child: Text(ctx.l10n.t('delete')),
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
                            context.l10n.t('favoriteDoctors'),
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
                  decoration: InputDecoration(
                    hintText: context.l10n.t('search'),
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
                      context.l10n.t('noFavDoctors'),
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
                      final vm = _filtered[i];
                      final name = vm.doctor.fullName;
                      final specialty = vm.doctor.specialty ?? '—';
                      final category = context.l10n.t(
                        'categoryN',
                        args: {'cat': vm.doctor.category ?? 'C'},
                      );
                      final lastVisit = _visitLabel(context, vm.visitCount);
                      final doctorId = vm.doctor.id;
                      final pressed = _pressedDoctorId == doctorId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTapDown: (_) {
                            setState(() => _pressedDoctorId = doctorId);
                          },
                          onTapCancel: () {
                            setState(() => _pressedDoctorId = null);
                          },
                          onTapUp: (_) {
                            setState(() => _pressedDoctorId = null);
                          },
                          onTap: () => _onDoctorCardTap(vm.doctor),
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
