import 'package:flutter/material.dart';

import '../../app/transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/course_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_button.dart';
import '../../widgets/course_image.dart';
import '../../widgets/glass_card.dart';
import 'course_detail_screen.dart';
import 'course_learning_screen.dart';

class PurchaseCoursesScreen extends StatelessWidget {
  const PurchaseCoursesScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        children: [
          Text('ENROLLMENT', style: AppText.label),
          const SizedBox(height: 6),
          Text('Purchase Courses', style: AppText.h1),
          const SizedBox(height: 6),
          Text(
              'Compare plans, then preview course-specific classes and lessons.',
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
                  'Demo catalogue • Secure enrollment and payment are not configured. No payment will be taken and opening previews does not enroll you.',
                  style: AppText.body.copyWith(fontSize: 13),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          for (final course in CourseRepository.courses) ...[
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(14)),
                      child: SizedBox(
                        height: 112,
                        width: double.infinity,
                        child: Stack(fit: StackFit.expand, children: [
                          CourseImage(course: course),
                          DecoratedBox(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                AppColors.navyDeep.fade(.9),
                                AppColors.navyDeep.fade(.12)
                              ]))),
                          Positioned(
                              left: 15,
                              right: 15,
                              bottom: 12,
                              child: Text(course.name, style: AppText.h2)),
                        ]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(course.tagline, style: AppText.caption),
                            const SizedBox(height: 12),
                            for (final plan in course.plans)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 11, vertical: 9),
                                  decoration: BoxDecoration(
                                      color: AppColors.glassFill,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AppColors.glassBorder)),
                                  child: Row(children: [
                                    Expanded(
                                        child: Text(
                                            '${plan.label}  •  ${plan.duration}',
                                            style: AppText.body
                                                .copyWith(fontSize: 12.5))),
                                    Text(rupees(plan.price),
                                        style: AppText.h3.copyWith(
                                            fontSize: 15,
                                            color: AppColors.sky)),
                                  ]),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text('Learning options',
                                style: AppText.label.copyWith(fontSize: 10)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: _LearningOption(
                                icon: Icons.sensors_outlined,
                                label: 'Live Classes',
                                onTap: () => CourseLearningScreen.open(
                                    context, course,
                                    tab: CourseLearningTab.live),
                              )),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _LearningOption(
                                icon: Icons.play_lesson_outlined,
                                label: 'Recorded',
                                onTap: () =>
                                    CourseLearningScreen.open(context, course),
                              )),
                            ]),
                            const SizedBox(height: 9),
                            Row(children: [
                              Expanded(
                                  child: Text(
                                      'Enrollment: Not enrolled in this demo',
                                      style: AppText.caption
                                          .copyWith(fontSize: 10.5))),
                              AppButton(
                                  label: 'Course details',
                                  primary: false,
                                  icon: Icons.arrow_forward_rounded,
                                  onTap: () => Navigator.of(context).push(
                                      AppRoutes.fadeScale(CourseDetailScreen(
                                          course: course,
                                          heroTag:
                                              'purchase-course-${course.id}')))),
                            ]),
                            const SizedBox(height: 8),
                            Text('No course materials are configured yet.',
                                style: AppText.caption),
                          ]),
                    ),
                  ]),
            ),
            const SizedBox(height: 13),
          ],
        ],
      );
}

class _LearningOption extends StatelessWidget {
  const _LearningOption(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.glassBorderStrong)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 17, color: AppColors.sky),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: AppColors.ink))),
            ]),
          ),
        ),
      );
}
