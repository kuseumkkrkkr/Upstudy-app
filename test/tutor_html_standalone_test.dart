import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';

void main() {
  for (final size in [const Size(390,844),const Size(1280,900)]) {
    testWidgets('standalone reference structure and controls at $size',(tester) async {
      tester.view.physicalSize=size;
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home:ServerChatPage(standalone:true)));
      await tester.pumpAndSettle();
      expect(find.text('AIFLOW TUTOR · LIVE'),findsNothing);
      expect(find.text('막힌 지점부터 질문해 보세요.'),findsNothing);
      expect(find.text('오늘'),findsOneWidget);
      expect(find.byKey(const ValueKey('tutor-html-composer')),findsOneWidget);
      final use=find.byKey(const ValueKey('tutor-use-suggestion'));
      expect(tester.getSize(use),const Size(44,44));
      expect(tester.getSize(find.byKey(const ValueKey('tutor-send'))).height,44);
      await tester.tap(use);
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,'도함수와 접선의 관계를 설명해줘');
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('expanded text remains usable and context selection is announced',(tester) async {
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics=tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(builder:(context,child)=>MediaQuery(
      data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(1.5)),child:child!),
      home:const ServerChatPage(standalone:true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tutor-personalized')));
    await tester.pump();
    expect(find.bySemanticsLabel('학습 맥락 첨부 해제'),findsWidgets);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
}
