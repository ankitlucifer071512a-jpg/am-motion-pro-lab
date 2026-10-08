import 'package:flutter/material.dart';

/// AM Motion Lab brand colors (same tokens as the website's style.css).
class AppColors {
  AppColors._();

  static const navy = Color(0xFF0F172A);
  static const navyDeep = Color(0xFF090E1A);
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF6D28D9);
  static const sky = Color(0xFF60A5FA);
  static const offWhite = Color(0xFFF8FAFC);

  static const ink = Color(0xFFE7ECF5);
  static const inkDim = Color(0xFFA7B2C6);
  static const inkFaint = Color(0xFF6E7A91);

  static const glassFill = Color(0x0EF8FAFC);
  static const glassFillStrong = Color(0x1AF8FAFC);
  static const glassBorder = Color(0x2994ADD6);
  static const glassBorderStrong = Color(0x4794ADD6);

  /// Used sparingly: main CTA, active indicator, progress.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, violet],
  );
}

extension ColorAlpha on Color {
  /// Same color with the given opacity (0..1). Works on every Flutter version.
  Color fade(double opacity) => withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}
