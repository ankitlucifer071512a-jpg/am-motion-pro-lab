import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.navyDeep,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        secondary: AppColors.violet,
        surface: AppColors.navy,
        onSurface: AppColors.ink,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme)
          .apply(bodyColor: AppColors.ink, displayColor: AppColors.offWhite),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: GoogleFonts.poppins(color: AppColors.ink, fontSize: 13),
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

  static TextStyle mark(double size, {Color color = AppColors.offWhite, double spacing = 3}) =>
      GoogleFonts.staatliches(fontSize: size, color: color, letterSpacing: spacing, height: 1.05);

  static TextStyle get h1 =>
      GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.offWhite, height: 1.22);
  static TextStyle get h2 =>
      GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.offWhite, height: 1.25);
  static TextStyle get h3 =>
      GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.offWhite, height: 1.3);
  static TextStyle get body =>
      GoogleFonts.poppins(fontSize: 14, color: AppColors.inkDim, height: 1.55);
  static TextStyle get label => GoogleFonts.poppins(
      fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1.6, color: AppColors.sky);
  static TextStyle get caption =>
      GoogleFonts.poppins(fontSize: 12, color: AppColors.inkFaint, height: 1.4);
}
