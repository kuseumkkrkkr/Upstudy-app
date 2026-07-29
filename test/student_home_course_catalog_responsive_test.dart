import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';

/// 필요한 값은 코스 상태가 다른 고정 목록이다.
/// 네트워크 없이 수강 중 직행과 완료 코스 미리보기의 반응형 카드 구조를 재현한다.
List<Course> _courses() {
  return const [
    Course(
      id: 'active',
      title: '일차함수 완성',
      description: '그래프와 기울기를 학습하는 진행 코스',
      level: '중2',
      duration: '3주',
      status: 'in_progress',
      progress: .42,
      lessons: 12,
      targetOvr: 22,
      focusTags: ['함수', '그래프'],
    ),
    Course(
      id: 'complete',
      title: '일차방정식 기초',
      description: '완료한 코스는 상세에서만 미리보기 합니다.',
      level: '중2',
      duration: '2주',
      status: 'completed',
      progress: 1,
      lessons: 8,
      focusTags: ['방정식'],
    ),
  ];
}

/// 필요한 값은 논리 화면 크기와 실제 학생 화면이다.
/// 390·500·1280 폭을 직접 주입해 공용 셸 수정 없이 화면 내부 반응형 키와 주요 문구를 검증한다.
Future<void> _pumpAt(WidgetTester tester, Size size, Widget page) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump();
}

void main() {
  testWidgets('코스 카탈로그는 1280 PC와 390·500 모바일에서 모든 필터와 상태 카드를 유지한다', (
    tester,
  ) async {
    for (final width in [1280.0, 390.0, 500.0]) {
      await _pumpAt(
        tester,
        Size(width, 900),
        CourseCatalogPage(
          courseFeedLoader: ({required keyword, recommend}) async => _courses(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('코스'), findsWidgets);
      expect(find.text('완료 코스'), findsOneWidget);
      expect(find.text('일차함수 완성'), findsWidgets);
      expect(
        find.byKey(
          ValueKey(
            width < 760 ? 'course-catalog-mobile' : 'course-catalog-desktop',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('course-catalog-mobile-redesign')),
        width < 760 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('course-mobile-search-dock')),
        width < 760 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('course-mobile-search-button')),
        width < 760 ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('학생 홈은 1280 PC와 390·500 모바일에서 학습 시작 흐름을 유지한다', (tester) async {
    for (final width in [1280.0, 390.0, 500.0]) {
      await _pumpAt(
        tester,
        Size(width, 900),
        const MainStudentPage(username: '김학생'),
      );
      await tester.pump();

      expect(
        find.textContaining(width < 760 ? '바로 시작해요.' : '오늘도 시작해 볼까요?'),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey(
            width < 760 ? 'student-home-mobile' : 'student-home-desktop',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('홈 하단 정보는 PC·태블릿에 유지하고 세로 모바일은 핵심 행동만 남긴다', (tester) async {
    const cases = <(double, String)>[
      (1280, 'student-home-footer-desktop'),
      (900, 'student-home-footer-tablet'),
    ];

    for (final (width, layoutKey) in cases) {
      await _pumpAt(
        tester,
        Size(width, 3200),
        const MainStudentPage(username: '김학생'),
      );
      await tester.pump();

      expect(find.byKey(ValueKey(layoutKey)), findsOneWidget);
      expect(find.text('일정 달력'), findsOneWidget);
      expect(find.text('도전과제 / 업적'), findsOneWidget);
      expect(find.text('공지사항'), findsWidgets);
      expect(tester.takeException(), isNull);
    }

    await _pumpAt(
      tester,
      const Size(500, 900),
      const MainStudentPage(username: '김학생'),
    );
    await tester.pump();

    expect(find.text('학습 시작'), findsOneWidget);
    expect(find.text('현재 코스'), findsOneWidget);
    expect(find.text('오늘 할 일'), findsOneWidget);
    expect(find.text('학습 현황'), findsOneWidget);
    expect(find.text('레이팅'), findsOneWidget);
    expect(find.text('업적'), findsOneWidget);
    expect(find.text('공지'), findsOneWidget);
    expect(find.text('AIFlow'), findsNothing);
    expect(find.text('빠른 도구'), findsNothing);
    expect(find.text('코스 이어하기'), findsNothing);
    expect(find.text('일정 달력'), findsNothing);
    expect(find.text('도전과제 / 업적'), findsNothing);
    expect(find.text('공지사항'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 홈의 학습·상태·현황 그룹은 같은 가로축과 폭을 사용한다', (tester) async {
    await _pumpAt(
      tester,
      const Size(390, 900),
      const MainStudentPage(username: '김학생'),
    );
    await tester.pump();

    final learnRect = tester.getRect(
      find.byKey(const ValueKey('student-home-mobile-learn-banner')),
    );
    final statusRect = tester.getRect(
      find.byKey(const ValueKey('student-home-mobile-status-group')),
    );
    final insightsRect = tester.getRect(
      find.byKey(const ValueKey('student-home-mobile-insights-group')),
    );

    expect(statusRect.left, closeTo(learnRect.left, 0.1));
    expect(insightsRect.left, closeTo(learnRect.left, 0.1));
    expect(statusRect.width, closeTo(learnRect.width, 0.1));
    expect(insightsRect.width, closeTo(learnRect.width, 0.1));
    expect(learnRect.height, lessThanOrEqualTo(100));
    expect(find.text('이어 하거나 새로 시작'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
