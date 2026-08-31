import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/daily_test_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/today_tasks_modal.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

List<TodayTaskEntry> _todayTasks() => const [
  TodayTaskEntry(
    title: '문제 12개',
    caption: '교사 과제 · 오늘 22:00 · 진행 상태 확인',
    icon: Icons.check_rounded,
  ),
  TodayTaskEntry(
    title: '교재 3장 읽기',
    caption: '교사 과제 · 최소 학습 시간 확인',
    icon: Icons.menu_book_outlined,
  ),
  TodayTaskEntry(
    title: '개인 복습 20분',
    caption: '내 일정 · 일정에서 보기',
    icon: Icons.event_note_rounded,
  ),
];

DailyQuestBundle _dailyBundle({bool claimable = false}) => DailyQuestBundle(
  account: const AccountSummary(),
  revision: 7,
  items: [
    DailyQuestItem(
      id: 'daily-1',
      questType: 'problem',
      title: '일차함수 기본',
      target: 10,
      progress: claimable ? 10 : 4,
      status: claimable ? 'completed' : 'in_progress',
      rewardPoints: 80,
      claimable: claimable,
      difficultyLabel: '하',
    ),
    const DailyQuestItem(
      id: 'daily-2',
      questType: 'problem',
      title: '그래프 해석',
      target: 10,
      progress: 0,
      status: 'pending',
      rewardPoints: 60,
      difficultyLabel: '하',
    ),
  ],
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    ApiClient.instance.setHttpClientForTest(http.Client());
  });

  testWidgets('390 오늘 할 일은 단일 열 시트와 실제 과제·일정 콜백을 사용한다', (tester) async {
    _setView(tester, const Size(390, 844));
    TodayTaskEntry? selected;
    final tasks = _todayTasks();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open-today-tasks'),
              onPressed: () => showTodayTasksModal<void>(
                context: context,
                tasks: tasks,
                onTaskTap: (task) => selected = task,
              ),
              child: const Text('오늘 할 일 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-today-tasks')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.byKey(const ValueKey('today-tasks-mobile-sheet')),
      findsOneWidget,
    );
    expect(find.text('TODAY TASKS'), findsOneWidget);
    expect(find.text('별도 페이지를 열지 않고 홈에서 교사 과제와 개인 일정을 확인합니다.'), findsOneWidget);
    expect(find.text('일정 달력에서 보기'), findsOneWidget);
    final sheetHeight = tester
        .getSize(find.byKey(const ValueKey('today-tasks-mobile-sheet')))
        .height;
    expect(sheetHeight, greaterThan(680));
    expect(sheetHeight, lessThan(800));

    final first = tester.getTopLeft(find.text('문제 12개'));
    final second = tester.getTopLeft(find.text('교재 3장 읽기'));
    final third = tester.getTopLeft(find.text('개인 복습 20분'));
    expect((first.dx - second.dx).abs(), lessThan(4));
    expect((second.dx - third.dx).abs(), lessThan(4));
    expect(second.dy, greaterThan(first.dy));
    expect(third.dy, greaterThan(second.dy));

    await tester.tap(find.text('문제 12개'));
    await tester.pumpAndSettle();
    expect(selected, same(tasks.first));
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.byKey(const ValueKey('open-today-tasks')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일정 달력에서 보기'));
    await tester.pumpAndSettle();
    expect(selected, same(tasks.last));
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('780 경계에서도 오늘 할 일은 모바일 시트로 열리고 닫힌다', (tester) async {
    _setView(tester, const Size(780, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showTodayTasksModal<void>(
                context: context,
                tasks: _todayTasks(),
                onTaskTap: (_) {},
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('today-tasks-mobile-sheet')))
          .height,
      greaterThan(700),
    );
    await tester.tap(find.byTooltip('닫기').first);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('390 일일 테스트는 시트에서 실제 보상 API를 호출한다', (tester) async {
    _setView(tester, const Size(390, 844));
    String? claimPath;
    Map<String, dynamic>? claimBody;
    await ApiClient.instance.setToken('daily-sheet-token');
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        claimPath = request.url.path;
        claimBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'daily-1',
                'quest_type': 'problem',
                'title': '일차함수 기본',
                'target': 10,
                'progress': 10,
                'status': 'completed',
                'reward_points': 80,
                'reward_claimed': true,
                'claimable': false,
                'difficulty_label': '하',
              },
              {
                'id': 'daily-2',
                'quest_type': 'problem',
                'title': '그래프 해석',
                'target': 10,
                'progress': 0,
                'status': 'pending',
                'reward_points': 60,
                'reward_claimed': false,
                'claimable': false,
                'difficulty_label': '하',
              },
            ],
            'account': {
              'reward': {
                'granted_points': 0,
                'duplicate': false,
                'daily_cap_reached': false,
              },
            },
            'revision': 8,
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDailyTestModal<void>(
                context: context,
                courseId: 'course-1',
                initialBundle: _dailyBundle(claimable: true),
              ),
              child: const Text('일일 테스트 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('일일 테스트 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-test-mobile-sheet')),
      findsOneWidget,
    );
    expect(find.text('DAILY QUEST'), findsOneWidget);
    expect(find.text('완료율 50%'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('daily-test-mobile-sheet')))
          .height,
      greaterThan(680),
    );

    await tester.tap(find.byTooltip('보상 수령'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(claimPath, '/challenges/daily-quests/complete');
    expect(claimBody, {
      'course_id': 'course-1',
      'quest_id': 'daily-1',
      'revision': 7,
    });
    expect(find.byTooltip('수령 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1280에서는 두 패널이 넓은 데스크톱 다이얼로그로 유지된다', (tester) async {
    _setView(tester, const Size(1280, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => showTodayTasksModal<void>(
                    context: context,
                    tasks: _todayTasks(),
                    onTaskTap: (_) {},
                  ),
                  child: const Text('오늘 열기'),
                ),
                TextButton(
                  onPressed: () => showDailyTestModal<void>(
                    context: context,
                    initialBundle: _dailyBundle(),
                  ),
                  child: const Text('퀘스트 열기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('오늘 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('today-tasks-desktop-dialog')))
          .width,
      greaterThan(850),
    );
    expect(find.text('TODAY TASKS'), findsOneWidget);
    await tester.tap(find.byTooltip('닫기').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('퀘스트 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('daily-test-desktop-dialog')))
          .width,
      greaterThan(850),
    );
    expect(find.text('DAILY QUEST'), findsOneWidget);
    expect(find.text('일차함수 기본'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
