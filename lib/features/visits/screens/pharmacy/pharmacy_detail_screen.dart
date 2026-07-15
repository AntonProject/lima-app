import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/features/visits/data/organisations_repository.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/services/app_actions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import 'package:lima/shell/nav_bar_layout.dart';
import 'package:url_launcher/url_launcher.dart';

class PharmacyDetailScreen extends ConsumerStatefulWidget {
  final int pharmacyId;
  final String pharmacyName;

  const PharmacyDetailScreen({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  ConsumerState<PharmacyDetailScreen> createState() =>
      _PharmacyDetailScreenState();
}

class _PharmacyDetailScreenState extends ConsumerState<PharmacyDetailScreen> {
  Map<String, dynamic>? _org;

  Map<String, dynamic> _rawOrg() {
    final raw = _org?['raw_json'] as String?;
    if (raw == null || raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return const <String, dynamic>{};
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrg());
  }

  Future<void> _loadOrg() async {
    final org = await ref
        .read(organisationsRepositoryProvider)
        .getById(widget.pharmacyId);
    if (!mounted) return;
    setState(() => _org = org);
  }

  String? _orgPhone() {
    final direct = (_org?['phone'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final raw = _rawOrg();
    final v =
        (raw['phone'] ?? raw['phone_1'] ?? raw['phone1'] ?? raw['phone_number'])
            ?.toString()
            .trim();
    if (v != null && v.isNotEmpty) return v;
    return null;
  }

  String? _orgInn() {
    final raw = _rawOrg();
    final v = (raw['inn'] ?? raw['org_inn'])?.toString().trim();
    if (v != null && v.isNotEmpty) return v;
    return null;
  }

  String? _orgResponsible() {
    final raw = _rawOrg();
    final v = (raw['responsible_person'] ?? raw['responsible'])
        ?.toString()
        .trim();
    if (v != null && v.isNotEmpty) return v;
    return null;
  }

  String? _orgDistrict() {
    final raw = _rawOrg();
    final v = (raw['district'] ?? raw['area'] ?? raw['area_name'])
        ?.toString()
        .trim();
    if (v != null && v.isNotEmpty) return v;
    final direct = (_org?['district'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return null;
  }

  String? _orgCategory() {
    final raw = _rawOrg();
    final v = (raw['category'] ?? raw['category_name'] ?? raw['class'])
        ?.toString()
        .trim();
    if (v != null && v.isNotEmpty) return v;
    return null;
  }

  bool? _worksWithUs() {
    final raw = _rawOrg();
    final candidate =
        raw['is_working_with_us'] ??
        raw['working_with_us'] ??
        raw['is_partner'] ??
        raw['is_active_partner'];
    if (candidate is bool) return candidate;
    if (candidate is num) return candidate != 0;
    if (candidate is String) {
      final s = candidate.toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    // Fallback: API returns `visited: true/false` for this rep's pharmacies
    final visited = raw['visited'];
    if (visited is bool) return visited;
    return null;
  }

  Future<void> _openEditOrganizationSheet() async {

    final nameCtrl = TextEditingController(
      text: (_org?['name'] as String?) ?? widget.pharmacyName,
    );
    final innCtrl = TextEditingController(text: _orgInn() ?? '');
    final phoneCtrl = TextEditingController(text: _orgPhone() ?? '');
    final cityCtrl = TextEditingController(
      text: (_org?['city'] as String?) ?? '',
    );
    final districtCtrl = TextEditingController(text: _orgDistrict() ?? '');
    final addressCtrl = TextEditingController(
      text: (_org?['address'] as String?) ?? '',
    );
    final categoryCtrl = TextEditingController(text: _orgCategory() ?? 'C');
    final responsibleCtrl = TextEditingController(
      text: _orgResponsible() ?? '',
    );
    final lat = (_org?['latitude'] as num?)?.toDouble();
    final lon = (_org?['longitude'] as num?)?.toDouble();

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
              decoration: InputDecoration(labelText: context.l10n.t('fieldName')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: innCtrl,
              decoration: InputDecoration(labelText: context.l10n.t('fieldInn')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(labelText: context.l10n.t('phone')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cityCtrl,
              decoration: InputDecoration(labelText: context.l10n.t('fieldRegion')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: districtCtrl,
              decoration: InputDecoration(labelText: context.l10n.t('fieldDistrict')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addressCtrl,
              decoration: InputDecoration(labelText: context.l10n.t('fieldAddress')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: categoryCtrl,
              decoration: InputDecoration(labelText: context.l10n.t('category')),
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

    final orgs = ref.read(organisationsRepositoryProvider);
    final name = nameCtrl.text.trim();
    final address = addressCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final city = cityCtrl.text.trim();
    final district = districtCtrl.text.trim();
    final inn = innCtrl.text.trim();
    final category = categoryCtrl.text.trim();
    final responsible = responsibleCtrl.text.trim();

    // Сначала сохраняем локально — UI реагирует мгновенно
    await orgs.updateLocal(
      id: widget.pharmacyId,
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
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _loadOrg();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.t('orgUpdated'))));

    // Отправляем в API в фоне; при ошибке кладём в очередь
    try {
      await orgs.updateRemote(
        organizationId: widget.pharmacyId,
        name: name,
        address: address,
        phone: phone,
        city: city,
        district: district,
        inn: inn,
        category: category,
        responsiblePerson: responsible,
        latitude: lat,
        longitude: lon,
      );
    } catch (_) {
      await orgs.enqueuePendingOrgUpdate(
        orgId: widget.pharmacyId,
        name: name,
        address: address,
        phone: phone,
        city: city,
        district: district,
        inn: inn,
        category: category,
        responsible: responsible,
        latitude: lat,
        longitude: lon,
      );
    }
  }

  Future<void> _buildYandexRoute() async {
    final lat = (_org?['latitude'] as num?)?.toDouble();
    final lon = (_org?['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return;
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

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(appCollectionsProvider);
    final isFavorite = collections.favoritePharmacyIds.contains(
      widget.pharmacyId,
    );
    final address = _org?['address'] as String? ?? '';
    final city = _org?['city'] as String? ?? '';
    final phone = _orgPhone();
    final inn = _orgInn();
    final category = _orgCategory();
    final worksWithUs = _worksWithUs();
    final ctaBottom = LimaNavBarLayout.ctaBottomOffset(context);

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Stack(
        children: [
          Column(
            children: [
              AppCenteredHeader(title: context.l10n.t('pharmacyOne'), onBack: () => context.pop()),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, ctaBottom + 56),
                  children: [
                    // Org header card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: shadowSm,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.iconBgGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.medication_rounded,
                              color: AppColors.success,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.pharmacyName,
                                  style: GoogleFonts.manrope(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                if ((category != null && category.isNotEmpty) ||
                                    worksWithUs != null) ...[
                                  const SizedBox(height: 8),
                                  // Category + status sit below the name and wrap
                                  // so a long name never floats the status badge
                                  // beside the middle of the text.
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (category != null &&
                                          category.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.iconBgLight,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            category,
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              color: AppColors.secondaryText,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      if (worksWithUs != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: worksWithUs == true
                                                ? const Color(0xFFDDF5E6)
                                                : const Color(0xFFFFEEF0),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            worksWithUs == true
                                                ? context.l10n.t('worksWithUs')
                                                : context.l10n.t(
                                                    'notWorksWithUs',
                                                  ),
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: worksWithUs == true
                                                  ? const Color(0xFF2AA65A)
                                                  : AppColors.error,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              final added = await ref
                                  .read(appCollectionsProvider.notifier)
                                  .toggleFavoritePharmacy(widget.pharmacyId);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    added
                                        ? context.l10n.t('addedToFav')
                                        : context.l10n.t('removedFromFav'),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isFavorite
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const SizedBox(height: 10),
                    SectionLabel(text: context.l10n.t('informationCaps')),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: shadowSm,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          if (city.isNotEmpty)
                            InfoRow(label: context.l10n.t('region'), value: city),
                          if (address.isNotEmpty)
                            InfoRow(label: context.l10n.t('address'), value: address),
                          if (phone != null && phone.isNotEmpty)
                            InfoRow(
                              label: context.l10n.t('phone'),
                              value: phone,
                              isLink: true,
                              onTap: () => launchPhone(phone),
                            ),
                          if (inn != null && inn.isNotEmpty)
                            InfoRow(label: context.l10n.t('inn'), value: inn),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.call_rounded,
                            label: context.l10n.t('call'),
                            onTap: (phone == null || phone.isEmpty)
                                ? null
                                : () => launchPhone(phone),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.near_me_rounded,
                            label: context.l10n.t('route'),
                            onTap: _buildYandexRoute,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.edit_rounded,
                            label: context.l10n.t('edit'),
                            onTap: _openEditOrganizationSheet,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: shadowSm,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.iconBgBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          context.l10n.t('orderHistory'),
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.hintText,
                        ),
                        onTap: () => context.push(
                          Uri(
                            path: '/visits/history',
                            queryParameters: {
                              'type': 'pharmacy',
                              'orgId': '${widget.pharmacyId}',
                              'openFirst': '1',
                            },
                          ).toString(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: ctaBottom,
            child: ElevatedButton(
              onPressed: () => context.push(
                Uri(
                  path: '/visits/pharmacy/detail/${widget.pharmacyId}/type',
                  queryParameters: {'name': widget.pharmacyName},
                ).toString(),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(context.l10n.t('startVisit')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadowSm,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: onTap == null ? AppColors.hintText : AppColors.primary,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: onTap == null
                    ? AppColors.hintText
                    : AppColors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
