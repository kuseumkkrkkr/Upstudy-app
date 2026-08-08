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
/// 작동 원리는 화면을 한 프레임 렌더링한 뒤 모바일 하단 앱바가 있고 PC 드로어·햄버거가 없는지 확인한다.
Future<void> _expectMobileShell(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump();

  expect(find.byType(MobileStudentBottomAppBar), findsOneWidget);
  expect(find.byType(Drawer), findsNothing);
  expect(find.byKey(const ValueKey('student-mobile-menu')), findsNothing);
  expect(find.text('AIFlow'), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('일정은 모바일 하단 앱 셸을 사용한다', (tester) async {
    await _expectMobileShell(
      tester,
      SchedulePage(
        initialSchedule: const [],
        initialDate: DateTime(2026, 7, 29),
      ),
    );
  });

  testWidgets('오답 노트는 모바일 하단 앱 셸을 사용한다', (tester) async {
    await _expectMobileShell(tester, const WrongAnswerListPage());
  });

  testWidgets('레벨 테스트는 모바일 하단 앱 셸을 사용한다', (tester) async {
    await _expectMobileShell(tester, const LevelTestHomePage());
  });

  testWidgets('대결은 모바일 하단 앱 셸을 사용한다', (tester) async {
    await _expectMobileShell(
      tester,
      const ArenaPage(initialSummary: {'queues': <Object>[]}),
    );
  });

  testWidgets('친구와 소셜은 모바일 하단 앱 셸을 사용한다', (tester) async {
    await _expectMobileShell(tester, const SoWidget(preview: true));
  });

  testWidgets('스터디 그룹은 모바일 하단 앱 셸을 사용한다', (tester) async {
    await _expectMobileShell(
      tester,
      const GroupListPage(initialGroups: <Object>[]),
    );
    expect(find.byKey(const ValueKey('group-mobile-actions')), findsOneWidget);
    expect(find.text('그룹찾기·코드참가'), findsOneWidget);
  });

  testWidgets('AI 학습 튜터는 모바일 하단 앱 셸을 사용한다', (tester) async {
    await _expectMobileShell(tester, const ServerChatPage(standalone: true));
  });
}
