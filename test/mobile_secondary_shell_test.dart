import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/features/arena/arena_page.dart';
import 'package:s11/features/group_study/group_list_page.dart';
import 'package:s11/features/level_test/level_test_home_page.dart';
import 'package:s11/features/student_schedule/schedule_page.dart';
import 'package:s11/features/wrong_answer/wrong_answer_list_page.dart';
import 'package:s11/sessions/friend/friend.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';

/// 필요한 변수는 390px에서 확인할 학생 보조 화면이다.
/// 작동 원리는 참조 시안처럼 바텀 탭 대신 햄버거와 공용 드로어를 렌더하고,
/// 실제 메뉴 버튼으로 드로어가 열리는지 확인하는 것이다.
Future<void> _expectReferenceMobileShell(
  WidgetTester tester,
  Widget page,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump();

  expect(find.byType(MobileStudentBottomAppBar), findsNothing);
  expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
  expect(find.text('AIFlow'), findsAtLeastNWidgets(1));
  expect(find.byType(NavigationRail), findsNothing);

  await tester.tap(find.byKey(const ValueKey('student-mobile-menu')));
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text('오늘'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('일정은 모바일 햄버거 셸을 사용한다', (tester) async {
    await _expectReferenceMobileShell(
      tester,
      SchedulePage(
        initialSchedule: const [],
        initialDate: DateTime(2026, 7, 29),
      ),
    );
  });

  testWidgets('오답 노트는 모바일 햄버거 셸을 사용한다', (tester) async {
    await _expectReferenceMobileShell(tester, const WrongAnswerListPage());
  });

  testWidgets('레벨 테스트는 모바일 햄버거 셸을 사용한다', (tester) async {
    await _expectReferenceMobileShell(tester, const LevelTestHomePage());
  });

  testWidgets('대결은 모바일 햄버거 셸을 사용한다', (tester) async {
    await _expectReferenceMobileShell(
      tester,
      const ArenaPage(initialSummary: {'queues': <Object>[]}),
    );
  });

  testWidgets('친구와 소셜은 모바일 햄버거 셸을 사용한다', (tester) async {
    await _expectReferenceMobileShell(tester, const SoWidget(preview: true));
  });

  testWidgets('스터디 그룹은 모바일 햄버거 셸을 사용한다', (tester) async {
    await _expectReferenceMobileShell(
      tester,
      const GroupListPage(initialGroups: <Object>[]),
    );
    expect(find.byKey(const ValueKey('group-mobile-actions')), findsOneWidget);
    expect(find.text('그룹 찾기 · 코드 참가'), findsOneWidget);
  });

  testWidgets('AI 학습 튜터는 모바일 햄버거 셸을 사용한다', (tester) async {
    await _expectReferenceMobileShell(
      tester,
      const ServerChatPage(standalone: true),
    );
  });

  testWidgets('대결은 1280px에서 중앙 캡슐 메뉴를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ArenaPage(initialSummary: {'queues': <Object>[]}),
      ),
    );
    await tester.pump();

    expect(find.byType(MobileStudentBottomAppBar), findsNothing);
    expect(find.byKey(const ValueKey('student-top-nav-코스')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('student-top-nav-마켓플레이스')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
