import 'package:flutter/widgets.dart';

/// Tells tab screens the keyboard is up. They can't read it themselves: the
/// shell [Scaffold] removes the bottom view inset from its body.
class ShellKeyboard extends InheritedWidget {
  final bool isOpen;

  const ShellKeyboard({super.key, required this.isOpen, required super.child});

  static bool isOpenOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellKeyboard>()?.isOpen ??
      false;

  @override
  bool updateShouldNotify(ShellKeyboard oldWidget) =>
      isOpen != oldWidget.isOpen;
}

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
