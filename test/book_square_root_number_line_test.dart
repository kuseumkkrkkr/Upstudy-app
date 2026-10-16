import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';

void main() {
  final json = <String, dynamic>{'id': 'synthetic-root', 'kind': 'squareRootNumberLine',
      'prompt': '제곱근 위치 확인', 'min': 1, 'max': 25, 'hints': <String>[]};
  test('registered bounds serialize exactly; invalid variants never disappear', () {
    expect(BookActivity.fromJson(json).toJson(), json);
    for (final change in [{'min': true}, {'max': 25.0}, {'min': 0}, {'max': 26}, {'script': 'bad'}]) {
      expect(() => BookActivity.fromJson({...json, ...change}), throwsFormatException);
    }
  });
  testWidgets('reader activity slider updates n, root and number-line marker', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 390,
      child: BookActivityView(activity: BookActivity.fromJson(json))))));
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.semanticFormatterCallback!(9), '9');
    expect(slider.label, isNull); // The permanent readout replaces an overlapping tooltip.
    final before = tester.getTopLeft(find.byKey(const ValueKey('square-root-position')));
    expect(find.text('n = 1 · √1 = 1'), findsOneWidget);
    slider.onChanged!(9);
    await tester.pump();
    expect(find.text('n = 9 · √9 = 3'), findsOneWidget);
    final after = tester.getTopLeft(find.byKey(const ValueKey('square-root-position')));
    expect(after.dx, greaterThan(before.dx));
    expect(tester.takeException(), isNull);
  });
}
