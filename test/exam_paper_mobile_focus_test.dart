import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

void main() {
  testWidgets('모바일 시험지 타이머를 전환하고 문항 확대·페이지 맞춤을 제공한다', (tester) async {
    await (FontLoader(
      'Noto Sans KR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'))).load();
    await (FontLoader(
      'Batang',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'))).load();
    final icons = File(
      'public/assets/fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.setTokenForTest('exam-mobile-focus-fixture');
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/continue/strokes')) {
          return http.Response('{"detail":"no continue session found"}', 404);
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/exams/mobile-focus-fixture')) {
          return http.Response(
            jsonEncode({
              'exam_id': 'mobile-focus-fixture',
              'status': 'done',
              'items': [
                {
                  'exam_id': 'mobile-focus-fixture',
                  'item_index': 0,
                  'quest_id': 'fixture-question-1',
                  'quest_title': 'x² - 4x + 3 = 0의 두 근의 합을 구하세요.',
                  'flow_count': 2,
                  'question_type': 'subjective',
                },
                {
                  'exam_id': 'mobile-focus-fixture',
                  'item_index': 1,
                  'quest_id': 'fixture-question-2',
                  'quest_title': '다항식 나눗셈의 나머지를 구하세요.',
                  'flow_count': 2,
                  'question_type': 'subjective',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
    );
    addTearDown(() async {
      ApiClient.instance.setHttpClientForTest(http.Client());
      ApiClient.instance.clearTokenForTest();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Noto Sans KR'),
        home: const ExamPaperPage(
          examId: 'mobile-focus-fixture',
          timeLimitMinutes: 60,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('60:00'), findsOneWidget);
    expect(find.byTooltip('시간 표시 숨기기'), findsOneWidget);
    final defaultFocusedScale = tester
        .widget<Transform>(
          find.byKey(const ValueKey('exam-paper-canvas-transform')),
        )
        .transform
        .storage[0];
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        'goldens/exam-paper-mobile-default-focus-390x844.png',
      ),
    );
    await tester.tap(find.byTooltip('시간 표시 숨기기'));
    await tester.pump();
    expect(find.text('60:00'), findsNothing);
    expect(find.byTooltip('시간 표시 보기'), findsOneWidget);
    await tester.tap(find.byTooltip('시간 표시 보기'));
    await tester.pump();
    expect(find.text('60:00'), findsOneWidget);
    await tester.tap(find.byTooltip('화면 도구'));
    await tester.pumpAndSettle();
    expect(find.text('문항 확대'), findsOneWidget);
    expect(find.text('페이지 맞춤'), findsOneWidget);
    await tester.tap(find.text('페이지 맞춤'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    final pageFitScale = tester
        .widget<Transform>(
          find.byKey(const ValueKey('exam-paper-canvas-transform')),
        )
        .transform
        .storage[0];
    expect(defaultFocusedScale, greaterThan(pageFitScale * 1.8));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        'goldens/exam-paper-mobile-page-fit-390x844.png',
      ),
    );
    await tester.tap(find.byTooltip('화면 도구'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('문항 확대'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/exam-paper-mobile-focus-next-390x844.png'),
    );
    await tester.tap(find.byTooltip('다시 볼 문항 표시'));
    await tester.pump();
    await tester.tap(find.byTooltip('문항 목록'));
    await tester.pumpAndSettle();
    expect(find.text('1개 다시 보기'), findsOneWidget);
    expect(find.text('미응답'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('exam-question-nav-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-question-nav-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('exam-question-nav-1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final focusedCanvas = tester.widget<Transform>(
      find.byKey(const ValueKey('exam-paper-canvas-transform')),
    );
    expect(focusedCanvas.transform.storage[0], greaterThan(pageFitScale * 1.8));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/exam-paper-mobile-navigate-focus-390x844.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
