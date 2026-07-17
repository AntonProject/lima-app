part of '../screens/new_bron_screen.dart';

extension _NewBronScreenUi on _NewBronScreenState {
  Future<void> _showSpecFormatDialog() async {
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
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final data = SpecificationData(
                    orderId: DateTime.now().millisecondsSinceEpoch % 100000,
                    date: DateTime.now(),
                    seller: 'LIMA',
                    buyer: widget.pharmacyName,
                    items: _ids
                        .map(
                          (id) => SpecificationItem(
                            name: _drugById[id]?.name ?? '—',
                            manufacturer: _drugById[id]?.manufacturer ?? '',
                            quantity: _qtyByDrugId[id] ?? 1,
                            serialNumber: _drugById[id]?.serialNumber ?? '—',
                            expiryDate: _drugById[id]?.expiryDate ?? '—',
                            basePrice: (_drugById[id]?.price ?? 0) / 1.2,
                          ),
                        )
                        .toList(),
                  );
                  _specExport.export(
                    context,
                    data: data,
                    format: SpecificationFormat.xlsx,
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Excel (.xlsx)',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final data = SpecificationData(
                    orderId: DateTime.now().millisecondsSinceEpoch % 100000,
                    date: DateTime.now(),
                    seller: 'LIMA',
                    buyer: widget.pharmacyName,
                    items: _ids
                        .map(
                          (id) => SpecificationItem(
                            name: _drugById[id]?.name ?? '—',
                            manufacturer: _drugById[id]?.manufacturer ?? '',
                            quantity: _qtyByDrugId[id] ?? 1,
                            serialNumber: _drugById[id]?.serialNumber ?? '—',
                            expiryDate: _drugById[id]?.expiryDate ?? '—',
                            basePrice: (_drugById[id]?.price ?? 0) / 1.2,
                          ),
                        )
                        .toList(),
                  );
                  _specExport.export(
                    context,
                    data: data,
                    format: SpecificationFormat.png,
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  context.l10n.t('imagePng'),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showResultDialog({
    required String title,
    required String subtitle,
    String? badge,
    bool success = true,
    bool stayOnPageOnClose = false,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !success,
      builder: (ctx) => PopScope(
        canPop: !success,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!success)
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppTapScale(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.secondaryText,
                        size: 22,
                      ),
                    ),
                  ),
                SizedBox(
                  width: 74,
                  height: 74,
                  child: Center(
                    child: Icon(
                      success ? Icons.check_rounded : Icons.close_rounded,
                      color: success
                          ? const Color(0xFF4AAE7E)
                          : const Color(0xFFE05050),
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3DB),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: const Color(0xFFE3A335),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (success) const SizedBox(height: 16),
                if (success)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.pushReplacement(
                        Uri(
                          path: '/visits/pharmacy/detail/${widget.pharmacyId}',
                          queryParameters: {'name': widget.pharmacyName},
                        ).toString(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.l10n.t('goToCompany'),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (success) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (!stayOnPageOnClose) {
                        context.go(
                          '/home?refresh=${DateTime.now().millisecondsSinceEpoch}',
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE2E6EE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      stayOnPageOnClose
                          ? context.l10n.t('understood')
                          : context.l10n.t('toHome'),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _orderDetailsCard(int itemsCount) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadowSm,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _fromCart
                    ? context.l10n.t('orderDetails')
                    : context.l10n.t('bronDetails'),
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                context.l10n.t('pcsN', args: {'n': '$itemsCount'}),
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final id in _ids) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              decoration: BoxDecoration(
                color: AppColors.primaryBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isLineOverStock(id)
                      ? AppColors.error
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _drugById[id]?.name ??
                              context.l10n.t('drugHash', args: {'id': '$id'}),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((_drugById[id]?.manufacturer ?? '').isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            _drugById[id]!.manufacturer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          '${formatUzs(_drugById[id]?.price ?? 0)} x ${_qtyByDrugId[id]} = ${formatUzs((_drugById[id]?.price ?? 0) * (_qtyByDrugId[id] ?? 0))}',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_fromCart)
                    Text(
                      context.l10n.t(
                        'pcsN',
                        args: {'n': '${_qtyByDrugId[id] ?? 0}'},
                      ),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isLineOverStock(id)
                            ? AppColors.error
                            : AppColors.secondaryText,
                      ),
                    )
                  else
                    Row(
                      children: [
                        _qtyButton(
                          icon: Icons.remove_rounded,
                          onTap: () => _orderViewModel.decrement(id),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_qtyByDrugId[id] ?? 0}',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _isLineOverStock(id)
                                ? AppColors.error
                                : AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _qtyButton(
                          icon: Icons.add_rounded,
                          onTap: _canIncreaseQty(id)
                              ? () => _orderViewModel.increment(id)
                              : null,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _pair(String left, String right) {
    return Row(
      children: [
        Text(
          left,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppColors.secondaryText,
          ),
        ),
        const Spacer(),
        Text(
          right,
          style: GoogleFonts.manrope(
            fontSize: 18,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          color: AppColors.secondaryBg,
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? AppColors.hintText : AppColors.secondaryText,
        ),
      ),
    );
  }
}
