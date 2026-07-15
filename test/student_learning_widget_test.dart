import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/sessions/course/session/course_learning_page.dart';
import 'package:s11/sessions/course/session/teacher_course_textbook_reader_page.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/course/ui/course_detail_page.dart';
import 'package:s11/sessions/course/ui/course_html_dialogs.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/flow_view_page.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/services/api/api_client.dart';

/// 필요한 변수는 API 경로별 요청 기록과 교재 본문 응답이다.
/// 실제 네트워크 없이 런타임 시작·heartbeat·완료 계약을 검증할 클라이언트를 만든다.
MockClient _textbookClient(List<http.Request> requests) {
  return MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/textbook-view/start')) {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'elapsed_seconds': 30, 'completion_rate': 0.25},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (path.endsWith('/textbooks/book-1')) {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'textbook': {
              'textbook_id': 'book-1',
              'title': '런타임 검증 교재',
              'subtitle': '마지막 위치와 체류 시간을 보존합니다.',
              'chapters': [
                {
                  'title': '1단원',
                  'intro': ['첫 페이지 본문'],
                  'sections': [
                    {
                      'title': '두 번째 페이지',
                      'paragraphs': ['두 번째 페이지 본문'],
                    },
                  ],
                },
              ],
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (path.endsWith('/textbook-view/heartbeat')) {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'elapsed_seconds': 31, 'completion_rate': 0.5},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (path.endsWith('/textbook-view/complete')) {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'elapsed_seconds': 32, 'completion_rate': 1},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response('{}', 404);
  });
}

