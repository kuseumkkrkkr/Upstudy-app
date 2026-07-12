import 'package:flutter_test/flutter_test.dart';
import 'package:s11_teacher/services/course_builder_payload.dart';

void main() {
  test('buildCourseV2Payload keeps module payload shape', () {
    final payload = buildCourseV2Payload(
      title: '코스A',
      description: '설명',
      advancedOpen: true,
      difficulty: '중',
      targetOvr: 1200,
      tags: const ['함수', '수열'],
      focusTags: const ['함수'],
      textbookId: 'tb-1',
      modules: <Map<String, dynamic>>[
        {
          'id': 'mod_0',
          'position': 0,
          'type': 'textbook_view',
          'title': '교재보기',
          'page_from': 3,
          'page_to': 15,
          'min_minutes': 10,
          'enforce_min_minutes': false,
        },
        {
          'id': 'mod_1',
          'position': 1,
          'type': 'problem_solve',
          'title': '문제풀기',
          'hash_tags': ['함수'],
          'question_count': 5,
          'difficulty': '중',
          'pass_rate': 100,
          'objectify_mode': 'all',
          'problem_ids': ['q1', 'q2'],
        },
        {
          'id': 'mod_2',
          'position': 2,
          'type': 'exam_solve',
          'title': '시험지풀기',
          'exam_id': 'exam-9',
          'exam_duration': 30,
          'show_timer': true,
        },
      ],
      curriculumEnabled: true,
      curriculumEveryNDays: 2,
      curriculumMaxDeadlineDeviation: 1,
      curriculumDailyMaxModules: 3,
      moduleDeadlineDays: const [0, 2, 4],
      wrongAnswerReviewEnabled: false,
    );

    expect(payload['title'], '코스A');
    expect(payload['textbook_id'], 'tb-1');
    final modules = payload['modules'] as List<dynamic>;
    expect(modules.length, 3);
    expect((modules[0] as Map<String, dynamic>)['type'], 'textbook_view');
    expect((modules[1] as Map<String, dynamic>)['type'], 'problem_solve');
    expect((modules[2] as Map<String, dynamic>)['type'], 'exam_solve');
    expect((modules[1] as Map<String, dynamic>)['problem_ids'], ['q1', 'q2']);
    expect(payload['challenge_settings']['daily_random_count_min'], 3);
    expect(payload['curriculum_settings']['module_deadline_days'], [0, 2, 4]);
    expect(
      payload['runtime_flags']['enable_wrong_answer_auto_insert'],
      isFalse,
    );
  });

  test('buildCourseV2Payload omits top-level textbook when empty', () {
    final payload = buildCourseV2Payload(
      title: '코스B',
      description: '설명',
      advancedOpen: false,
      difficulty: '중',
      targetOvr: 0,
      tags: const [],
      focusTags: const [],
      textbookId: '',
      modules: <Map<String, dynamic>>[
        {
          'id': 'mod_0',
          'position': 0,
          'type': 'textbook_view',
          'title': '교재보기',
          'textbook_id': 'tb-9',
          'page_from': 1,
          'page_to': 3,
        },
      ],
      curriculumEnabled: false,
      curriculumEveryNDays: 0,
      curriculumMaxDeadlineDeviation: 0,
      curriculumDailyMaxModules: 0,
      moduleDeadlineDays: const [0],
    );

    expect(payload.containsKey('textbook_id'), isFalse);
    expect((payload['modules'] as List).length, 1);
    expect(payload['runtime_flags']['enable_wrong_answer_auto_insert'], isTrue);
  });
}
