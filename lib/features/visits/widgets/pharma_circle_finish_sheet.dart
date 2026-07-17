import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/theme/app_theme.dart';

class PharmaCircleFinishPayload {
  final String fio;
  final int participantsCount;

  const PharmaCircleFinishPayload({
    required this.fio,
    required this.participantsCount,
  });
}

class PharmaCircleFinishSheet extends StatefulWidget {
  final int drugsCount;
  final int materialsCount;

  const PharmaCircleFinishSheet({
    super.key,
    required this.drugsCount,
    required this.materialsCount,
  });

  @override
  State<PharmaCircleFinishSheet> createState() =>
      PharmaCircleFinishSheetState();
}

class PharmaCircleFinishSheetState extends State<PharmaCircleFinishSheet> {
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
                            _participantsStr = (cur > 1 ? cur - 1 : 1)
                                .toString();
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
                    PharmaCircleNumKeypad(onKey: _onKey),
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
                          _meta(
                            context.l10n.t('discussedDrugsColon'),
                            '${widget.drugsCount}',
                          ),
                          const Divider(height: 10),
                          _meta(
                            context.l10n.t('shownMaterialsColon'),
                            '${widget.materialsCount}',
                          ),
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
                          PharmaCircleFinishPayload(
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

class PharmaCircleNumKeypad extends StatelessWidget {
  final void Function(String key) onKey;

  const PharmaCircleNumKeypad({super.key, required this.onKey});

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
