import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';

BookData syntheticBook() => BookData.fromJson({
  'textbook_id': 'private-import-synthetic',
  'title': 'Synthetic prototype',
  'category': 'concept_textbook_prototype',
  'curriculum_version': '2022',
  'standard_codes': ['12기하01-01'],
  'source_sha256': 'a' * 64,
  'chapters': [
    {
      'title': 'Chapter',
      'sections': [
        {
          'title': 'Supplement unique',
          'paragraphs': ['Section prose survives'],
        },
      ],
      'pages': [
        {
          'id': 'experiment',
          'template': 'experiment',
          'title': 'Graph page',
          'blocks': [
            {
              'type': 'graph',
              'title': 'Plot title survives',
              'text': 'Graph explanation survives',
              'graph': {
                'items': [
                  {
                    'id': 'curve',
                    'type': 'function',
                    'expression': 'x*x/(4*p)',
                  },
                ],
                'settings': {
                  'parameters': [
                    {'id': 'p', 'value': 2, 'min': .5, 'max': 3, 'step': .5},
                  ],
                },
              },
            },
          ],
        },
      ],
    },
  ],
});

void main() {
  test('source metadata and slider document survive serialization', () {
    final book = syntheticBook();
    final roundTrip = BookData.fromJson(book.toJson());
    expect(roundTrip.curriculumVersion, '2022');
    expect(roundTrip.standardCodes, ['12기하01-01']);
    expect(roundTrip.sourceSha256, 'a' * 64);
    expect(roundTrip.toLibraryJson()['source_sha256'], 'a' * 64);
    expect(
      roundTrip
          .chapters
          .single
          .pages
          .single
          .blocks
          .single
          .graph!
          .settings
          .parameters
          .single
          .value,
      2,
    );
    expect(
      roundTrip.chapters.single.sections.single.paragraphs.single,
      'Section prose survives',
    );
  });

  for (final index in [0, 1]) {
    testWidgets(
      'reader preserves graph explanation / supplementary prose $index',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        ApiClient.instance.setTokenForTest('synthetic-import-owner');
        addTearDown(ApiClient.instance.clearTokenForTest);
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final book = syntheticBook();
        await tester.pumpWidget(
          MaterialApp(
            home: BookWidget(
              book: book,
              initialEntryIndex: index,
              persistenceEnabled: false,
              bookLoader: (_) async => book,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            index == 0
                ? 'Graph explanation survives'
                : 'Section prose survives',
            findRichText: true,
          ),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('이 페이지 질문하기'));
        await tester.pumpAndSettle();
        final chat = tester.widget<ServerChatPage>(find.byType(ServerChatPage));
        expect(chat.initialMode, 'socratic');
        expect(chat.ephemeral, isTrue);
        expect(chat.initialContext!['quest_title'], contains(book.title));
        final attached = chat.initialContext!['answer_riddle'] as String;
        expect(
          attached,
          contains(
            index == 0
                ? 'Graph explanation survives'
                : 'Section prose survives',
          ),
        );
        expect(
          attached,
          isNot(
            contains(
              index == 0
                  ? 'Section prose survives'
                  : 'Graph explanation survives',
            ),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
