import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/course.dart';

/// Course thumbnail from assets. Falls back to a branded gradient if the image is missing.
class CourseImage extends StatelessWidget {
  const CourseImage({super.key, required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      course.imageAsset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 900,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          frame != null || wasSynchronouslyLoaded ? child : _fallback(),
      errorBuilder: (context, error, stack) => _fallback(),
    );
  }

  Widget _fallback() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.blue.fade(0.35),
              AppColors.navy,
              AppColors.violet.fade(0.35)
            ],
          ),
        ),
        child: Center(
            child: Icon(course.icon, size: 52, color: AppColors.sky.fade(0.6))),
      );
}
