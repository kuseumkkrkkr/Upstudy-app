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
}
