import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/learning_tools/ui/pages/notepad_page.dart';

void main() {
  testWidgets('모바일 노트패드는 획을 그리면 실행 취소가 활성화되고 되돌리면 다시 비활성화된다', (tester) async {
    // 필요한 변수는 390×844 모바일 화면과 저장을 끈 노트패드다.
    // 작동 원리는 캔버스에 실제 포인터 획을 만든 뒤 하단 실행 취소 버튼의 상태가
    // 활성→비활성으로 돌아오는지 확인해 획과 도구 상태가 함께 갱신됨을 검증한다.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: NotepadPage(persistenceEnabled: false)),
    );
    await tester.pump();

    expect(find.text('필기 노트'), findsOneWidget);
    expect(find.text('되돌리기'), findsOneWidget);
    expect(find.byTooltip('필기 도구'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);

    final undoBefore = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('되돌리기'), matching: find.byType(InkWell))
          .first,
    );
    expect(undoBefore.onTap, isNull);

    final canvas = find.byKey(const ValueKey('notepad-canvas'));
    expect(canvas, findsOneWidget);
    await tester.dragFrom(
      tester.getTopLeft(canvas) + const Offset(90, 90),
      const Offset(100, 32),
    );
    await tester.pump();

    final undoAfterDraw = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('되돌리기'), matching: find.byType(InkWell))
          .first,
    );
    expect(undoAfterDraw.onTap, isNotNull);

    await tester.tap(find.text('되돌리기'));
    await tester.pump();

    final undoAfterUndo = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('되돌리기'), matching: find.byType(InkWell))
          .first,
    );
    expect(undoAfterUndo.onTap, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 필기 도구는 참조형 바텀시트로 색상·굵기·노트 설정을 제공한다', (tester) async {
    // 필요한 변수는 모바일 노트패드와 필기 도구 버튼이다.
    // 작동 원리는 하단 도구 버튼으로 둥근 시트를 열어 큰 제목과 모든 세부 설정을 확인한다.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: NotepadPage(persistenceEnabled: false)),
    );
    await tester.tap(find.text('도구'));
    await tester.pumpAndSettle();

    expect(find.text('필기 도구'), findsWidgets);
    expect(find.text('펜 색상'), findsOneWidget);
    expect(find.text('펜 굵기'), findsOneWidget);
    expect(find.text('형광펜'), findsOneWidget);
    expect(find.text('노트 줄'), findsOneWidget);
    expect(find.text('모든 필기 지우기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 노트패드는 타이핑·페이지 이동·펜 모드를 분리한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: NotepadPage(persistenceEnabled: false)),
    );

    await tester.tap(find.text('타이핑'));
    await tester.pump();
    expect(find.byKey(const ValueKey('notepad-text-editor')), findsOneWidget);
    await tester.enterText(find.byType(TextField), '함수 개념 정리');
    expect(find.text('함수 개념 정리'), findsOneWidget);

    await tester.tap(find.text('이동'));
    await tester.pump();
    final moveScroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(moveScroll.physics, isA<BouncingScrollPhysics>());

    await tester.tap(find.text('펜'));
    await tester.pump();
    final penScroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(penScroll.physics, isA<NeverScrollableScrollPhysics>());
    expect(find.byKey(const ValueKey('notepad-canvas')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
