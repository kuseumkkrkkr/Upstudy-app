import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/app/router.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';

/// 필요한 변수는 모바일·데스크톱 뷰포트와 `/tools` 명명 라우트다.
/// 작동 원리: 실제 라우트 표로 챗봇 전용 화면을 열어 핵심 문구와 레이아웃 예외가 없는지 확인한다.
void main() {
  testWidgets('학습 도구 라우트가 모바일 AI 챗봇 화면을 연다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(initialRoute: AppRoutes.tools, routes: appRoutes()),
    );
    await tester.pump();

    final page = tester.widget<ServerChatPage>(find.byType(ServerChatPage));
    expect(page.standalone, isTrue);
    expect(find.text('AI 학습 튜터'), findsOneWidget);
    expect(find.text('AIFlow 튜터'), findsOneWidget);
    expect(find.text('메시지 입력'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('데스크톱 챗봇 화면이 질문과 학습 지원 3열을 표시한다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(initialRoute: AppRoutes.tools, routes: appRoutes()),
    );
    await tester.pump();

    expect(find.text('오늘의 공부 계획'), findsOneWidget);
    expect(find.text('개념 쉽게 이해하기'), findsOneWidget);
    expect(find.text('오답 줄이는 방법'), findsOneWidget);
    expect(find.text('풀이 힌트 받기'), findsOneWidget);
    expect(find.text('학습 지원'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('문제 풀이의 임시 챗봇은 맥락이 연결된 모달을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ServerChatPage(
          initialContext: <String, dynamic>{'quest_title': '이차방정식'},
          ephemeral: true,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('문제 맥락이 연결되었습니다.', findRichText: true),
      findsOneWidget,
    );
    expect(find.byTooltip('닫기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
