import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Uses the REAL logo files from the website (copy them into assets/brand/).
/// If the file is missing, shows a simple "AM" text so the app never crashes.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 64, this.full = false});
  final double size;
  final bool full; // true = full-logo.png, false = icon_logo.png

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      full ? 'assets/brand/full-logo.png' : 'assets/brand/icon_logo.png',
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => SizedBox(
        height: size,
        width: size,
        child: Center(child: Text('AM', style: AppText.mark(size * 0.6, color: AppColors.sky))),
      ),
    );
  }
}
