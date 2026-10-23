import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/services/course_repository.dart';
import 'package:my_first_app/widgets/home_media_showcase.dart';

void main() {
  testWidgets('showcase remains 16:9 and opens the selected course',
      (tester) async {
    final courses = CourseRepository.courses;
    final openedCourses = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 700,
              child: HomeMediaShowcase(
                courses: courses,
                onExplore: (course) => openedCourses.add(course.id),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final bannerSize = tester.getSize(find.byType(AspectRatio).first);
    expect(bannerSize.width / bannerSize.height, closeTo(16 / 9, .01));
    expect(find.text('3D Animation'), findsOneWidget);

    await tester.tap(find.byTooltip('Next course'));
    await tester.pumpAndSettle();
    expect(find.text('Video Editing'), findsOneWidget);

    await tester.tap(find.text('Explore course'));
    expect(openedCourses, ['video-editing']);
  });

  testWidgets('showcase advances automatically after its interval',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 700,
              child: HomeMediaShowcase(
                courses: CourseRepository.courses,
                onExplore: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('3D Animation'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();

    expect(find.text('Video Editing'), findsOneWidget);
  });
}