/// 필요한 변수는 코스 상세·계정 요약 요청과 테스트용 두 코스다.
/// 목록은 주입하고 후속 화면 API만 UTF-8 JSON으로 응답해 실제 Navigator 분기를 검증한다.
MockClient _courseClient() {
  return MockClient((request) async {
    final id = request.url.path.contains('completed-course')
        ? 'completed-course'
        : 'active-course';
    final completed = id == 'completed-course';
    final data = request.url.path == '/account/summary'
        ? <String, dynamic>{
            'level': 3,
            'total_points': 120,
            'level_progress': 0.4,
          }
        : <String, dynamic>{
            'id': id,
            'title': completed ? '완료 코스' : '진행 코스',
            'description': '코스 상태별 위젯 진입 검증',
            'difficulty': '기본',
            'duration': '7일',
            'status': completed ? 'completed' : 'in_progress',
            'progress': completed ? 1.0 : 0.5,
            'units': [
              {
                'title': completed ? '완료 기록 단원' : '이전 단원',
                'type': 'problem_solve',
                'missions': [
                  {
                    'title': completed ? '완료 기록' : '이전 미션',
                    'detail': {'type': 'problem_solve'},
                  },
                ],
              },
              {
                'title': '현재 단원',
                'type': 'problem_solve',
                'missions': [
                  {
                    'title': '현재 미션',
                    'detail': {'type': 'problem_solve'},
                  },
                ],
              },
            ],
          };
    return http.Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

/// 필요한 변수는 진행 중·완료 상태가 다른 두 코스다.
/// 진행 코스는 학습 화면, 완료 코스는 읽기 전용 상세 화면으로 보내는 목록 입력값을 만든다.
List<Course> _entryCourses() {
  /// 필요한 변수는 코스 식별자·제목·상태·진행률이다.
  /// 동일 유닛 구조에 상태값만 달리 넣어 단일 완료 판정의 화면 분기를 비교한다.
  Course course(String id, String title, String status, double progress) {
    return Course(
      id: id,
      title: title,
      description: '코스 상태별 위젯 진입 검증',
      level: '기본',
      duration: '7일',
      status: status,
      progress: progress,
      units: const [
        CourseUnit(
          title: '이전 단원',
          type: 'problem_solve',
          detail: {'type': 'problem_solve'},
          status: CourseUnitStatus.completed,
          missions: [
            CourseUnitMission(
              title: '이전 미션',
              detail: {'type': 'problem_solve'},
            ),
          ],
        ),
        CourseUnit(
          title: '현재 단원',
          type: 'problem_solve',
          detail: {'type': 'problem_solve'},
          status: CourseUnitStatus.active,
          missions: [
            CourseUnitMission(
              title: '현재 미션',
              detail: {'type': 'problem_solve'},
            ),
          ],
        ),
      ],
    );
  }

  return [
    course('active-course', '진행 코스', 'in_progress', 0.5),
    course('completed-course', '완료 코스', 'completed', 1),
  ];
}

/// 필요한 변수는 테스트 바인딩·인증 토큰·모바일 화면 크기다.
/// 교재 API 계약과 Flow의 그래프 우선 배치를 실제 위젯 트리에서 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ApiClient.instance.setToken('student-learning-widget-token');
  });

  testWidgets('교재 런타임은 시작 후 현재 페이지 heartbeat와 완료를 전송한다', (tester) async {
    final requests = <http.Request>[];
    ApiClient.instance.setHttpClientForTest(_textbookClient(requests));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: TeacherCourseTextbookReaderPage(
          courseId: 'course-1',
          moduleId: 'module-1',
          textbookId: 'book-1',
          pageFrom: 1,
          pageTo: 2,
          minMinutes: 1,
          enforceMinMinutes: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final visibleTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList(growable: false);
    expect(
      find.text('런타임 검증 교재'),
      findsNWidgets(2),
      reason:
          '현재 화면 텍스트: $visibleTexts / 요청: ${requests.map((e) => e.url.path)}',
    );
    expect(
      requests.map((request) => request.url.path),
      containsAllInOrder([
        '/courses/v2/runtime/textbook-view/start',
        '/courses/v2/course-1/textbooks/book-1',
      ]),
    );
    expect(find.byTooltip('필기 도구'), findsOneWidget);
    await tester.tap(find.byTooltip('필기 도구'));
    await tester.pump();
    expect(find.byTooltip('이동'), findsOneWidget);
    expect(find.byTooltip('펜'), findsOneWidget);
    expect(find.byTooltip('지우개'), findsOneWidget);
    expect(find.byTooltip('팔레트'), findsOneWidget);
    expect(find.byTooltip('실행 취소'), findsOneWidget);
    expect(find.byTooltip('북마크 추가'), findsOneWidget);

    await tester.tap(find.byTooltip('북마크 추가'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('북마크 해제'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-340, 0));
    await tester.pumpAndSettle();
    final heartbeat = requests.lastWhere(
      (request) => request.url.path.endsWith('/textbook-view/heartbeat'),
    );
    expect(jsonDecode(heartbeat.body)['page'], 2);

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    final complete = requests.lastWhere(
      (request) => request.url.path.endsWith('/textbook-view/complete'),
    );
    expect(jsonDecode(complete.body)['page'], 2);
  });

  testWidgets('모바일 Flow는 그래프를 문제 정보와 제출 상세보다 먼저 배치한다', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: FlowViewPage(
          quest: {
            'data': {'quest_title': '그래프 순서 검증 문제', 'quest_answer': '정답'},
            'solves': [
              {
                'flow': '첫 번째 풀이 단계',
                'hint_riddle': '힌트',
                'answer_riddle': '해설',
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('첫 번째 풀이 단계'), findsOneWidget);
    expect(find.text('문제 정보'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('첫 번째 풀이 단계')).dy,
      lessThan(tester.getTopLeft(find.text('문제 정보')).dy),
    );
    expect(find.byTooltip('축소'), findsOneWidget);
    expect(find.byTooltip('확대'), findsOneWidget);
    expect(find.text('초기화'), findsOneWidget);
    final scaleLabel = find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data ?? '').endsWith('%'),
    );
    expect(scaleLabel, findsOneWidget);
    final initialScale = tester.widget<Text>(scaleLabel).data;
    await tester.tap(find.byTooltip('확대'));
    await tester.pump();
    expect(tester.widget<Text>(scaleLabel).data, isNot(initialScale));

    await tester.scrollUntilVisible(
      find.text('문제 정보'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('문제 정보'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('노드를 선택해주세요'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('노드를 선택해주세요'), findsOneWidget);
  });

  testWidgets('코스 목록은 진행 상태와 완료 상태를 서로 다른 화면으로 연다', (tester) async {
    ApiClient.instance.setHttpClientForTest(_courseClient());
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/study-center': (_) => const SizedBox.shrink(),
          '/courses': (_) => const SizedBox.shrink(),
          '/bookbag': (_) => const SizedBox.shrink(),
          '/social': (_) => const SizedBox.shrink(),
          '/marketplace': (_) => const SizedBox.shrink(),
        },
        home: CourseCatalogPage(
          courseFeedLoader: ({required keyword, recommend}) async =>
              _entryCourses(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final activeCard = find.byWidgetPredicate(
      (widget) => widget is CourseCard && !widget.course.isCompleted,
    );
    await tester.ensureVisible(activeCard);
    await tester.tap(activeCard);
    await tester.pumpAndSettle();
    expect(find.byType(CourseLearningPage), findsOneWidget);
    expect(find.text('현재 미션'), findsWidgets);

    Navigator.of(tester.element(find.byType(CourseLearningPage))).pop();
    await tester.pumpAndSettle();
    final completedFilter = find.widgetWithText(ChoiceChip, '완료 코스');
    await tester.ensureVisible(completedFilter);
    await tester.tap(completedFilter);
    await tester.pumpAndSettle();
    final completedCard = find.byWidgetPredicate(
      (widget) => widget is CourseCard && widget.course.isCompleted,
    );
    await tester.ensureVisible(completedCard);
    await tester.tap(completedCard);
    await tester.pumpAndSettle();
    expect(find.byType(CourseDetailPage), findsOneWidget);
    expect(find.text('완료한 코스 · 미리보기'), findsWidgets);
    expect(find.text('코스 계속하기'), findsNothing);
  });

  testWidgets('코스 HTML 액션은 순서·비교·완료 조건 모달을 연다', (tester) async {
    final courses = _entryCourses();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => showCourseReorderDialog(
                    context,
                    courses: courses,
                    onSaved: () {},
                  ),
                  child: const Text('순서 열기'),
                ),
                TextButton(
                  onPressed: () =>
                      showCourseCompareDialog(context, courses: courses),
                  child: const Text('비교 열기'),
                ),
                TextButton(
                  onPressed: () => showCoursePolicyDialog(context),
                  child: const Text('정책 열기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('순서 열기'));
    await tester.pumpAndSettle();
    expect(find.text('MY COURSE ORDER'), findsOneWidget);
    expect(find.text('진행 코스'), findsOneWidget);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('비교 열기'));
    await tester.pumpAndSettle();
    expect(find.text('COMPARE COURSES'), findsOneWidget);
    expect(find.text('완료 코스'), findsOneWidget);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('정책 열기'));
    await tester.pumpAndSettle();
    expect(find.text('RUNTIME POLICY'), findsOneWidget);
    expect(find.text('최소 학습 시간'), findsOneWidget);
    expect(find.text('진행 시간 보존'), findsOneWidget);
    expect(find.text('완료 후 다음 모듈'), findsOneWidget);
  });
}
