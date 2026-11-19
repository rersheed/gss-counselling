import 'package:flutter/material.dart';

/// Calm green + warm amber palette — soft, friendly, and close to the
/// school's green. Inspired by counselling-app shots on Dribbble.
class AppColors {
  static const primary = Color(0xFF0E7C5A);
  static const primaryDark = Color(0xFF0A5C43);
  static const mint = Color(0xFFE3F2EA);
  static const background = Color(0xFFF4F8F5);
  static const surface = Colors.white;
  static const amber = Color(0xFFF5A524);
  static const amberSoft = Color(0xFFFFF3DC);
  static const danger = Color(0xFFE5484D);
  static const dangerSoft = Color(0xFFFDECEC);
  static const lilac = Color(0xFF7C6BD6);
  static const lilacSoft = Color(0xFFEEEBFB);
  static const sky = Color(0xFF2E8BD8);
  static const skySoft = Color(0xFFE6F1FB);
  static const ink = Color(0xFF14231C);
  static const muted = Color(0xFF6B7B73);
  static const line = Color(0xFFE2EAE5);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.amber,
    error: AppColors.danger,
    surface: AppColors.surface,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'PlusJakartaSans');
  final text = base.textTheme.apply(
    fontFamily: 'PlusJakartaSans',
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.mint,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
        text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Shared input style (kept out of ThemeData to stay compatible across
/// Flutter versions).
InputDecoration inputDeco(String label, {IconData? icon, String? hint, String? helper}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    prefixIcon: icon == null ? null : Icon(icon, color: AppColors.muted),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(AppColors.line),
    enabledBorder: border(AppColors.line),
    focusedBorder: border(AppColors.primary, 1.6),
    errorBorder: border(AppColors.danger),
  );
}
