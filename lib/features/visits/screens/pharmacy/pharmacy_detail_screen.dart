import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/services/app_actions.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrg());
  }

  Future<void> _loadOrg() async {
    final org = await ref
        .read(localDatabaseProvider)
        .getOrganisationById(widget.pharmacyId);
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
    return null;
  }

  Future<void> _openEditOrganizationSheet() async {
    if (!_canEditDirectory) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Редактирование доступно только администратору'),
        ),
      );
      return;
    }

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

    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
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
              'Редактировать организацию',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Название *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: innCtrl,
              decoration: const InputDecoration(labelText: 'ИНН *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Телефон'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cityCtrl,
              decoration: const InputDecoration(labelText: 'Регион *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: districtCtrl,
              decoration: const InputDecoration(labelText: 'Район'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(labelText: 'Адрес *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: categoryCtrl,
              decoration: const InputDecoration(labelText: 'Категория'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: responsibleCtrl,
              decoration: const InputDecoration(
                labelText: 'Ответственное лицо',
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
                    ? 'Местоположение установлено'
                    : 'Местоположение не задано',
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
              child: const Text('Обновить'),
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
    ).showSnackBar(const SnackBar(content: Text('Организация обновлена')));

    // Отправляем в API в фоне; при ошибке кладём в очередь
    try {
      await api.updateOrganization(
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
      await db.enqueuePendingOrgUpdate(
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
    final canEditDirectory = ref.watch(authProvider).user?.role == 'admin';
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
    final ctaBottom = LimaNavBarLayout.totalBarHeight(context) + 12;

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Stack(
        children: [
          Column(
            children: [
              AppCenteredHeader(title: 'Аптека', onBack: () => context.pop()),
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.pharmacyName,
                                        style: GoogleFonts.manrope(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                    ),
                                    if (category != null &&
                                        category.isNotEmpty) ...[
                                      const SizedBox(width: 8),
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
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (worksWithUs == false) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEEF0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Не работает с нами',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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
                                        ? 'Добавлено в избранное'
                                        : 'Убрано из избранного',
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
                    const SectionLabel(text: 'ИНФОРМАЦИЯ'),
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
                            InfoRow(label: 'Регион', value: city),
                          if (address.isNotEmpty)
                            InfoRow(label: 'Адрес', value: address),
                          if (phone != null && phone.isNotEmpty)
                            InfoRow(
                              label: 'Телефон',
                              value: phone,
                              isLink: true,
                              onTap: () => launchPhone(phone),
                            ),
                          if (inn != null && inn.isNotEmpty)
                            InfoRow(label: 'ИНН', value: inn),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.call_rounded,
                            label: 'Позвонить',
                            onTap: (phone == null || phone.isEmpty)
                                ? null
                                : () => launchPhone(phone),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.near_me_rounded,
                            label: 'Маршрут',
                            onTap: _buildYandexRoute,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.edit_rounded,
                            label: 'Редактировать',
                            onTap: canEditDirectory
                                ? _openEditOrganizationSheet
                                : null,
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
                          'История заказов',
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
              child: const Text('Начать визит'),
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
