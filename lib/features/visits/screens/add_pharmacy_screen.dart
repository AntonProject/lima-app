import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/db/local_database.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../core/network/remote_api_service.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import 'yandex_map_picker.dart';

/// Organisation kind for the create form. Pharmacy and LPU share the same
/// screen; LPU adds revision status, facility type and multiple phones, and
/// requires the district.
enum OrgKind { pharmacy, lpu }

/// "Добавить организацию / ЛПУ" — create a pharmacy (type_id=1) or LPU
/// (type_id=2) via POST /dict/organizations/add.
class AddPharmacyScreen extends ConsumerStatefulWidget {
  final OrgKind kind;

  const AddPharmacyScreen({super.key, this.kind = OrgKind.pharmacy});

  @override
  ConsumerState<AddPharmacyScreen> createState() => _AddPharmacyScreenState();
}

class _AddPharmacyScreenState extends ConsumerState<AddPharmacyScreen> {
  bool get _isLpu => widget.kind == OrgKind.lpu;
  int get _typeId => _isLpu ? 2 : 1;

  final _nameCtrl = TextEditingController();
  final _innCtrl = TextEditingController();
  // Up to 3 phones for LPU; pharmacy uses only the first.
  final _phoneCtrls = <TextEditingController>[
    TextEditingController(text: '+998'),
  ];
  final _addressCtrl = TextEditingController();
  final _responsibleCtrl = TextEditingController();

  List<Map<String, dynamic>> _regions = const [];
  List<Map<String, dynamic>> _areas = const [];
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _facilityTypes = const [];

  int? _regionId;
  String? _regionName;
  int? _areaId;
  String? _areaName;
  int? _categoryId;
  String? _categoryName;
  int? _facilityTypeId;
  String? _facilityTypeName;
  // Revision status (LPU only): none | partial | full. Defaults to none.
  String _revisionStatus = 'none';
  double? _latitude;
  double? _longitude;
  LatLng? _areaCenter;

