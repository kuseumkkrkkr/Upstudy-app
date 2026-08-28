import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/graph_tools/session/jsx_graph_page.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';

void main() {
  testWidgets('그래프 직접 그리기 화면은 교과 예제 대신 빈 수식으로 시작한다', (tester) async {
    // 필요한 변수는 데스크톱 화면 크기와 웹뷰를 끈 그래프 페이지다.
    // 작동 원리는 첫 렌더링에서 자동 예제 문구가 없고 직접 입력 안내와 빈 함수가 보이는지 확인한다.
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: JsxGraphPage(embedEnabled: false)),
    );
    await tester.pump();

    expect(find.text('함수 그리기'), findsOneWidget);
    expect(find.text('함수 1'), findsOneWidget);
    expect(find.text('이차함수와 직선'), findsNothing);
    expect(find.text('예제 불러오기'), findsOneWidget);
    expect(find.text('그래프 탐색기'), findsOneWidget);
    expect(find.text('좌표평면'), findsNothing);
  });

  testWidgets('전체 메뉴가 열리면 그래프 플랫폼 뷰를 잠시 제거한다', (tester) async {
    // 필요한 변수는 데스크톱 화면과 전체 메뉴가 있는 그래프 페이지다.
    // 작동 원리는 메뉴 아이콘을 누른 뒤 웹뷰 대신 일시 중단 영역이 렌더링되는지 확인한다.
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: JsxGraphPage(embedEnabled: false)),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('전체 메뉴'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('graph-embed-suspended-for-drawer')),
      findsOneWidget,
    );
    expect(find.byType(Drawer), findsOneWidget);
  });

  testWidgets('좁은 화면에서 앱바 그래프 도구가 넘치지 않는다', (tester) async {
    // 필요한 변수는 모바일 화면 크기와 아이콘 모드로 전환되는 그래프 페이지다.
    // 작동 원리는 첫 프레임의 레이아웃 예외가 없고 두 작업의 도구 설명이 유지되는지 확인한다.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: JsxGraphPage(embedEnabled: false)),
    );
    await tester.pump();

    expect(
      find.byIcon(Icons.stacked_line_chart_rounded),
      findsAtLeastNWidgets(1),
    );
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 수식은 반영 버튼을 누르면 정규화되어 그래프 상태에 적용된다', (tester) async {
    // 필요한 변수는 모바일 그래프 화면과 암시적 곱셈이 포함된 수식이다.
    // 작동 원리는 반영 버튼이 입력을 검증하고 2x를 2*x로 정규화해 문서 재생성 상태를 만드는지 확인한다.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: JsxGraphPage(embedEnabled: false)),
    );
    await tester.pump();

    final expressionField = find.byType(TextField).first;
    await tester.enterText(expressionField, 'y = 2x + 1');
    await tester.pump();
    final applyButton = find.byKey(const ValueKey('mobile-graph-apply'));
    expect(applyButton, findsOneWidget);
    await tester.tap(applyButton);
    await tester.pump();

    final field = tester.widget<TextField>(expressionField);
    expect(field.controller?.text, '2*x+1');
    expect(find.text('검증된 형식으로 바꾼 뒤 다시 갱신하세요.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('직접 그리기용 HTML은 내부 매개변수 슬라이더만 숨길 수 있다', () {
    // 필요한 변수는 빈 그래프 문서와 조작부 표시 옵션이다.
    // 작동 원리는 교재 기본 HTML은 슬라이더를 유지하고 직접 그리기 HTML만 display:none을 주입하는지 확인한다.
    const document = AiFlowGraphDocument(
      items: [],
      settings: AiFlowGraphSettings(),
    );

    final textbookHtml = buildAiFlowGraphHtml(document);
    final drawingHtml = buildAiFlowGraphHtml(
      document,
      showParameterControls: false,
      directManipulationMode: true,
    );

    expect(textbookHtml, contains('display: flex;'));
    expect(drawingHtml, contains('display: none;'));
    expect(drawingHtml, isNot(contains('__AIFLOW_GRAPH_CONTROLS_DISPLAY__')));
    expect(drawingHtml, contains('<body class="direct-drawing">'));
    expect(drawingHtml, contains('showNavigation: false,'));
    expect(drawingHtml, contains('<span class="compact-label">+</span>'));
    expect(textbookHtml, contains('<body class="">'));
    expect(textbookHtml, contains('showNavigation: true,'));
  });

  test('좌표평면은 그래프 카드의 남은 높이를 모두 채운다', () {
    // 필요한 변수는 빈 그래프 문서로 생성한 HTML이다.
    // 작동 원리는 고정 높이 대신 graphHost 전체 높이를 사용하도록 board 스타일을 검사한다.
    const document = AiFlowGraphDocument(
      items: [],
      settings: AiFlowGraphSettings(),
    );

    final html = buildAiFlowGraphHtml(
      document,
      showParameterControls: false,
      directManipulationMode: true,
    );

    expect(html, contains('#board {'));
    expect(html, contains('height: 100%;'));
    expect(html, contains('jsxgraph@1.13.1/distrib/jsxgraph.css'));
    expect(html, contains('position: relative;'));
    expect(html, contains('touch-action: none;'));
    expect(
      html,
      isNot(contains('#board {\n        width: 100%;\n        height: 220px;')),
    );
  });
}
