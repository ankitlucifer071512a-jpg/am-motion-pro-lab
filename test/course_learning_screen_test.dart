import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/screens/courses/course_learning_screen.dart';
import 'package:my_first_app/services/course_repository.dart';
import 'package:my_first_app/services/learning_progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  testWidgets('course live tab shows pending schedule without fake join action',
      (tester) async {
    final course = CourseRepository.courses.first;
    await tester.pumpWidget(MaterialApp(
      home: CourseLearningScreen(
          course: course, initialTab: CourseLearningTab.live),
    ));

    expect(find.text('Live class setup pending'), findsOneWidget);
    expect(find.text('No live classes scheduled yet'), findsOneWidget);
    expect(find.text('Join Live Class'), findsNothing);
  });

  testWidgets('sample lesson can be completed and saved as local demo progress',
      (tester) async {
    final course = CourseRepository.courses.first;
    await tester.pumpWidget(MaterialApp(
      home: CourseLearningScreen(course: course),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sample lesson outlines'), findsOneWidget);
    expect(find.textContaining('Sample outline'), findsWidgets);
    await tester.tap(find.text('Understanding the basics'));
    await tester.pumpAndSettle();
    expect(find.text('Lesson preview'), findsOneWidget);
    expect(find.textContaining('Recording unavailable'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mark demo outline complete'),
      250,
      scrollable: find.descendant(
        of: find.byType(Scaffold).last,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Mark demo outline complete'));
    await tester.pumpAndSettle();

    expect(await LearningProgressStore.instance.completedCourseLessons,
        contains('${course.id}:lesson-0'));
    expect(find.text('1 of 12 demo lessons'), findsOneWidget);
  });
}
