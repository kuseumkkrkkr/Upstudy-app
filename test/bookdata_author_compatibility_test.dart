import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_area_model_pieces.dart';

void main() {
  test('standard block identity and 48 tags survive serialization', () {
    final book = BookData.fromJson({
      'title': 'Synthetic',
      'tags': List.generate(48, (i) => 'tag-$i'),
      'chapters': [{'title': 'Chapter', 'pages': [{'template': 'concept',
        'blocks': [{'type': 'standard', 'title': 'Standard', 'text': 'Keep'}]}]}],
    });
    final restored = BookData.fromJson(book.toJson());
    expect(restored.tags, book.tags);
    expect(restored.chapters.single.pages.single.blocks.single.type,
        BookContentBlockType.standard);
    expect(restored.toJson(), book.toJson());
  });

  testWidgets('all four area labels remain visible at enlarged mobile text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: const SingleChildScrollView(child: Padding(
        padding: EdgeInsets.all(24),
        child: BookAreaModelPieces(labels: ['x² 정사각형', 'ax 직사각형', 'bx 직사각형', 'ab 정사각형']),
      )),
    ))));
    for (final label in ['x² 정사각형', 'ax 직사각형', 'bx 직사각형', 'ab 정사각형']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
