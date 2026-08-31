import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/app/router.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/student_learning_tools_page.dart';
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
}
