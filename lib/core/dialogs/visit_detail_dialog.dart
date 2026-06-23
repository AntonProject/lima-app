import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/dialogs/payment_type_dialog.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/services/specification_export_service.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/features/visits/models/history_records.dart';

Future<void> showVisitDetailDialog(
  BuildContext context, {
  required HistoryVisitRecord visit,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VisitDetailSheet(visit: visit),
  );
}

class _VisitDetailSheet extends ConsumerStatefulWidget {
  final HistoryVisitRecord visit;

  const _VisitDetailSheet({required this.visit});

  @override
  ConsumerState<_VisitDetailSheet> createState() => _VisitDetailSheetState();
}

class _VisitDetailSheetState extends ConsumerState<_VisitDetailSheet> {
  late int _prepayment;
  late int _buyerType;
  bool _allowWholesale = true;
  final _specExport = SpecificationExportService();

  HistoryVisitRecord get visit => widget.visit;
  bool get _isPharmacy => visit.type == 'pharmacy';
  bool get _isStock => visit.type == 'stock';
  bool get _isCircle => visit.type == 'pharmacy' && visit.subType == 'circle';
  String _visitTitle(String base) =>
      visit.hasServerId ? '$base №${visit.id}' : base;

  /// Unified header for every visit/order dialog: only a centered drag handle
  /// (no close button; the sheet is dismissed by swiping down), then the title
  /// ("Заказ/Визит №NNN") on the left edge and the type/status chip on the
  /// right edge.
  Widget _dialogHeader(
    BuildContext context, {
    required String title,
    required String chipText,
    required Color chipBg,
    required Color chipFg,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _chip(text: chipText, bg: chipBg, fg: chipFg),
          ],
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _prepayment = visit.prepaymentPercent ?? 100;
    _buyerType = visit.buyerType ?? 0;
    // Same check as creation path (pharmacy_type_screen.dart): if the company
    // has no wholesale markup, the "Опт" button must stay locked during edit.
    if (_isPharmacy && !_isStock && !_isCircle) {
      _loadWholesaleSupport();
    }
  }

