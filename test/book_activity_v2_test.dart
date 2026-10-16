import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/shared/services/api/api_client.dart';

Map<String, dynamic> quiz() => {
  'id': 'quiz',
  'kind': 'quiz',
  'prompt': 'Choose',
  'options': ['A', 'B'],
  'correct_index': 1,
  'correct_feedback': 'Correct',
  'incorrect_feedback': 'Try again',
  'hints': ['Think first'],
};

Widget app(Map<String, dynamic> value, {bool reduced = false}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: SingleChildScrollView(
        child: BookActivityView(activity: BookActivity.fromJson(value)),
      ),
    ),
  ),
);

void main() {
  const sourcePath = String.fromEnvironment('BOOK_ACTIVITY_SOURCE');
  if (sourcePath.isNotEmpty) {
    test('external private manuscript V2 model round trip', () async {
      final book = BookData.fromJson(
        jsonDecode(await File(sourcePath).readAsString())
            as Map<String, dynamic>,
      );
      expect(book.schemaVersion, 2);
      final restored = BookData.fromJson(book.toJson());
      expect(restored.toJson(), book.toJson());
      final activities = book.chapters
          .expand((c) => c.pages)
          .expand((p) => p.blocks)
          .where((b) => b.activity != null);
      expect(activities.length, 4);
    });
  }
  testWidgets('scrolling a lazy list does not discard practice answers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              BookActivityView(activity: BookActivity.fromJson(quiz())),
              const SizedBox(height: 2000),
              const Text('Bottom'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('B'));
    await tester.tap(find.text('답 확인'));
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -2400));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 2400));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
  });
  testWidgets(
    'V2 activity remains reachable in actual reader at mobile and desktop',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      ApiClient.instance.setTokenForTest('synthetic-v2-owner');
      addTearDown(ApiClient.instance.clearTokenForTest);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final book = BookData.fromJson({
        'schema_version': 2,
        'textbook_id': 'synthetic-v2',
        'title': 'V2',
        'chapters': [
          {
            'title': 'Practice',
            'pages': [
              {
                'id': 'quiz-page',
                'template': 'practice',
                'title': 'Check',
                'blocks': [
                  {'type': 'activity', 'activity': quiz()},
                ],
              },
            ],
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: BookWidget(
            book: book,
            persistenceEnabled: false,
            bookLoader: (_) async => book,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookActivityView), findsOneWidget);
      await tester.ensureVisible(find.text('B'));
      await tester.tap(find.text('B'));
      await tester.tap(find.text('답 확인'));
      await tester.pump();
      expect(find.text('Correct'), findsOneWidget);
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      expect(find.byType(BookActivityView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('V1 stays V1, V2 survives storage and create serialization', () {
    final old = BookData.fromJson({'title': 'V1', 'chapters': []});
    expect(old.schemaVersion, 1);
    final value = {
      'schema_version': 2,
      'title': 'V2',
      'chapters': [
        {
          'title': 'Chapter',
          'pages': [
            {
              'id': 'p',
              'template': 'practice',
              'blocks': [
                {'type': 'activity', 'activity': quiz()},
              ],
            },
          ],
        },
      ],
    };
    final book = BookData.fromJson(value);
    final restored = BookData.fromJson(book.toJson());
    expect(restored.schemaVersion, 2);
    expect(
      restored.chapters.single.pages.single.blocks.single.activity!.toJson(),
      BookActivity.fromJson(quiz()).toJson(),
    );
    expect(restored.toCreateJson()['schema_version'], 2);
    expect(
      () => BookData.fromJson({...value, 'schema_version': 3}),
      throwsFormatException,
    );
    expect(
      () => BookActivity.fromJson({...quiz(), 'script': 'bad'}),
      throwsFormatException,
    );
    expect(BookActivity.numericInput('1/2'), .5);
    for (final bad in ['1/0', 'NaN', 'Infinity', '1+1', '1/2/3']) {
      expect(BookActivity.numericInput(bad), isNull);
    }
  });
  testWidgets('choice, retry, hint, correct response and reset', (
    tester,
  ) async {
    await tester.pumpWidget(app(quiz()));
    await tester.tap(find.text('답 확인'));
    await tester.pump();
    expect(find.text('답을 선택해 주세요.'), findsOneWidget);
    await tester.tap(find.text('A'));
    await tester.tap(find.text('답 확인'));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('힌트 한 단계'));
    await tester.pump();
    expect(find.text('Think first'), findsOneWidget);
    await tester.tap(find.text('B'));
    await tester.tap(find.text('답 확인'));
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    await tester.pumpWidget(app(quiz()));
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    await tester.tap(find.text('초기화'));
    await tester.pump();
    expect(find.text('Correct'), findsNothing);
  });
  testWidgets('numeric decimal and fraction validation', (tester) async {
    await tester.pumpWidget(
      app({
        'id': 'numeric',
        'kind': 'quiz',
        'prompt': 'Half',
        'answer': .5,
        'tolerance': .001,
        'correct_feedback': 'Yes',
        'incorrect_feedback': 'Retry',
      }),
    );
    await tester.enterText(find.byType(TextField), '1/2');
    await tester.tap(find.text('답 확인'));
    await tester.pump();
    expect(find.text('Yes'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1/0');
    await tester.tap(find.text('답 확인'));
    await tester.pump();
    expect(find.text('유한한 숫자 또는 분수로 입력해 주세요.'), findsOneWidget);
  });
  testWidgets('geometry, reduced motion and timer disposal', (tester) async {
    final data = {
      'id': 'parabola',
      'kind': 'parabolaDistance',
      'prompt': 'Distance',
      'p': 2,
      'x': 4,
    };
    await tester.pumpWidget(app(data, reduced: true));
    expect(find.text('PF 4.00 · 준선까지 4.00'), findsOneWidget);
    await tester.ensureVisible(find.text('재생'));
    await tester.tap(find.text('재생'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('동작 줄이기 설정'), findsOneWidget);
    expect(find.text('x = 4.00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(data));
    await tester.ensureVisible(find.text('재생'));
    await tester.tap(find.text('재생'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('정지'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
}
