import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';

Map<String, dynamic> definition() => {
  'id': 'details',
  'kind': 'disclosure',
  'prompt': 'Synthetic summary',
  'content': 'Literal <script> text, not HTML',
  'hints': <String>[],
};
void main() {
  test('disclosure definition roundtrip and V1 rejection', () {
    final data = {
      'schema_version': 2,
      'title': 'Synthetic',
      'chapters': [
        {
          'title': 'Chapter',
          'pages': [
            {
              'template': 'experiment',
              'blocks': [
                {'type': 'activity', 'activity': definition()},
              ],
            },
            {
              'template': 'practice',
              'blocks': [
                {'type': 'paragraph', 'text': 'Unrelated other page'},
              ],
            },
          ],
        },
      ],
    };
    final book = BookData.fromJson(data);
    expect(
      book.chapters.single.pages.first.contextText,
      containsAll([definition()['prompt'], definition()['content']]),
    );
    expect(
      book.chapters.single.pages.first.contextText,
      isNot(contains('Unrelated other page')),
    );
    expect(
      BookData.fromJson(book.toCreateJson()).toCreateJson(),
      book.toCreateJson(),
    );
    for (final change in [
      <String, dynamic>{'content': null},
      {'content': true},
      {'content': ''},
      {'content': 'x' * 2001},
      {'onclick': 'bad'},
    ]) {
      expect(
        () => BookActivity.fromJson({...definition(), ...change}),
        throwsFormatException,
      );
    }
    expect(
      () => BookData.fromJson({...data, 'schema_version': 1}),
      throwsFormatException,
    );
  });
  testWidgets(
    'reversible disclosure restores only identical reader definition',
    (tester) async {
      final keys = <String, GlobalKey>{};
      final states = <String, Map<String, Object?>>{};
      Widget page({bool visible = true, String? content}) => MaterialApp(
        home: Scaffold(
          body: BookActivityKeyScope(
            keys: keys,
            states: states,
            bookId: 'synthetic',
            child: visible
                ? BookActivityView(
                    activity: BookActivity.fromJson({
                      ...definition(),
                      if (content != null) 'content': content,
                    }),
                  )
                : const SizedBox(),
          ),
        ),
      );
      await tester.pumpWidget(page());
      expect(find.text(definition()['content'] as String), findsNothing);
      await tester.tap(find.text('Synthetic summary'));
      await tester.pumpAndSettle();
      expect(find.text(definition()['content'] as String), findsOneWidget);
      await tester.pumpWidget(page(visible: false));
      await tester.pump();
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text(definition()['content'] as String), findsOneWidget);
      await tester.tap(find.text('Synthetic summary'));
      await tester.pumpAndSettle();
      expect(find.text(definition()['content'] as String), findsNothing);
      await tester.tap(find.text('Synthetic summary'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(page(content: 'Changed definition'));
      await tester.pumpAndSettle();
      expect(find.text('Changed definition'), findsNothing);
      await tester.tap(find.text('Synthetic summary'));
      await tester.pumpAndSettle();
      expect(find.text('Changed definition'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
