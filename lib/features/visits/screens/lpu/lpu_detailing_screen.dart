import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/dialogs/medical_status_sheet.dart';
import 'package:lima/core/models/local_visit.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/services/in_app_notifications_service.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/core/providers/dashboard_counts_provider.dart';

final _detailingDrugs = [
  {
    'name': 'абелла суппозиториивагинальные №7',
    'manufacturer': 'SHARQ DARMON OOO',
    'mandatory': 'true',
  },
  {
    'name': 'адамант, таб. покрытые пленочной оболочкой 100мг, №10',
    'manufacturer': 'KWALITY PHARMACEUTICAL, INDIA',
    'mandatory': 'false',
  },
  {
    'name':
        'адеус концентрат для приготовления р-ра для инфузий 5мг/мл 2 мл № 5',
    'manufacturer': 'BAYAN MEDICAL OOO',
    'mandatory': 'true',
  },
  {
    'name': 'адэтта раствор для инфузий 100мл',
    'manufacturer': 'TEMUR MED',
    'mandatory': 'false',
  },
  {
    'name': 'аккорд раствор для инфузий 50 мл',
    'manufacturer': 'TEMUR MED',
    'mandatory': 'false',
  },
  {
    'name': 'аксона раствор для инфузий 0.3 мг/мл 100 мл',
    'manufacturer': 'TEMUR MED',
    'mandatory': 'false',
  },
];

class LpuDetailingScreen extends ConsumerStatefulWidget {
  final int orgId;
  final int doctorId;
  final String doctorName;
  final String orgName;
  final String? doctorIds;
  final int? visitId;

  const LpuDetailingScreen({
    super.key,
    required this.orgId,
    required this.doctorId,
    required this.doctorName,
    this.orgName = '',
    this.doctorIds,
    this.visitId,
  });

  @override
  ConsumerState<LpuDetailingScreen> createState() => _LpuDetailingScreenState();
}

class _LpuDetailingScreenState extends ConsumerState<LpuDetailingScreen> {
  String _query = '';
  final Map<String, DrugStatus> _statuses = {};
  List<Map<String, dynamic>> _doctors = [];
  bool _actionLocked = false;
  // drugName → {id, documents_count}
  final Map<String, Map<String, dynamic>> _drugDbData = {};
  final InAppNotificationsService _notificationsService =
      InAppNotificationsService();

  List<int> get _allDoctorIds {
    if (widget.doctorIds != null && widget.doctorIds!.isNotEmpty) {
      return widget.doctorIds!
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
    }
    return [widget.doctorId];
  }

