import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_theme.dart';

enum PlanProgressLevel { unavailable, low, medium, high }

PlanProgressLevel planProgressLevel(double? value) {
  if (value == null) return PlanProgressLevel.unavailable;
  if (value >= 80) return PlanProgressLevel.high;
  if (value >= 40) return PlanProgressLevel.medium;
  return PlanProgressLevel.low;
}

Color planProgressColor(double? value) {
  return switch (planProgressLevel(value)) {
    PlanProgressLevel.unavailable => AppColors.hintText,
    PlanProgressLevel.low => AppColors.error,
    PlanProgressLevel.medium => AppColors.warning,
    PlanProgressLevel.high => AppColors.success,
  };
}

String planPercentLabel(double? value) =>
    value == null ? '—' : '${value.round()}%';

String planLocaleName(BuildContext context) {
  final locale = Localizations.localeOf(context);
  final country = locale.countryCode;
  return country == null || country.isEmpty
      ? locale.languageCode
      : '${locale.languageCode}_$country';
}

String formatPlanInt(BuildContext context, int value) {
  return NumberFormat.decimalPattern(planLocaleName(context)).format(value);
}

String formatPlanMoney(BuildContext context, double value) {
  final absolute = value.abs();
  if (absolute >= 1000000000) {
    return '${_formatCompact(context, value / 1000000000)} '
        '${context.l10n.t('billionShort')}';
  }
  if (absolute >= 1000000) {
    return '${_formatCompact(context, value / 1000000)} '
        '${context.l10n.t('millionShort')}';
  }
  return '${formatPlanInt(context, value.round())} UZS';
}

String localizedPlanMonth(BuildContext context, int month) {
  final normalized = month.clamp(1, 12);
  final value = DateFormat.MMMM(
    planLocaleName(context),
  ).format(DateTime(2026, normalized, 1));
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _formatCompact(BuildContext context, double value) {
  return NumberFormat('0.00', planLocaleName(context)).format(value);
}

class PlanProgressBar extends StatelessWidget {
  final double? value;
  final double height;

  const PlanProgressBar({super.key, required this.value, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final factor = value == null
        ? 0.0
        : (value! / 100).clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFF0F3FB)),
            if (factor > 0)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: factor,
                child: ColoredBox(color: planProgressColor(value)),
              ),
          ],
        ),
      ),
    );
  }
}
