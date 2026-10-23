import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;

import '../core/theme/app_colors.dart';
import '../services/idea_lab_backend.dart';

/// A poster-only card. Playback starts in the existing detail player after tap.
class IdeaCommunityVideoPreview extends StatelessWidget {
  const IdeaCommunityVideoPreview({
    super.key,
    required this.media,
    required this.viewCount,
    this.onTap,
  });

  final IdeaLabPostMedia media;
  final int? viewCount;
  final VoidCallback? onTap;

  String _duration(Duration? duration) {
    if (duration == null) return '--:--';
    final seconds = duration.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.navyDeep,
    child: InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media.thumbnailUrl case final url?)
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: MediaQuery.disableAnimationsOf(context) ? 0 : 16,
                sigmaY: MediaQuery.disableAnimationsOf(context) ? 0 : 16,
              ),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _BrandedVideoFallback(),
              ),
            )
          else
            const _BrandedVideoFallback(),
          if (media.thumbnailUrl case final url?)
            Center(
              child: AspectRatio(
                aspectRatio: media.aspectRatio,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const _BrandedVideoFallback(),
                ),
              ),
            ),
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
          Positioned(
            left: 7,
            bottom: 7,
            child: _VideoBadge(
              icon: Icons.schedule_rounded,
              label: _duration(media.duration),
            ),
          ),
          Positioned(
            right: 7,
            bottom: 7,
            child: _VideoBadge(
              icon: Icons.visibility_outlined,
              label: viewCount == null ? '— views' : '$viewCount views',
            ),
          ),
        ],
      ),
    ),
  );
}

class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.navyDeep.withValues(alpha: .88),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    ),
  );
}

class _BrandedVideoFallback extends StatelessWidget {
  const _BrandedVideoFallback();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff142957), Color(0xff101728), Color(0xff35215f)],
      ),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Icon(
          Icons.movie_creation_outlined,
          color: AppColors.sky,
          size: 44,
        ),
        Positioned(
          right: 10,
          bottom: 8,
          child: Text(
            'AM MOTION LAB',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    ),
  );
}
