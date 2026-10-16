import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';

Map<String, dynamic> triangle() => {
  'id': 'triangle',
  'kind': 'rightTriangle',
  'prompt': 'Pythagoras exploration',
  'a': 6,
  'b': 8,
  'hints': ['Compare the squares'],
};

void main() {
  setUpAll(() async {
    final font = FontLoader('NotoSansKR')
      ..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'));
    await font.load();
  });
  test('strict definition round trip and invalid fields', () {
    expect(BookActivity.fromJson(triangle()).toJson(), triangle());
    for (final value in [
      null,
      true,
      0,
      13,
      6.0,
      '6',
      double.nan,
      double.infinity,
    ]) {
      expect(
        () => BookActivity.fromJson({...triangle(), 'a': value}),
        throwsFormatException,
      );
      expect(
        () => BookActivity.fromJson({...triangle(), 'b': value}),
        throwsFormatException,
      );
    }
    expect(
      () => BookActivity.fromJson({...triangle(), 'c': 10}),
      throwsFormatException,
    );
  });

  testWidgets('slider, keyboard, hints, reset and absent-frame state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final keys = <String, GlobalKey>{};
    final states = <String, Map<String, Object?>>{};
    Widget frame(bool visible) => MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansKR'),
      home: BookActivityKeyScope(
        keys: keys,
        states: states,
        bookId: 'synthetic-triangle',
        child: Scaffold(
          body: visible
              ? SingleChildScrollView(
                  child: BookActivityView(
                    activity: BookActivity.fromJson(triangle()),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpWidget(frame(true));
    expect(find.text('빗변 c: 10.00'), findsOneWidget);
    final first = find.byType(Slider).first;
    tester.widget<Slider>(first).onChanged!(3);
    await tester.pump();
    expect(find.text('빗변 c: 8.54'), findsOneWidget);
    await tester.tap(find.text('힌트 한 단계'));
    await tester.pump();
    await tester.pumpWidget(frame(false));
    await tester.pumpWidget(frame(true));
    expect(find.text('첫 직각변 a: 3'), findsOneWidget);
    expect(find.text('Compare the squares'), findsOneWidget);
    await tester.tap(find.byType(Slider).first);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      tester.widget<Slider>(find.byType(Slider).first).value,
      greaterThan(3),
    );
    await tester.tap(find.text('초기화'));
    await tester.pump();
    expect(find.text('빗변 c: 10.00'), findsOneWidget);
    expect(find.text('Compare the squares'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/book_right_triangle_mobile.png'),
    );
  });
}
