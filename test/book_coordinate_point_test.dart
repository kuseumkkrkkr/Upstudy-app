import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/book_coordinate_point.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_coordinate_point_view.dart';

Map<String, dynamic> point() => {
  'id': 'point',
  'kind': 'coordinatePoint',
  'prompt': 'Move point A',
  'x': -2,
  'y': 3,
  'hints': ['Horizontal, then vertical'],
};

void main() {
  setUpAll(() async {
    final font = FontLoader('NotoSansKR')
      ..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'));
    await font.load();
  });
  test(
    'strict round trip, quadrant/axis/origin outputs and clamped movement',
    () {
      expect(BookActivity.fromJson(point()).toJson(), point());
      for (final value in [null, true, -6, 6, 2.0, '2', double.nan]) {
        expect(
          () => BookActivity.fromJson({...point(), 'x': value}),
          throwsFormatException,
        );
      }
      for (final entry in [
        [1, 1, '제1사분면'],
        [-1, 1, '제2사분면'],
        [-1, -1, '제3사분면'],
        [1, -1, '제4사분면'],
        [0, 0, '원점'],
        [0, 1, 'y축 위'],
        [1, 0, 'x축 위'],
      ]) {
        final p = BookCoordinatePoint.fromJson({'x': entry[0], 'y': entry[1]});
        expect(p.quadrant, entry[2]);
      }
      expect(BookCoordinatePoint.bounded(99, -99).toJson(), {'x': 5, 'y': -5});
      expect(BookCoordinatePoint.snapped(-1.5, 2.5).toJson(), {
        'x': -1,
        'y': 3,
      });
      expect(
        () => BookCoordinatePoint.snapped(double.nan, 0),
        throwsArgumentError,
      );
      expect(BookCoordinatePoint.bounded(5, -5).move(1, -1).toJson(), {
        'x': 5,
        'y': -5,
      });
      expect(
        () => BookActivity.fromJson({...point(), 'onDrag': 'execute()'}),
        throwsFormatException,
      );
    },
  );
  test(
    'existing function line scatter slider graphs survive V1/V2 canonical round trip',
    () {
      for (final version in [1, 2]) {
        final graphDefinition = {
          'items': [
            {'id': 'f', 'type': 'function', 'expression': 'x*x/(4*p)'},
            {
              'id': 'l',
              'type': 'line',
              'xValues': [-1, 1],
              'yValues': [2, 3],
            },
            {
              'id': 's',
              'type': 'scatter',
              'xValues': [0],
              'yValues': [4],
            },
          ],
          'settings': {
            'parameters': [
              {'id': 'p', 'value': 2, 'min': .5, 'max': 3, 'step': .5},
            ],
          },
        };
        final book = BookData.fromJson({
          'schema_version': version,
          'title': 'Synthetic graph',
          'chapters': [
            {
              'title': 'Chapter',
              'pages': [
                {
                  'id': 'g',
                  'title': 'Graph',
                  'template': 'experiment',
                  'blocks': [
                    {'type': 'graph', 'graph': graphDefinition},
                  ],
                },
              ],
            },
          ],
        });
        final canonical = book.toJson();
        expect(BookData.fromJson(canonical).toJson(), canonical);
        final graph = book.chapters.single.pages.single.blocks.single.graph!;
        expect(graph.items.map((i) => i.type.name), [
          'function',
          'line',
          'scatter',
        ]);
        expect(graph.items.first.expression, 'x*x/(4*p)');
        expect(graph.settings.parameters.single.value, 2);
      }
    },
  );

  for (final device in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('direct point $device drag, keys, stage, snapshot and reset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final keys = <String, GlobalKey>{},
          states = <String, Map<String, Object?>>{};
      Widget frame(bool visible) => MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansKR'),
        home: BookActivityKeyScope(
          keys: keys,
          states: states,
          bookId: 'synthetic-point',
          child: Scaffold(
            body: visible
                ? SingleChildScrollView(
                    child: BookActivityView(
                      activity: BookActivity.fromJson(point()),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpWidget(frame(true));
      final plot = find.descendant(
        of: find.byType(BookCoordinatePointView),
        matching: find.byType(Stack),
      );
      final rect = tester.getRect(plot),
          unit = (tester.getSize(plot).width - 48) / 10;
      final handle = find.byKey(const ValueKey('coordinate-point-handle'));
      final drag = await tester.startGesture(
        tester.getCenter(handle),
        kind: device,
      );
      await drag.moveTo(rect.center + Offset(3 * unit, 2 * unit));
      await drag.up();
      await tester.pumpAndSettle();
      expect(find.text('A(3, -2) · 제4사분면'), findsOneWidget);
      await tester.tap(handle);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(find.text('A(3, -1) · 제4사분면'), findsOneWidget);
      await tester.tap(find.text('이동 순서 보기'));
      await tester.tap(find.text('힌트 한 단계'));
      await tester.pump();
      await tester.pumpWidget(frame(false));
      await tester.pumpWidget(frame(true));
      expect(find.text('A(3, -1) · 제4사분면'), findsOneWidget);
      expect(find.text('Horizontal, then vertical'), findsOneWidget);
      expect(find.textContaining('2단계:'), findsOneWidget);
      await tester.tap(find.text('처음 위치로'));
      await tester.pumpAndSettle();
      expect(find.text('A(-2, 3) · 제2사분면'), findsOneWidget);
      expect(find.text('Horizontal, then vertical'), findsNothing);
      expect(tester.takeException(), isNull);
      if (device == PointerDeviceKind.touch) {
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/book_coordinate_point_mobile.png'),
        );
      }
    });
  }
}
