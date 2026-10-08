import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Temporary screen for tabs that are built in later phases.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.icon, required this.message});
  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.sky.fade(0.8)),
            const SizedBox(height: 16),
            Text(title, style: AppText.h2),
            const SizedBox(height: 8),
            Text(message, style: AppText.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
