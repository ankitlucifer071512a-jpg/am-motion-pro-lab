import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/services/course_repository.dart';

void main() {
  test('each course has its own useful outline and practice brief', () {
    final courses = CourseRepository.courses;

    expect(courses, hasLength(5));
    expect(courses.map((course) => course.description).toSet(), hasLength(5));
    for (final course in courses) {
      expect(course.suitedFor, isNotEmpty, reason: course.name);
      expect(course.prerequisites, isNotEmpty, reason: course.name);
      expect(course.modules, hasLength(4), reason: course.name);
      expect(
          course.modules.every((module) => module.topics.length == 3), isTrue,
          reason: course.name);
      expect(course.practiceProjects, isNotEmpty, reason: course.name);
      expect(course.finalProject, isNotEmpty, reason: course.name);
    }
  });
}
