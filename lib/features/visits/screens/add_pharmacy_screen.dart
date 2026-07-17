import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/swallowed.dart';
import '../domain/entities/organisation_draft.dart';
import '../presentation/view_models/add_pharmacy_view_model.dart';
import '../providers/add_pharmacy_provider.dart';
import '../providers/visits_hub_provider.dart';
import '../widgets/organisation_form_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addPharmacyViewModelProvider(_isLpu).notifier).load();
    });
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

  bool _canSubmit(AddPharmacyViewState form) =>
      _nameCtrl.text.trim().isNotEmpty &&
      _innCtrl.text.trim().isNotEmpty &&
      form.regionId != null &&
      // District is required for LPU (matches web).
      (!_isLpu || form.areaId != null) &&
      _addressCtrl.text.trim().isNotEmpty;

  /// Non-empty trimmed phone numbers (LPU may have up to 3).
  List<String> get _phones => _phoneCtrls
      .map((c) => c.text.trim())
      .where((p) => p.isNotEmpty && p != '+998')
      .toList();

  Future<void> _pickRegion() async {
    final form = ref.read(addPharmacyViewModelProvider(_isLpu));
    final picked = await showOrganisationPicker(
      context: context,
      title: context.l10n.t('selectRegion'),
      options: form.regions,
      selectedId: form.regionId,
    );
    if (picked == null || !mounted) return;
    await ref
        .read(addPharmacyViewModelProvider(_isLpu).notifier)
        .selectRegion(picked['id'] as int, picked['name'] as String);
  }

  Future<void> _pickArea() async {
    final form = ref.read(addPharmacyViewModelProvider(_isLpu));
    if (form.areas.isEmpty) return;
    final picked = await showOrganisationPicker(
      context: context,
      title: context.l10n.t('selectArea'),
      options: form.areas
          .map(
            (area) => <String, dynamic>{
              'id': area.id,
              'name': area.name,
              'latitude': area.latitude,
              'longitude': area.longitude,
            },
          )
          .toList(growable: false),
      selectedId: form.areaId,
    );
    if (picked == null || !mounted) return;
    final selected = form.areas.firstWhere((area) => area.id == picked['id']);
    ref.read(addPharmacyViewModelProvider(_isLpu).notifier).setArea(selected);
  }

  /// Approx region centre = average of its districts' coordinates (regions
  /// themselves carry no lat/lng from the API).
  LatLng? _regionCenter(AddPharmacyViewState form) {
    final points = form.areas
        .map((area) {
          return (area.latitude != null && area.longitude != null)
              ? LatLng(area.latitude!, area.longitude!)
              : null;
        })
        .whereType<LatLng>()
        .toList();
    if (points.isEmpty) return null;
    final lat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  Future<void> _pickCategory() async {
    final form = ref.read(addPharmacyViewModelProvider(_isLpu));
    final picked = await showOrganisationPicker(
      context: context,
      title: context.l10n.t('selectCategory'),
      options: form.categories,
      selectedId: form.categoryId,
    );
    if (picked == null || !mounted) return;
    ref.read(addPharmacyViewModelProvider(_isLpu).notifier).setCategory(picked);
  }

  Future<void> _pickFacilityType() async {
    final form = ref.read(addPharmacyViewModelProvider(_isLpu));
    final picked = await showOrganisationPicker(
      context: context,
      title: context.l10n.t('selectLpuType'),
      options: form.facilityTypes,
      selectedId: form.facilityTypeId,
    );
    if (picked == null || !mounted) return;
    ref
        .read(addPharmacyViewModelProvider(_isLpu).notifier)
        .setFacilityType(picked);
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

  Future<void> _pickOnMap() async {
    final initial = await _initialMapPoint(
      ref.read(addPharmacyViewModelProvider(_isLpu)),
    );
    if (!mounted) return;
    // Yandex map (WebView): pin fixed at centre, map pans under it, address is
    // geocoded from the point under the pin — returned together with coords.
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(builder: (_) => YandexMapPicker(initial: initial)),
    );
    if (result == null || !mounted) return;
    ref
        .read(addPharmacyViewModelProvider(_isLpu).notifier)
        .setLocation(
          latitude: result.point.latitude,
          longitude: result.point.longitude,
        );
    if (result.address.isNotEmpty) _addressCtrl.text = result.address;
  }

  /// Initial map centre, by priority:
  /// already-picked point → selected district centre → region centre →
  /// user's current location (if permitted) → Tashkent fallback.
  Future<LatLng> _initialMapPoint(AddPharmacyViewState form) async {
    if (form.latitude != null && form.longitude != null) {
      return LatLng(form.latitude!, form.longitude!);
    }
    final selectedArea = form.areas.where((area) => area.id == form.areaId);
    final area = selectedArea.isEmpty ? null : selectedArea.first;
    if (area?.latitude != null && area?.longitude != null) {
      return LatLng(area!.latitude!, area.longitude!);
    }
    final region = _regionCenter(form);
    if (region != null) return region;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        return LatLng(pos.latitude, pos.longitude);
      }
    } catch (error) {
      logSwallowed(error, 'AddPharmacyScreen.createLocalOrganisation');
    }
    return const LatLng(41.311081, 69.240562); // Tashkent
  }

  Future<void> _submit() async {
    final form = ref.read(addPharmacyViewModelProvider(_isLpu));
    final viewModel = ref.read(addPharmacyViewModelProvider(_isLpu).notifier);
    if (!_canSubmit(form) || form.isSubmitting) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    viewModel.setSubmitting(true);

    final name = _nameCtrl.text.trim();
    final inn = _innCtrl.text.trim();
    final phones = _phones;
    final phone = phones.isNotEmpty ? phones[0] : '';
    final phone2 = phones.length > 1 ? phones[1] : null;
    final phone3 = phones.length > 2 ? phones[2] : null;
    final address = _addressCtrl.text.trim();
    final responsible = _responsibleCtrl.text.trim();
    final draft = OrganisationDraft(
      name: name,
      inn: inn,
      type: _isLpu ? OrgType.lpu : OrgType.pharmacy,
      typeId: _typeId,
      regionId: form.regionId!,
      regionName: form.regionName,
      areaId: form.areaId,
      areaName: form.areaName,
      phone: phone.isEmpty ? null : phone,
      phone2: phone2,
      phone3: phone3,
      address: address.isEmpty ? null : address,
      categoryId: form.categoryId,
      categoryName: form.categoryName,
      healthCareFacilityTypeId: _isLpu ? form.facilityTypeId : null,
      healthCareFacilityTypeName: _isLpu ? form.facilityTypeName : null,
      revisionStatus: _isLpu ? form.revisionStatus : null,
      responsible: responsible.isEmpty ? null : responsible,
      latitude: form.latitude,
      longitude: form.longitude,
    );
    final repository = ref.read(organisationsDirectoryRepositoryProvider);

    // Offline-first (mirrors addDoctor): write a local row with a negative
    // temp id so the org shows up immediately, then push if online or queue
    // it for the next sync.
    final tempId = -(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    try {
      await repository.insertLocalOrganisation(
        draft.toLocalModel(
          id: tempId,
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      viewModel.setSubmitting(false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.t('couldNotAddOrg', args: {'error': '$e'})),
        ),
      );
      return;
    }

    final offline = ref.read(isOfflineProvider);
    var queued = false;
    if (!offline) {
      try {
        final remoteId = await repository.createRemoteOrganisation(draft);
        if (remoteId != null) {
          await repository.replaceOrganisationTempId(tempId, remoteId);
        }
      } catch (_) {
        queued = true;
      }
    } else {
      queued = true;
    }

    if (queued) {
      await repository.enqueueNewOrganisation(
        tempLocalId: tempId,
        draft: draft,
      );
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          queued
              ? l10n.t('organizationSavedOffline')
              : l10n.t('organizationAdded'),
        ),
      ),
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(addPharmacyViewModelProvider(_isLpu));
    final hasLocation = form.latitude != null && form.longitude != null;
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
            child: form.isLoading
                ? const Center(child: CircularProgressIndicator())
                : OrganisationFormBody(
                    isLpu: _isLpu,
                    form: form,
                    nameController: _nameCtrl,
                    innController: _innCtrl,
                    addressController: _addressCtrl,
                    responsibleController: _responsibleCtrl,
                    phoneControllers: _phoneCtrls,
                    hasLocation: hasLocation,
                    canAddPhone: _canAddPhone,
                    onTextChanged: () => setState(() {}),
                    onPickRegion: _pickRegion,
                    onPickArea: _pickArea,
                    onPickFacilityType: _pickFacilityType,
                    onPickCategory: _pickCategory,
                    onPickMap: _pickOnMap,
                    onAddPhone: _addPhoneField,
                    onRemovePhone: _removePhoneField,
                    onRevisionStatusChanged: (value) => ref
                        .read(addPharmacyViewModelProvider(_isLpu).notifier)
                        .setRevisionStatus(value),
                    onPhoneChanged: (_) => setState(() {}),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: ElevatedButton(
                onPressed: _canSubmit(form) && !form.isSubmitting
                    ? _submit
                    : null,
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
                child: form.isSubmitting
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
}
