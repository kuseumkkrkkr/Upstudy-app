import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_area_model_pieces.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';

void main() {
  test(
    'chapter tags and standard codes survive BookData runtime serialization',
    () {
      final book = BookData.fromJson({
        'title': 'Synthetic',
        'tags': ['book-only'],
        'chapters': [
          {
            'title': 'Chapter',
            'tags': ['chapter-only'],
            'standard_codes': ['synthetic-standard'],
            'pages': [],
          },
        ],
      });
      final restored = BookData.fromJson(book.toCreateJson());
      expect(restored.tags, ['book-only']);
      expect(restored.chapters.single.tags, ['chapter-only']);
      expect(restored.chapters.single.standardCodes, ['synthetic-standard']);
      expect(restored.toCreateJson(), book.toCreateJson());
    },
  );
  test('standard block identity and 48 tags survive serialization', () {
    final book = BookData.fromJson({
      'title': 'Synthetic',
      'tags': List.generate(48, (i) => 'tag-$i'),
      'chapters': [
        {
          'title': 'Chapter',
          'pages': [
            {
              'template': 'concept',
              'blocks': [
                {'type': 'standard', 'title': 'Standard', 'text': 'Keep'},
              ],
            },
          ],
        },
      ],
    });
    final restored = BookData.fromJson(book.toJson());
    expect(restored.tags, book.tags);
    expect(
      restored.chapters.single.pages.single.blocks.single.type,
      BookContentBlockType.standard,
    );
    expect(restored.toJson(), book.toJson());
  });

  testWidgets('all four area labels remain visible at enlarged mobile text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: const SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: BookAreaModelPieces(
                  labels: ['x² 정사각형', 'ax 직사각형', 'bx 직사각형', 'ab 정사각형'],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (final label in ['x² 정사각형', 'ax 직사각형', 'bx 직사각형', 'ab 정사각형']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('long area formula can be scrolled instead of clipped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final book = BookData.fromJson({
      'title': 'Synthetic',
      'chapters': [
        {
          'title': 'Area',
          'pages': [
            {
              'template': 'concept',
              'title': 'Area',
              'blocks': [
                {
                  'type': 'visual',
                  'visual': {
                    'kind': 'area-model',
                    'title': 'Pieces',
                    'formula': '(x+a)(x+b)=x^2+ax+bx+ab',
                    'items': ['x²', 'ax', 'bx', 'ab'],
                  },
                },
              ],
            },
          ],
        },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(home: BookWidget(book: book, persistenceEnabled: false)),
    );
    await tester.pumpAndSettle();
    final area = find.byWidgetPredicate(
      (w) =>
          w is Semantics && w.properties.label == '수식. 좌우로 움직여 전체 수식을 확인하세요.',
    );
    final scroll = find.descendant(of: area, matching: find.byType(Scrollable));
    expect(scroll, findsOneWidget);
    final state = tester.state<ScrollableState>(scroll);
    expect(state.position.maxScrollExtent, greaterThan(0));
    await tester.drag(scroll, const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(state.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
