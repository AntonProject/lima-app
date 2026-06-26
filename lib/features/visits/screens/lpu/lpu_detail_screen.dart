import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/services/app_actions.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/shell/nav_bar_layout.dart';
import 'package:url_launcher/url_launcher.dart';

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
  List<Map<String, dynamic>> _doctors = [];
  Map<String, dynamic>? _org;
  final Set<int> _expandedDoctorIds = {};
  bool _remoteDoctorsLoaded = false;
  bool get _canEditDirectory => ref.read(authProvider).user?.role == 'admin';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadOrg();
      await _loadDoctors();
    });
  }

  Future<void> _loadOrg() async {
    final org = await ref
        .read(localDatabaseProvider)
        .getOrganisationById(widget.orgId);
    if (!mounted) return;
    setState(() => _org = org);
  }

  Future<void> _loadDoctors() async {
    final hadVisitLabel = context.l10n.t('hadVisit');
    final db = ref.read(localDatabaseProvider);
    var results = await db.getDoctors(
      orgId: widget.orgId,
      includeGlobalFallback: false,
    );

    if (!_remoteDoctorsLoaded && !ref.read(isOfflineProvider)) {
      _remoteDoctorsLoaded = true;
      try {
        final remoteDoctors = await ref
            .read(remoteApiServiceProvider)
            .getDoctorsByOrganization(widget.orgId);
        if (remoteDoctors.length > results.length) {
          await db.upsertDoctors(remoteDoctors);
          await db.upsertDoctorOrganisationLinks(
            remoteDoctors
                .map((d) => (d['id'] as num?)?.toInt())
                .whereType<int>()
                .map(
                  (doctorId) => <String, dynamic>{
                    'doctor_id': doctorId,
                    'organisation_id': widget.orgId,
                  },
                )
                .toList(),
          );
          results = await db.getDoctors(
            orgId: widget.orgId,
            includeGlobalFallback: false,
          );
        }
      } catch (_) {}
    }

    final mutableResults = results
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // Mark doctors that have been visited using local visit history
    try {
      final doctorIds = mutableResults
          .map((r) => (r['id'] as num?)?.toInt())
          .whereType<int>()
          .toList();
      final visitCounts = await db.getVisitCountsByDoctorIds(doctorIds);
      for (final row in mutableResults) {
        final id = row['id'] as int?;
        if (id != null && (visitCounts[id] ?? 0) > 0) {
          row['last_visit_label'] = hadVisitLabel;
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _doctors = mutableResults);
  }

  Future<void> _toggleFavorite(Map<String, dynamic> doctor) async {
    final doctorId = doctor['id'] as int?;
    if (doctorId == null) return;
    final current = (doctor['is_favorite'] ?? 0) == 1;
    final next = !current;

    setState(() => doctor['is_favorite'] = next ? 1 : 0);

    final db = ref.read(localDatabaseProvider);
    final api = ref.read(remoteApiServiceProvider);
    var updated = await db.updateDoctorFavorite(doctorId, next);
    if (updated == 0) {
      await db.upsertDoctors([
        {
          'id': doctorId,
          'full_name': (doctor['full_name'] ?? doctor['name'] ?? '').toString(),
          'specialty': (doctor['specialty'] ?? doctor['position'] ?? '')
              .toString(),
          'organisation_id':
              ((doctor['organisation_id'] ?? doctor['organization_id']) is num)
              ? ((doctor['organisation_id'] ?? doctor['organization_id'])
                        as num)
                    .toInt()
              : widget.orgId,
          'is_favorite': next ? 1 : 0,
          'category': (doctor['category'] ?? 'C').toString(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);
      await db.updateDoctorFavorite(doctorId, next);
    }
    try {
      if (next) {
        await api.addDoctorToFavorites(doctorId);
      } else {
        await api.removeDoctorFromFavorites(doctorId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next ? context.l10n.t('addedToFav') : context.l10n.t('removedFromFav'),
          ),
        ),
      );
    } catch (_) {
      // Queue for retry when internet returns.
      try {
        await db.enqueueFavorite(
          entityType: 'doctor',
          entityId: doctorId,
          add: next,
        );
      } catch (_) {}
      if (ref.read(isOfflineProvider)) {
        pulseOfflineBanner(ref);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next ? context.l10n.t('addedToFav') : context.l10n.t('removedFromFav'),
          ),
        ),
      );
    }
  }

  String? _orgPhone() {
    final direct = (_org?['phone'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    try {
      final raw = _org?['raw_json'] as String?;
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        final v =
            (map['phone'] ??
                    map['phone_1'] ??
                    map['phone1'] ??
                    map['phone_number'])
                ?.toString()
                .trim();
        if (v != null && v.isNotEmpty) return v;
      }
    } catch (_) {}
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
    final visited = raw['visited'];
    if (visited is bool) return visited;
    return null;
  }

  Future<void> _buildYandexRoute() async {
    final lat = (_org?['latitude'] as num?)?.toDouble();
    final lon = (_org?['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('orgNoCoords'))),
      );
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

  Future<void> _openEditOrganizationSheet() async {
    if (!_canEditDirectory) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('editAdminOnly')),
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController(
      text: (_org?['name'] as String?) ?? widget.orgName,
    );
    final innCtrl = TextEditingController(text: _orgInn() ?? '');
    final phoneCtrl = TextEditingController(text: _orgPhone() ?? '');
    final cityCtrl = TextEditingController(
      text: (_org?['city'] as String?) ?? '',
    );
    final districtCtrl = TextEditingController(text: _orgDistrict() ?? '');
    final displayAddress = ((_org?['address'] as String?) ?? widget.orgAddress)
        .trim();
    final addressCtrl = TextEditingController(text: displayAddress);
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

    final db = ref.read(localDatabaseProvider);
    final api = ref.read(remoteApiServiceProvider);
    final name = nameCtrl.text.trim();
    final address = addressCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final city = cityCtrl.text.trim();
    final district = districtCtrl.text.trim();
    final inn = innCtrl.text.trim();
    final category = categoryCtrl.text.trim();
    final responsible = responsibleCtrl.text.trim();

    // Сначала сохраняем локально — UI реагирует мгновенно
    await db.updateOrganisation(
      id: widget.orgId,
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
      await api.updateOrganization(
        organizationId: widget.orgId,
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
      await db.enqueuePendingOrgUpdate(
        orgId: widget.orgId,
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

  @override
  Widget build(BuildContext context) {
    final canEditDirectory = ref.watch(authProvider).user?.role == 'admin';
    final hasPhone = (_orgPhone() ?? '').trim().isNotEmpty;
    final phone = _orgPhone();
    final inn = _orgInn();
    final responsible = _orgResponsible();
    final category = _orgCategory();
    final worksWithUs = _worksWithUs();
    final displayAddress = ((_org?['address'] as String?) ?? widget.orgAddress)
        .trim();
    final ctaBottom = LimaNavBarLayout.ctaBottomOffset(context);

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Stack(
        children: [
          Column(
            children: [
              // ── AppBar ────────────────────────────────────────────────────
              AppCenteredHeader(title: context.l10n.t('lpu'), onBack: () => context.pop()),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, ctaBottom + 56),
                  children: [
                    // ── Org header card ────────────────────────────────────────
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
                              color: AppColors.iconBgBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.home_work_rounded,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.orgName,
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
                                  // so a long org name never pushes the status
                                  // badge to float beside the middle of the text.
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Info ───────────────────────────────────────────────────
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
                          if ((_org?['city'] as String? ?? '').isNotEmpty)
                            InfoRow(
                              label: context.l10n.t('region'),
                              value: _org!['city'] as String,
                            ),
                          if (displayAddress.isNotEmpty)
                            InfoRow(label: context.l10n.t('address'), value: displayAddress),
                          if (phone != null && phone.isNotEmpty)
                            InfoRow(
                              label: context.l10n.t('phone'),
                              value: phone,
                              isLink: true,
                              onTap: () => launchPhone(phone),
                            ),
                          if (inn != null && inn.isNotEmpty)
                            InfoRow(label: context.l10n.t('inn'), value: inn),
                          if (responsible != null && responsible.isNotEmpty)
                            InfoRow(label: context.l10n.t('responsible'), value: responsible),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Call / Route / Edit ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.call_rounded,
                            label: context.l10n.t('call'),
                            onTap: hasPhone
                                ? () async {
                                    if (phone == null || phone.isEmpty) return;
                                    await launchPhone(phone);
                                  }
                                : null,
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
                            onTap: canEditDirectory
                                ? _openEditOrganizationSheet
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── History ────────────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: shadowSm,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push(
                          Uri(
                            path: '/visits/history',
                            queryParameters: {
                              'type': 'lpu',
                              'orgId': '${widget.orgId}',
                              'openFirst': '1',
                            },
                          ).toString(),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.iconBgBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.access_time_filled_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  context.l10n.t('visitHistory'),
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
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
                    const SizedBox(height: 16),

                    // ── Doctors ────────────────────────────────────────────────
                    Row(
                      children: [
                        SectionLabel(text: context.l10n.t('doctorsCaps')),
                        const Spacer(),
                        Text(
                          '${_doctors.length}',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    if (_doctors.isEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBg,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: shadowSm,
                        ),
                        child: ListTile(
                          title: Text(
                            context.l10n.t('doctorsNotFound'),
                            style: GoogleFonts.manrope(
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _doctors.map((d) {
                          final isFavorite = (d['is_favorite'] ?? 0) == 1;
                          final name = d['full_name'] as String? ?? '';
                          final specialty = d['specialty'] as String? ?? '';
                          final doctorId = (d['id'] as int?) ?? -1;
                          final expanded = _expandedDoctorIds.contains(
                            doctorId,
                          );
                          final category =
                              '${context.l10n.t('category')} ${d['category'] ?? 'C'}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFDDE3EB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.divider,
                                  width: 1,
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(left: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryBg,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: shadowSm,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    setState(() {
                                      if (expanded) {
                                        _expandedDoctorIds.remove(doctorId);
                                      } else {
                                        _expandedDoctorIds.add(doctorId);
                                      }
                                    });
                                  },
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          14,
                                          14,
                                          12,
                                          14,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => _toggleFavorite(d),
                                              child: Icon(
                                                isFavorite
                                                    ? Icons.bookmark_rounded
                                                    : Icons
                                                          .bookmark_border_rounded,
                                                color: AppColors.primary,
                                                size: 21,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              expanded
                                                  ? Icons
                                                        .keyboard_arrow_down_rounded
                                                  : Icons.chevron_right_rounded,
                                              color: AppColors.hintText,
                                              size: 21,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (expanded) ...[
                                        const Divider(
                                          height: 1,
                                          color: AppColors.divider,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            12,
                                            12,
                                            14,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.iconBgBlue,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  category,
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.secondaryText,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.work_outline_rounded,
                                                    color: AppColors.hintText,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      specialty.isEmpty
                                                          ? '—'
                                                          : specialty,
                                                      style:
                                                          GoogleFonts.manrope(
                                                            fontSize: 14,
                                                            color: AppColors
                                                                .secondaryText,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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
                  path: '/visits/lpu/detail/${widget.orgId}/doctors',
                  queryParameters: {'name': widget.orgName},
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
