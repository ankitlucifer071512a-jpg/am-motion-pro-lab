import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/course_repository.dart';
import '../../widgets/course_card.dart';
import '../../widgets/reveal.dart';
import 'course_detail_screen.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courses = CourseRepository.courses;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      itemCount: courses.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Reveal(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('COURSES', style: AppText.label),
                  const SizedBox(height: 6),
                  Text('Choose your creative path', style: AppText.h1),
                  const SizedBox(height: 6),
                  Text('Structured, practical, project-based. Pick a course, then pick your level.',
                      style: AppText.body),
                ],
              ),
            ),
          );
        }
        final course = courses[i - 1];
        final tag = 'course-img-${course.id}-list';
        return Reveal(
          delay: Duration(milliseconds: i < 4 ? 70 * i : 0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: CourseCard(
              course: course,
              heroTag: tag,
              onTap: () => CourseDetailScreen.open(context, course, tag),
            ),
          ),
        );
      },
    );
  }
}
