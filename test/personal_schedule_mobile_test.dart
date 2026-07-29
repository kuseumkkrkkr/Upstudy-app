import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/features/student_schedule/schedule_page.dart';
import 'package:s11/shared/services/api/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    ApiClient.instance.setHttpClientForTest(http.Client());
    await ApiClient.instance.clearToken();
  });

  testWidgets('모바일 개인 일정은 바텀시트 검증 후 실제 동기화 요청에 포함된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ApiClient.instance.setToken('personal-schedule-test-token');
    http.Request? savedRequest;
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        savedRequest = request;
        return http.Response(
          jsonEncode({'success': true}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SchedulePage(
          initialSchedule: const <Map<String, dynamic>>[],
          initialDate: DateTime(2026, 7, 29),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('개인 일정 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('개인 일정 추가'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('personal-schedule-title')),
      findsOneWidget,
    );
    expect(find.text('2026년 7월 29일 (수)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('personal-schedule-save')));
    await tester.pump();
    expect(find.text('일정 제목을 입력해 주세요.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('personal-schedule-title')),
      '이차함수 오답 복습',
    );
    expect(find.text('이차함수 오답 복습'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('personal-schedule-save')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('personal-schedule-save')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('personal-schedule-title')), findsNothing);

    expect(savedRequest?.method, 'PUT');
    final body = jsonDecode(savedRequest!.body) as Map<String, dynamic>;
    final tasksByDate = body['tasks_by_date'] as Map<String, dynamic>;
    expect(tasksByDate['2026-07-29'], contains('이차함수 오답 복습'));
    expect(find.text('개인 일정을 저장했어요.'), findsOneWidget);
    expect(find.text('이차함수 오답 복습'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });
}
