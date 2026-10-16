import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';
import 'package:s11/sessions/course/session/teacher_course_textbook_reader_page.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/ui/components/textbook_activity_block.dart';

const _additionalReaderValidationPaths = <String>[
  'docs/advanced-generation-vault/07 Data/교재 원고/수학Ⅰ_2015개정_지수로그누락기준_Batch2_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학상_2015개정_초안/수학상_2015개정_포물선과직선의위치관계_보충V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학상_2015개정_초안/수학상_2015개정_이차함수최대최소활용_보충V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학상_2015개정_초안/수학상_2015개정_사차방정식풀이_보충V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학상_2015개정_초안/수학상_2015개정_이차함수와연립이차부등식_보충V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학상_2015개정_초안/수학상_2015개정_내분점외분점_보충V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학상_2015개정_초안/수학상_2015개정_직선yx대칭_보충V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학하_2015개정_초안/수학하_2015개정_집합개념과표현_보충V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학하_2015개정_초안/수학하_2015개정_전칭존재명제_보충V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학상_2015개정_초안/수학상_2015개정_항등식_V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학상_2015개정_초안/수학상_2015개정_절댓값일차부등식_V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학상_2015개정_초안/수학상_2015개정_점과직선사이거리_V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학하_2015개정_초안/수학하_2015개정_집합포함관계_V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학하_2015개정_초안/수학하_2015개정_명제의역과대우_V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학하_2015개정_초안/수학하_2015개정_충분조건필요조건_V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학하_2015개정_초안/수학하_2015개정_대우증명과귀류법_V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학하_2015개정_초안/수학하_2015개정_절대부등식_V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학하_2015개정_초안/수학하_2015개정_함수의합성_V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학하_2015개정_초안/수학하_2015개정_역함수_V2_BookData_초안.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2015개정_통계_배치1/중등수학_2015개정_통계_배치1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2015개정_도형_배치2/중등수학_2015개정_도형_배치2_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2015개정_도형_배치1/중등수학_2015개정_도형_배치1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2015개정_함수그래프_부분초안/중등수학_2015개정_함수그래프_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2022개정_도형과통계_부분초안/중등수학_2022개정_도형과통계_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2022개정_실수와근호_부분초안/중등수학_2022개정_실수와근호_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2022개정_이차방정식과이차함수_부분초안/중등수학_2022개정_이차방정식과이차함수_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2022개정_대수와방정식_부분초안/중등수학_2022개정_대수와방정식_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2022개정_함수와연립방정식_부분초안/중등수학_2022개정_함수와연립방정식_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/공통수학1_2022개정_누락기준3단원_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/공통수학1_2022개정_미연결기준16모듈_Batch2_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/확률과통계_2015개정_조건부확률이항분포_2단원_Batch1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/확률과통계_2022개정_기본확률1단원_Batch4_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/확률과통계_2022개정_확률누락3단원_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/확률과통계_2022개정_확률누락4단원_Batch2_BookData_V2_시범.json',
];

const _draftPaths = <String>[
  ..._additionalReaderValidationPaths,
  'docs/advanced-generation-vault/07 Data/교재 원고/대수_2022개정_미연결기준14모듈_Batch1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/대수_2022개정_EqEdit복구기준_수열_Batch2_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/기하_2015개정_이차곡선공간도형_Batch1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/기하_2022개정_space_BookData_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/기하_2022개정_vector_BookData_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/고등수학_기하_벡터의덧셈과실수배_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/고등수학_기하_벡터의뜻_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/고등수학_기하_위치벡터와좌표_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/미적분Ⅰ_2022개정_누락기준_Batch1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/미적분_2015개정_미연결기준_Batch1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/미적분Ⅱ_2022개정_수열극한급수5단원_Batch1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/미적분Ⅱ_2022개정_미분적분18기준_Batch2_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학Ⅰ_2015개정_누락기준_Batch1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/수학Ⅱ_2015개정_미연결기준_Batch1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/공통수학2_2022개정_추출가능기준14모듈_Batch1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/공통수학2_2022개정_EqEdit복구기준_Batch2_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/대수_2022개정_EqEdit복구기준_수열_Batch2_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/확률과통계_2015개정_미연결기준15모듈_Batch2_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/확률과통계_2022개정_확률통계누락8단원_Batch3_BookData_V2_시범.json',
];

