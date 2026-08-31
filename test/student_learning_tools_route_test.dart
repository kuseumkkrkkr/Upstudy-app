import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/app/router.dart';
import 'package:s11/sessions/learning_tools/ui/pages/focus_mode_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/student_learning_tools_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/timer_page.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';

void main() {
  testWidgets('학습 도구 메뉴는 모바일 햄버거 셸과 세 모달 도구를 연다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(initialRoute: AppRoutes.learningTools, routes: appRoutes()),
    );
    await tester.pump();

    expect(find.byType(StudentLearningToolsPage), findsOneWidget);
    expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
    expect(find.byType(MobileStudentBottomAppBar), findsNothing);
    expect(
      find.byKey(const ValueKey('learning-tools-notepad')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('learning-tools-timer')), findsOneWidget);
    expect(find.byKey(const ValueKey('learning-tools-focus')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('학습 도구 허브는 AI 튜터 기존 기능을 보존한다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(initialRoute: AppRoutes.learningTools, routes: appRoutes()),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('student-top-nav-학습터')), findsOneWidget);
    expect(find.text('AI 학습 튜터'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('learning-tools-tutor')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ServerChatPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('학습 도구 허브는 390에서 타이머와 집중 상태를 공통 셸로 연다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(initialRoute: AppRoutes.learningTools, routes: appRoutes()),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('learning-tools-timer')));
    await tester.pumpAndSettle();

    expect(find.byType(TimerPage), findsOneWidget);
    expect(find.byKey(const ValueKey('timer-tool-page')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timer-tool-page')),
        matching: find.byKey(const ValueKey('student-mobile-menu')),
      ),
      findsOneWidget,
    );
    expect(find.text('LEARNING TOOL · SESSION'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('timer-mode-toggle')),
        matching: find.text('타이머'),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('timer-setup-card')), findsOneWidget);
    await tester.tap(find.text('+10분'));
    await tester.pump();
    await tester.ensureVisible(find.text('시작'));
    await tester.tap(find.text('시작'));
    await tester.pump();
    expect(find.text('일시정지'), findsOneWidget);
    await tester.tap(find.text('일시정지'));
    await tester.pump();
    expect(find.text('시작'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentLearningToolsPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('learning-tools-focus')));
    await tester.pumpAndSettle();
    expect(find.byType(FocusModePage), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-tool-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-setup-surface')), findsOneWidget);
    expect(find.text('LEARNING TOOL · SESSION'), findsNothing);

    await tester.ensureVisible(find.text('집중 시작'));
    await tester.tap(find.text('집중 시작'));
    await tester.pump();
    expect(find.byKey(const ValueKey('focus-running-surface')), findsOneWidget);
    await tester.ensureVisible(find.text('집중 해제'));
    await tester.tap(find.text('집중 해제'));
    await tester.pump();
    expect(find.text('취소'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pump();
    expect(find.byKey(const ValueKey('focus-running-surface')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
