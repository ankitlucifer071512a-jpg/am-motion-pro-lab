import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/course.dart';
import '../utils/formatters.dart';
import 'animated_progress_bar.dart';
import 'course_image.dart';
import 'glass_card.dart';
import 'pressable.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.heroTag,
    required this.onTap,
    this.compact = false,
    this.progress,
  });

  final Course course;
  final String heroTag;
  final VoidCallback onTap;
  final bool compact; // compact = horizontal list on Home (no description)
  final double? progress; // null = not enrolled

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: AspectRatio(
                aspectRatio: compact ? 16 / 10 : 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(tag: heroTag, child: CourseImage(course: course)),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.navyDeep.fade(0), AppColors.navyDeep.fade(0.75)],
                        ),
                      ),
                    ),
                    Positioned(left: 12, bottom: 10, child: _Pill(course.durationLabel)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.name, style: AppText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(course.tagline, style: AppText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 10),
                  if (progress != null) ...[
                    AnimatedProgressBar(value: progress!),
                    const SizedBox(height: 6),
                    Text('${(progress! * 100).round()}% complete', style: AppText.caption),
                  ] else
                    Row(
                      children: [
                        Text('From ', style: AppText.caption),
                        Text(rupees(course.startingPrice),
                            style: AppText.h3.copyWith(color: AppColors.sky, fontSize: 15)),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.inkDim),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.navyDeep.fade(0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(text, style: AppText.caption.copyWith(color: AppColors.ink, fontSize: 11)),
    );
  }
}
