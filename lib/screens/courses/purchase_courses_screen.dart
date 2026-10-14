import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/course_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/glass_card.dart';

class PurchaseCoursesScreen extends StatelessWidget {
  const PurchaseCoursesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 30), children: [
        Text('ENROLLMENT', style: AppText.label),
        const SizedBox(height: 6),
        Text('Purchase Courses', style: AppText.h1),
        const SizedBox(height: 6),
        Text('Compare plans and durations for each creative path.',
            style: AppText.body),
        const SizedBox(height: 16),
        GlassCard(
            selected: true,
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: AppColors.sky),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'Demo catalogue • Secure enrollment is not configured in this app. No payment will be taken and no course will be marked as purchased.',
                      style: AppText.body.copyWith(fontSize: 13))),
            ])),
        const SizedBox(height: 18),
        for (final course in CourseRepository.courses) ...[
          GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name, style: AppText.h3),
                    const SizedBox(height: 4),
                    Text(course.tagline, style: AppText.caption),
                    const SizedBox(height: 12),
                    for (final plan in course.plans)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: AppColors.glassFill,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: AppColors.glassBorder)),
                              child: Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(plan.label,
                                          style: AppText.body
                                              .copyWith(color: AppColors.ink)),
                                      Text(plan.duration,
                                          style: AppText.caption)
                                    ])),
                                Text(rupees(plan.price),
                                    style: AppText.h3
                                        .copyWith(color: AppColors.sky)),
                              ]))),
                    Text('Enrollment status: Not enrolled in this demo',
                        style:
                            AppText.caption.copyWith(color: AppColors.inkDim)),
                  ])),
          const SizedBox(height: 12),
        ],
      ]);
}
