import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

class VisitSummaryScreen extends StatelessWidget {
  const VisitSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

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
              12,
              MediaQuery.of(context).padding.top + 8,
              12,
              10,
            ),
            child: Row(
              children: [
                AppTapScale(
                  pressedScale: 0.9,
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/visits'),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.primaryText,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Сводка визита',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Визит сохранён',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Данные доступны в истории визитов',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBg,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: shadowSm,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      children: [
                        _row(
                          'Дата',
                          '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}',
                        ),
                        const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
                        _row(
                          'Время',
                          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                        ),
                        const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
                        _row('Статус', 'Завершён'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  AppTapScale(
                    pressedScale: 0.97,
                    onTap: () => context.go('/visits'),
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        disabledBackgroundColor: AppColors.primary,
                        disabledForegroundColor: Colors.white,
                      ),
                      child: const Text('К визитам'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppTapScale(
                    pressedScale: 0.97,
                    onTap: () => context.go('/visits/history'),
                    child: OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        disabledForegroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      child: const Text('Открыть историю'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
