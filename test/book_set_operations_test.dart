import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/book_set_operations.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';

Map<String, dynamic> definition() => {
  'id': 'sets',
  'kind': 'setOperations',
  'prompt': 'Synthetic sets',
  'universe': [1, 2, 3, 4, 5, 6],
  'set_a': [1, 2, 3],
  'set_b': [3, 4, 5],
  'operation': 'intersection',
  'hints': [],
};
void main() {
  for (final operation in BookSetOperations.operations) {
    testWidgets('$operation highlights exactly its selected regions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookActivityView(
                activity: BookActivity.fromJson({
                  ...definition(),
                  'operation': operation,
                }),
              ),
            ),
          ),
        ),
      );
      final painter = tester
          .widget<CustomPaint>(find.byKey(const ValueKey('set-venn')))
          .painter!;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(640, 330));
        final picture = recorder.endRecording();
        final image = await picture.toImage(640, 330);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        List<int> pixel(int x, int y) => [
          for (var c = 0; c < 4; c++) bytes.getUint8((y * 640 + x) * 4 + c),
        ];
        const selected = {
          'intersection': [false, false, true, false],
          'union': [true, true, true, false],
          'difference': [true, false, false, false],
          'complement': [false, true, false, true],
        };
        // A only, B only, intersection, outside both; away from glyphs and strokes.
        for (var i = 0; i < 4; i++) {
          expect(
            pixel([205, 435, 320, 540][i], 250),
            selected[operation]![i]
                ? isNot([255, 255, 255, 255])
                : [255, 255, 255, 255],
          );
        }
        image.dispose();
        picture.dispose();
      });
    });
  }
  test('roundtrip and exhaustive two-set truth tables', () {
    expect(BookActivity.fromJson(definition()).toJson(), definition());
    for (final change in [
      <String, dynamic>{
        'set_a': [true],
      },
      {
        'universe': [1.0, 2, 3, 4, 5, 6],
      },
      {
        'set_b': [7],
      },
      {
        'set_a': [1, 1],
      },
      {'operation': 'script'},
      {'html': 'bad'},
    ]) {
      expect(
        () => BookActivity.fromJson({...definition(), ...change}),
        throwsFormatException,
      );
    }
    for (var maskA = 0; maskA < 64; maskA++) {
      for (var maskB = 0; maskB < 64; maskB++) {
        final a = {
          for (var n = 1; n <= 6; n++)
            if ((maskA & (1 << (n - 1))) != 0) n,
        };
        final b = {
          for (var n = 1; n <= 6; n++)
            if ((maskB & (1 << (n - 1))) != 0) n,
        };
        expect(
          BookSetOperations.result(a, b, 'intersection').toSet(),
          a.intersection(b),
        );
        expect(BookSetOperations.result(a, b, 'union').toSet(), a.union(b));
        expect(
          BookSetOperations.result(a, b, 'difference').toSet(),
          a.difference(b),
        );
        expect(
          BookSetOperations.result(a, b, 'complement').toSet(),
          {1, 2, 3, 4, 5, 6}.difference(a),
        );
      }
    }
  });
  testWidgets(
    'membership operation reset and definition-bound session restoration',
    (tester) async {
      final keys = <String, GlobalKey>{};
      final states = <String, Map<String, Object?>>{};
      Widget page({bool visible = true, Map<String, dynamic>? data}) =>
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BookActivityKeyScope(
                  keys: keys,
                  states: states,
                  bookId: 'test',
                  child: visible
                      ? BookActivityView(
                          activity: BookActivity.fromJson(data ?? definition()),
                        )
                      : const SizedBox(),
                ),
              ),
            ),
          );
      await tester.pumpWidget(page());
      expect(find.textContaining('A∩B = {3}'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).at(4)); // Remove element 3 from A.
      await tester.pump();
      expect(find.textContaining('A∩B = {}'), findsOneWidget);
      await tester.ensureVisible(find.text('Aᶜ'));
      await tester.tap(find.text('Aᶜ'));
      await tester.pump();
      expect(find.textContaining('Aᶜ = {3, 4, 5, 6}'), findsOneWidget);
      await tester.pumpWidget(page(visible: false));
      await tester.pump();
      await tester.pumpWidget(page());
      await tester.pump();
      expect(find.textContaining('Aᶜ = {3, 4, 5, 6}'), findsOneWidget);
      await tester.ensureVisible(find.text('초기화'));
      await tester.tap(find.text('초기화'));
      await tester.pump();
      expect(find.textContaining('A∩B = {3}'), findsOneWidget);
      await tester.pumpWidget(page(data: {...definition(), 'set_a': <int>[]}));
      await tester.pump();
      expect(find.textContaining('A∩B = {}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
