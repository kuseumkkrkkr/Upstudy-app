import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> experiment() => {
  'id': 'event',
  'kind': 'discreteExperiment',
  'prompt': 'Synthetic probability experiment',
  'hints': ['Compare the counts'],
  'experiment': {
    'outcomes': [
      {'label': 'never', 'weight': 0, 'success': false},
      {'label': 'always', 'weight': 1, 'success': true},
    ],
    'max_trials': 15,
    'batch_sizes': [1, 10],
  },
};

void main() {
  testWidgets(
    'reader session restores experiment after an absent layout frame',
    (tester) async {
      final keys = <String, GlobalKey>{};
      final states = <String, Map<String, Object?>>{};
      Widget frame(bool visible) => MaterialApp(
        home: BookActivityKeyScope(
          keys: keys,
          states: states,
          bookId: 'synthetic-remount',
          child: Scaffold(
            body: visible
                ? BookActivityView(
                    activity: BookActivity.fromJson(experiment()),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpWidget(frame(true));
      await tester.tap(find.text('1회 시행'));
      await tester.tap(find.text('힌트 한 단계'));
      await tester.pump();
      await tester.pumpWidget(frame(false));
      await tester.pumpWidget(frame(true));
      expect(find.text('시행 횟수: 1'), findsOneWidget);
      expect(find.text('Compare the counts'), findsOneWidget);
      await tester.tap(find.text('실험 초기화'));
      await tester.pump();
      await tester.pumpWidget(frame(false));
      await tester.pumpWidget(frame(true));
      expect(find.text('시행 횟수: 0'), findsOneWidget);
      expect(find.text('Compare the counts'), findsNothing);
    },
  );
  testWidgets('mobile keyboard activation runs exactly one local trial', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookActivityView(
              activity: BookActivity.fromJson(experiment()),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('시행 횟수: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('V2 experiment reaches actual private reader rendering', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.setTokenForTest('synthetic-experiment-owner');
    addTearDown(ApiClient.instance.clearTokenForTest);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final book = BookData.fromJson({
      'schema_version': 2,
      'textbook_id': 'synthetic-experiment',
      'title': 'Synthetic experiment',
      'chapters': [
        {
          'title': 'Chapter',
          'pages': [
            {
              'id': 'p',
              'title': 'Experiment',
              'template': 'experiment',
              'blocks': [
                {'type': 'activity', 'activity': experiment()},
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
    await tester.ensureVisible(find.text('1회 시행'));
    await tester.tap(find.text('1회 시행'));
    await tester.pump();
    expect(find.text('시행 횟수: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('힌트 한 단계'));
    await tester.pump();
    expect(find.text('Compare the counts'), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();
    expect(find.text('시행 횟수: 1'), findsOneWidget);
    expect(find.text('Compare the counts'), findsOneWidget);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.text('시행 횟수: 1'), findsOneWidget);
    expect(find.text('Compare the counts'), findsOneWidget);
    final replacement = BookData.fromJson({
      ...book.toJson(),
      'textbook_id': 'different-book',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: replacement,
          persistenceEnabled: false,
          bookLoader: (_) async => replacement,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('시행 횟수: 0'), findsOneWidget);
    expect(find.text('Compare the counts'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('bounded experiment round trip and zero weight exclusion', () {
    final activity = BookActivity.fromJson(experiment());
    final restored = BookActivity.fromJson(activity.toJson());
    expect(restored.toJson(), activity.toJson());
    expect(
      () => BookActivity.fromJson({...experiment(), 'hints': null}),
      throwsFormatException,
    );
    final random = math.Random(1);
    for (var i = 0; i < 100; i++) {
      expect(restored.experiment!.sample(random), 1);
    }
    for (final patch in [
      {'max_trials': true},
      {'max_trials': null},
      {'batch_sizes': null},
      {
        'batch_sizes': [10, 10],
      },
      {'initial_trials': 99},
      {
        'outcomes': [
          {'label': 'A', 'weight': 0, 'success': false},
          {'label': 'B', 'weight': 0, 'success': true},
        ],
      },
    ]) {
      expect(
        () => BookActivity.fromJson({
          ...experiment(),
          'experiment': {
            ...experiment()['experiment'] as Map<String, dynamic>,
            ...patch,
          },
        }),
        throwsFormatException,
      );
    }
  });
  testWidgets('real sampling, bounded batch, reset and lazy scroll state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              BookActivityView(activity: BookActivity.fromJson(experiment())),
              const SizedBox(height: 2000),
              const Text('Bottom'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('상대도수: 시행 전'), findsOneWidget);
    await tester.tap(find.text('10회 시행'));
    await tester.pump();
    expect(find.text('시행 횟수: 10'), findsOneWidget);
    expect(find.text('상대도수: 10/10 = 1.000'), findsOneWidget);
    expect(find.text('never: 0회'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -2400));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 2400));
    await tester.pumpAndSettle();
    expect(find.text('시행 횟수: 10'), findsOneWidget);
    await tester.tap(find.text('10회 시행'));
    await tester.pump();
    expect(find.text('시행 횟수: 15'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '10회 시행'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('실험 초기화'));
    await tester.pump();
    expect(find.text('시행 횟수: 0'), findsOneWidget);
    expect(find.text('상대도수: 시행 전'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
