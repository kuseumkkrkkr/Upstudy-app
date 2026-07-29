import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

void main() {
  test('문제 문자열의 이스케이프 줄바꿈을 실제 개행으로 복원한다', () {
    final blocks = parseContentBlocks(r'방정식을 푸세요.\n7x + 8 = 64');

    expect(blocks, hasLength(1));
    expect(blocks.single.content, '방정식을 푸세요.\n7x + 8 = 64');
  });

  testWidgets('모바일 필기판은 드래그 획을 표시하고 제출을 활성화한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: BuildpageWidget(
          config: ProblemSolveConfig(
            ratingEnabled: false,
            quests: [
              {
                'header': {'quest_id': 'mobile-canvas-test'},
                'data': {'quest_title': r'방정식을 푸세요.\n7x + 8 = 64'},
              },
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('문제 풀이'), findsOneWidget);
    expect(find.text('방정식을 푸세요.\n7x + 8 = 64'), findsOneWidget);
    expect(find.text('풀이 노트'), findsOneWidget);

    final placeholder = find.text('여기에 풀이를 적어보세요');
    final canvas = find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onPanStart != null,
    );
    expect(canvas, findsOneWidget);
    await tester.ensureVisible(canvas);
    await tester.pump();
    await tester.drag(canvas, const Offset(70, 24));
    await tester.pump();

    expect(placeholder, findsNothing);
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '제출'),
    );
    expect(submit.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 객관식은 문제를 압축하고 풀이 노트를 필요할 때만 펼친다', (tester) async {
    // 필요한 변수는 네 개 선택지가 있는 모바일 객관식 문제다.
    // 작동 원리는 첫 화면에서 문제·선택·제출을 우선하고 필기판과 도구를 명시적으로 펼친다.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: BuildpageWidget(
          config: ProblemSolveConfig(
            ratingEnabled: false,
            quests: [
              {
                'header': {'quest_id': 'mobile-objective-density-test'},
                'data': {
                  'quest_title': '5x + 7 = 12일 때 x의 값을 구하세요.',
                  'quest_options': ['1', '2', '0', '3'],
                },
              },
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final problemCard = find.byKey(const ValueKey('mobile-solve-problem-card'));
    expect(problemCard, findsOneWidget);
    expect(tester.getSize(problemCard).height, lessThan(330));
    expect(
      find.byKey(const ValueKey('mobile-solve-note-launcher')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-solve-writing-surface')),
      findsNothing,
    );
    expect(find.text('펜'), findsNothing);

    await tester.tap(find.text('2'));
    await tester.pump();
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '제출'),
    );
    expect(submit.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('mobile-solve-note-launcher')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('mobile-solve-writing-surface')),
      findsOneWidget,
    );
    expect(find.text('펜'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 필기 풀이를 충분히 작성하고 제출하면 채점 화면으로 이동한다', (tester) async {
    // 필요한 변수는 모바일 풀이 화면과 서술형 문제, 네 개의 필기 획이다.
    // 작동 원리는 최소 풀이량을 충족한 뒤 제출 버튼을 눌러 즉시 채점 라우트가 열리는지 확인한다.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: BuildpageWidget(
          config: ProblemSolveConfig(
            ratingEnabled: false,
            quests: [
              {
                'header': {'quest_id': 'mobile-submit-test'},
                'data': {'quest_title': '세 획을 작성하고 제출하세요.'},
              },
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final canvas = find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onPanStart != null,
    );
    expect(canvas, findsOneWidget);
    await tester.ensureVisible(canvas);
    await tester.pump();

    for (var index = 0; index < 4; index += 1) {
      await tester.dragFrom(
        tester.getTopLeft(canvas) + Offset(45, 40 + (index * 28)),
        const Offset(90, 18),
      );
      await tester.pump();
    }

    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '제출'),
    );
    expect(submit.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, '제출'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('채점 중'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
