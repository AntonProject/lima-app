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
}
