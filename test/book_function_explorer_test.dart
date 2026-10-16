import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(File('test/fixtures/function_explorers.json').readAsStringSync())
        as Map<String, dynamic>;
List<Map<String, dynamic>> definitions() => [
  for (final page in fixture()['chapters'][0]['pages'])
    Map<String, dynamic>.from(page['blocks'][0]['activity']),
];

void main() {
  test(
    'numeric explorer rejects wrong types, grid errors and unbounded results',
    () {
      for (final (index, change) in <(int, Map<String, dynamic>)>[
        (
          0,
          {
            'a_values': [0, 1],
          },
        ),
        (
          0,
          {
            'a_values': [1, 1],
          },
        ),
        (
          0,
          {
            'a_values': [.00001, 1],
          },
        ),
        (0, {'initial_a': true}),
        (0, {'initial_a': 3}),
        (0, {'initial_b': .2}),
        (0, {'b_step': .000001}),
        (0, {'max_c': double.infinity}),
        (1, {'h_step': 0}),
        (1, {'initial_k': -4}),
        (
          2,
          {
            'bases': [1, 2],
          },
        ),
        (
          2,
          {
            'bases': [-2, 2],
          },
        ),
        (
          2,
          {
            'bases': [1e-100, 2],
          },
        ),
        (2, {'step': .3}),
        (2, {'initial_exponent': .1}),
        (2, {'min_exponent': -5}),
      ]) {
        final definition = definitions()[index];
        expect(
          () => BookActivity.fromJson({
            ...definition,
            'explorer': {...definition['explorer'], ...change},
          }),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'all three typed formulas and authored metadata survive create roundtrip',
    () {
      final book = BookData.fromJson(fixture());
      expect(
        BookData.fromJson(book.toCreateJson()).toCreateJson(),
        book.toCreateJson(),
      );
      expect(book.toCreateJson()['candidate_standard_codes'], [
        'candidate-only',
      ]);
      expect(
        book.chapters.single.toJson()['candidate_standard_codes'],
        isEmpty,
      );
      expect(
        book.chapters.single.toJson()['source_html_reference'],
        'synthetic-reference.html',
      );
      final configs = definitions()
          .map(BookActivity.fromJson)
          .map((a) => a.functionExplorer!)
          .toList();
      expect(configs[0].valueAt(-2, 2, 2, 1), isNull);
      expect(configs[0].valueAt(-1, 2, 2, 1), 1);
      expect(configs[1].valueAt(1, 2, 1, -3), isNull);
      expect(configs[1].valueAt(2, 2, 1, -3), -1);
      expect(configs[2].valueAt(2, 2, 0, 0), 4);
      for (final definition in definitions()) {
        expect(
          () => BookActivity.fromJson({...definition, 'extra': true}),
          throwsFormatException,
        );
        for (final extra in [
          {'script': 'bad'},
          {'unknown': 1},
        ]) {
          expect(
            () => BookActivity.fromJson({
              ...definition,
              'explorer': {...definition['explorer'], ...extra},
            }),
            throwsFormatException,
          );
        }
      }
      expect(
        () => BookData.fromJson({...fixture(), 'schema_version': 1}),
        throwsFormatException,
      );
      for (final bad in [
        null,
        true,
        ['x' * 81],
        List.filled(33, 'x'),
      ]) {
        expect(
          () => BookData.fromJson({
            ...fixture(),
            'candidate_standard_codes': bad,
          }),
          throwsFormatException,
        );
      }
      for (final bad in [
        '',
        '..',
        '../source.html',
        'https://example.org/a',
        'C:\\source.html',
        'x' * 241,
      ]) {
        final data = fixture();
        data['chapters'][0]['source_html_reference'] = bad;
        expect(() => BookData.fromJson(data), throwsFormatException);
      }
    },
  );

  for (final index in [0, 1, 2]) {
    testWidgets(
      'explorer $index controls, steps, hint, reset and identical-definition restore',
      (tester) async {
        final keys = <String, GlobalKey>{},
            states = <String, Map<String, Object?>>{};
        final definition = definitions()[index];
        Widget host({bool visible = true, Map<String, dynamic>? change}) =>
            MaterialApp(
              home: Scaffold(
                body: BookActivityKeyScope(
                  keys: keys,
                  states: states,
                  bookId: 'synthetic',
                  child: SingleChildScrollView(
                    child: visible
                        ? BookActivityView(
                            activity: BookActivity.fromJson({
                              ...definition,
                              ...?change,
                            }),
                          )
                        : const SizedBox(),
                  ),
                ),
              ),
            );
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final initialEquation = tester
            .widget<Text>(find.byKey(const ValueKey('explorer-equation')))
            .data;
        final slider = tester.widget<Slider>(
          find.byKey(const ValueKey('explorer-u')),
        );
        slider.onChanged!(slider.min);
        await tester.pumpAndSettle();
        final changedEquation = tester
            .widget<Text>(find.byKey(const ValueKey('explorer-equation')))
            .data;
        expect(changedEquation, isNot(initialEquation));
        await tester.ensureVisible(find.text('다음 단계 보기'));
        await tester.tap(find.text('다음 단계 보기'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('explorer-stage')))
              .data,
          startsWith('1단계'),
        );
        await tester.ensureVisible(find.text('힌트 보기'));
        await tester.tap(find.text('힌트 보기'));
        await tester.pumpAndSettle();
        expect(find.text('힌트 숨기기'), findsOneWidget);
        await tester.pumpWidget(host(visible: false));
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('explorer-equation')))
              .data,
          changedEquation,
        );
        expect(find.text('힌트 숨기기'), findsOneWidget);
        await tester.ensureVisible(find.text('처음 값으로'));
        await tester.tap(find.text('처음 값으로'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('explorer-equation')))
              .data,
          initialEquation,
        );
        expect(find.text('힌트 보기'), findsOneWidget);
        await tester.pumpWidget(
          host(change: {'prompt': 'Changed authored definition'}),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('explorer-equation')))
              .data,
          initialEquation,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
