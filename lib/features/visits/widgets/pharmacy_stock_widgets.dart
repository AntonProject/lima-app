import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_theme.dart';

class PharmacyStockSubmitPayload {
  final Map<int, int> qtyByDrugId;
  final Map<int, Drug> drugsById;
  final String comment;

  const PharmacyStockSubmitPayload({
    required this.qtyByDrugId,
    required this.drugsById,
    required this.comment,
  });
}

class PharmacyStockConfirmScreen extends StatefulWidget {
  final String pharmacyName;
  final Map<int, int> qtyByDrugId;
  final Map<int, Drug> drugsById;

  const PharmacyStockConfirmScreen({
    super.key,
    required this.pharmacyName,
    required this.qtyByDrugId,
    required this.drugsById,
  });

  @override
  State<PharmacyStockConfirmScreen> createState() =>
      PharmacyStockConfirmScreenState();
}

class PharmacyStockConfirmScreenState
    extends State<PharmacyStockConfirmScreen> {
  late final Map<int, int> _qtyByDrugId = Map<int, int>.from(
    widget.qtyByDrugId,
  );
  final _commentCtrl = TextEditingController();

  int get _itemsCount => _qtyByDrugId.values.fold<int>(0, (a, b) => a + b);
  List<int> get _ids =>
      _qtyByDrugId.keys.where((id) => (_qtyByDrugId[id] ?? 0) > 0).toList();
  bool get _hasInvalidQty => _ids.any((id) {
    final drug = widget.drugsById[id];
    if (drug == null) return false;
    return _isOverStock(drug, _qtyByDrugId[id] ?? 0);
  });

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
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
                  onTap: () => context.pop(),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.primaryText,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.t('stockRests'),
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                for (final id in _ids) ...[
                  _stockItemCard(id),
                  const SizedBox(height: 10),
                ],
                Text(
                  context.l10n.t('comment'),
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        context.l10n.t('quantityColon'),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        context.l10n.t('pcsN', args: {'n': '$_itemsCount'}),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          boxShadow: shadowMd,
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).padding.bottom + 8,
        ),
        child: ElevatedButton(
          onPressed: _ids.isEmpty || _hasInvalidQty
              ? null
              : () => Navigator.pop(
                  context,
                  PharmacyStockSubmitPayload(
                    qtyByDrugId: _qtyByDrugId,
                    drugsById: widget.drugsById,
                    comment: _commentCtrl.text.trim(),
                  ),
                ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            context.l10n.t('removeStock'),
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _stockItemCard(int id) {
    final drug = widget.drugsById[id]!;
    final qty = _qtyByDrugId[id] ?? 0;
    final isOverStock = _isOverStock(drug, qty);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(12),
        border: isOverStock ? Border.all(color: AppColors.error) : null,
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drug.name,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  drug.serialNumber?.isNotEmpty == true
                      ? drug.serialNumber!
                      : '—',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOverStock ? AppColors.error : const Color(0xFFE9A165),
              ),
            ),
            child: Text(
              '$qty',
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: isOverStock ? AppColors.error : const Color(0xFFE9A165),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _editQty(id),
            child: _iconSquare(
              Icons.edit_outlined,
              color: const Color(0xFF7A8899),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _qtyByDrugId.remove(id)),
            child: _iconSquare(
              Icons.delete_outline_rounded,
              color: const Color(0xFFE05B57),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconSquare(IconData icon, {required Color color}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Future<void> _editQty(int id) async {
    final drug = widget.drugsById[id]!;
    final available = _availableStock(drug);
    final initial = _qtyByDrugId[id] ?? 1;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) =>
          PharmacyStockEditQtyDialog(initialQty: initial, available: available),
    );
    if (result == null) return;
    setState(() {
      if (result <= 0) {
        _qtyByDrugId.remove(id);
      } else {
        _qtyByDrugId[id] = result;
      }
    });
  }

  int _availableStock(Drug drug) => drug.remainsStock ?? drug.stock ?? 0;

  bool _isOverStock(Drug drug, int qty) => qty > _availableStock(drug);
}

Widget pharmacyStockQtyLine(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
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
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Quantity sheet for "Снятие остатков". Own [StatefulWidget] so the qty
/// [TextEditingController] follows State.dispose() instead of a manual
/// dispose right after Navigator.pop() — see _QtyDialog in
/// pharmacy_order_screen.dart for why that crashed the app. Keeps the
/// existing on-screen [PharmacyStockNumKeypad] alongside a real TextField so both the
/// device keyboard and the tap-keypad work.
class PharmacyStockQtyDialog extends StatefulWidget {
  final Drug drug;
  final int initialQty;
  final int available;

  const PharmacyStockQtyDialog({
    super.key,
    required this.drug,
    required this.initialQty,
    required this.available,
  });

  @override
  State<PharmacyStockQtyDialog> createState() => PharmacyStockQtyDialogState();
}

class PharmacyStockQtyDialogState extends State<PharmacyStockQtyDialog> {
  late final TextEditingController _qtyCtrl;
  late int _qty;

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

  void _onKey(String key) {
    setState(() {
      var qtyStr = '$_qty';
      if (key == 'C') {
        qtyStr = '0';
      } else if (key == '←') {
        qtyStr = qtyStr.length <= 1
            ? '0'
            : qtyStr.substring(0, qtyStr.length - 1);
      } else {
        qtyStr = qtyStr == '0' ? key : qtyStr + key;
      }
      _qty = int.tryParse(qtyStr) ?? 0;
      _qtyCtrl.text = '$_qty';
    });
  }

  @override
  Widget build(BuildContext context) {
    final drug = widget.drug;
    final available = widget.available;
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
                  pharmacyStockQtyLine(context.l10n.t('drug'), drug.name),
                  pharmacyStockQtyLine(
                    context.l10n.t('manufacturer'),
                    drug.manufacturer.isNotEmpty ? drug.manufacturer : '—',
                  ),
                  pharmacyStockQtyLine(
                    context.l10n.t('expiryDate'),
                    drug.expiryDate?.isNotEmpty == true
                        ? drug.expiryDate!
                        : '—',
                  ),
                  pharmacyStockQtyLine(
                    context.l10n.t('serialNumber'),
                    drug.serialNumber?.isNotEmpty == true
                        ? drug.serialNumber!
                        : '—',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  PharmacyStockQtyButton(
                    icon: Icons.remove_rounded,
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
                  PharmacyStockQtyButton(
                    icon: Icons.add_rounded,
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
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PharmacyStockNumKeypad(onKey: _onKey),
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

/// Compact quantity-edit sheet used by PharmacyStockConfirmScreen. Own
/// [StatefulWidget] for the same reason as [PharmacyStockQtyDialog] — see its
/// doc comment.
class PharmacyStockEditQtyDialog extends StatefulWidget {
  final int initialQty;
  final int available;

  const PharmacyStockEditQtyDialog({
    super.key,
    required this.initialQty,
    required this.available,
  });

  @override
  State<PharmacyStockEditQtyDialog> createState() =>
      PharmacyStockEditQtyDialogState();
}

class PharmacyStockEditQtyDialogState
    extends State<PharmacyStockEditQtyDialog> {
  late final TextEditingController _qtyCtrl;
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty;
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

  void _onKey(String key) {
    setState(() {
      var qtyStr = '$_qty';
      if (key == 'C') {
        qtyStr = '0';
      } else if (key == '←') {
        qtyStr = qtyStr.length <= 1
            ? '0'
            : qtyStr.substring(0, qtyStr.length - 1);
      } else {
        qtyStr = qtyStr == '0' ? key : qtyStr + key;
      }
      _qty = int.tryParse(qtyStr) ?? 0;
      _qtyCtrl.text = '$_qty';
    });
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.available;
    final isOverStock = _qty > available;
    final canIncrease = _qty < available;
    final counterColor = isOverStock
        ? AppColors.error
        : const Color(0xFFE9A165);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.t('quantity'),
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              PharmacyStockQtyButton(
                icon: Icons.remove_rounded,
                onTap: () => _setQty(_qty > 1 ? _qty - 1 : 0),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: counterColor, width: 1.5),
                  ),
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
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
              const SizedBox(width: 10),
              PharmacyStockQtyButton(
                icon: Icons.add_rounded,
                onTap: canIncrease ? () => _setQty(_qty + 1) : null,
              ),
            ],
          ),
          if (isOverStock) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.t('availableN', args: {'n': '$available'}),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: 10),
          PharmacyStockNumKeypad(onKey: _onKey),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _qty <= 0 || isOverStock
                ? null
                : () => Navigator.pop(context, _qty),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.l10n.t('saved'),
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PharmacyStockNumKeypad extends StatelessWidget {
  final void Function(String key) onKey;

  const PharmacyStockNumKeypad({super.key, required this.onKey});

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

class PharmacyStockQtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const PharmacyStockQtyButton({super.key, required this.icon, this.onTap});

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
          size: 28,
          color: onTap == null ? AppColors.hintText : AppColors.primaryText,
        ),
      ),
    );
  }
}
