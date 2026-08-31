import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/sessions/course/session/course_learning_page.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/course/ui/course_detail_page.dart';
import 'package:s11/shared/services/api/api_client.dart';

const _activeCourseId = 'catalog-active-course';
const _completedCourseId = 'catalog-completed-course';

/// 실제 /courses/v2 계약 형태를 보존한 응답이다.
/// 목록은 data 배열, 상세는 data 객체로 각각 반환해 주입 로더나 가짜 라우트 없이
/// 카탈로그의 실제 API 파싱·Navigator 분기를 검증한다.
Map<String, dynamic> _coursePayload({
  required String id,
  required String title,
  required String status,
  required double progress,
}) => <String, dynamic>{
  'id': id,
  'title': title,
  'description': '실제 코스 API 계약을 통한 반응형 진입 검증',
  'difficulty': '중2',
  'duration': '3주',
  'status': status,
  'progress': progress,
  'lessons': 8,
  'target_ovr': 22,
  'focus_tags': const ['함수'],
  'units': const [
    {
      'title': '현재 단원',
      'type': 'problem_solve',
      'detail': {'type': 'problem_solve', 'module_id': 'module-current'},
      'missions': [
        {
          'title': '현재 미션',
          'detail': {'type': 'problem_solve', 'module_id': 'module-current'},
          'action_label': '문제 풀기',
        },
      ],
    },
  ],
};

List<Map<String, dynamic>> _coursePayloads() => <Map<String, dynamic>>[
  _coursePayload(
    id: _activeCourseId,
    title: '계약 진행 코스',
    status: 'in_progress',
    progress: .5,
  ),
  _coursePayload(
    id: _completedCourseId,
    title: '계약 완료 코스',
    status: 'completed',
    progress: 1,
  ),
];

