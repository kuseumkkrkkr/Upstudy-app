import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/app/router.dart';
import 'package:s11/features/wrong_answer/wrong_answer_list_page.dart';
import 'package:s11/shared/services/api/api_client.dart';

Widget _legacyWrongAnswerRouteApp(double width) => MaterialApp(
  key: ValueKey('legacy-wrong-answer-route-$width'),
  initialRoute: AppRoutes.wrongAnswerSolve,
  routes: appRoutes(),
  onGenerateRoute: onGenerateAppRoute,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        if (request.url.path == '/history/solve') {
          return http.Response(jsonEncode(<String, Object>{'items': []}), 200);
        }
        if (request.url.path == '/weakness/tags') {
          return http.Response(jsonEncode(<String, Object>{'tags': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );
  });

  tearDown(() async {
    ApiClient.instance.setHttpClientForTest(http.Client());
    await ApiClient.instance.clearToken();
  });

  testWidgets('구형 오답 재풀이 경로는 모든 학생 폭에서 실제 오답 목록으로 간다', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in const [390.0, 780.0, 1280.0]) {
      tester.view.physicalSize = Size(width, width <= 780 ? 844 : 900);
      await tester.pumpWidget(_legacyWrongAnswerRouteApp(width));
      await tester.pump();
      await tester.pump();

      expect(find.byType(WrongAnswerListPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('wrong-answers-screen')),
        findsOneWidget,
      );
      expect(
        find.text('재풀이 세션이 여기에서 실행됩니다. (WrongAnswerReviewWidget 연동 예정)'),
        findsNothing,
      );
      expect(
        ModalRoute.of(
          tester.element(find.byType(WrongAnswerListPage)),
        )?.settings.name,
        AppRoutes.wrongAnswers,
      );

      if (width <= 780) {
        expect(
          find.byKey(const ValueKey('student-mobile-menu')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('student-top-nav-코스')), findsNothing);
      } else {
        expect(
          find.byKey(const ValueKey('student-top-nav-코스')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    }
  });
}
