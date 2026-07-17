part of '../screens/pharmacy/pharmacy_order_screen.dart';

class _DrugCard extends StatelessWidget {
  final Drug drug;
  final int selectedQty;
  final bool isOverStock;
  final VoidCallback onTap;

  const _DrugCard({
    required this.drug,
    required this.selectedQty,
    required this.isOverStock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selectedQty > 0
                ? const Color(0xFFF2F6FF)
                : AppColors.secondaryBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: shadowSm,
            border: Border.all(
              color: isOverStock
                  ? AppColors.error
                  : selectedQty > 0
                  ? AppColors.primary
                  : Colors.transparent,
              width: selectedQty > 0 ? 1.5 : 0,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: AppColors.iconBgBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.medication_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          context.l10n.t(
                            'manufacturerColon',
                            args: {
                              'value': drug.manufacturer.isNotEmpty
                                  ? drug.manufacturer
                                  : '—',
                            },
                          ),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.t(
                            'serialColon',
                            args: {
                              'value': drug.serialNumber?.isNotEmpty == true
                                  ? drug.serialNumber!
                                  : '—',
                            },
                          ),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.t(
                            'expiryColon',
                            args: {
                              'value': drug.expiryDate?.isNotEmpty == true
                                  ? drug.expiryDate!
                                  : '—',
                            },
                          ),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.t(
                            'mainStockColon',
                            args: {
                              'value': '${drug.mainStock ?? drug.stock ?? 0}',
                            },
                          ),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.t(
                            'remainsColon',
                            args: {
                              'value':
                                  '${drug.remainsStock ?? drug.stock ?? 0}',
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
                  if (selectedQty > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8, top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isOverStock
                            ? AppColors.error
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$selectedQty',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 8),
              Text(
                formatUzs(drug.price),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _QtyBtn({required this.icon, this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primaryBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 30,
          color: onTap == null
              ? AppColors.hintText
              : (iconColor ?? AppColors.primaryText),
        ),
      ),
    );
  }
}

Widget _qtyDialogLine(
  String label,
  String value, {
  int labelFlex = 1,
  int valueFlex = 1,
  int maxLines = 2,
  bool showDivider = false,
  Color? valueColor,
  FontWeight valueWeight = FontWeight.w600,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: labelFlex,
              child: Text(
                '$label:',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: valueFlex,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: valueWeight,
                  color: valueColor ?? AppColors.primaryText,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.divider),
        ],
      ],
    ),
  );
}

/// Quantity-selection sheet content for the Бронь flow. Its own
/// [StatefulWidget] so [TextEditingController] follows the normal
/// State.dispose() lifecycle instead of being manually disposed right after
/// the enclosing bottom sheet's Navigator.pop() — the sheet's close
/// animation can still hold the field mounted for a few frames after pop()
/// resolves, and disposing the controller mid-animation crashed the app.
class _QtyDialog extends StatefulWidget {
  final Drug drug;
  final int initialQty;
  final String Function(String?) formatExpiry;

  const _QtyDialog({
    required this.drug,
    required this.initialQty,
    required this.formatExpiry,
  });

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  late final TextEditingController _qtyCtrl;
  late int _qty;

  int get _available => widget.drug.remainsStock ?? widget.drug.stock ?? 0;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty > 0 ? widget.initialQty : 0;
    _qtyCtrl = TextEditingController(text: '$_qty');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _setQty(int next) {
    setState(() {
      _qty = next < 0 ? 0 : next;
      _qtyCtrl.text = '$_qty';
    });
  }

  @override
  Widget build(BuildContext context) {
    final drug = widget.drug;
    final mainStock = drug.mainStock ?? drug.stock ?? 0;
    final available = _available;
    final isOverStock = _qty > available;
    final canIncrease = _qty < available;
    final counterColor = isOverStock
        ? AppColors.error
        : const Color(0xFFE49351);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.t('selectQuantity'),
                      style: GoogleFonts.manrope(
                        fontSize: 18,
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                children: [
                  _qtyDialogLine(
                    context.l10n.t('drug'),
                    drug.name,
                    valueFlex: 2,
                    maxLines: 3,
                    showDivider: true,
                  ),
                  _qtyDialogLine(
                    context.l10n.t('manufacturer'),
                    drug.manufacturer.isNotEmpty ? drug.manufacturer : '—',
                    showDivider: true,
                  ),
                  _qtyDialogLine(
                    context.l10n.t('expiryDate'),
                    widget.formatExpiry(drug.expiryDate),
                    showDivider: true,
                  ),
                  _qtyDialogLine(
                    context.l10n.t('serialNumber'),
                    drug.serialNumber?.isNotEmpty == true
                        ? drug.serialNumber!
                        : '—',
                    showDivider: true,
                  ),
                  _qtyDialogLine(
                    context.l10n.t('mainStock'),
                    context.l10n.t('pcsN', args: {'n': '$mainStock'}),
                    showDivider: true,
                  ),
                  _qtyDialogLine(
                    context.l10n.t('remains'),
                    context.l10n.t('pcsN', args: {'n': '$available'}),
                    showDivider: true,
                  ),
                  _qtyDialogLine(
                    context.l10n.t('price'),
                    formatUzs(drug.price),
                    valueColor: AppColors.primary,
                    valueWeight: FontWeight.w700,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _QtyBtn(
                    icon: Icons.remove_rounded,
                    iconColor: const Color(0xFFE49351),
                    onTap: () => _setQty(_qty > 1 ? _qty - 1 : 0),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: counterColor, width: 2),
                      ),
                      child: Center(
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: counterColor,
                          ),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          // Select-all on tap so typing replaces the "0"
                          // instead of appending to it ("0" → "36", not
                          // "036").
                          onTap: () {
                            _qtyCtrl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _qtyCtrl.text.length,
                            );
                          },
                          onChanged: (v) => setState(() {
                            _qty = v.isEmpty ? 0 : (int.tryParse(v) ?? 0);
                          }),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _QtyBtn(
                    icon: Icons.add_rounded,
                    iconColor: const Color(0xFF2AA65A),
                    onTap: canIncrease ? () => _setQty(_qty + 1) : null,
                  ),
                ],
              ),
            ),
            if (isOverStock) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.t('availableN', args: {'n': '$available'}),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFE77834),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Text(
                      context.l10n.t('totalColon'),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatUzs(drug.price * _qty),
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _qty <= 0 || isOverStock
                    ? null
                    : () => Navigator.pop(context, _qty),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  context.l10n.t('confirm'),
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
    );
  }
}