void main() {
  for (final path in _draftPaths) {
    test('$path preserves activity payloads through BookData round-trip', () {
      final source =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final expected = _activities(source);
      final parsed = BookData.fromJson(source);
      final actual = _activities(parsed.toJson());

      expect(expected, isNotEmpty);
      expect(actual, expected);
    });
  }

  testWidgets(
    '2022 square-root HTML behavior maps to native number-line control',
    (tester) async {
      const path =
          'docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2022개정_실수와근호_부분초안/중등수학_2022개정_실수와근호_BookData_V2_시범.json';
      final raw =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final activities = _activities(raw);
      final activity = activities.singleWhere(
        (item) => item['kind'] == 'squareRootNumberLine',
      );
      expect(activity['min'], 1);
      expect(activity['max'], 25);
      await tester.pumpWidget(
        MaterialApp(
          home: BookWidget(
            book: _activityBook(activity),
            initialEntryIndex: 0,
            persistenceEnabled: false,
          ),
        ),
      );
      expect(find.text('n = 1 · √n = 1.000'), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(4);
      await tester.pump();
      expect(find.text('n = 4 · √n = 2.000'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    },
  );

  test(
    '2015 middle-school linear and quadratic function graphs build natively',
    () {
      const path =
          'docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2015개정_함수그래프_부분초안/중등수학_2015개정_함수그래프_BookData_V2_시범.json';
      final raw =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final book = BookData.fromJson(raw);
      final graphs = [
        for (final chapter in book.chapters)
          for (final page in chapter.pages)
            for (final block in page.blocks)
              if (block.graph != null) block.graph!,
      ];
      expect(graphs, hasLength(6));
      expect(
        graphs.map((graph) => graph.items.length).fold(0, (a, b) => a + b),
        8,
      );
      for (final graph in graphs) {
        expect(buildAiFlowGraphHtml(graph), contains('renderCurrentGraph()'));
      }
    },
  );

  for (final path in _additionalReaderValidationPaths) {
    testWidgets('$path quizzes submit and show feedback', (tester) async {
      final source =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final activities = _activities(
        source,
      ).where((item) => item['kind'] == 'quiz').toList();
      expect(activities, isNotEmpty);
      for (final activity in activities) {
        final feedback = activity['correct_feedback'] as String;
        await tester.pumpWidget(
          MaterialApp(
            home: BookWidget(
              book: _activityBook(activity),
              initialEntryIndex: 0,
              persistenceEnabled: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (activity['options'] is List) {
          final options = activity['options'] as List<dynamic>;
          final correctIndex = activity['correct_index'] as int;
          await tester.tap(find.text(options[correctIndex] as String));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('정답 확인'));
          await tester.tap(find.text('정답 확인'));
        } else {
          await tester.enterText(
            find.byType(TextField),
            (activity['answer'] as num).toString(),
          );
          await tester.tap(find.text('답 확인'));
        }
        await tester.pumpAndSettle();
        expect(find.text(feedback), findsOneWidget);
      }
    });
  }

  testWidgets(
    '2015 logarithm HTML controls map to native base, exponent, steps, hint, and reset',
    (tester) async {
      const path =
          'docs/advanced-generation-vault/07 Data/교재 원고/수학Ⅰ_2015개정_지수로그누락기준_Batch2_BookData_V2_시범.json';
      final source =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final explorerData = _activities(
        source,
      ).singleWhere((item) => item['kind'] == 'logarithmPowerExplorer');
      final activity = BookActivity.fromJson(explorerData);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookActivityView(activity: activity),
            ),
          ),
        ),
      );

      expect(find.text('현재 관계  2.0^2 = 4'), findsOneWidget);
      expect(find.text('log_2.0(4) = 2'), findsOneWidget);
      final exponent = tester.widget<Slider>(
        find.byKey(const ValueKey('log-power-explorer-exponent')),
      );
      exponent.onChanged!(-1);
      await tester.pump();
      expect(find.text('현재 관계  2.0^-1 = 0.5'), findsOneWidget);
      expect(find.text('log_2.0(0.5) = -1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('log-power-explorer-next')));
      await tester.tap(find.byKey(const ValueKey('log-power-explorer-next')));
      await tester.tap(find.byKey(const ValueKey('log-power-explorer-next')));
      await tester.pump();
      expect(find.text('3단계 · 거꾸로 읽으면 log_2.0(0.5)=-1입니다.'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('log-power-explorer-hint-toggle')),
      );
      await tester.pump();
      expect(find.textContaining('1^x는 x가 무엇이든 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('log-power-explorer-reset')));
      await tester.pump();
      expect(find.text('현재 관계  2.0^2 = 4'), findsOneWidget);
      expect(find.text('시작: 밑과 지수를 정하고 결과를 먼저 예측하세요.'), findsOneWidget);
    },
  );

  testWidgets('quiz supports selection, feedback, hints, and retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TextbookActivityBlock(
              activity: {
                'id': 'quiz-round-trip',
                'kind': 'quiz',
                'prompt': '2 + 3은?',
                'options': ['4', '5'],
                'correct_index': 1,
                'correct_feedback': '정답입니다.',
                'incorrect_feedback': '다시 계산해 보세요.',
                'hints': ['2와 3을 더합니다.'],
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('2 + 3은?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-option-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다.'), findsOneWidget);

    await tester.tap(find.text('다시 풀기'));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다.'), findsNothing);

    await tester.tap(find.text('힌트 보기'));
    await tester.pumpAndSettle();
    expect(find.text('1. 2와 3을 더합니다.'), findsOneWidget);
  });

  testWidgets('unknown activity remains visible as an explicit fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextbookActivityBlock(
            activity: {
              'kind': 'interactive_graph',
              'prompt': '원래 prompt는 표시되어야 합니다.',
            },
          ),
        ),
      ),
    );

    expect(find.text('지원하지 않는 활동: interactive_graph'), findsOneWidget);
    expect(find.text('원래 prompt는 표시되어야 합니다.'), findsOneWidget);
  });

  test('vector inner product V2 draft imports and round-trips', () {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/고등수학_기하_평면벡터내적_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(source);
    final activity = _activities(source).single;
    expect(activity['kind'], 'vectorInnerProduct');
    expect(_activities(book.toJson()), [activity]);
  });

  testWidgets('vector operations V2 candidate runs in the student reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/고등수학_기하_벡터의덧셈과실수배_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(source);
    final activities = _activities(source);
    expect(activities.map((activity) => activity['kind']), [
      'vectorOperation',
      'quiz',
      'quiz',
      'quiz',
    ]);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: book,
          initialEntryIndex: 1,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (
      var attempt = 0;
      attempt < 5 && find.textContaining('u+v=(4, 3)').evaluate().isEmpty;
      attempt++
    ) {
      await tester.tap(find.byTooltip('다음 페이지'));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('u+v=(4, 3)'), findsOneWidget);
    final operationPicker = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(operationPicker);
    await tester.tap(operationPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('뺄셈 u − v').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('u−v=(2, -1)'), findsOneWidget);

    await tester.ensureVisible(operationPicker);
    await tester.tap(operationPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('실수배 αu').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('αu=(6, 2)'), findsOneWidget);
    final alphaSlider = find.byType(Slider).first;
    await tester.ensureVisible(alphaSlider);
    await tester.drag(
      alphaSlider,
      Offset(-tester.getSize(alphaSlider).width * 0.75, 0),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('αu=('), findsOneWidget);
    expect(find.textContaining('계수가 음수'), findsOneWidget);
  });

  testWidgets('2015 Geometry V2 02-05 quiz runs in the student BookWidget', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/기하_2015개정_이차곡선공간도형_Batch1_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final module = (source['chapters'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((chapter) => chapter['title_code'] == '02-05');
    final examplePage = (module['pages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((page) => page['id'] == 'geo15-0205-example');
    final solution =
        (examplePage['blocks'] as List)
                .cast<Map<String, dynamic>>()
                .singleWhere((block) => block['type'] == 'solutionStep')['text']
            as String;
    expect(solution, contains('(x,y)=(0,1)+t(3,2)'));
    expect(solution, contains('(x−2)²+(y+1)²=9'));
    expect(solution, isNot(contains('(1,2)+t(2,−1)')));
    final activity = _activities(
      source,
    ).singleWhere((activity) => activity['id'] == 'geo15-0205-quiz');
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(activity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('점 (0,1)을 지나고 방향벡터 (3,2)'), findsOneWidget);
    await tester.tap(find.text('(x,y)=(0,1)+t(3,2)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다: (x,y)=(0,1)+t(3,2)'), findsOneWidget);
  });

  testWidgets('Calculus I 2022 V2 quiz imports and runs in the student reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/미적분Ⅰ_2022개정_누락기준_Batch1_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final activities = _activities(source);
    expect(activities, hasLength(13));
    final activity = activities.singleWhere(
      (activity) => activity['id'] == 'c1-0101-quiz',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(activity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('x가 2에 가까워질 때'), findsOneWidget);
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('맞아요. 3×2−1=5'), findsOneWidget);
  });

  testWidgets('2015 Calculus V2 quiz imports and runs in the student reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/미적분_2015개정_미연결기준_Batch1_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final activities = _activities(source);
    expect(activities, hasLength(27));
    final activity = activities.singleWhere(
      (activity) => activity['id'] == 'calc15-0101-quiz',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(activity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('aₙ=3/n'), findsOneWidget);
    await tester.tap(find.text('0'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다: 0'), findsOneWidget);
  });

  testWidgets('2015 Probability Batch2 quiz runs in the student reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/확률과통계_2015개정_미연결기준15모듈_Batch2_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final activities = _activities(source);
    expect(activities, hasLength(15));
    final activity = activities.singleWhere(
      (activity) => activity['id'] == 'prob150101-quiz',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(activity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('원순열의 수는?'), findsOneWidget);
    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('회전한 배치를 같게 보므로'), findsOneWidget);
  });

  test('2015 probability addition-rule quiz matches its event definition', () {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/확률과통계_2015개정_미연결기준15모듈_Batch2_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final activity = _activities(
      source,
    ).singleWhere((activity) => activity['id'] == 'prob150203-quiz');
    expect(activity['prompt'], contains('B=4보다 큰'));
    expect(
      (activity['options'] as List<dynamic>)[activity['correct_index'] as int],
      '2/3',
    );
  });

  testWidgets('2022 Probability estimators run in the student reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/확률과통계_2022개정_확률통계누락8단원_Batch3_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final activities = _activities(source);
    expect(activities, hasLength(10));
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final meanActivity = activities.singleWhere(
      (activity) => activity['id'] == 'ps0307-estimate-mean',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(meanActivity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('추정하기'));
    await tester.pumpAndSettle();
    expect(find.text('모평균의 추정값: 10.0000'), findsOneWidget);

    final proportionActivity = activities.singleWhere(
      (activity) => activity['id'] == 'ps0307-estimate-proportion',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(proportionActivity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('추정하기'));
    await tester.pumpAndSettle();
    expect(find.text('모비율의 추정값: 56.00%'), findsOneWidget);
  });

  testWidgets(
    'Calculus II 2022 Batch2 quiz imports and runs in the student reader',
    (tester) async {
      const path =
          'docs/advanced-generation-vault/07 Data/교재 원고/미적분Ⅱ_2022개정_미분적분18기준_Batch2_BookData_V2_시범.json';
      final source =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final activities = _activities(source);
      expect(activities, hasLength(18));
      final activity = activities.singleWhere(
        (activity) => activity['id'] == 'calc20201-quiz',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BookWidget(
            book: _activityBook(activity),
            initialEntryIndex: 0,
            persistenceEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('(5ˣ)\'는?'), findsOneWidget);
      await tester.tap(find.text('5ˣ ln 5'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('정답 확인'));
      await tester.tap(find.text('정답 확인'));
      await tester.pumpAndSettle();
      expect(find.textContaining('밑 a의 지수함수 미분은 aˣ ln a'), findsOneWidget);
    },
  );

  test('2015 Calculus V2 worked examples match their practice prompts', () {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/미적분_2015개정_미연결기준_Batch1_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final chapters = source['chapters'] as List<dynamic>;
    expect(chapters, hasLength(27));
    for (final rawChapter in chapters) {
      final chapter = rawChapter as Map<String, dynamic>;
      final pages = chapter['pages'] as List<dynamic>;
      final examplePage =
          pages.singleWhere(
                (page) =>
                    (page as Map<String, dynamic>)['template'] == 'example',
              )
              as Map<String, dynamic>;
      final practicePage =
          pages.singleWhere(
                (page) =>
                    (page as Map<String, dynamic>)['template'] == 'practice',
              )
              as Map<String, dynamic>;
      final exampleBlocks = examplePage['blocks'] as List<dynamic>;
      final practiceBlocks = practicePage['blocks'] as List<dynamic>;
      final exampleQuestion =
          exampleBlocks.singleWhere(
                (block) =>
                    (block as Map<String, dynamic>)['type'] == 'question',
              )
              as Map<String, dynamic>;
      final practiceQuestion =
          practiceBlocks.singleWhere(
                (block) =>
                    (block as Map<String, dynamic>)['type'] == 'question',
              )
              as Map<String, dynamic>;
      expect(exampleQuestion['text'], practiceQuestion['text']);
      final activity = _activities({
        'chapters': [
          {
            'pages': [practicePage],
          },
        ],
      }).single;
      expect(activity['prompt'], practiceQuestion['text']);
      expect(
        (activity['options'] as List<dynamic>)[activity['correct_index']
            as int],
        (practiceBlocks.singleWhere(
              (block) => (block as Map<String, dynamic>)['type'] == 'answer',
            )
            as Map<String, dynamic>)['text'],
      );
    }
  });

  testWidgets('2015 Math I V2 examples and quiz load in the student reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/수학Ⅰ_2015개정_누락기준_Batch1_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(source);
    final chapters = source['chapters'] as List<dynamic>;
    expect(chapters, hasLength(10));
    for (final rawChapter in chapters) {
      final chapter = rawChapter as Map<String, dynamic>;
      final pages = chapter['pages'] as List<dynamic>;
      final examplePage =
          pages.singleWhere(
                (page) =>
                    (page as Map<String, dynamic>)['template'] == 'example',
              )
              as Map<String, dynamic>;
      final blocks = examplePage['blocks'] as List<dynamic>;
      expect(
        (blocks.singleWhere(
              (block) => (block as Map<String, dynamic>)['type'] == 'question',
            )
            as Map<String, dynamic>)['text'],
        isNotEmpty,
      );
      expect(
        (blocks.singleWhere(
              (block) =>
                  (block as Map<String, dynamic>)['type'] == 'solutionStep',
            )
            as Map<String, dynamic>)['text'],
        isNotEmpty,
      );
    }
    final activity = _activities(
      source,
    ).singleWhere((activity) => activity['id'] == 'm10101-quiz');
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(activity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('√144와 ⁵√32'), findsOneWidget);
    await tester.tap(find.text('12와 2'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('제곱근의 주값은 음이 아닌 수'), findsOneWidget);
    expect(BookData.fromJson(source).chapters, isNotEmpty);
    expect(book.chapters, hasLength(10));
  });

  testWidgets('2015 Math II V2 examples and quiz load in the student reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/수학Ⅱ_2015개정_미연결기준_Batch1_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(source);
    final chapters = source['chapters'] as List<dynamic>;
    expect(chapters, hasLength(18));
    for (final rawChapter in chapters) {
      final chapter = rawChapter as Map<String, dynamic>;
      final pages = chapter['pages'] as List<dynamic>;
      final examplePage =
          pages.singleWhere(
                (page) =>
                    (page as Map<String, dynamic>)['template'] == 'example',
              )
              as Map<String, dynamic>;
      final blocks = examplePage['blocks'] as List<dynamic>;
      final question =
          blocks.singleWhere(
                (block) =>
                    (block as Map<String, dynamic>)['type'] == 'question',
              )
              as Map<String, dynamic>;
      final solution =
          blocks.singleWhere(
                (block) =>
                    (block as Map<String, dynamic>)['type'] == 'solutionStep',
              )
              as Map<String, dynamic>;
      expect(question['text'], isNotEmpty);
      expect(solution['text'], isNotEmpty);
    }
    final activity = _activities(
      source,
    ).singleWhere((activity) => activity['id'] == 'm2-0104-quiz');
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(activity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('영점이 구간 안에 있나요?'), findsOneWidget);
    await tester.tap(find.text('있다'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다. 있다'), findsOneWidget);
    expect(book.chapters, hasLength(18));
  });

  testWidgets('Common Math 2 V2 examples and quiz load in the student reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/공통수학2_2022개정_추출가능기준14모듈_Batch1_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(source);
    final chapters = source['chapters'] as List<dynamic>;
    expect(chapters, hasLength(14));
    for (final rawChapter in chapters) {
      final chapter = rawChapter as Map<String, dynamic>;
      final pages = chapter['pages'] as List<dynamic>;
      final examplePage =
          pages.singleWhere(
                (page) =>
                    (page as Map<String, dynamic>)['template'] == 'example',
              )
              as Map<String, dynamic>;
      final practicePage =
          pages.singleWhere(
                (page) =>
                    (page as Map<String, dynamic>)['template'] == 'practice',
              )
              as Map<String, dynamic>;
      final exampleBlocks = examplePage['blocks'] as List<dynamic>;
      final practiceBlocks = practicePage['blocks'] as List<dynamic>;
      final exampleQuestion =
          (exampleBlocks.singleWhere(
                (block) =>
                    (block as Map<String, dynamic>)['type'] == 'question',
              )
              as Map<String, dynamic>)['text'];
      final practiceQuestion =
          (practiceBlocks.singleWhere(
                (block) =>
                    (block as Map<String, dynamic>)['type'] == 'question',
              )
              as Map<String, dynamic>)['text'];
      expect(exampleQuestion, isNotEmpty);
      expect(practiceQuestion, isNotEmpty);
      expect(exampleQuestion, isNot(practiceQuestion));
    }
    final activity = _activities(
      source,
    ).singleWhere((activity) => activity['id'] == 'cm20101-quiz');
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(activity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('A(−2), B(10)'), findsOneWidget);
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('내분점은 A에서 전체 길이의 1/(1+3)'), findsOneWidget);
    expect(book.chapters, hasLength(14));
  });

  testWidgets('Common Math 2 EqEdit Batch2 examples and quizzes run', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/공통수학2_2022개정_EqEdit복구기준_Batch2_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final chapters = source['chapters'] as List<dynamic>;
    expect(chapters, hasLength(3));
    for (final rawChapter in chapters) {
      final chapter = rawChapter as Map<String, dynamic>;
      final pages = chapter['pages'] as List<dynamic>;
      final examplePage =
          pages.singleWhere(
                (page) =>
                    (page as Map<String, dynamic>)['template'] == 'example',
              )
              as Map<String, dynamic>;
      final practicePage =
          pages.singleWhere(
                (page) =>
                    (page as Map<String, dynamic>)['template'] == 'practice',
              )
              as Map<String, dynamic>;
      final exampleQuestion =
          ((examplePage['blocks'] as List<dynamic>).singleWhere(
                (block) =>
                    (block as Map<String, dynamic>)['type'] == 'question',
              )
              as Map<String, dynamic>)['text'];
      final practiceQuestion =
          ((practicePage['blocks'] as List<dynamic>).singleWhere(
                (block) =>
                    (block as Map<String, dynamic>)['type'] == 'question',
              )
              as Map<String, dynamic>)['text'];
      expect(exampleQuestion, isNotEmpty);
      expect(practiceQuestion, isNotEmpty);
      expect(exampleQuestion, isNot(practiceQuestion));
    }

    final activities = _activities(source);
    expect(activities, hasLength(3));
    for (final activity in activities) {
      final options = activity['options'] as List<dynamic>;
      final correctIndex = activity['correct_index'] as int;
      final correctAnswer = options[correctIndex] as String;
      await tester.pumpWidget(
        MaterialApp(
          home: BookWidget(
            book: _activityBook(activity),
            initialEntryIndex: 0,
            persistenceEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(correctAnswer));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('정답 확인'));
      await tester.tap(find.text('정답 확인'));
      await tester.pumpAndSettle();
      expect(find.text('정답입니다. 좌표 변환과 정의역 조건을 확인했습니다.'), findsOneWidget);
    }
  });

  testWidgets('Algebra EqEdit Batch2 examples and quizzes run', (tester) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/대수_2022개정_EqEdit복구기준_수열_Batch2_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final chapters = source['chapters'] as List<dynamic>;
    expect(chapters, hasLength(3));
    for (final rawChapter in chapters) {
      final chapter = rawChapter as Map<String, dynamic>;
      final pages = chapter['pages'] as List<dynamic>;
      final examplePage =
          pages.singleWhere(
                (page) =>
                    (page as Map<String, dynamic>)['template'] == 'example',
              )
              as Map<String, dynamic>;
      final practicePage =
          pages.singleWhere(
                (page) =>
                    (page as Map<String, dynamic>)['template'] == 'practice',
              )
              as Map<String, dynamic>;
      final exampleQuestion =
          ((examplePage['blocks'] as List<dynamic>).singleWhere(
                (block) =>
                    (block as Map<String, dynamic>)['type'] == 'question',
              )
              as Map<String, dynamic>)['text'];
      final practiceQuestion =
          ((practicePage['blocks'] as List<dynamic>).singleWhere(
                (block) =>
                    (block as Map<String, dynamic>)['type'] == 'question',
              )
              as Map<String, dynamic>)['text'];
      expect(exampleQuestion, isNotEmpty);
      expect(practiceQuestion, isNotEmpty);
      expect(exampleQuestion, isNot(practiceQuestion));
    }

    final activities = _activities(source);
    expect(activities, hasLength(3));
    for (final activity in activities) {
      final options = activity['options'] as List<dynamic>;
      final correctIndex = activity['correct_index'] as int;
      final correctAnswer = options[correctIndex] as String;
      await tester.pumpWidget(
        MaterialApp(
          home: BookWidget(
            book: _activityBook(activity),
            initialEntryIndex: 0,
            persistenceEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(correctAnswer));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('정답 확인'));
      await tester.tap(find.text('정답 확인'));
      await tester.pumpAndSettle();
      expect(find.text('정답입니다. 수열의 항이나 합을 확인했습니다.'), findsOneWidget);
    }
  });

  testWidgets('Algebra Batch1 examples and all quizzes run', (tester) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/대수_2022개정_미연결기준14모듈_Batch1_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final chapters = source['chapters'] as List<dynamic>;
    expect(chapters, hasLength(14));
    for (final rawChapter in chapters) {
      final chapter = rawChapter as Map<String, dynamic>;
      final pages = chapter['pages'] as List<dynamic>;
      final examplePage =
          pages.singleWhere(
                (page) =>
                    (page as Map<String, dynamic>)['template'] == 'example',
              )
              as Map<String, dynamic>;
      final practicePage =
          pages.singleWhere(
                (page) =>
                    (page as Map<String, dynamic>)['template'] == 'practice',
              )
              as Map<String, dynamic>;
      final exampleQuestion =
          ((examplePage['blocks'] as List<dynamic>).singleWhere(
                (block) =>
                    (block as Map<String, dynamic>)['type'] == 'question',
              )
              as Map<String, dynamic>)['text'];
      final practiceQuestion =
          ((practicePage['blocks'] as List<dynamic>).singleWhere(
                (block) =>
                    (block as Map<String, dynamic>)['type'] == 'question',
              )
              as Map<String, dynamic>)['text'];
      expect(exampleQuestion, isNotEmpty);
      expect(practiceQuestion, isNotEmpty);
      expect(exampleQuestion, isNot(practiceQuestion));
    }

    final activities = _activities(source);
    expect(activities, hasLength(14));
    for (final activity in activities) {
      final options = activity['options'] as List<dynamic>;
      final correctIndex = activity['correct_index'] as int;
      final correctAnswer = options[correctIndex] as String;
      final feedback = activity['correct_feedback'] as String;
      await tester.pumpWidget(
        MaterialApp(
          home: BookWidget(
            book: _activityBook(activity),
            initialEntryIndex: 0,
            persistenceEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(correctAnswer));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('정답 확인'));
      await tester.tap(find.text('정답 확인'));
      await tester.pumpAndSettle();
      expect(find.text(feedback), findsOneWidget);
    }
  });

  testWidgets('vector meaning V2 practice runs in the student reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/고등수학_기하_벡터의뜻_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(source);
    expect(source['standard_codes'], contains('12기하02-01'));
    final activity = _activities(source).single;
    expect(activity['kind'], 'quiz');
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(activity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('크기가 같고 방향이 반대인 두 벡터'), findsOneWidget);
    await tester.tap(find.text('서로 반대벡터이며 같은 벡터는 아니다'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.text('맞아요. 크기는 같지만 방향이 반대이므로 반대벡터입니다.'), findsOneWidget);
  });

  testWidgets('position vector V2 quiz runs in the student reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/고등수학_기하_위치벡터와좌표_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final activity = _activities(source).single;
    expect(source['standard_codes'], contains('12기하02-03'));
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(activity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('A=(-2,1), B=(2,4)'), findsOneWidget);
    await tester.tap(find.text('(4,3)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.text('맞아요. (2−(-2), 4−1)=(4,3)입니다.'), findsOneWidget);
  });

  testWidgets('vector operations V2 Socratic quiz runs in the student reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/고등수학_기하_벡터의덧셈과실수배_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final activity = _activities(source)[1];
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(activity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('u−v를 만들 때'), findsOneWidget);
    await tester.ensureVisible(find.text('u+(−v)'));
    await tester.tap(find.text('u+(−v)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.text('맞아요. v를 −v로 바꾸어 u에 더합니다.'), findsOneWidget);
  });

  testWidgets('vector inner product runs in the student BookWidget', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/고등수학_기하_평면벡터내적_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final activity = _activities(source).single;
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _activityBook(activity),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('내적 u·v = 6.00'), findsOneWidget);
    expect(find.text('현재 θ=60°에서 u·v의 부호는?'), findsOneWidget);
    await tester.ensureVisible(find.text('양수'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('양수'));
    await tester.pumpAndSettle();
    expect(find.textContaining('맞아요.'), findsOneWidget);
    await tester.tap(find.text('다음 단계'));
    await tester.pumpAndSettle();
    expect(find.textContaining('부호 있는 길이는'), findsOneWidget);
    await tester.tap(find.text('힌트 한 단계'));
    await tester.pumpAndSettle();
    expect(find.text('θ가 90°보다 작으면 cosθ는 양수입니다.'), findsOneWidget);
  });

  testWidgets('student BookWidget displays and runs page-based quiz blocks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookWidget(
          book: _quizBook(),
          initialEntryIndex: 0,
          persistenceEnabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 + 3은?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-option-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다.'), findsOneWidget);
  });

  testWidgets('teacher course reader displays and runs page-based quizzes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      MaterialApp(
        home: TeacherCourseTextbookReaderPage(
          courseId: 'compatibility-course',
          moduleId: 'compatibility-module',
          textbookId: 'compatibility-book',
          pageFrom: 1,
          pageTo: 1,
          minMinutes: 0,
          previewBook: _quizBook(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 + 3은?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-option-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다.'), findsOneWidget);
  });

  testWidgets('2022 Geometry V2 activity runs in the teacher reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/기하_2022개정_space_BookData_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(source);
    final activity = _activities(source).first;
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      MaterialApp(
        home: TeacherCourseTextbookReaderPage(
          courseId: 'geometry-course',
          moduleId: 'geometry-module',
          textbookId: 'geometry-book',
          pageFrom: 4,
          pageTo: 4,
          minMinutes: 0,
          previewBook: book,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(activity['prompt'] as String), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('quiz-option-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quiz-option-0')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.text(activity['correct_feedback'] as String), findsOneWidget);
  });

  testWidgets('Algebra EqEdit Batch2 quiz runs in the teacher reader', (
    tester,
  ) async {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/대수_2022개정_EqEdit복구기준_수열_Batch2_BookData_V2_시범.json';
    final source =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(source);
    final activity = _activities(source).first;
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      MaterialApp(
        home: TeacherCourseTextbookReaderPage(
          courseId: 'algebra-course',
          moduleId: 'algebra-module',
          textbookId: 'algebra-book',
          pageFrom: 4,
          pageTo: 4,
          minMinutes: 0,
          previewBook: book,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(activity['prompt'] as String), findsOneWidget);
    final correctIndex = activity['correct_index'] as int;
    await tester.ensureVisible(
      find.byKey(ValueKey('quiz-option-$correctIndex')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('quiz-option-$correctIndex')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정답 확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정답 확인'));
    await tester.pumpAndSettle();
    expect(find.text(activity['correct_feedback'] as String), findsOneWidget);
  });
}

BookData _activityBook(Map<String, dynamic> activity) => BookData(
  id: 'activity-book',
  title: 'Activity 호환성 교재',
  subtitle: '',
  chapters: [
    BookChapter(
      title: '벡터 단원',
      intro: const [],
      sections: const [],
      pages: [
        BookPage(
          id: 'vector-page',
          template: BookPageTemplate.practice,
          title: '내적 체험',
          blocks: [
            BookContentBlock(
              type: BookContentBlockType.activity,
              activity: activity,
            ),
          ],
        ),
      ],
    ),
  ],
);

BookData _quizBook() => BookData(
  id: 'quiz-book',
  title: 'Activity 호환성 교재',
  subtitle: '',
  chapters: [
    BookChapter(
      title: '퀴즈 단원',
      intro: const [],
      sections: const [],
      pages: [
        BookPage(
          id: 'quiz-page',
          template: BookPageTemplate.practice,
          title: '퀴즈 연습',
          blocks: [
            BookContentBlock(
              type: BookContentBlockType.activity,
              activity: {
                'id': 'quiz-reader-integration',
                'kind': 'quiz',
                'prompt': '2 + 3은?',
                'options': ['4', '5'],
                'correct_index': 1,
                'correct_feedback': '정답입니다.',
                'incorrect_feedback': '다시 계산해 보세요.',
                'hints': ['2와 3을 더합니다.'],
              },
            ),
          ],
        ),
      ],
    ),
  ],
);

List<Map<String, dynamic>> _activities(Map<String, dynamic> book) =>
    (book['chapters'] as List)
        .whereType<Map>()
        .expand((chapter) => (chapter['pages'] as List? ?? const []))
        .whereType<Map>()
        .expand((page) => (page['blocks'] as List? ?? const []))
        .whereType<Map>()
        .where((block) => block['type'] == 'activity')
        .map((block) => Map<String, dynamic>.from(block['activity'] as Map))
        .toList(growable: false);