/// 필요한 값은 실제 API 요청 기록과 해당 엔드포인트의 계약 응답이다.
/// 작동 원리: 네트워크만 대체하고 CourseService의 V2 목록·등록 폴백·상세 호출은
/// 그대로 통과시켜 UI 전용 고정 loader가 실제 흐름을 가리는 일을 막는다.
MockClient _catalogContractClient(List<http.Request> requests) {
  return MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    Object data;
    if (path == '/courses/v2') {
      data = _coursePayloads();
    } else if (path == '/courses/enrolled') {
      data = const {'items': <Object>[]};
    } else if (path == '/quests/generation-tags') {
      data = const {'groups': <Object>[]};
    } else if (path.startsWith('/courses/v2/')) {
      final id = path.substring('/courses/v2/'.length);
      data = _coursePayloads().firstWhere(
        (course) => course['id'] == id,
        orElse: () => const <String, dynamic>{},
      );
    } else {
      return http.Response(
        jsonEncode({'detail': 'Unexpected course-catalog request: $path'}),
        404,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Finder _courseCard(String courseId) => find.byWidgetPredicate(
  (widget) => widget is CourseCard && widget.course.id == courseId,
);

Finder _mobileCourseRow(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(InkWell));

void _expectCatalogShell({required bool mobile}) {
  expect(
    find.byKey(
      ValueKey(mobile ? 'course-catalog-mobile' : 'course-catalog-desktop'),
    ),
    findsOneWidget,
  );
  expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
  expect(
    find.byKey(const ValueKey('student-top-nav-코스')),
    mobile ? findsNothing : findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('course-catalog-mobile-redesign')),
    mobile ? findsOneWidget : findsNothing,
  );
}

Future<void> _pumpCatalog(
  WidgetTester tester, {
  required Size size,
  required List<http.Request> requests,
}) async {
  await ApiClient.instance.setToken('course-catalog-contract-${size.width}');
  await ApiClient.instance.clearUserCache();
  ApiClient.instance.setHttpClientForTest(_catalogContractClient(requests));
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey('course-catalog-contract-${size.width}'),
      home: const CourseCatalogPage(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openActiveCourse(
  WidgetTester tester, {
  required bool mobile,
}) async {
  if (mobile) {
    final continueButton = find.descendant(
      of: find.byKey(const ValueKey('course-mobile-featured')),
      matching: find.text('학습 이어하기'),
    );
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
  } else {
    final activeCard = _courseCard(_activeCourseId);
    await tester.ensureVisible(activeCard);
    await tester.tap(activeCard);
  }
  await tester.pumpAndSettle();
  expect(find.byType(CourseLearningPage), findsOneWidget);
  expect(find.byKey(const ValueKey('course-learning-screen')), findsOneWidget);
  expect(find.text('현재 미션'), findsWidgets);
}

Future<void> _returnToCatalog(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(CourseLearningPage))).pop();
  await tester.pumpAndSettle();
  expect(find.byType(CourseCatalogPage), findsOneWidget);
}

Future<void> _openCompletedCourse(
  WidgetTester tester, {
  required bool mobile,
}) async {
  final completedTarget = mobile
      ? _mobileCourseRow('계약 완료 코스')
      : _courseCard(_completedCourseId);
  await tester.ensureVisible(completedTarget);
  await tester.tap(completedTarget);
  await tester.pumpAndSettle();
  expect(find.byType(CourseDetailPage), findsOneWidget);
  expect(find.byKey(const ValueKey('course-detail-screen')), findsOneWidget);
  expect(find.text('완료한 코스 · 미리보기'), findsWidgets);
  expect(find.text('코스 계속하기'), findsNothing);
  expect(find.text('91%'), findsOneWidget);
  expect(find.text('1,284'), findsOneWidget);
  final metricGrid = tester.widget<GridView>(find.byType(GridView));
  final delegate =
      metricGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  expect(delegate.crossAxisCount, mobile ? 2 : 4);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('CourseCatalog는 390·780 단일열과 1280 다열에서 실제 V2 카드 흐름을 유지한다', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const cases = <(Size, bool)>[
      (Size(390, 844), true),
      (Size(780, 844), true),
      (Size(781, 844), false),
      (Size(1280, 900), false),
    ];
    for (final (size, mobile) in cases) {
      final requests = <http.Request>[];
      await _pumpCatalog(tester, size: size, requests: requests);
      _expectCatalogShell(mobile: mobile);

      final activeCard = _courseCard(_activeCourseId);
      final completedCard = _courseCard(_completedCourseId);
      if (mobile) {
        final featured = find.byKey(const ValueKey('course-mobile-featured'));
        final completedRow = _mobileCourseRow('계약 완료 코스');
        expect(featured, findsOneWidget);
        expect(activeCard, findsNothing);
        expect(completedCard, findsNothing);
        expect(completedRow, findsOneWidget);
        await tester.ensureVisible(featured);
        final featuredRect = tester.getRect(featured);
        await tester.ensureVisible(completedRow);
        final completedRect = tester.getRect(completedRow);
        expect(featuredRect.left, closeTo(completedRect.left, 1));
        expect(featuredRect.width, closeTo(completedRect.width, 1));
      } else {
        expect(activeCard, findsOneWidget);
        expect(completedCard, findsOneWidget);
        await tester.ensureVisible(activeCard);
        await tester.ensureVisible(completedCard);
        final activeRect = tester.getRect(activeCard);
        final completedRect = tester.getRect(completedCard);
        expect(
          (activeRect.top - completedRect.top).abs(),
          lessThanOrEqualTo(1),
        );
        expect(activeRect.left, lessThan(completedRect.left));
      }

      await _openActiveCourse(tester, mobile: mobile);
      await _returnToCatalog(tester);
      await _openCompletedCourse(tester, mobile: mobile);

      final paths = requests.map((request) => request.url.path).toList();
      expect(paths, contains('/courses/v2'));
      expect(paths, contains('/courses/enrolled'));
      expect(paths, contains('/courses/v2/$_activeCourseId'));
      expect(paths, contains('/courses/v2/$_completedCourseId'));
      expect(tester.takeException(), isNull);
    }
  });
}
