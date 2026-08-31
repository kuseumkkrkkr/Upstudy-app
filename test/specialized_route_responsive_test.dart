import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/graph_tools/session/jsx_graph_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/focus_mode_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/notepad_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/timer_page.dart';

void main() {
  testWidgets('그래프 도구는 760px에서도 모바일 조작부와 공용 상단바를 쓴다', (tester) async {
    tester.view.physicalSize = const Size(760, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: JsxGraphPage(embedEnabled: false)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('mobile-graph-page-scroll')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mobile-math-keypad')), findsOneWidget);
    expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
    expect(find.byTooltip('검색'), findsOneWidget);
    expect(find.byTooltip('알림'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그래프 도구 PC 상단바는 공용 목적지와 유틸을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: JsxGraphPage(embedEnabled: false)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('student-top-nav-학습터')), findsOneWidget);
    expect(find.byKey(const ValueKey('student-top-nav-코스')), findsOneWidget);
    expect(find.byTooltip('검색'), findsOneWidget);
    expect(find.byTooltip('알림'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('노트 모달 내용은 760px에서도 모바일 바텀 도구를 쓴다', (tester) async {
    tester.view.physicalSize = const Size(760, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: NotepadPage(persistenceEnabled: false)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('notepad-mobile-toolbar')),
      findsOneWidget,
    );
    expect(find.text('필기 노트'), findsOneWidget);
    expect(find.text('도구'), findsOneWidget);
    expect(find.text('LEARNING TOOL · SESSION'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('타이머와 집중 모드는 780px에서 공용 모바일 상단바를 쓴다', (tester) async {
    tester.view.physicalSize = const Size(780, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final page in const <Widget>[TimerPage(), FocusModePage()]) {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();

      expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
      expect(find.byTooltip('뒤로가기'), findsOneWidget);
      expect(find.byTooltip('검색'), findsOneWidget);
      expect(find.byTooltip('알림'), findsOneWidget);
      expect(find.text('LEARNING TOOL · SESSION'), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('타이머와 집중 모드는 1280px에서 공용 PC 상단바를 쓴다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final page in const <Widget>[TimerPage(), FocusModePage()]) {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();

      expect(find.byKey(const ValueKey('student-top-nav-학습터')), findsOneWidget);
      expect(find.byKey(const ValueKey('student-top-nav-코스')), findsOneWidget);
      expect(find.byTooltip('뒤로가기'), findsOneWidget);
      expect(find.byTooltip('검색'), findsOneWidget);
      expect(find.byTooltip('알림'), findsOneWidget);
      expect(find.text('LEARNING TOOL · SESSION'), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
}
