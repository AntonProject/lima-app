import 'package:flutter/widgets.dart';

class LimaNavBarLayout {
  const LimaNavBarLayout._();

  static const double barHeight = 100;
  static const double contentBottomSpacing = barHeight + 24;

  static double totalBarHeight(BuildContext context) {
    return barHeight + MediaQuery.of(context).padding.bottom;
  }

  static double scrollBottomPadding(BuildContext context) {
    return totalBarHeight(context) + 24;
  }

  /// Canonical `bottom` offset for a floating CTA that sits just above the nav
  /// bar (matches the "Найти рядом" button the design is standardised on).
  /// Use this for any `Positioned` CTA on a screen that shows the nav bar so
  /// every action button lands at the same height.
  static double ctaBottomOffset(BuildContext context) {
    return totalBarHeight(context) - 10;
  }
}
