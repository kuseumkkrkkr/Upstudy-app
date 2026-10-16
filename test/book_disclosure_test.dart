import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';

Map<String, dynamic> _definition() => {
  'id': 'details',
  'kind': 'disclosure',
  'prompt': 'Synthetic summary',
  'content': 'Literal <script> text, not HTML',
  'hints': <String>['Read the assumption first.'],
};

void main() {
  test('disclosure content round-trips and stays in its page context', () {
    final data = {
      'schema_version': 2,
      'title': 'Synthetic',
      'chapters': [
        {
          'title': 'Chapter',
          'pages': [
            {
              'id': 'disclosure-page',
              'template': 'experiment',
              'blocks': [
                {'type': 'activity', 'activity': _definition()},
                {
                  'type': 'activity',
                  'activity': {
                    'id': 'point-context',
                    'kind': 'coordinatePoint',
                    'prompt': 'Synthetic coordinate prompt',
                    'x': -2,
                    'y': 3,
                    'hints': ['Authored axis case'],
                  },
                },
              ],
            },
            {
              'id': 'other-page',
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
    final page = book.chapters.single.pages.first;
    expect(
      page.contextText,
      containsAll([
        _definition()['prompt'],
        _definition()['content'],
        'Read the assumption first.',
        'Authored axis case',
      ]),
    );
    expect(page.contextText, isNot(contains('Unrelated other page')));
    expect(
      BookData.fromJson(book.toCreateJson()).toCreateJson(),
      book.toCreateJson(),
    );
    final activity = BookActivity.fromJson(_definition());
    expect(BookActivity.fromJson(activity.toJson()).toJson(), _definition());

    for (final change in [
      <String, dynamic>{'content': null},
      {'content': true},
      {'content': ''},
      {'content': 'x' * 2001},
      {'onclick': 'bad'},
    ]) {
      expect(
        () => BookActivity.fromJson({..._definition(), ...change}),
        throwsFormatException,
      );
    }
  });

  testWidgets('disclosure opens safely and restores only identical content', (
    tester,
  ) async {
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
                    ..._definition(),
                    if (content != null) 'content': content,
                  }),
                )
              : const SizedBox(),
        ),
      ),
    );

    await tester.pumpWidget(page());
    expect(find.text(_definition()['content'] as String), findsNothing);
    await tester.tap(find.text('Synthetic summary'));
    await tester.pumpAndSettle();
    expect(find.text(_definition()['content'] as String), findsOneWidget);

    await tester.pumpWidget(page(visible: false));
    await tester.pump();
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text(_definition()['content'] as String), findsOneWidget);

    await tester.tap(find.text('Synthetic summary'));
    await tester.pumpAndSettle();
    expect(find.text(_definition()['content'] as String), findsNothing);
    await tester.tap(find.text('Synthetic summary'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(page(content: 'Changed definition'));
    await tester.pumpAndSettle();
    expect(find.text('Changed definition'), findsNothing);
    await tester.tap(find.text('Synthetic summary'));
    await tester.pumpAndSettle();
    expect(find.text('Changed definition'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
