import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';

Map<String, dynamic> walk() => {
  'id': 'walk',
  'kind': 'coordinateWalk',
  'prompt': 'Coordinate walk',
  'x': -3,
  'y': 2,
  'duration_ms': 1500,
  'hints': ['Horizontal then vertical'],
};

void main() {
  setUpAll(() async {
    final font = FontLoader('NotoSansKR')
      ..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'));
    await font.load();
  });
  test('walk and old point definitions remain distinct and lossless', () {
    expect(BookActivity.fromJson(walk()).toJson(), walk());
    final point = {
      'id': 'point',
      'kind': 'coordinatePoint',
      'prompt': 'Point',
      'x': -2,
      'y': 3,
    };
    expect(BookActivity.fromJson(point).toJson(), {...point, 'hints': []});
    for (final value in [null, true, 0, 1499, 1501, 1500.0, '1500']) {
      expect(
        () => BookActivity.fromJson({...walk(), 'duration_ms': value}),
        throwsFormatException,
      );
    }
    expect(
      () => BookActivity.fromJson({...walk(), 'kind': 'coordinatePoint'}),
      throwsFormatException,
    );
    expect(
      () => BookActivity.fromJson({...walk(), 'running': true}),
      throwsFormatException,
    );
  });

  for (final reduced in [false, true]) {
    testWidgets('walk pause/remount/swap/reset and reduced motion $reduced', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final keys = <String, GlobalKey>{},
          states = <String, Map<String, Object?>>{};
      Widget frame(bool visible) => MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansKR'),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 1100),
            disableAnimations: reduced,
          ),
          child: BookActivityKeyScope(
            keys: keys,
            states: states,
            bookId: 'synthetic-walk',
            child: Scaffold(
              body: visible
                  ? SingleChildScrollView(
                      child: BookActivityView(
                        activity: BookActivity.fromJson(walk()),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpWidget(frame(true));
      await tester.tap(find.text('이동 시작'));
      await tester.pump();
      await tester
          .pump(); // First ticker frame follows the guarded post-frame start.
      await tester.pump(const Duration(milliseconds: 300));
      if (reduced) {
        expect(states.values.single['walk_progress'], 1.0);
        expect(find.textContaining('도착!'), findsOneWidget);
      } else {
        final progress = states.values.single['walk_progress'] as double;
        expect(progress, greaterThan(0));
        expect(progress, lessThan(1));
        await tester.tap(find.text('일시정지'));
        await tester.pumpAndSettle();
        final paused = states.values.single['walk_progress'];
        await tester.pump(const Duration(seconds: 2));
        expect(states.values.single['walk_progress'], paused);
        await tester.pumpWidget(frame(false));
        await tester.pumpWidget(frame(true));
        await tester.pump(const Duration(seconds: 1));
        expect(states.values.single['walk_progress'], paused);
        expect(find.text('계속 이동'), findsOneWidget);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/book_coordinate_walk_paused.png'),
        );
        await tester.tap(find.text('계속 이동'));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1600));
        expect(find.textContaining('도착!'), findsOneWidget);
      }
      await tester.tap(find.text('좌표 순서 바꾸기'));
      await tester.pump();
      expect(find.text('A(2, -3) · 제4사분면'), findsOneWidget);
      expect(states.values.single['walk_visible'], false);
      await tester.tap(find.byKey(const ValueKey('coordinate-point-handle')));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('A(3, -3) · 제4사분면'), findsOneWidget);
      await tester.tap(find.text('처음 위치로'));
      await tester.pumpAndSettle();
      expect(find.text('A(-3, 2) · 제2사분면'), findsOneWidget);
      expect(states.values.single['walk_progress'], 0.0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets(
    'duplicate starts, disabled ticker and disposal do not autoplay',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final keys = <String, GlobalKey>{},
          states = <String, Map<String, Object?>>{};
      Widget frame(bool enabled, {bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 1100),
            disableAnimations: reduced,
          ),
          child: BookActivityKeyScope(
            keys: keys,
            states: states,
            bookId: 'duplicate',
            child: Scaffold(
              body: TickerMode(
                enabled: enabled,
                child: SingleChildScrollView(
                  child: BookActivityView(
                    activity: BookActivity.fromJson(walk()),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(frame(true));
      await tester.tap(find.text('이동 시작'));
      await tester.tap(find.text('이동 시작'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(states.values.single['walk_progress'], 0.0);
      await tester.tap(find.text('계속 이동'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(states.values.single['walk_progress'] as double, greaterThan(0));
      await tester.pumpWidget(frame(false));
      final paused = states.values.single['walk_progress'];
      await tester.pump(const Duration(seconds: 2));
      expect(states.values.single['walk_progress'], paused);
      await tester.pumpWidget(frame(true));
      await tester.pump(const Duration(seconds: 1));
      expect(states.values.single['walk_progress'], paused);
      await tester.tap(find.text('계속 이동'));
      await tester.pump();
      await tester.pumpWidget(frame(true, reduced: true));
      await tester.pump();
      expect(states.values.single['walk_progress'], 1.0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}
