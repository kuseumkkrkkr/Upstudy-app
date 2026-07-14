import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/sessions/course/session/teacher_course_textbook_reader_page.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/flow_view_page.dart';
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
      findsOneWidget,
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

    final graphTop = tester.getTopLeft(find.text('첫 번째 풀이 단계')).dy;
    final problemTop = tester.getTopLeft(find.text('문제 정보')).dy;
    expect(graphTop, lessThan(problemTop));

    await tester.scrollUntilVisible(
      find.text('노드를 선택해주세요'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final detailTop = tester.getTopLeft(find.text('노드를 선택해주세요')).dy;
    expect(problemTop, lessThan(detailTop));
  });
}