  Future<void> _loadWholesaleSupport() async {
    try {
      final companyId = ref.read(authProvider).user?.companyId;
      final supported = await ref
          .read(remoteApiServiceProvider)
          .supportsWholesaleOrders(companyId: companyId);
      if (!mounted) return;
      setState(() => _allowWholesale = supported);
    } catch (_) {
      // On error, fall back to permissive (matches creation path behavior).
      if (mounted) setState(() => _allowWholesale = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insetBottom = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.80;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 14, insetBottom + 12),
          child: _isCircle
              ? _buildCircleVisit(context)
              : _isPharmacy
              ? _buildPharmacyOrder(context)
              : _isStock
              ? _buildStockVisit(context)
              : _buildDefault(context),
        ),
      ),
    );
  }

  Widget _buildStockVisit(BuildContext context) {
    final firstItem = visit.stockItems.isEmpty
        ? visit.drug
        : visit.stockItems.first;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dialogHeader(
          context,
          title: _visitTitle(context.l10n.t('stockBalance')),
          chipText: context.l10n.t('removeStockTitle'),
          chipBg: const Color(0xFFFFF3DB),
          chipFg: const Color(0xFFE3A335),
        ),
        const SizedBox(height: 8),
        Text(
          visit.org,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: const Color(0xFF8390A3),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _softInfo(
          title: context.l10n.t('medRep'),
          value: visit.medicalRep,
          icon: Icons.person_2_outlined,
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 8),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel(context.l10n.t('stockItemsTaken').toUpperCase()),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstItem is HistoryStockItemRecord
                            ? firstItem.name
                            : firstItem.toString(),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: AppColors.secondaryText,
                          ),
                          children: [
                            TextSpan(text: '${context.l10n.t('qtyColon')} '),
                            TextSpan(
                              text:
                                  '${firstItem is HistoryStockItemRecord ? firstItem.quantity : visit.quantity}',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: ' ${context.l10n.t('pcsShort')}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${context.l10n.t('serialNumber')}: ${firstItem is HistoryStockItemRecord ? firstItem.serialNumber : (visit.serialNumber.isEmpty ? '—' : visit.serialNumber)}',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionLabel(context.l10n.t('generalInfo').toUpperCase()),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _kvCard(
                        title: context.l10n.t('visitDate'),
                        value: visit.dateTime,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statusCard(
                        title: context.l10n.t('status'),
                        label: _statusLabel(visit.status),
                        color: visit.statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            context.l10n.t('close'),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleVisit(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dialogHeader(
          context,
          title: _visitTitle(context.l10n.t('visit')),
          chipText: context.l10n.t('pharmCircle'),
          chipBg: const Color(0xFFDDF5E6),
          chipFg: const Color(0xFF2AA65A),
        ),
        const SizedBox(height: 8),
        Text(
          visit.org,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: const Color(0xFF8390A3),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _softInfo(
          title: context.l10n.t('pharmacists'),
          value: visit.pharmacistsFio == '—' ? '—' : visit.pharmacistsFio,
          icon: Icons.groups_2_rounded,
          trailing: visit.participantsCount > 0
              ? context.l10n.t('participantsN', args: {'count': '${visit.participantsCount}'})
              : null,
        ),
        const SizedBox(height: 8),
        _softInfo(
          title: context.l10n.t('medRep'),
          value: visit.medicalRep,
          icon: Icons.person_2_outlined,
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 8),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel(context.l10n.t('presentationsList').toUpperCase()),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    context.l10n.t('noPresentationData'),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppColors.hintText,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _sectionLabel(context.l10n.t('generalInfo').toUpperCase()),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _kvCard(
                        title: context.l10n.t('visitDate'),
                        value: visit.dateTime,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statusCard(
                        title: context.l10n.t('status'),
                        label: _statusLabel(visit.status),
                        color: visit.statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            context.l10n.t('close'),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPharmacyOrder(BuildContext context) {
    final total = visit.orderTotal > 0 ? visit.orderTotal : 0.0;
    final items = _extractOrderItems();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dialogHeader(
          context,
          title: _visitTitle(context.l10n.t('order')),
          chipText: context.l10n.t('bron'),
          chipBg: const Color(0xFFDDF5E6),
          chipFg: const Color(0xFF2AA65A),
        ),
        const SizedBox(height: 8),
        Text(
          visit.org,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: const Color(0xFF8390A3),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _softInfo(
          title: context.l10n.t('medRep'),
          value: visit.medicalRep,
          icon: Icons.person_2_outlined,
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _actionPill(
                icon: Icons.description_outlined,
                label: context.l10n.t('specification'),
                onTap: _showFormatDialog,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _actionPill(
                icon: Icons.history_rounded,
                label: context.l10n.t('historyField'),
                onTap: _showStatusHistoryDialog,
              ),
            ),
            const SizedBox(width: 8),
            _iconAction(icon: Icons.edit_outlined, onTap: _editPaymentTerms),
            const SizedBox(width: 8),
            _iconAction(icon: Icons.star_rounded, onTap: _showRatingDialog),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 10),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _sectionLabel(context.l10n.t('orderHistory').toUpperCase()),
                const SizedBox(height: 8),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: AppColors.secondaryText,
                              ),
                              children: [
                                TextSpan(text: '${context.l10n.t('qtyColon')} '),
                                TextSpan(
                                  text: '${item.qty}',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: ' ${context.l10n.t('pcsShort')}'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${context.l10n.t('serialNumber')}: ${item.serial}',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatUzs(item.sum),
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionLabel(context.l10n.t('generalInfo').toUpperCase()),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _kvCard(
                        title: context.l10n.t('sum'),
                        value: formatUzs(total),
                        accent: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _kvCard(
                        title: context.l10n.t('prepayment'),
                        value: '$_prepayment%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _kvCard(
                        title: context.l10n.t('markup'),
                        value:
                            '${(visit.markupPercent ?? 20).toStringAsFixed(0)}%',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _kvCard(
                        title: context.l10n.t('orderStatus'),
                        value: visit.orderStatus,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _kvCard(
                  title: context.l10n.t('clientType'),
                  value: _buyerType == 1 ? context.l10n.t('wholesale') : context.l10n.t('retail'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _kvCard(
                        title: context.l10n.t('visitDate'),
                        value: visit.dateTime,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statusCard(
                        title: context.l10n.t('status'),
                        label: _statusLabel(visit.status),
                        color: visit.statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  final id = visit.orgId;
                  if (id == null) return;
                  context.push(
                    Uri(
                      path: '/visits/pharmacy/detail/$id/type',
                      queryParameters: {
                        'name': visit.org,
                        'prepayment': '$_prepayment',
                        'buyerType': '$_buyerType',
                      },
                    ).toString(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  context.l10n.t('newOrderInPharmacy'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  context.l10n.t('close'),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDefault(BuildContext context) {
    final (chipText, chipBg, chipFg) = switch (visit.subType) {
      'group' => (
        context.l10n.t('groupPresentation'),
        const Color(0xFFEFE9FF),
        const Color(0xFF7A63E8),
      ),
      'double' => (
        context.l10n.t('doubleVisit'),
        const Color(0xFFEAF0FF),
        const Color(0xFF5B84F4),
      ),
      _ => (
        context.l10n.t('presentation'),
        const Color(0xFFEAF0FF),
        const Color(0xFF5B84F4),
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dialogHeader(
          context,
          title: _visitTitle(context.l10n.t('visit')),
          chipText: chipText,
          chipBg: chipBg,
          chipFg: chipFg,
        ),
        const SizedBox(height: 8),
        Text(
          visit.org,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        _softInfo(
          title: (visit.subType == 'group' || visit.doctor.contains(','))
              ? context.l10n.t('doctors')
              : context.l10n.t('doctorField'),
          value: visit.doctor,
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 8),
        _softInfo(
          title: context.l10n.t('medRep'),
          value: visit.medicalRep,
          icon: Icons.person_2_outlined,
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 8),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel(context.l10n.t('presentationsList').toUpperCase()),
                const SizedBox(height: 8),
                if (visit.presentations.isEmpty)
                  _presentationCard(
                    name: visit.drug,
                    manufacturer: '—',
                    color: visit.statusColor,
                    statusLabel: _statusLabel(visit.drugStatus),
                  )
                else
                  ...visit.presentations.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _presentationCard(
                        name: item.name,
                        manufacturer: item.manufacturer,
                        color: item.statusColor,
                        statusLabel: _presentationStatusLabel(item),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 8),
                _sectionLabel(context.l10n.t('generalInfo').toUpperCase()),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _kvCard(
                        title: context.l10n.t('visitDate'),
                        value: visit.dateTime,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statusCard(
                        title: context.l10n.t('status'),
                        label: _statusLabel(visit.status),
                        color: visit.statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            context.l10n.t('close'),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showFormatDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.t('selectFormat'),
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  AppTapScale(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _formatBtn(ctx, 'Excel (.xlsx)'),
              const SizedBox(height: 10),
              _formatBtn(ctx, context.l10n.t('imagePng')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatBtn(BuildContext ctx, String text) {
    return OutlinedButton(
      onPressed: () {
        Navigator.pop(ctx);
        final data = SpecificationData(
          orderId: int.tryParse(visit.id) ?? 0,
          date: DateTime.now(),
          seller: 'LIMA',
          buyer: visit.org,
          items: visit.presentations.isEmpty
              ? [
                  SpecificationItem(
                    name: visit.drug,
                    manufacturer: '',
                    quantity: visit.quantity > 0 ? visit.quantity : 1,
                    serialNumber: visit.serialNumber.isEmpty
                        ? '—'
                        : visit.serialNumber,
                    expiryDate: '—',
                    basePrice: visit.orderTotal > 0
                        ? (visit.orderTotal / 1.2)
                        : 0,
                    markupPercent: visit.markupPercent ?? 20,
                  ),
                ]
              : visit.presentations
                    .map(
                      (p) => SpecificationItem(
                        name: p.name,
                        manufacturer: p.manufacturer,
                        quantity: 1,
                        serialNumber: visit.serialNumber.isEmpty
                            ? '—'
                            : visit.serialNumber,
                        expiryDate: '—',
                        basePrice: visit.orderTotal > 0
                            ? ((visit.orderTotal / visit.presentations.length) /
                                  1.2)
                            : 0,
                        markupPercent: visit.markupPercent ?? 20,
                      ),
                    )
                    .toList(),
        );
        _specExport.export(
          context,
          data: data,
          format: text.contains('xlsx')
              ? SpecificationFormat.xlsx
              : SpecificationFormat.png,
        );
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _showStatusHistoryDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.60,
        decoration: const BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                context.l10n.t('status'),
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visit.orderStatus,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${visit.date}, ${visit.medicalRep}',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: AppColors.secondaryText,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                MediaQuery.of(context).padding.bottom + 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 110,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        context.l10n.t('close'),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPaymentTerms() async {
    final updated = await showModalBottomSheet<PaymentTermsSelection>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPaymentSheet(
        initialPrepayment: _prepayment,
        initialBuyerType: _buyerType,
        allowWholesale: _allowWholesale,
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _prepayment = updated.prepayment;
      _buyerType = updated.buyerType;
    });
  }

  Future<void> _showRatingDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _OrderRatingSheet(),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF818CA0),
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _softInfo({
    required String title,
    required String value,
    required IconData icon,
    String? trailing,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null && trailing.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondaryBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trailing,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _presentationCard({
    required String name,
    required String manufacturer,
    required ColorSpec color,
    String? statusLabel,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.t('manufacturerColon', args: {'value': manufacturer}),
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          _chip(
            text: statusLabel ?? _statusLabel(visit.status),
            bg: Color(color.bgHex),
            fg: Color(color.fgHex),
          ),
        ],
      ),
    );
  }

  List<_OrderItemVm> _extractOrderItems() {
    try {
      final raw = jsonDecode(visit.rawJson);
      if (raw is! Map) return _fallbackOrderItems();
      final map = Map<String, dynamic>.from(raw);
      final drugs = map['drugs'];
      if (drugs is! List || drugs.isEmpty) return _fallbackOrderItems();
      final out = <_OrderItemVm>[];
      for (final item in drugs) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final name = '${m['drug_name'] ?? m['name'] ?? '—'}';
        final qty =
            (m['package'] as num?)?.toInt() ??
            (m['quantity'] as num?)?.toInt() ??
            1;
        final serial = '${m['serial_no'] ?? m['serial_number'] ?? '—'}';
        final direct =
            (m['total_sum'] as num?)?.toDouble() ??
            (m['sum'] as num?)?.toDouble() ??
            (m['amount'] as num?)?.toDouble();
        final salePrice =
            (m['sale_price'] as num?)?.toDouble() ??
            (m['price'] as num?)?.toDouble() ??
            0;
        final sum = direct ?? (salePrice * qty);
        out.add(_OrderItemVm(name: name, qty: qty, serial: serial, sum: sum));
      }
      if (out.isNotEmpty) return out;
    } catch (_) {}
    return _fallbackOrderItems();
  }

  List<_OrderItemVm> _fallbackOrderItems() {
    if (visit.stockItems.isNotEmpty) {
      return visit.stockItems
          .map(
            (e) => _OrderItemVm(
              name: e.name,
              qty: e.quantity,
              serial: e.serialNumber.isEmpty ? '—' : e.serialNumber,
              sum: visit.orderTotal > 0
                  ? (visit.orderTotal / visit.stockItems.length)
                  : 0,
            ),
          )
          .toList();
    }
    return <_OrderItemVm>[
      _OrderItemVm(
        name: visit.drug,
        qty: visit.quantity > 0 ? visit.quantity : 1,
        serial: visit.serialNumber.isEmpty ? '—' : visit.serialNumber,
        sum: visit.orderTotal,
      ),
    ];
  }

  Widget _kvCard({
    required String title,
    required String value,
    bool accent = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: accent ? 16 : 15,
              fontWeight: FontWeight.w600,
              color: accent ? AppColors.primary : AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard({
    required String title,
    required String label,
    required ColorSpec color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 6),
          _chip(text: label, bg: Color(color.bgHex), fg: Color(color.fgHex)),
        ],
      ),
    );
  }

  Widget _chip({required String text, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 13,
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.secondaryText),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconAction({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, size: 18, color: AppColors.primaryText),
      ),
    );
  }

  String _statusLabel(String key) {
    switch (key) {
      case 'completed':
        return context.l10n.t('conducted');
      case 'planned':
        return context.l10n.t('planned');
      case 'cancelled':
        return context.l10n.t('cancelled');
      default:
        return '—';
    }
  }

  // Localized label for a presentation (drug-familiarity) status. Server-sent
  // labels (rawStatusLabel) are shown verbatim; otherwise the statusKey is
  // mapped to a localized string so it follows the selected language.
  String _presentationStatusLabel(HistoryPresentationRecord item) {
    final raw = item.rawStatusLabel?.trim() ?? '';
    if (raw.isNotEmpty) return raw;
    switch (item.statusKey) {
      case 'completed':
        return context.l10n.t('familiarPrescribes');
      case 'familiar_not_prescribes':
        return context.l10n.t('familiarNotPrescribes');
      case 'planned':
        return context.l10n.t('comment');
      case 'cancelled':
        return context.l10n.t('notFamiliar');
      default:
        return '—';
    }
  }
}

class _OrderItemVm {
  final String name;
  final int qty;
  final String serial;
  final double sum;

  const _OrderItemVm({
    required this.name,
    required this.qty,
    required this.serial,
    required this.sum,
  });
}

class _EditPaymentSheet extends StatefulWidget {
  final int initialPrepayment;
  final int initialBuyerType;
  final bool allowWholesale;

  const _EditPaymentSheet({
    required this.initialPrepayment,
    required this.initialBuyerType,
    this.allowWholesale = true,
  });

  @override
  State<_EditPaymentSheet> createState() => _EditPaymentSheetState();
}

class _EditPaymentSheetState extends State<_EditPaymentSheet> {
  late int _prepayment;
  late int _buyerType;

  @override
  void initState() {
    super.initState();
    _prepayment = widget.initialPrepayment;
    // If wholesale is locked but the saved value is "Опт", normalize to retail
    // so the visible selection matches what the user is actually allowed to
    // submit.
    _buyerType = (!widget.allowWholesale && widget.initialBuyerType == 1)
        ? 0
        : widget.initialBuyerType;
  }

  @override
  Widget build(BuildContext context) {
    final changed =
        _prepayment != widget.initialPrepayment ||
        _buyerType != widget.initialBuyerType;
    final canContinue = changed;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.t('paymentConditions'),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
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
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Text(
            context.l10n.t('prepayments'),
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _paymentToggle(
                text: '100%',
                active: _prepayment == 100,
                onTap: () => setState(() => _prepayment = 100),
              ),
              const SizedBox(width: 8),
              _paymentToggle(
                text: '0%',
                active: _prepayment == 0,
                onTap: () => setState(() => _prepayment = 0),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.t('clientType'),
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(
                  child: _clientTypeBtn(
                    text: context.l10n.t('retail'),
                    active: _buyerType == 0,
                    onTap: () => setState(() => _buyerType = 0),
                  ),
                ),
                Expanded(
                  child: _clientTypeBtn(
                    text: context.l10n.t('wholesale'),
                    active: _buyerType == 1,
                    enabled: widget.allowWholesale,
                    onTap: widget.allowWholesale
                        ? () => setState(() => _buyerType = 1)
                        : () {},
                  ),
                ),
              ],
            ),
          ),
          if (!widget.allowWholesale) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.t('wholesaleUnavailable'),
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.hintText,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: canContinue
                ? () => Navigator.pop(
                    context,
                    PaymentTermsSelection(
                      prepayment: _prepayment,
                      buyerType: _buyerType,
                    ),
                  )
                : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.l10n.t('continueAction'),
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentToggle({
    required String text,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : AppColors.primaryBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.primary : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _clientTypeBtn({
    required String text,
    required bool active,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.primary : AppColors.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderRatingSheet extends StatefulWidget {
  const _OrderRatingSheet();

  @override
  State<_OrderRatingSheet> createState() => _OrderRatingSheetState();
}

class _OrderRatingSheetState extends State<_OrderRatingSheet> {
  int _efficiency = 0;
  int _politeness = 0;
  int _speed = 0;
  final TextEditingController _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.62,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.t('rating'),
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ratingRow(
                        title: context.l10n.t('rateEffectiveness'),
                        value: _efficiency,
                        onChanged: (v) => setState(() => _efficiency = v),
                      ),
                      const SizedBox(height: 14),
                      _ratingRow(
                        title: context.l10n.t('rateCourtesy'),
                        value: _politeness,
                        onChanged: (v) => setState(() => _politeness = v),
                      ),
                      const SizedBox(height: 14),
                      _ratingRow(
                        title: context.l10n.t('rateDelivery'),
                        value: _speed,
                        onChanged: (v) => setState(() => _speed = v),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.l10n.t('orderComment'),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _commentCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: context.l10n.t('comment'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).padding.bottom + 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          context.l10n.t('save'),
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ratingRow({
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final selected = i < value;
            final color = !selected
                ? const Color(0xFFD7DAE0)
                : value <= 2
                ? const Color(0xFFE05050)
                : value <= 4
                ? const Color(0xFFE3A335)
                : const Color(0xFF2AA65A);
            return GestureDetector(
              onTap: () => onChanged(i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.star_rounded, size: 28, color: color),
              ),
            );
          }),
        ),
      ],
    );
  }
}
