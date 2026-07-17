part of '../screens/pharmacy/pharma_circle_screen.dart';

extension _PharmaCircleScreenUi on _PharmaCircleScreenState {
  Widget _buildScreen(BuildContext context) {
    final viewState = ref.watch(pharmaCircleViewModelProvider);
    final filtered = viewState.filteredDrugs;
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
                    context.canPop() ? context.pop() : context.go('/visits');
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
              onChanged: (v) =>
                  ref.read(pharmaCircleViewModelProvider.notifier).setQuery(v),
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
            child: viewState.isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : filtered.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: context.l10n.t('nothingFound'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final drug = filtered[i];
                      final shownCount =
                          viewState.shownDocumentIdsByDrug[drug.id]?.length ??
                          0;
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
                                            ? context.l10n.t(
                                                'mfrMaterialsN',
                                                args: {
                                                  'mfr': drug.manufacturer,
                                                  'count':
                                                      '${drug.documentsCount}',
                                                },
                                              )
                                            : context.l10n.t(
                                                'materialsCountN',
                                                args: {
                                                  'count':
                                                      '${drug.documentsCount}',
                                                },
                                              ),
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
    final viewModel = ref.read(pharmaCircleViewModelProvider.notifier);
    final viewState = ref.read(pharmaCircleViewModelProvider);
    if ((viewState.shownDocumentIdsByDrug[drug.id]?.isNotEmpty ?? false)) {
      viewModel.clearShownMaterials(drug.id);
      return;
    }

    final materials = await ref
        .read(knowledgeRepositoryProvider)
        .getDrugMaterialModels(drug.id);
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
    final documentId = material.documentId;
    if (documentId != null) {
      viewModel.markMaterialShown(
        drugId: drug.id,
        drugName: drug.name,
        documentId: documentId,
      );
    }

    await context.push(
      Uri(
        path: '/knowledge/drug/${drug.id}/materials',
        queryParameters: {'index': '$selectedIndex'},
      ).toString(),
    );
  }

  String _materialTitle(DrugMaterial material) {
    return material.title.trim().isNotEmpty
        ? material.title
        : context.l10n.t('material');
  }

  String _materialType(DrugMaterial material) {
    final type = material.documentTypeName?.trim();
    if (type != null && type.isNotEmpty) return type;
    final fileType = material.fileType.trim();
    if (fileType.isNotEmpty) return fileType;
    final fileName = material.fileName?.trim();
    if (fileName != null && fileName.isNotEmpty) return fileName;
    return 'file';
  }

  Future<void> _openFinishSheet() async {
    final payload = await showAppSheet<PharmaCircleFinishPayload>(
      context,
      useRootNavigator: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PharmaCircleFinishSheet(
        drugsCount: ref
            .read(pharmaCircleViewModelProvider)
            .shownDocumentIdsByDrug
            .length,
        materialsCount: ref
            .read(pharmaCircleViewModelProvider)
            .shownMaterialsCount,
      ),
    );
    if (payload == null || !mounted) return;
    await _finishCircle(payload);
  }

  Future<void> _finishCircle(PharmaCircleFinishPayload payload) async {
    if (_actionLocked) return;
    _setActionLocked(true);
    final now = DateTime.now().toIso8601String();
    try {
      final viewState = ref.read(pharmaCircleViewModelProvider);
      final talkedAboutDrugs = viewState.shownDocumentIdsByDrug.entries
          .where((entry) => entry.value.isNotEmpty)
          .map(
            (entry) => DiscussedDrugRecord(
              drugId: entry.key,
              documentIds: List.unmodifiable(entry.value),
            ),
          )
          .toList(growable: false);
      await ref
          .read(visitWriteRepositoryProvider)
          .complete(
            CompletedVisitDraft(
              organizationId: widget.pharmacyId,
              organizationName: widget.pharmacyName,
              doctorId: null,
              doctorName: null,
              localVisitType: 'circle',
              notes: payload.fio.trim(),
              medicalRepName: ref.read(authProvider).user?.fullName,
              createdAt: DateTime.tryParse(now) ?? DateTime.now(),
              updatedAt: DateTime.tryParse(now) ?? DateTime.now(),
              payload: PharmaCircleCompletedVisitPayload(
                pharmacistName: payload.fio.trim(),
                participantsCount: payload.participantsCount,
                materialsShownCount: viewState.shownMaterialsCount,
                visitFormatName: context.l10n.t('pharmCircle'),
                discussedDrugs: List.unmodifiable(talkedAboutDrugs),
              ),
            ),
            tryRemote: !ref.read(isOfflineProvider),
          );
      ref.invalidate(dashboardCountsProvider);
      // The repository has already queued the local row when the network is
      // unavailable or the API rejects the remote attempt.
    } catch (error) {
      debugPrint('PharmaCircleScreen.saveVisit failed: $error');
    }
    if (ref.read(isOfflineProvider)) {
      pulseOfflineBanner(ref);
    }
    if (!mounted) return;
    await _showSuccessDialog(payload);
  }

  Future<void> _showSuccessDialog(PharmaCircleFinishPayload payload) async {
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
                _summaryLine(
                  context.l10n.t('visitType'),
                  context.l10n.t('pharmCircle'),
                ),
                _summaryLine(
                  context.l10n.t('organization'),
                  widget.pharmacyName.toUpperCase(),
                ),
                _summaryLine(context.l10n.t('pharmacistsNames'), payload.fio),
                _summaryLine(
                  context.l10n.t('participantsCount'),
                  context.l10n.t(
                    'participantsN',
                    args: {'count': '${payload.participantsCount}'},
                  ),
                ),
                _summaryLine(
                  context.l10n.t('discussedDrugs'),
                  ref
                          .read(pharmaCircleViewModelProvider)
                          .shownDrugNamesByDrug
                          .isEmpty
                      ? context.l10n.t('drugsNotDiscussed')
                      : context.l10n.t(
                          'pcsN',
                          args: {
                            'n':
                                '${ref.read(pharmaCircleViewModelProvider).shownDrugNamesByDrug.length}',
                          },
                        ),
                ),
                _summaryLine(
                  context.l10n.t('shownMaterials'),
                  context.l10n.t(
                    'pcsN',
                    args: {
                      'n':
                          '${ref.read(pharmaCircleViewModelProvider).shownMaterialsCount}',
                    },
                  ),
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
