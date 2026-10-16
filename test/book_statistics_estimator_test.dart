import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> definition({bool proportion = false}) => {
  'id': 'statistics-qa',
  'kind': 'statisticsEstimator',
  'prompt': 'Synthetic estimator',
  'hints': ['Compare another sample'],
  'statistics': proportion
      ? {'mode': 'proportion', 'successes': 3, 'trials': 10}
      : {
          'mode': 'mean',
          'sample_values': [2, 4, 6],
        },
};

void main() {
  testWidgets(
    'actual multipage reader keeps estimator state and clears on book/session change',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      ApiClient.instance.setTokenForTest('synthetic-statistics-owner');
      addTearDown(ApiClient.instance.clearTokenForTest);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      BookData book(String id) => BookData.fromJson({
        'schema_version': 2,
        'textbook_id': id,
        'title': 'Synthetic multi-page statistics',
        'chapters': [
          {
            'title': 'Chapter',
            'pages': [
              {
                'id': 'estimate',
                'title': 'Mean',
                'template': 'experiment',
                'blocks': [
                  {'type': 'activity', 'activity': definition()},
                ],
              },
              {
                'id': 'next',
                'title': 'Next',
                'template': 'experiment',
                'blocks': [
                  {'type': 'paragraph', 'text': 'Second source page'},
                ],
              },
            ],
          },
        ],
      });
      Future<void> open(BookData value) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BookWidget(
              book: value,
              persistenceEnabled: false,
              bookLoader: (_) async => value,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open(book('statistics-owner-book'));
      await tester.enterText(find.byType(TextField), '2, 4, 12');
      await tester.tap(find.text('추정하기'));
      await tester.tap(find.text('힌트 한 단계'));
      await tester.pump();
      for (final size in [const Size(390, 844), const Size(1280, 900)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(find.text('모평균의 추정값: 6.0000'), findsOneWidget);
        expect(find.text('Compare another sample'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '2, 4, 12',
        );
      }
      await open(book('different-statistics-book'));
      expect(find.text('모평균의 추정값: 6.0000'), findsNothing);
      expect(find.text('Compare another sample'), findsNothing);
      ApiClient.instance.clearTokenForTest();
      await tester.pumpAndSettle();
      expect(find.byType(BookActivityView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('strict typed statistics round trip', () {
    for (final proportion in [false, true]) {
      final a = BookActivity.fromJson(definition(proportion: proportion));
      expect(BookActivity.fromJson(a.toJson()).toJson(), a.toJson());
    }
    for (final statistics in [
      {'mode': 'mean', 'sample_values': []},
      {
        'mode': 'mean',
        'sample_values': [double.nan],
      },
      {
        'mode': 'mean',
        'sample_values': [true],
      },
      {
        'mode': 'mean',
        'sample_values': [1],
        'script': 'bad',
      },
      {'mode': 'proportion', 'successes': 2, 'trials': 1},
      {'mode': 'proportion', 'successes': true, 'trials': 2},
      {'mode': 'proportion', 'successes': 1, 'trials': 2.0},
    ]) {
      expect(
        () =>
            BookActivity.fromJson({...definition(), 'statistics': statistics}),
        throwsFormatException,
      );
    }
  });
  testWidgets(
    'sample mean edits, errors, hint and absent-frame session restore',
    (tester) async {
      final keys = <String, GlobalKey>{},
          states = <String, Map<String, Object?>>{};
      Widget frame(bool visible) => MaterialApp(
        home: BookActivityKeyScope(
          keys: keys,
          states: states,
          bookId: 'mean-qa',
          child: Scaffold(
            body: SingleChildScrollView(
              child: visible
                  ? BookActivityView(
                      activity: BookActivity.fromJson(definition()),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpWidget(frame(true));
      await tester.tap(find.text('추정하기'));
      await tester.pump();
      expect(find.text('모평균의 추정값: 4.0000'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1, 3, 8');
      await tester.pump();
      expect(find.text('모평균의 추정값: 4.0000'), findsNothing);
      await tester.tap(find.text('추정하기'));
      await tester.tap(find.text('힌트 한 단계'));
      await tester.pump();
      await tester.pumpWidget(frame(false));
      await tester.pumpWidget(frame(true));
      expect(find.text('모평균의 추정값: 4.0000'), findsOneWidget);
      expect(find.text('Compare another sample'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1, 3, 8',
      );
      await tester.enterText(find.byType(TextField), 'NaN');
      await tester.tap(find.text('추정하기'));
      await tester.pump();
      expect(find.textContaining('유한한 숫자'), findsOneWidget);
      expect(find.textContaining('모평균의 추정값:'), findsNothing);
      await tester.tap(find.text('표본 초기화'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '2.0, 4.0, 6.0',
      );
      expect(find.text('Compare another sample'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('proportion validates counts and calculates percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookActivityView(
              activity: BookActivity.fromJson(definition(proportion: true)),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('추정하기'));
    await tester.pump();
    expect(find.text('모비율의 추정값: 30.00%'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '11');
    await tester.tap(find.text('추정하기'));
    await tester.pump();
    expect(find.textContaining('정수여야 합니다.'), findsOneWidget);
    expect(find.text('모비율의 추정값: 30.00%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
