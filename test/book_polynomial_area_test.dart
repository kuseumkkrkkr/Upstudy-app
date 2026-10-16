import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';

Map<String, dynamic> definition() => {
  'id': 'synthetic-area',
  'kind': 'polynomialArea',
  'prompt': '전개식을 관찰하세요.',
  'a': 3,
  'b': 2,
  'hints': <String>[],
};

void main() {
  testWidgets('long desktop TOC titles fit their variable-height rows', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final title = List.filled(10, '긴 장 제목의 줄바꿈').join(' ');
    final book = BookData.fromJson({'title': 'Synthetic TOC', 'chapters': [
      {'title': title, 'sections': []}, {'title': 'Next chapter', 'sections': []}]});
    await tester.pumpWidget(MaterialApp(home: BookWidget(book: book, persistenceEnabled: false)));
    // Verify row geometry after layout, not unrelated reader animation settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final row = find.byKey(const ValueKey('book-toc-entry-0'));
    final next = find.byKey(const ValueKey('book-toc-entry-1'));
    final label = find.descendant(of: row, matching: find.text(title));
    expect(tester.getRect(label).top, greaterThanOrEqualTo(tester.getRect(row).top));
    expect(tester.getRect(label).bottom, lessThanOrEqualTo(tester.getRect(row).bottom));
    expect(tester.getRect(row).bottom, lessThanOrEqualTo(tester.getRect(next).top));
    expect(tester.takeException(), isNull);
  });
  test('existing V2 activity slot retains exact bounded definition', () {
    final json = definition();
    expect(BookActivity.fromJson(json).toJson(), json);
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
                {'type': 'activity', 'activity': json},
              ],
            },
          ],
        },
      ],
    };
    final book = BookData.fromJson(data);
    final restored = BookData.fromJson(book.toCreateJson());
    expect(restored.toCreateJson(), book.toCreateJson());
    expect(
      restored.chapters.single.pages.single.blocks.single.activity!.toJson(),
      json,
    );
    for (final change in [
      {'a': true},
      {'b': 2.0},
      {'a': 0},
      {'b': 9},
      {'script': 'bad'},
    ]) {
      expect(
        () => BookActivity.fromJson({...json, ...change}),
        throwsFormatException,
      );
    }
    expect(
      () => BookData.fromJson({...data, 'schema_version': 1}),
      throwsFormatException,
    );
  });

  testWidgets(
    'source bounds, equation, reset and reader remount state stay consistent',
    (tester) async {
      final keys = <String, GlobalKey>{};
      final states = <String, Map<String, Object?>>{};
      Widget page({bool visible = true, Map<String, dynamic>? json}) =>
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BookActivityKeyScope(
                  keys: keys,
                  states: states,
                  bookId: 'synthetic',
                  child: visible
                      ? BookActivityView(
                          activity: BookActivity.fromJson(json ?? definition()),
                        )
                      : const SizedBox(),
                ),
              ),
            ),
          );
      await tester.pumpWidget(page());
      expect(find.text('(x+3)(x+2) = x² + 5x + 6'), findsOneWidget);
      await tester.tap(find.byTooltip('a 늘리기'));
      await tester.pump();
      expect(find.text('(x+4)(x+2) = x² + 6x + 8'), findsOneWidget);
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('polynomial-area-b')),
      );
      expect(slider.min, 1);
      expect(slider.max, 8);
      expect(slider.divisions, 7);
      slider.onChanged!(8);
      await tester.pump();
      expect(find.text('(x+4)(x+8) = x² + 12x + 32'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'b 늘리기',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(page(visible: false));
      await tester.pump();
      await tester.pumpWidget(page());
      await tester.pump();
      expect(find.text('(x+4)(x+8) = x² + 12x + 32'), findsOneWidget);
      await tester.ensureVisible(find.text('초기화'));
      await tester.tap(find.text('초기화'));
      await tester.pump();
      expect(find.text('(x+3)(x+2) = x² + 5x + 6'), findsOneWidget);
      await tester.pumpWidget(page(json: {...definition(), 'a': 1}));
      await tester.pump();
      expect(find.text('(x+1)(x+2) = x² + 3x + 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