  List<Map<String, String>> get _filtered => _detailingDrugs
      .where((d) => d['name']!.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDoctors());
  }

  Future<void> _loadDoctors() async {
    final db = ref.read(localDatabaseProvider);
    final ids = _allDoctorIds;
    final results = await db.getDoctors(
      orgId: widget.orgId,
      includeGlobalFallback: false,
    );
    final list = results
        .map((e) => Map<String, dynamic>.from(e))
        .where((d) => ids.contains((d['id'] as num?)?.toInt()))
        .toList();
    // Load drug documents_count from DB
    final dbDrugs = await db.getDrugs(onlyWithPositivePrice: false);
    final drugMap = <String, Map<String, dynamic>>{};
    for (final row in dbDrugs) {
      final n = (row['name'] as String? ?? '').toLowerCase();
      if (n.isNotEmpty) drugMap[n] = row;
    }
    if (!mounted) return;
    setState(() {
      _doctors = list;
      _drugDbData
        ..clear()
        ..addAll(drugMap);
    });
  }

  Future<void> _finishVisit() async {
    if (_actionLocked) return;
    setState(() => _actionLocked = true);
    final selectedDrugs = _statuses.keys.toList();
    final now = DateTime.now().toIso8601String();
    final comment = selectedDrugs.isEmpty
        ? 'Без выбора препаратов'
        : 'Препаратов: ${selectedDrugs.length}';
    final medRepName = ref.read(authProvider).user?.fullName ?? '—';
    int? localId;
    var apiOk = false;
    var localOk = false;

    if (widget.visitId != null) {
      try {
        await ref
            .read(remoteApiServiceProvider)
            .updateVisit(
              widget.visitId!,
              data: {'complete': true, 'comment': comment, 'end_date': now},
            );
        await ref
            .read(localDatabaseProvider)
            .updateVisitStatusByRemoteId(
              widget.visitId!,
              'completed',
              notes: comment,
            );

        final positive = _statuses.values
            .where(
              (s) =>
                  s == DrugStatus.familiarPrescribes ||
                  s == DrugStatus.familiarNotPrescribes,
            )
            .length;
        final rating = _statuses.isEmpty
            ? 0
            : ((positive / _statuses.length) * 5).round().clamp(1, 5);

        await ref
            .read(remoteApiServiceProvider)
            .markDoctorVisited(
              doctorId: widget.doctorId,
              organizationId: widget.orgId,
              visitId: widget.visitId,
            );

        await ref
            .read(remoteApiServiceProvider)
            .rateVisit(
              visitId: widget.visitId!,
              rating: rating,
              comment: comment,
            );
        apiOk = true;
      } catch (_) {
        // Keep UI flow and local completion dialog even if network failed.
      }
    } else {
      // Manual flow (without pre-created plan): persist visit locally so it
      // appears in offline history/home and can be synced later.
      try {
        final presentations = selectedDrugs.map((name) {
          final meta = _detailingDrugs.firstWhere(
            (e) => e['name'] == name,
            orElse: () => const <String, String>{},
          );
          final status = _statuses[name];
          final statusCode = switch (status) {
            DrugStatus.familiarPrescribes => 'familiar_prescribes',
            DrugStatus.familiarNotPrescribes => 'familiar_not_prescribes',
            DrugStatus.unfamiliar => 'not_familiar',
            DrugStatus.other => 'other',
            _ => '',
          };
          return <String, dynamic>{
            'drug_name': name,
            'manufacturer': meta['manufacturer'] ?? '',
            'status': statusCode,
          };
        }).toList();

        final isGroupVisit =
            widget.doctorIds != null && widget.doctorIds!.contains(',');
        final rawVisitJson = jsonEncode({
          'organization_id': widget.orgId,
          'organization_name': widget.orgName,
          'visit_type': 2,
          if (isGroupVisit) 'visit_format': 3,
          if (isGroupVisit) 'visit_format_id': 3,
          if (isGroupVisit) 'visit_format_name': 'Групповая презентация',
          'doctor_ids': _allDoctorIds,
          'doctor_name': widget.doctorName,
          'medical_representative_name': medRepName,
          'presentations': presentations,
          'talked_about_drugs': presentations,
          'status': 'completed',
          'comment': comment,
          'start_date': now,
          'end_date': now,
        });
        localId = await ref.read(localDatabaseProvider).insertVisit({
          'remote_id': null,
          'org_id': widget.orgId,
          'org_name': widget.orgName,
          'doctor_id': widget.doctorId,
          'doctor_name': widget.doctorName,
          'visit_type': 'lpu',
          'status': 'completed',
          'notes': comment,
          'medical_rep_name': medRepName,
          'created_at': now,
          'updated_at': now,
          'raw_json': rawVisitJson,
        });
        ref.invalidate(dashboardCountsProvider);
        localOk = true;
        final isOffline = ref.read(isOfflineProvider);
        if (!isOffline) {
          try {
            final pushResult = await ref
                .read(remoteApiServiceProvider)
                .pushUnsyncedVisitDebug(
                  LocalVisit(
                    id: localId,
                    remoteId: null,
                    orgId: widget.orgId,
                    orgName: widget.orgName,
                    doctorId: widget.doctorId,
                    doctorName: widget.doctorName,
                    visitType: 'lpu',
                    status: 'completed',
                    notes: comment,
                    createdAt: DateTime.tryParse(now) ?? DateTime.now(),
                    updatedAt: DateTime.tryParse(now) ?? DateTime.now(),
                    isSynced: false,
                    rawJson: rawVisitJson,
                  ),
                );
            await ref.read(localDatabaseProvider).markSynced([localId]);
            apiOk = true;
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
                  .read(localDatabaseProvider)
                  .updateVisitRemoteId(
                    localVisitId: localId,
                    remoteId: remoteId,
                  );
            }
            await ref
                .read(localDatabaseProvider)
                .setVisitPushPayload(
                  visitId: localId,
                  requestJson: jsonEncode(pushResult['request']),
                  responseJson: jsonEncode(pushResult['response']),
                );
          } catch (e) {
            debugPrint('pushUnsyncedVisitDebug failed: $e');
          }
        }
      } catch (_) {}
    }

    if (ref.read(isOfflineProvider)) {
      pulseOfflineBanner(ref);
    }
    if (!mounted) return;
    final db = ref.read(localDatabaseProvider);
    final localRows = await db.getVisits();
    if (widget.visitId == null && localId != null) {
      final exists = localRows.any((r) => (r['id'] as int?) == localId);
      localOk = exists;
      if (!exists) {
        debugPrint('Local visit row not found after insert: id=$localId');
      }
    }
    await _notificationsService.add(
      title: 'Визит завершён',
      body: apiOk
          ? 'Визит отправлен в API и сохранён локально.'
          : (localOk
                ? 'Визит сохранён локально и будет отправлен при синхронизации.'
                : 'Визит завершён, но локальное сохранение не подтверждено.'),
      kind: 'visit',
    );
    final org = await ref
        .read(localDatabaseProvider)
        .getOrganisationById(widget.orgId);
    if (!mounted) return;
    final orgAddress = '${org?['address'] ?? ''}'.trim();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isGroup = _allDoctorIds.length > 1;
        final doctorsLabel = isGroup ? 'Врачи' : 'Врач';
        final subtitle = isGroup ? 'Групповая презентация' : 'Презентация 1:1';
        final firstDrug = selectedDrugs.isEmpty
            ? 'Нет выбранных препаратов'
            : selectedDrugs.first;
        final firstStatus = selectedDrugs.isEmpty
            ? null
            : _statuses[selectedDrugs.first];
        final firstStatusText = switch (firstStatus) {
          DrugStatus.familiarPrescribes => 'Ознакомлен, выписывает',
          DrugStatus.familiarNotPrescribes => 'Ознакомлен, не выписывает',
          DrugStatus.unfamiliar => 'Не знаком',
          DrugStatus.other => 'Комментарий',
          _ => null,
        };
        final firstStatusColor = switch (firstStatus) {
          DrugStatus.familiarPrescribes => const Color(0xFF55B98A),
          DrugStatus.familiarNotPrescribes => const Color(0xFFC89B3C),
          DrugStatus.unfamiliar => const Color(0xFFE35D5B),
          DrugStatus.other => AppColors.secondaryText,
          _ => AppColors.secondaryText,
        };
        final firstStatusBg = switch (firstStatus) {
          DrugStatus.familiarPrescribes => const Color(0xFFE4F6EE),
          DrugStatus.familiarNotPrescribes => const Color(0xFFFAF1DF),
          DrugStatus.unfamiliar => const Color(0xFFFCE7E7),
          DrugStatus.other => const Color(0xFFEFF2F7),
          _ => const Color(0xFFEFF2F7),
        };

        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDDF8EC),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFF55C796),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Визит завершён',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.divider),
                  _dialogRow('Организация', widget.orgName),
                  if (orgAddress.isNotEmpty) ...[
                    const Divider(height: 1, color: AppColors.divider),
                    _dialogRow('Адрес', orgAddress),
                  ],
                  const Divider(height: 1, color: AppColors.divider),
                  _dialogRow(doctorsLabel, widget.doctorName),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 10),
                  Text(
                    'Препараты (${selectedDrugs.length})',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            firstDrug,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                        if (firstStatusText != null)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: firstStatusBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              firstStatusText,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: firstStatusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go(
                        Uri(
                          path: '/visits/lpu/detail/${widget.orgId}',
                          queryParameters: {'name': widget.orgName},
                        ).toString(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    child: const Text('К организации'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go(
                        '/home?refresh=${DateTime.now().millisecondsSinceEpoch}',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    child: const Text('На главную'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDoctorsDialog() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DoctorsInfoSheet(doctors: _doctors),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canFinish = _statuses.isNotEmpty;
    final doctorCount = _allDoctorIds.length;
    final countLabel = _pluralDoctors(doctorCount);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primaryBg,
        body: Column(
          children: [
            Container(
              color: AppColors.primary,
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 8,
                16,
                14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppTapScale(
                        pressedScale: 0.9,
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                            return;
                          }
                          context.go(
                            Uri(
                              path:
                                  '/visits/lpu/detail/${widget.orgId}/doctors',
                              queryParameters: {'name': widget.orgName},
                            ).toString(),
                          );
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.orgName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  countLabel,
                                  style: GoogleFonts.manrope(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: _showDoctorsDialog,
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Поиск препарата...',
                      prefixIcon: Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Ничего не найдено',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final d = _filtered[i];
                        final name = d['name']!;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _statuses.containsKey(name)
                                  ? const Color(0xFFEAF0FF)
                                  : AppColors.secondaryBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _statuses.containsKey(name)
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: _statuses.containsKey(name) ? 1.5 : 0.5,
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryText,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        d['manufacturer']!,
                                        style: GoogleFonts.manrope(
                                          color: AppColors.secondaryText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Builder(
                                  builder: (_) {
                                    final dbRow =
                                        _drugDbData[name.toLowerCase()];
                                    final docsCount =
                                        (dbRow?['documents_count'] as num?)
                                            ?.toInt() ??
                                        0;
                                    final drugId = (dbRow?['id'] as num?)
                                        ?.toInt();
                                    final hasDoc =
                                        docsCount > 0 && drugId != null;
                                    return _ActionIconBox(
                                      icon: Icons.description_outlined,
                                      active: false,
                                      disabled: !hasDoc,
                                      onTap: hasDoc
                                          ? () => context.push(
                                              '/knowledge/drug/$drugId/materials',
                                            )
                                          : () {},
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                _ActionIconBox(
                                  icon: Icons.assignment_outlined,
                                  active: _statuses.containsKey(name),
                                  onTap: () async {
                                    final status = await showMedicalStatusSheet(
                                      context,
                                      drugName: name,
                                    );
                                    if (status == null) return;
                                    setState(() => _statuses[name] = status);
                                  },
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
        bottomNavigationBar: Container(
          color: AppColors.secondaryBg,
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            MediaQuery.of(context).padding.bottom + 8,
          ),
          child: AppTapScale(
            pressedScale: 0.97,
            onTap: (canFinish && !_actionLocked) ? _finishVisit : null,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                disabledBackgroundColor: (canFinish && !_actionLocked)
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
              ),
              child: const Text('Завершить визит'),
            ),
          ),
        ),
      ),
    );
  }
}

String _pluralDoctors(int n) {
  if (n % 10 == 1 && n % 100 != 11) return '$n врач';
  if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
    return '$n врача';
  }
  return '$n врачей';
}

// ── Боттом-шит "Информация о враче" ────────────────────────────────────────

class _DoctorsInfoSheet extends StatefulWidget {
  final List<Map<String, dynamic>> doctors;
  const _DoctorsInfoSheet({required this.doctors});

  @override
  State<_DoctorsInfoSheet> createState() => _DoctorsInfoSheetState();
}

class _DoctorsInfoSheetState extends State<_DoctorsInfoSheet> {
  Map<String, dynamic>? _detail;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: screenHeight * 0.6,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Информация о враче',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 16, thickness: 0.7, color: AppColors.divider),
            if (_detail != null)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _detail = null),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Назад к списку',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 0.7,
                    color: AppColors.divider,
                  ),
                ],
              ),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: _detail == null
                    ? _DoctorList(
                        doctors: widget.doctors,
                        onSelect: (d) => setState(() => _detail = d),
                      )
                    : _DoctorDetail(doctor: _detail!),
              ),
            ),
            const Divider(height: 1, thickness: 0.7, color: AppColors.divider),
            // Close button
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad + 20),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorList extends StatelessWidget {
  final List<Map<String, dynamic>> doctors;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _DoctorList({required this.doctors, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (doctors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Text(
          'Нет данных о врачах',
          style: GoogleFonts.manrope(color: AppColors.hintText),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: doctors.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, thickness: 0.5, color: AppColors.divider),
      itemBuilder: (_, i) {
        final d = doctors[i];
        final name = d['full_name'] as String? ?? '';
        final specialty = d['specialty'] as String? ?? '';
        final category = _doctorCategoryLabel(d);
        return GestureDetector(
          onTap: () => onSelect(d),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                      if (specialty.isNotEmpty)
                        Text(
                          specialty,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  category,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.hintText,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DoctorDetail extends StatelessWidget {
  final Map<String, dynamic> doctor;
  const _DoctorDetail({required this.doctor});

  @override
  Widget build(BuildContext context) {
    final name = doctor['full_name'] as String? ?? '';
    final specialty = doctor['specialty'] as String? ?? '';
    final category = _doctorCategoryLabel(doctor);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailRow(label: 'ФИО', value: name),
          _DetailRow(label: 'Специализация', value: specialty),
          _DetailRow(
            label: 'Категория',
            value: category,
            isLast: true,
            asChip: true,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  final bool asChip;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
    this.asChip = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: asChip
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.iconBgLight,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        value,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _doctorCategoryLabel(Map<String, dynamic> d) {
  String? category = (d['category'] as String?)?.trim();
  if (category == null || category.isEmpty) {
    final raw = d['raw_json'] as String?;
    if (raw != null && raw.isNotEmpty) {
      try {
        final m = Map<String, dynamic>.from(
          (const JsonDecoder().convert(raw)) as Map,
        );
        category = (m['category'] ?? m['category_name'] ?? m['class'])
            ?.toString()
            .trim();
      } catch (_) {}
    }
  }
  final normalized = (category == null || category.isEmpty)
      ? 'C'
      : category.toUpperCase();
  return 'Категория $normalized';
}

class _ActionIconBox extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool disabled;
  final VoidCallback? onTap;

  const _ActionIconBox({
    required this.icon,
    required this.active,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.primaryBg
              : active
              ? AppColors.iconBgBlue
              : AppColors.primaryBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 23,
          color: disabled
              ? AppColors.hintText.withValues(alpha: 0.35)
              : active
              ? AppColors.primary
              : AppColors.secondaryText,
        ),
      ),
    );
  }
}
