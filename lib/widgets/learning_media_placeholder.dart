import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

enum LearningMediaType {
  image,
  video,
  screenRecording,
  model3d,
  animation,
  project
}

/// Reusable media frame. With no asset supplied, it renders a labelled preview;
/// invalid optional assets also fall back safely.
class LearningMediaPlaceholder extends StatelessWidget {
  const LearningMediaPlaceholder(
      {super.key,
      required this.type,
      this.assetPath,
      this.caption,
      this.aspectRatio = 16 / 9});
  final LearningMediaType type;
  final String? assetPath;
  final String? caption;
  final double aspectRatio;

  String get _label =>
      caption ??
      switch (type) {
        LearningMediaType.image => 'Image coming soon',
        LearningMediaType.video => 'Video placeholder',
        LearningMediaType.screenRecording => 'Screen recording placeholder',
        LearningMediaType.model3d => '3D preview coming soon',
        LearningMediaType.animation => 'Animation preview coming soon',
        LearningMediaType.project => 'Student project example coming soon',
      };
  IconData get _icon => switch (type) {
        LearningMediaType.video ||
        LearningMediaType.screenRecording =>
          Icons.play_circle_outline,
        LearningMediaType.model3d => Icons.view_in_ar_outlined,
        LearningMediaType.animation => Icons.animation_outlined,
        LearningMediaType.project => Icons.work_outline,
        _ => Icons.image_outlined,
      };

  @override
  Widget build(BuildContext context) => AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DecoratedBox(
              decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  border: Border.all(color: AppColors.glassBorder)),
              child: assetPath == null
                  ? _fallback()
                  : Image.asset(assetPath!,
                      fit: BoxFit.cover,
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) =>
                              frame != null || wasSynchronouslyLoaded
                                  ? child
                                  : _loading(),
                      errorBuilder: (_, __, ___) => _fallback()))));

  Widget _loading() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF15233D), Color(0xFF0B1222)],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Loading media preview',
            ),
          ),
        ),
      );

  Widget _fallback() => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(_icon, color: AppColors.sky, size: 34),
        const SizedBox(height: 8),
        Text(_label, style: AppText.caption, textAlign: TextAlign.center)
      ]));
}
