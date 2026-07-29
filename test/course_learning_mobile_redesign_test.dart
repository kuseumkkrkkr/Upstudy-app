import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/sessions/course/session/course_learning_page.dart';

/// 필요한 변수는 서버가 내려주는 코스·단원·미션 필드다.
/// 작동 원리: 기존 화면의 일차함수 고정 문구와 구별되는 데이터로 수강 후 화면을
/// 구성해 모든 주요 문구와 행동이 실제 모델에서 파생되는지 검증한다.
Course _geometryCourse() {
  return Course(
    id: 'geometry-live',
    title: '기하 심화 과정',
    description: '벡터와 공간도형을 연결하는 2단계 코스',
    level: '고등학교 2학년',
    duration: '6주',
    progress: .25,
    progressDetail: {
      'module_results': {
        'vector-problem': {'latest_elapsed_seconds': 125},
      },
    },
    status: 'in_progress',
    types: const ['기하'],
    focusTags: const ['벡터'],
    targetOvr: 27,
    units: const [
      CourseUnit(
        title: '공간벡터 문제 해결',
        type: 'problem_solve',
        detail: {'topic': '공간벡터', 'description': '좌표와 벡터를 연결합니다.'},
        status: CourseUnitStatus.active,
        estimatedMinutes: 20,
        missions: [
          CourseUnitMission(
            title: '공간벡터 기본 문제',
            detail: {'type': 'problem_solve'},
          ),
        ],
      ),
      CourseUnit(
        title: '공간도형 평가',
        type: 'exam_solve',
        detail: {'topic': '공간도형'},
        status: CourseUnitStatus.locked,
        estimatedMinutes: 30,
        missions: [
          CourseUnitMission(
            title: '공간도형 단원 평가',
            detail: {'type': 'exam_solve'},
          ),
        ],
      ),
    ],
  );
}

/// 필요한 변수는 모바일 논리 크기와 고정 코스다.
/// 작동 원리: 네트워크 상세 조회를 주입 로더로 대체해 화면 렌더링만 독립 검증한다.
Future<void> _pumpMobile(WidgetTester tester, Course course) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: CourseLearningPage(
        course: course,
        courseLoader: (_) async => course,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('수강 후 모바일 화면은 코스 데이터와 미션 유형으로 내용을 구성한다', (tester) async {
    final course = _geometryCourse();
    await _pumpMobile(tester, course);

    expect(
      find.byKey(const ValueKey('course-learning-mobile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('course-learning-mobile-overview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('course-learning-mobile-current')),
      findsOneWidget,
    );
    expect(find.text('기하 심화 과정'), findsOneWidget);
    expect(find.text('벡터와 공간도형을 연결하는 2단계 코스'), findsOneWidget);
    expect(find.text('고등학교 2학년'), findsOneWidget);
    expect(find.text('6주'), findsOneWidget);
    expect(find.text('공간벡터 문제 해결'), findsWidgets);
    expect(find.text('공간벡터 기본 문제'), findsWidgets);
    expect(find.text('문제 풀기'), findsWidgets);
    expect(find.text('02:05'), findsOneWidget);

    expect(find.text('중학교 2학년'), findsNothing);
    expect(find.textContaining('일차함수의 개념부터'), findsNothing);
    expect(find.text('18.6'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
