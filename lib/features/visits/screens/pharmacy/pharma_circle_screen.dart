import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/features/knowledge/data/drugs_repository.dart';
import 'package:lima/features/visits/data/visits_repository.dart';
import 'package:lima/core/models/local_visit.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/providers/dashboard_counts_provider.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';

import '../../../../core/models/models.dart';

class PharmaCircleScreen extends ConsumerStatefulWidget {
  final int pharmacyId;
  final String pharmacyName;

  const PharmaCircleScreen({
    super.key,
    required this.pharmacyId,
    this.pharmacyName = '',
  });

  @override
  ConsumerState<PharmaCircleScreen> createState() => _PharmaCircleScreenState();
}

class _PharmaCircleScreenState extends ConsumerState<PharmaCircleScreen> {
  List<Drug> _drugs = [];
  bool _loading = true;
  String _query = '';
  bool _actionLocked = false;
  final Map<int, Set<int>> _shownDocumentIdsByDrug = {};
  final Map<int, String> _shownDrugNamesByDrug = {};

  List<Drug> get _filtered => _drugs
      .where((d) => d.name.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  int get _shownMaterialsCount =>
      _shownDocumentIdsByDrug.values.fold(0, (sum, ids) => sum + ids.length);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDrugs());
  }

  Future<void> _loadDrugs() async {
    final db = ref.read(drugsRepositoryProvider);
    var rows = await db.getDrugs(
      onlyWithPositivePrice: false,
      onlyWithDocuments: true,
    );
    if (rows.isEmpty) {
      rows = await db.getDrugs(onlyWithPositivePrice: false);
    }
    final loaded = rows.map(Drug.fromJson).toList();
    if (!mounted) return;
    setState(() {
      _drugs = loaded;
      _loading = false;
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
              16,
              MediaQuery.of(context).padding.top + 8,
              16,
              12,
            ),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    context.canPop()
                        ? context.pop()
                        : context.go('/visits');
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.primaryText,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.t('pharmCircle'),
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                      if (widget.pharmacyName.isNotEmpty)
                        Text(
                          widget.pharmacyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextFormField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: context.l10n.t('searchDrugs'),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.hintText,
                  size: 20,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _filtered.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: context.l10n.t('nothingFound'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final drug = _filtered[i];
                      final shownCount =
                          _shownDocumentIdsByDrug[drug.id]?.length ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => _openMaterials(drug),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.secondaryBg,
                              borderRadius: BorderRadius.circular(14),
                              border: shownCount > 0
                                  ? Border.all(color: AppColors.primary)
                                  : Border.all(color: Colors.transparent),
                              boxShadow: shadowSm,
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        drug.name,
                                        style: GoogleFonts.manrope(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        drug.manufacturer.isNotEmpty
                                            ? context.l10n.t('mfrMaterialsN', args: {'mfr': drug.manufacturer, 'count': '${drug.documentsCount}'})
                                            : context.l10n.t('materialsCountN', args: {'count': '${drug.documentsCount}'}),
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (shownCount > 0) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF0FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$shownCount',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.hintText,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              boxShadow: shadowMd,
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            child: ElevatedButton(
              onPressed: _actionLocked ? null : _openFinishSheet,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                context.l10n.t('finish'),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMaterials(Drug drug) async {
    if ((_shownDocumentIdsByDrug[drug.id]?.isNotEmpty ?? false)) {
      setState(() {
        _shownDocumentIdsByDrug.remove(drug.id);
        _shownDrugNamesByDrug.remove(drug.id);
      });
      return;
    }

    final db = ref.read(drugsRepositoryProvider);
    final materials = await db.getDrugMaterials(drug.id);
    if (!mounted) return;
    if (materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('materialsNotFound')),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final selectedIndex = materials.length == 1
        ? 0
        : await showModalBottomSheet<int>(
            context: context,
            useRootNavigator: true,
            backgroundColor: AppColors.secondaryBg,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.t('materials'),
                            style: GoogleFonts.manrope(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      drug.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: materials.length,
                        itemBuilder: (_, index) {
                          final material = materials[index];
                          final title = _materialTitle(material);
                          final type = _materialType(material);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppTapScale(
                              onTap: () => Navigator.pop(ctx, index),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      type.toUpperCase(),
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
    if (selectedIndex == null || !mounted) return;

    final material = materials[selectedIndex];
    final documentId = _remoteDocumentId(material);
    if (documentId != null) {
      setState(() {
        _shownDocumentIdsByDrug
            .putIfAbsent(drug.id, () => <int>{})
            .add(documentId);
        _shownDrugNamesByDrug[drug.id] = drug.name;
      });
    }

    await context.push(
      Uri(
        path: '/knowledge/drug/${drug.id}/materials',
        queryParameters: {'index': '$selectedIndex'},
      ).toString(),
    );
  }

  String _materialTitle(Map<String, dynamic> material) {
    return (material['title'] as String?)?.trim().isNotEmpty == true
        ? material['title'] as String
        : context.l10n.t('material');
  }

  String _materialType(Map<String, dynamic> material) {
    final raw = material['file_type'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    final rawJson = material['raw_json'];
    if (rawJson is String && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          final type = decoded['document_type_name'] ?? decoded['file_name'];
          if (type is String && type.trim().isNotEmpty) return type.trim();
        }
      } catch (_) {}
    }
    return 'file';
  }

  int? _remoteDocumentId(Map<String, dynamic> material) {
    final rawJson = material['raw_json'];
    if (rawJson is String && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          return _asInt(decoded['id'] ?? decoded['document_id']);
        }
      } catch (_) {}
    }
    return _asInt(material['document_id'] ?? material['remote_id']);
  }

  int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _openFinishSheet() async {
    final payload = await showAppSheet<_CircleFinishPayload>(
      context,
      useRootNavigator: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CircleFinishSheet(
        drugsCount: _shownDocumentIdsByDrug.length,
        materialsCount: _shownMaterialsCount,
      ),
    );
    if (payload == null || !mounted) return;
    await _finishCircle(payload);
  }

  Future<void> _finishCircle(_CircleFinishPayload payload) async {
    if (_actionLocked) return;
    setState(() => _actionLocked = true);
    final now = DateTime.now().toIso8601String();
    int? localId;
    try {
      final talkedAboutDrugs = _shownDocumentIdsByDrug.entries
          .where((entry) => entry.value.isNotEmpty)
          .map((entry) {
            final documentIds = entry.value.toList()..sort();
            return {'drug_id': entry.key, 'document_ids': documentIds};
          })
          .toList();
      final rawVisitJson = jsonEncode({
        'organization_id': widget.pharmacyId,
        'organization_name': widget.pharmacyName,
        'visit_type': 1,
        'visit_format': 1,
        'visit_format_name': context.l10n.t('pharmCircle'),
        'status': 'completed',
        'pharmacists_fio': payload.fio.trim(),
        'participants_count': payload.participantsCount,
        'discussed_drugs_count': talkedAboutDrugs.length,
        'materials_shown_count': _shownMaterialsCount,
        'visit_pharm_circle': {
          'pharmacist_names': payload.fio.trim(),
          'start': now,
          'end': now,
          'number_of_participants': payload.participantsCount,
        },
        'talked_about_drugs': talkedAboutDrugs,
        'start_date': now,
        'end_date': now,
      });
      localId = await ref.read(visitsRepositoryProvider).insertVisit({
        'remote_id': null,
        'org_id': widget.pharmacyId,
        'org_name': widget.pharmacyName,
        'doctor_id': null,
        'doctor_name': null,
        'visit_type': 'circle',
        'status': 'completed',
        'notes': payload.fio.trim(),
        'medical_rep_name': ref.read(authProvider).user?.fullName,
        'created_at': now,
        'updated_at': now,
        'raw_json': rawVisitJson,
      });
      ref.invalidate(dashboardCountsProvider);
      final isOffline = ref.read(isOfflineProvider);
      if (!isOffline) {
        try {
          final createdAt = DateTime.tryParse(now) ?? DateTime.now();
          final pushResult = await ref
              .read(visitsRepositoryProvider)
              .pushUnsyncedVisitDebug(
                LocalVisit(
                  id: localId,
                  remoteId: null,
                  orgId: widget.pharmacyId,
                  orgName: widget.pharmacyName,
                  visitType: 'circle',
                  status: 'completed',
                  notes: payload.fio.trim(),
                  createdAt: createdAt,
                  updatedAt: createdAt,
                  isSynced: false,
                  rawJson: rawVisitJson,
                ),
              );
          await ref.read(visitsRepositoryProvider).markSynced([localId]);
          final responseObj = pushResult['response'];
          final remoteId = switch (responseObj) {
            int v => v,
            String s => int.tryParse(s),
            Map<String, dynamic> m =>
              (m['id'] as num?)?.toInt() ??
                  (m['visit_id'] as num?)?.toInt() ??
                  (m['data'] is Map<String, dynamic>
                      ? ((m['data']['id'] as num?)?.toInt() ??
                            (m['data']['visit_id'] as num?)?.toInt())
                      : null),
            _ => null,
          };
          if (remoteId != null) {
            await ref
                .read(visitsRepositoryProvider)
                .updateVisitRemoteId(localVisitId: localId, remoteId: remoteId);
          }
        } catch (_) {}
      }
    } catch (_) {}
    if (ref.read(isOfflineProvider)) {
      pulseOfflineBanner(ref);
    }
    if (!mounted) return;
    await _showSuccessDialog(payload);
  }

  Future<void> _showSuccessDialog(_CircleFinishPayload payload) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 46),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F5ED),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.success,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.t('visitDone'),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 10),
                _summaryLine(context.l10n.t('visitType'), context.l10n.t('pharmCircle')),
                _summaryLine(context.l10n.t('organization'), widget.pharmacyName.toUpperCase()),
                _summaryLine(context.l10n.t('pharmacistsNames'), payload.fio),
                _summaryLine(
                  context.l10n.t('participantsCount'),
                  context.l10n.t('participantsN', args: {'count': '${payload.participantsCount}'}),
                ),
                _summaryLine(
                  context.l10n.t('discussedDrugs'),
                  _shownDrugNamesByDrug.isEmpty
                      ? context.l10n.t('drugsNotDiscussed')
                      : context.l10n.t('pcsN', args: {'n': '${_shownDrugNamesByDrug.length}'}),
                ),
                _summaryLine(
                  context.l10n.t('shownMaterials'),
                  context.l10n.t('pcsN', args: {'n': '$_shownMaterialsCount'}),
                ),
                _summaryLine(
                  context.l10n.t('status'),
                  context.l10n.t('finished'),
                  valueColor: const Color(0xFF34A36A),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.pushReplacement(
                            Uri(
                              path:
                                  '/visits/pharmacy/detail/${widget.pharmacyId}',
                              queryParameters: {'name': widget.pharmacyName},
                            ).toString(),
                          );
                        },
                        child: Text(
                          context.l10n.t('toOrganization'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.go(
                            '/home?refresh=${DateTime.now().millisecondsSinceEpoch}',
                          );
                        },
                        child: Text(
                          context.l10n.t('toHome'),
                          maxLines: 1,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryLine(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor ?? AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleFinishPayload {
  final String fio;
  final int participantsCount;

  const _CircleFinishPayload({
    required this.fio,
    required this.participantsCount,
  });
}

class _CircleFinishSheet extends StatefulWidget {
  final int drugsCount;
  final int materialsCount;

  const _CircleFinishSheet({
    required this.drugsCount,
    required this.materialsCount,
  });

  @override
  State<_CircleFinishSheet> createState() => _CircleFinishSheetState();
}

class _CircleFinishSheetState extends State<_CircleFinishSheet> {
  final _fioCtrl = TextEditingController();
  String _participantsStr = '1';

  @override
  void dispose() {
    _fioCtrl.dispose();
    super.dispose();
  }

  void _onKey(String key) {
    setState(() {
      if (key == 'C') {
        _participantsStr = '1';
      } else if (key == '←') {
        if (_participantsStr.length <= 1) {
          _participantsStr = '1';
        } else {
          _participantsStr = _participantsStr.substring(
            0,
            _participantsStr.length - 1,
          );
        }
      } else {
        if (_participantsStr == '0' || _participantsStr == '1' && key != '0') {
          _participantsStr = key;
        } else {
          _participantsStr = _participantsStr + key;
        }
      }
      final v = int.tryParse(_participantsStr) ?? 1;
      if (v < 1) _participantsStr = '1';
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateTime =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final participants = int.tryParse(_participantsStr) ?? 1;
    final canSubmit = _fioCtrl.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            12,
            0,
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  context.l10n.t('completion'),
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('pharmacistsNames'),
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _fioCtrl,
                  onChanged: (_) => setState(() {}),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: context.l10n.t('pharmacistsPlaceholder'),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.t('participantsCount'),
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _step(() {
                      setState(() {
                        final cur = int.tryParse(_participantsStr) ?? 1;
                        _participantsStr = (cur > 1 ? cur - 1 : 1).toString();
                      });
                    }, Icons.remove_rounded),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFE49351),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _participantsStr,
                          style: GoogleFonts.manrope(
                            fontSize: 24,
                            color: const Color(0xFFE49351),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _step(() {
                      setState(() {
                        final cur = int.tryParse(_participantsStr) ?? 1;
                        _participantsStr = (cur + 1).toString();
                      });
                    }, Icons.add_rounded),
                  ],
                ),
                const SizedBox(height: 10),
                _CircleNumKeypad(onKey: _onKey),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _meta(context.l10n.t('startColon'), dateTime),
                      const Divider(height: 10),
                      _meta(context.l10n.t('endColon'), dateTime),
                      const Divider(height: 10),
                      _meta(context.l10n.t('discussedDrugsColon'), '${widget.drugsCount}'),
                      const Divider(height: 10),
                      _meta(context.l10n.t('shownMaterialsColon'), '${widget.materialsCount}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: ElevatedButton(
              onPressed: canSubmit
                  ? () => Navigator.pop(
                      context,
                      _CircleFinishPayload(
                        fio: _fioCtrl.text.trim(),
                        participantsCount: participants,
                      ),
                    )
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                context.l10n.t('finish'),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(VoidCallback onTap, IconData icon) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primaryBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primaryText),
      ),
    );
  }

  Widget _meta(String l, String r) {
    return Row(
      children: [
        Text(
          l,
          style: GoogleFonts.manrope(
            fontSize: 16,
            color: AppColors.primaryText,
          ),
        ),
        const Spacer(),
        Text(
          r,
          style: GoogleFonts.manrope(
            fontSize: 16,
            color: AppColors.primaryText,
          ),
        ),
      ],
    );
  }
}

class _CircleNumKeypad extends StatelessWidget {
  final void Function(String key) onKey;

  const _CircleNumKeypad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '←'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: keys.map((k) {
        final isAction = k == 'C' || k == '←';
        return GestureDetector(
          onTap: () => onKey(k),
          child: Container(
            decoration: BoxDecoration(
              color: isAction ? const Color(0xFFEEF0F3) : AppColors.primaryBg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              k,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isAction
                    ? AppColors.secondaryText
                    : AppColors.primaryText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
