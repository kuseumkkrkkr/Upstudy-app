import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/services/api/course_service.dart';

void main() {
  test('v2 module payload parses into executable units', () {
    final course = CourseService.courseFromJsonForTest({
      'id': 'course-v2-1',
      'title': 'v2 코스',
      'description': 'desc',
      'difficulty': '중',
      'duration': '',
      'modules': [
        {
          'id': 'm1',
          'type': 'textbook_view',
          'page_from': 1,
          'page_to': 10,
          'min_minutes': 10,
        },
        {
          'id': 'm2',
          'type': 'problem_solve',
          'hash_tags': ['함수'],
          'question_count': 3,
          'pass_rate': 100,
        },
        {
          'id': 'm3',
          'type': 'exam_solve',
          'exam_id': 'exam-1',
          'exam_duration': 20,
        },
      ],
    });

    expect(course.units.length, 3);
    expect(course.units[0].detail['type'], 'textbook_view');
    expect(course.units[1].detail['type'], 'problem_solve');
    expect(course.units[2].detail['type'], 'exam_solve');
    expect(course.units[2].detail['exam_id'], 'exam-1');
    expect(course.units[2].detail['exam_duration'], 20);
  });
}
