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
    final savedRequests = <http.Request>[];
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        savedRequests.add(request);
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

    expect(savedRequests.first.method, 'PUT');
    final body = jsonDecode(savedRequests.first.body) as Map<String, dynamic>;
    final tasksByDate = body['tasks_by_date'] as Map<String, dynamic>;
    expect(tasksByDate['2026-07-29'], contains('이차함수 오답 복습'));
    expect(find.text('개인 일정을 저장했어요.'), findsOneWidget);
    expect(find.text('이차함수 오답 복습'), findsAtLeastNWidgets(1));
    await tester.tap(find.byTooltip('일정 삭제'));
    await tester.pumpAndSettle();
    final deleteBody =
        jsonDecode(savedRequests.last.body) as Map<String, dynamic>;
    expect(deleteBody['tasks_by_date'], isEmpty);
    expect(find.text('개인 일정이 삭제됐어요.'), findsOneWidget);
    expect(find.text('이차함수 오답 복습'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('월간 달 이동과 선택 날짜 요약 범위를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateUtils.dateOnly(DateTime.now());
    final later = today.add(const Duration(days: 90));
    final nextMonth = DateTime(today.year, today.month + 1);

    await tester.pumpWidget(
      MaterialApp(
        home: SchedulePage(
          initialDate: today,
          initialSchedule: [
            {'date': _dateKey(today), 'title': '오늘 일정', 'status': '예정'},
            {'date': _dateKey(later), 'title': '몇 달 뒤 일정', 'status': '예정'},
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('오늘 일정'), findsAtLeastNWidgets(1));
    expect(find.text('몇 달 뒤 일정'), findsNothing);
    expect(find.text('D-DAY'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('월간'));
    await tester.pump();
    expect(find.text(_monthLabel(today)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('schedule-next-month')));
    await tester.pump();
    expect(find.text(_monthLabel(nextMonth)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('schedule-previous-month')));
    await tester.pump();
    expect(find.text(_monthLabel(today)), findsOneWidget);
  });
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _monthLabel(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
