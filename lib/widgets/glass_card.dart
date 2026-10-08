import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Translucent surface with a thin light border (no blur filter, so it stays fast).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 14,
    this.selected = false,
    this.strong = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool selected;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: strong ? AppColors.glassFillStrong : AppColors.glassFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: selected ? AppColors.sky.fade(0.7) : AppColors.glassBorder),
        boxShadow: selected
            ? [BoxShadow(color: AppColors.blue.fade(0.28), blurRadius: 22, spreadRadius: -2)]
            : const [],
      ),
      child: child,
    );
  }
}
