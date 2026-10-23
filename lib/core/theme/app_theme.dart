import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const _fontFallback = [
    // Installed on Windows; Android and other platforms use their system
    // Devanagari and emoji fallback when these families are unavailable.
    'Nirmala UI',
    'Segoe UI Emoji',
    'Apple Color Emoji',
    'Segoe UI Symbol',
    'sans-serif',
  ];

  static ThemeData get dark {
    return darkWithAccent(AppColors.blue, AppColors.violet);
  }

  static ThemeData darkWithAccent(Color primary, Color secondary) {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamilyFallback: _fontFallback,
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.navyDeep,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: AppColors.navy,
        onSurface: AppColors.ink,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStatePropertyAll(primary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : AppColors.inkDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary.withValues(alpha: .38)
              : AppColors.glassFillStrong,
        ),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.offWhite,
        fontFamilyFallback: _fontFallback,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: GoogleFonts.poppins(
          color: AppColors.ink,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.glassBorderStrong),
        ),
      ),
    );
  }
}

/// Text styles: Poppins for UI, Staatliches for the brand mark (same as website).
class AppText {
  AppText._();

  static TextStyle mark(
    double size, {
    Color color = AppColors.offWhite,
    double spacing = 3,
  }) => GoogleFonts.staatliches(
    fontSize: size,
    color: color,
    letterSpacing: spacing,
    height: 1.05,
  );

  static TextStyle get h1 => GoogleFonts.poppins(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.offWhite,
    height: 1.22,
  ).copyWith(fontFamilyFallback: AppTheme._fontFallback);
  static TextStyle get h2 => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.offWhite,
    height: 1.25,
  ).copyWith(fontFamilyFallback: AppTheme._fontFallback);
  static TextStyle get h3 => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.offWhite,
    height: 1.3,
  ).copyWith(fontFamilyFallback: AppTheme._fontFallback);
  static TextStyle get body => GoogleFonts.poppins(
    fontSize: 14,
    color: AppColors.inkDim,
    height: 1.55,
  ).copyWith(fontFamilyFallback: AppTheme._fontFallback);
  static TextStyle get label => GoogleFonts.poppins(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: AppColors.sky,
  ).copyWith(fontFamilyFallback: AppTheme._fontFallback);
  static TextStyle get caption => GoogleFonts.poppins(
    fontSize: 12,
    color: AppColors.inkFaint,
    height: 1.4,
  ).copyWith(fontFamilyFallback: AppTheme._fontFallback);
}
