import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/theme/app_theme.dart';

enum DrugStatus { familiarPrescribes, familiarNotPrescribes, unfamiliar, other }

Future<DrugStatus?> showMedicalStatusSheet(
  BuildContext context, {
  required String drugName,
}) {
  return showModalBottomSheet<DrugStatus>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MedicalStatusSheet(drugName: drugName),
  );
}

class _MedicalStatusSheet extends StatefulWidget {
  final String drugName;
  const _MedicalStatusSheet({required this.drugName});

  @override
  State<_MedicalStatusSheet> createState() => _MedicalStatusSheetState();
}

class _MedicalStatusSheetState extends State<_MedicalStatusSheet> {
  DrugStatus? _selected;
  int _qty = 0;
  final _qtyController = TextEditingController(text: '0');
  final _commentController = TextEditingController();

  bool get _canSave {
    if (_selected == null) return false;
    if (_selected == DrugStatus.other && _commentController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  void _setQty(int v) {
    final clamped = v < 0 ? 0 : v;
    setState(() {
      _qty = clamped;
      _qtyController.text = '$clamped';
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.6 + bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + bottomPad + 16),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.drugName,
                    style: GoogleFonts.manrope(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.secondaryText, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 0.5, color: AppColors.divider),
            const SizedBox(height: 16),
            ..._statusOptions().map((opt) => _StatusCard(
              icon: opt.$1, iconBg: opt.$2, iconColor: opt.$3,
              title: opt.$4, subtitle: opt.$5, status: opt.$6,
              selectedColor: opt.$3,
              isSelected: _selected == opt.$6,
              onTap: () => setState(() => _selected = opt.$6),
            )),
            // "Количество лимиков" — only for familiarPrescribes
            if (_selected == DrugStatus.familiarPrescribes) ...[
              const SizedBox(height: 4),
              Text(
                'Количество лимиков',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (v) {
                          final parsed = int.tryParse(v) ?? 0;
                          setState(() => _qty = parsed);
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CounterBtn(
                          icon: Icons.remove,
                          onTap: () => _setQty(_qty - 1),
                        ),
                        Container(width: 1, height: 24, color: AppColors.border),
                        _CounterBtn(
                          icon: Icons.add,
                          onTap: () => _setQty(_qty + 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            // Comment field — always shown
            if (_selected != null) ...[
              const SizedBox(height: 12),
              Text(
                'Комментарий',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _commentController,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Добавьте комментарий...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _canSave ? () => Navigator.pop(context, _selected) : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
              ),
              child: Text(
                context.l10n.t('saved'),
                style: GoogleFonts.manrope(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white,
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  List<(IconData, Color, Color, String, String, DrugStatus)> _statusOptions() => [
    (Icons.check_circle_rounded, const Color(0xFFE8F5E9), AppColors.success,
        context.l10n.t('familiar'), context.l10n.t('prescribes'), DrugStatus.familiarPrescribes),
    (Icons.remove_circle_rounded, const Color(0xFFFFF8E1), const Color(0xFFFFB300),
        context.l10n.t('familiar'), context.l10n.t('notPrescribes'), DrugStatus.familiarNotPrescribes),
    (Icons.cancel_rounded, const Color(0xFFFFEBEE), AppColors.error,
        context.l10n.t('unfamiliar'), context.l10n.t('notPrescribes'), DrugStatus.unfamiliar),
    (Icons.chat_bubble_rounded, const Color(0xFFF5F5F5), AppColors.secondaryText,
        context.l10n.t('noneAbove'), context.l10n.t('leaveComment'), DrugStatus.other),
  ];
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CounterBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 48,
        child: Icon(icon, size: 18, color: AppColors.secondaryText),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle;
  final DrugStatus status;
  final Color selectedColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusCard({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.title, required this.subtitle, required this.status,
    required this.selectedColor,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? selectedColor : AppColors.border,
              width: isSelected ? 2 : 1.5,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.manrope(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: AppColors.primaryText)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: GoogleFonts.manrope(
                            fontSize: 12, color: AppColors.secondaryText)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
