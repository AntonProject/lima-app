import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF417DF7);
  static const primaryDark = Color(0xFF2E68E0);
  static const secondary = Color(0xFF5A8EF8);
  static const accent = Color(0xFFFF9500);
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFF9CF58);
  static const error = Color(0xFFFF3B30);

  static const primaryText = Color(0xFF2C3E50);
  static const secondaryText = Color(0xFF7A848A);
  static const hintText = Color(0xFFB7BBBF);

  static const primaryBg = Color(0xFFF4F7FA);
  static const secondaryBg = Color(0xFFFFFFFF);

  // Icon backgrounds
  static const iconBgBlue = Color(0xFFE3F2FD);
  static const iconBgGreen = Color(0xFFE8F5E9);
  static const iconBgPurple = Color(0xFFEEF2FF);
  static const iconBgOrange = Color(0xFFFFF7ED);
  static const iconBgGray = Color(0xFFF0F4FF);
  static const iconBgLight = Color(0xFFF0F2F5);

  static const divider = Color(0xFFE8ECF0);
  static const border = Color(0xFFE0E6ED);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(useMaterial3: true);
    final manropeBase = base.copyWith(
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme),
    );
    return manropeBase.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.secondaryBg,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.primaryBg,
      textTheme: manropeBase.textTheme.copyWith(
        displayLarge: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
        displayMedium: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.primaryText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.primaryText,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.secondaryText,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.primaryText,
        ),
        labelMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.primaryText,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.secondaryText,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.secondaryBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.secondaryBg,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.hintText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          elevation: 1,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(double.infinity, 44),
          elevation: 1,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondaryBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        // Keep the search/prefix icon close to the text (≤8px gap).
        prefixIconConstraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 34,
        ),
        hintStyle: TextStyle(color: AppColors.hintText, fontSize: 14),
        prefixIconColor: AppColors.hintText,
      ),
      cardTheme: CardThemeData(
        color: AppColors.secondaryBg,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}

// ─── Shared shadow ────────────────────────────────────────────────────────────
List<BoxShadow> get shadowSm => [
  const BoxShadow(
    color: Color(0x14000000),
    blurRadius: 3,
    offset: Offset(0, 1),
  ),
];

List<BoxShadow> get shadowMd => [
  const BoxShadow(
    color: Color(0x14000000),
    blurRadius: 6,
    offset: Offset(0, 3),
  ),
];

List<BoxShadow> get shadowLg => [
  const BoxShadow(
    color: Color(0x18000000),
    blurRadius: 15,
    offset: Offset(0, 8),
  ),
];
