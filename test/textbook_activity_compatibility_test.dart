import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/sessions/course/session/teacher_course_textbook_reader_page.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/ui/components/textbook_activity_block.dart';

const _draftPaths = <String>[
  'docs/advanced-generation-vault/07 Data/교재 원고/대수_2022개정_미연결기준14모듈_Batch1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/대수_2022개정_EqEdit복구기준_수열_Batch2_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/기하_2015개정_이차곡선공간도형_Batch1_BookData_V2_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/기하_2022개정_space_BookData_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/기하_2022개정_vector_BookData_시범.json',
  'docs/advanced-generation-vault/07 Data/교재 원고/고등수학_기하_벡터의덧셈과실수배_BookData_V2_시범.json',
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