  bool _loadingDicts = true;
  bool _loadingAreas = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDictionaries());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _innCtrl.dispose();
    for (final c in _phoneCtrls) {
      c.dispose();
    }
    _addressCtrl.dispose();
    _responsibleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDictionaries() async {
    final api = ref.read(remoteApiServiceProvider);
    try {
      final results = await Future.wait([
        api.getRegions(),
        api.getOrgCategories(),
        if (_isLpu) api.getHealthcareFacilityTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _regions = results[0];
        _categories = results[1];
        if (_isLpu && results.length > 2) _facilityTypes = results[2];
        _loadingDicts = false;
      });
      _prefillUserRegion();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDicts = false);
    }
  }

  /// Pre-selects the user's own region (from profile) so the field starts
  /// filled — matching the web form. Matches by region id, then by name.
  void _prefillUserRegion() {
    if (_regionId != null || _regions.isEmpty) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;
    Map<String, dynamic>? match;
    if (user.regionId != null) {
      for (final r in _regions) {
        if ((r['id'] as num?)?.toInt() == user.regionId) {
          match = r;
          break;
        }
      }
    }
    if (match == null && (user.city ?? '').trim().isNotEmpty) {
      final city = user.city!.trim().toLowerCase();
      for (final r in _regions) {
        if ('${r['name']}'.trim().toLowerCase() == city) {
          match = r;
          break;
        }
      }
    }
    if (match != null) {
      _selectRegion(match['id'] as int, match['name'] as String);
    }
  }

  bool get _canSubmit =>
      _nameCtrl.text.trim().isNotEmpty &&
      _innCtrl.text.trim().isNotEmpty &&
      _regionId != null &&
      // District is required for LPU (matches web).
      (!_isLpu || _areaId != null) &&
      _addressCtrl.text.trim().isNotEmpty;

  /// Non-empty trimmed phone numbers (LPU may have up to 3).
  List<String> get _phones => _phoneCtrls
      .map((c) => c.text.trim())
      .where((p) => p.isNotEmpty && p != '+998')
      .toList();

  Future<void> _pickRegion() async {
    final picked = await _openPicker(
      title: context.l10n.t('selectRegion'),
      options: _regions,
      selectedId: _regionId,
    );
    if (picked == null || !mounted) return;
    await _selectRegion(picked['id'] as int, picked['name'] as String);
  }

  /// Sets the region and loads its districts. Shared by the picker and the
  /// profile-based prefill.
  Future<void> _selectRegion(int id, String name) async {
    setState(() {
      _regionId = id;
      _regionName = name;
      _areaId = null;
      _areaName = null;
      _areaCenter = null;
      _areas = const [];
      _loadingAreas = true;
    });
    // Districts are fetched per region from /dict/common/areas/{regionId}.
    try {
      final areas = await ref
          .read(remoteApiServiceProvider)
          .getAreas(id);
      if (!mounted) return;
      setState(() {
        _areas = areas;
        _loadingAreas = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAreas = false);
    }
  }

  Future<void> _pickArea() async {
    if (_areas.isEmpty) return;
    final picked = await _openPicker(
      title: context.l10n.t('selectArea'),
      options: _areas,
      selectedId: _areaId,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _areaId = picked['id'] as int;
      _areaName = picked['name'] as String;
      // Remember the district centre — used as the map's initial point.
      final lat = picked['latitude'];
      final lng = picked['longitude'];
      _areaCenter = (lat is num && lng is num)
          ? LatLng(lat.toDouble(), lng.toDouble())
          : null;
    });
  }

  /// Approx region centre = average of its districts' coordinates (regions
  /// themselves carry no lat/lng from the API).
  LatLng? get _regionCenter {
    final points = _areas
        .map((a) {
          final lat = a['latitude'];
          final lng = a['longitude'];
          return (lat is num && lng is num)
              ? LatLng(lat.toDouble(), lng.toDouble())
              : null;
        })
        .whereType<LatLng>()
        .toList();
    if (points.isEmpty) return null;
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) /
        points.length;
    final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) /
        points.length;
    return LatLng(lat, lng);
  }

  Future<void> _pickCategory() async {
    final picked = await _openPicker(
      title: context.l10n.t('selectCategory'),
      options: _categories,
      selectedId: _categoryId,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _categoryId = picked['id'] as int;
      _categoryName = picked['name'] as String;
    });
  }

  Future<void> _pickFacilityType() async {
    final picked = await _openPicker(
      title: context.l10n.t('selectLpuType'),
      options: _facilityTypes,
      selectedId: _facilityTypeId,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _facilityTypeId = picked['id'] as int;
      _facilityTypeName = picked['name'] as String;
    });
  }

  void _addPhoneField() {
    setState(() {
      _phoneCtrls.add(TextEditingController(text: '+998'));
    });
  }

  void _removePhoneField(int index) {
    if (_phoneCtrls.length <= 1) return;
    setState(() {
      _phoneCtrls.removeAt(index).dispose();
    });
  }

  /// The "+ Add phone" button is enabled only when under the 3-phone cap and
  /// the last phone field already has a number (matches web behaviour).
  bool get _canAddPhone {
    if (_phoneCtrls.length >= 3) return false;
    final last = _phoneCtrls.last.text.trim();
    return last.isNotEmpty && last != '+998';
  }

  Future<Map<String, dynamic>?> _openPicker({
    required String title,
    required List<Map<String, dynamic>> options,
    required int? selectedId,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).padding.bottom;
        final maxH = MediaQuery.of(ctx).size.height * 0.55 + bottomPad;
        return Container(
          constraints: BoxConstraints(maxHeight: maxH),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: EdgeInsets.only(bottom: bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (_, i) {
                    final item = options[i];
                    final isSelected = item['id'] == selectedId;
                    return InkWell(
                      onTap: () => Navigator.pop(ctx, item),
                      child: Container(
                        color: isSelected
                            ? const Color(0xFFF3F6FB)
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item['name']}',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.primaryText,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
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
      },
    );
  }

  Future<void> _pickOnMap() async {
    final initial = await _initialMapPoint();
    if (!mounted) return;
    // Yandex map (WebView): pin fixed at centre, map pans under it, address is
    // geocoded from the point under the pin — returned together with coords.
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(
        builder: (_) => YandexMapPicker(initial: initial),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _latitude = result.point.latitude;
      _longitude = result.point.longitude;
      if (result.address.isNotEmpty) _addressCtrl.text = result.address;
    });
  }

  /// Initial map centre, by priority:
  /// already-picked point → selected district centre → region centre →
  /// user's current location (if permitted) → Tashkent fallback.
  Future<LatLng> _initialMapPoint() async {
    if (_latitude != null && _longitude != null) {
      return LatLng(_latitude!, _longitude!);
    }
    if (_areaCenter != null) return _areaCenter!;
    final region = _regionCenter;
    if (region != null) return region;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        return LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}
    return const LatLng(41.311081, 69.240562); // Tashkent
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _submitting = true);

    final db = ref.read(localDatabaseProvider);
    final api = ref.read(remoteApiServiceProvider);

    final name = _nameCtrl.text.trim();
    final inn = _innCtrl.text.trim();
    final phones = _phones;
    final phone = phones.isNotEmpty ? phones[0] : '';
    final phone2 = phones.length > 1 ? phones[1] : null;
    final phone3 = phones.length > 2 ? phones[2] : null;
    final address = _addressCtrl.text.trim();
    final responsible = _responsibleCtrl.text.trim();

    // Offline-first (mirrors addDoctor): write a local row with a negative
    // temp id so the org shows up immediately, then push if online or queue
    // it for the next sync.
    final tempId = -(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    try {
      await db.insertLocalOrganisation({
        'id': tempId,
        'name': name,
        'address': address,
        'type': _isLpu ? 'lpu' : 'pharmacy',
        'city': _regionName,
        'region_id': _regionId,
        'district': _areaName,
        'area_id': _areaId,
        'inn': inn,
        'category': _categoryName,
        'responsible': responsible.isEmpty ? null : responsible,
        'phone': phone.isEmpty ? null : phone,
        'latitude': _latitude,
        'longitude': _longitude,
        'is_favorite': 0,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('couldNotAddOrg', args: {'error': '$e'}))),
      );
      return;
    }

    final offline = ref.read(isOfflineProvider);
    var queued = false;
    if (!offline) {
      try {
        final remoteId = await api.createOrganization(
          name: name,
          inn: inn,
          typeId: _typeId,
          regionId: _regionId!,
          areaId: _areaId,
          phone: phone,
          phone2: phone2,
          phone3: phone3,
          address: address,
          categoryId: _categoryId,
          healthCareFacilityTypeId: _isLpu ? _facilityTypeId : null,
          revisionStatus: _isLpu ? _revisionStatus : null,
          responsiblePerson: responsible,
          latitude: _latitude,
          longitude: _longitude,
        );
        if (remoteId != null) {
          await db.replaceOrganizationTempId(tempId, remoteId);
        }
      } catch (_) {
        queued = true;
      }
    } else {
      queued = true;
    }

    if (queued) {
      await db.enqueuePendingOrganization(
        tempLocalId: tempId,
        name: name,
        inn: inn,
        typeId: _typeId,
        regionId: _regionId!,
        areaId: _areaId,
        phone: phone.isEmpty ? null : phone,
        phone2: phone2,
        phone3: phone3,
        address: address.isEmpty ? null : address,
        categoryId: _categoryId,
        healthCareFacilityTypeId: _isLpu ? _facilityTypeId : null,
        revisionStatus: _isLpu ? _revisionStatus : null,
        responsible: responsible.isEmpty ? null : responsible,
        latitude: _latitude,
        longitude: _longitude,
      );
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          queued ? l10n.t('organizationSavedOffline') : l10n.t('organizationAdded'),
        ),
      ),
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _latitude != null && _longitude != null;
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Column(
        children: [
          AppCenteredHeader(
            title: _isLpu
                ? context.l10n.t('addLpu')
                : context.l10n.t('addOrganization'),
            leftAlign: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: _loadingDicts
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _label(
                        _isLpu
                            ? context.l10n.t('lpuNameRequired')
                            : context.l10n.t('orgNameRequired'),
                      ),
                      _textField(
                        _nameCtrl,
                        _isLpu
                            ? context.l10n.t('lpuNamePlaceholder')
                            : context.l10n.t('orgNamePlaceholder'),
                      ),
                      const SizedBox(height: 14),
                      _label(context.l10n.t('innRequired')),
                      _textField(
                        _innCtrl,
                        '123456789',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          // Uzbek TIN (ИНН) is exactly 9 digits.
                          LengthLimitingTextInputFormatter(9),
                        ],
                      ),
                      // Revision status — LPU only.
                      if (_isLpu) ...[
                        const SizedBox(height: 14),
                        _label(context.l10n.t('revisionStatus')),
                        _revisionStatusSelector(),
                      ],
                      const SizedBox(height: 14),
                      _label(context.l10n.t('regionRequired')),
                      _selectField(
                        value: _regionName,
                        hint: context.l10n.t('selectRegion'),
                        onTap: _pickRegion,
                      ),
                      const SizedBox(height: 14),
                      _label(
                        _isLpu
                            ? context.l10n.t('areaRequired')
                            : context.l10n.t('area'),
                      ),
                      _selectField(
                        value: _areaName,
                        hint: _loadingAreas
                            ? context.l10n.t('searching')
                            : context.l10n.t('selectArea'),
                        onTap: _areas.isNotEmpty && !_loadingAreas
                            ? _pickArea
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _label(context.l10n.t('addressRequired')),
                      // Manual text input + a separate map button (web parity):
                      // typing edits the address freely; the map button picks a
                      // point and overwrites the address from it.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _textField(
                              _addressCtrl,
                              context.l10n.t('enterAddress'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppTapScale(
                            pressedScale: 0.92,
                            onTap: _pickOnMap,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD6DEE8),
                                  width: 0.8,
                                ),
                              ),
                              child: const Icon(
                                Icons.map_outlined,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Facility type — LPU only (optional).
                      if (_isLpu) ...[
                        const SizedBox(height: 14),
                        _label(context.l10n.t('lpuType')),
                        _selectField(
                          value: _facilityTypeName,
                          hint: context.l10n.t('selectLpuType'),
                          onTap: _facilityTypes.isNotEmpty
                              ? _pickFacilityType
                              : null,
                        ),
                      ],
                      const SizedBox(height: 14),
                      _phonesSection(),
                      const SizedBox(height: 14),
                      _label(context.l10n.t('category')),
                      _selectField(
                        value: _categoryName,
                        hint: context.l10n.t('selectCategory'),
                        onTap: _categories.isNotEmpty ? _pickCategory : null,
                      ),
                      const SizedBox(height: 14),
                      _label(context.l10n.t('responsiblePerson')),
                      _textField(
                        _responsibleCtrl,
                        context.l10n.t('responsiblePlaceholder'),
                      ),
                      const SizedBox(height: 14),
                      AppTapScale(
                        pressedScale: 0.98,
                        onTap: _pickOnMap,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.secondaryBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasLocation
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.location_on_outlined,
                                size: 18,
                                color: hasLocation
                                    ? AppColors.success
                                    : AppColors.secondaryText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hasLocation
                                    ? context.l10n.t('locationSet')
                                    : context.l10n.t('detectLocation'),
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: hasLocation
                                      ? AppColors.success
                                      : AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: ElevatedButton(
                onPressed: _canSubmit && !_submitting ? _submit : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(context.l10n.t('save')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryText,
      ),
    ),
  );

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? trailing,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.primaryText,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
          fontSize: 13,
          color: AppColors.hintText,
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: trailing,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD6DEE8), width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD6DEE8), width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
      ),
    );
  }

  Widget _selectField({
    required String? value,
    required String hint,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final selected = value != null && value.isNotEmpty;
    return AppTapScale(
      pressedScale: 0.99,
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF6F8FB),
          borderRadius: BorderRadius.circular(12),
          // Neutral border always — selection is shown by the blue text only.
          border: Border.all(color: const Color(0xFFD6DEE8), width: 0.8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected ? value : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  // Selected value uses the normal dark text (like the INN
                  // field), not blue. Blue is only for the picker dialog.
                  color: selected ? AppColors.primaryText : AppColors.hintText,
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: enabled
                  ? AppColors.hintText
                  : AppColors.hintText.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  /// Revision status radios (LPU): Не проверено / Сверено частично / полностью.
  Widget _revisionStatusSelector() {
    Widget radio(String value, String labelKey) {
      final selected = _revisionStatus == value;
      return InkWell(
        onTap: () => setState(() => _revisionStatus = value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? AppColors.primary : AppColors.hintText,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.t(labelKey),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        radio('none', 'revisionNone'),
        radio('partial', 'revisionPartial'),
        radio('full', 'revisionFull'),
      ],
    );
  }

  /// Phone list: single field for pharmacy, up to 3 with "+ Add phone" for LPU.
  Widget _phonesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(_isLpu ? context.l10n.t('phoneRequired') : context.l10n.t('phone')),
        for (var i = 0; i < _phoneCtrls.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _textField(
            _phoneCtrls[i],
            '+998901234567',
            keyboardType: TextInputType.phone,
            inputFormatters: [_UzPhoneFormatter()],
            trailing: (_isLpu && i > 0)
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.hintText,
                      size: 18,
                    ),
                    onPressed: () => _removePhoneField(i),
                  )
                : null,
          ),
        ],
        if (_isLpu) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AppTapScale(
              pressedScale: 0.97,
              onTap: _canAddPhone ? _addPhoneField : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    // Blue border when active (text is blue), grey when not.
                    color: _canAddPhone
                        ? AppColors.primary
                        : const Color(0xFFD6DEE8),
                    width: _canAddPhone ? 1 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: _canAddPhone
                          ? AppColors.primary
                          : AppColors.hintText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.t('addPhone'),
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _canAddPhone
                            ? AppColors.primary
                            : AppColors.hintText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}


/// Keeps the phone in Uzbek format: a `+998` prefix followed by up to 9 digits
/// (e.g. `+998901234567`). Strips anything else and caps the length.
class _UzPhoneFormatter extends TextInputFormatter {
  static const _prefix = '+998';
  static const _maxDigitsAfterPrefix = 9;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // The "+998" prefix is fixed. All digits are kept as one stream; the first
    // three (the 998 country code) belong to the prefix, the rest is the
    // subscriber number. Backspacing inside the prefix yields fewer than 3
    // digits → tail is empty → field stays "+998" (no "+99899" glitch, and the
    // 99 never "comes back").
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    var tail = digits.length > 3 ? digits.substring(3) : '';
    if (tail.length > _maxDigitsAfterPrefix) {
      tail = tail.substring(0, _maxDigitsAfterPrefix);
    }
    final text = '$_prefix$tail';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
