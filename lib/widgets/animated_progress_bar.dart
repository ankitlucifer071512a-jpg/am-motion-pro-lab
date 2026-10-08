import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Progress bar that animates smoothly to its value (0..1).
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({super.key, required this.value, this.height = 6});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Stack(
            children: [
              Container(height: height, color: AppColors.glassBorder),
              FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  height: height,
                  decoration: const BoxDecoration(gradient: AppColors.brandGradient),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
