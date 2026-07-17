import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/services/app_actions.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/collections/providers/collections_repository_providers.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/core/utils/swallowed.dart';
import 'package:lima/features/visits/providers/lpu_details_provider.dart';
import 'package:lima/features/visits/providers/organisation_details_provider.dart';
import 'package:lima/features/visits/providers/visits_hub_provider.dart';
import 'package:lima/features/visits/domain/entities/organisation_draft.dart';
import 'package:lima/shell/nav_bar_layout.dart';
import 'package:url_launcher/url_launcher.dart';

part '../../widgets/lpu_detail_widgets.dart';

class LpuDetailScreen extends ConsumerStatefulWidget {
  final int orgId;
  final String orgName;
  final String orgAddress;

  const LpuDetailScreen({
    super.key,
    required this.orgId,
    required this.orgName,
    required this.orgAddress,
  });

  @override
  ConsumerState<LpuDetailScreen> createState() => _LpuDetailScreenState();
}

class _LpuDetailScreenState extends ConsumerState<LpuDetailScreen> {
  final Set<int> _expandedDoctorIds = {};

  Organisation? get _org =>
      ref.read(organisationDetailsViewModelProvider(widget.orgId)).organisation;

  List<Doctor> get _doctors =>
      ref.read(lpuDetailsViewModelProvider(widget.orgId)).doctors;

  Set<int> get _visitedDoctorIds =>
      ref.read(lpuDetailsViewModelProvider(widget.orgId)).visitedDoctorIds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(lpuDetailsViewModelProvider(widget.orgId).notifier)
          .load(fetchRemote: !ref.read(isOfflineProvider));
    });
  }

  Future<void> _toggleFavorite(Doctor doctor) async {
    final doctorId = doctor.id;
    final next = !doctor.isFavorite;
    ref
        .read(lpuDetailsViewModelProvider(widget.orgId).notifier)
        .setDoctorFavorite(doctorId, next);

    final favorites = ref.read(favoritesRepositoryProvider);
    var updated = await favorites.setDoctorFavoriteLocal(doctorId, next);
    if (updated == 0) {
      await ref
          .read(doctorsDirectoryRepositoryProvider)
          .upsertDoctorModel(
            Doctor(
              id: doctorId,
              fullName: doctor.fullName,
              specialty: doctor.specialty,
              specializationId: doctor.specializationId,
              organisationId: doctor.organisationId > 0
                  ? doctor.organisationId
                  : widget.orgId,
              isFavorite: next,
              category: doctor.category,
              lastVisitLabel: doctor.lastVisitLabel,
              phone: doctor.phone,
              hobby: doctor.hobby,
              interests: doctor.interests,
              birthday: doctor.birthday,
              updatedAt: DateTime.now().toIso8601String(),
              rawJson: doctor.rawJson,
            ),
          );
      await favorites.setDoctorFavoriteLocal(doctorId, next);
    }
    try {
      if (next) {
        await favorites.addDoctorRemote(doctorId);
      } else {
        await favorites.removeDoctorRemote(doctorId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? context.l10n.t('addedToFav')
                : context.l10n.t('removedFromFav'),
          ),
        ),
      );
    } catch (_) {
      // Queue for retry when internet returns.
      try {
        await favorites.enqueuePending(
          entityType: 'doctor',
          entityId: doctorId,
          add: next,
        );
      } catch (error) {
        logSwallowed(error, 'LpuDetailScreen.loadDoctors');
      }
      if (ref.read(isOfflineProvider)) {
        pulseOfflineBanner(ref);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? context.l10n.t('addedToFav')
                : context.l10n.t('removedFromFav'),
          ),
        ),
      );
    }
  }

  String? _orgPhone() {
    return _org?.displayPhone;
  }

  String? _orgInn() {
    return _org?.displayInn;
  }

  String? _orgResponsible() {
    return _org?.displayResponsible;
  }

  String? _orgDistrict() {
    return _org?.displayDistrict;
  }

  String? _orgCategory() {
    return _org?.displayCategory;
  }

  bool? _worksWithUs() {
    return _org?.worksWithUs;
  }

  Future<void> _buildYandexRoute() async {
    final lat = _org?.latitude;
    final lon = _org?.longitude;
    if (lat == null || lon == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.t('orgNoCoords'))));
      return;
    }
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    }
    final fromLat = pos?.latitude ?? 41.298386;
    final fromLon = pos?.longitude ?? 69.338330;
    final webUri = Uri.parse(
      'https://yandex.ru/maps/?rtext=$fromLat,$fromLon~$lat,$lon&rtt=auto',
    );
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  void _toggleDoctorExpanded(int doctorId) {
    setState(() {
      if (_expandedDoctorIds.contains(doctorId)) {
        _expandedDoctorIds.remove(doctorId);
      } else {
        _expandedDoctorIds.add(doctorId);
      }
    });
  }

  Future<void> _openEditOrganizationSheet() async {
    final nameCtrl = TextEditingController(text: _org?.name ?? widget.orgName);
    final innCtrl = TextEditingController(text: _orgInn() ?? '');
    final phoneCtrl = TextEditingController(text: _orgPhone() ?? '');
    final cityCtrl = TextEditingController(text: _org?.city ?? '');
    final districtCtrl = TextEditingController(text: _orgDistrict() ?? '');
    final displayAddress = (_org?.address ?? widget.orgAddress).trim();
    final addressCtrl = TextEditingController(text: displayAddress);
    final categoryCtrl = TextEditingController(text: _orgCategory() ?? 'C');
    final responsibleCtrl = TextEditingController(
      text: _orgResponsible() ?? '',
    );
    final lat = _org?.latitude;
    final lon = _org?.longitude;

    final saved = await showAppSheet<bool>(
      context,
      useRootNavigator: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).padding.bottom +
              16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.t('editOrg'),
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.t('fieldName'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: innCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.t('fieldInn'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(labelText: context.l10n.t('phone')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cityCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.t('fieldRegion'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: districtCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.t('fieldDistrict'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addressCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.t('fieldAddress'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: categoryCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.t('category'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: responsibleCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.t('fieldResponsible'),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                (lat != null && lon != null)
                    ? context.l10n.t('locationSet')
                    : context.l10n.t('locationNotSet'),
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text(context.l10n.t('update')),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final name = nameCtrl.text.trim();
    final address = addressCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final city = cityCtrl.text.trim();
    final district = districtCtrl.text.trim();
    final inn = innCtrl.text.trim();
    final category = categoryCtrl.text.trim();
    final responsible = responsibleCtrl.text.trim();

    final draft = OrganisationUpdateDraft(
      organisationId: widget.orgId,
      name: name,
      address: address,
      city: city,
      district: district,
      inn: inn,
      category: category,
      responsible: responsible,
      phone: phone,
      latitude: lat,
      longitude: lon,
    );
    final orgs = ref.read(organisationsDirectoryRepositoryProvider);

    // Сначала сохраняем локально — UI реагирует мгновенно.
    await orgs.updateLocalOrganisation(draft);
    await ref
        .read(organisationDetailsViewModelProvider(widget.orgId).notifier)
        .load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.t('orgUpdated'))));

    // Отправляем в API в фоне; при ошибке кладём в очередь
    try {
      await orgs.updateRemoteOrganisation(draft);
    } catch (_) {
      await orgs.enqueueOrganisationUpdate(draft);
    }
  }

  @override
  Widget build(BuildContext context) => _buildDetailScaffold(context);
}
