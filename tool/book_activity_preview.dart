// Local native-widget QA only. Never used by lib/main.dart or copied to public.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Synthetic local session only; this entrypoint is never the deployed app.
  if (Uri.base.queryParameters['reader'] == '1') {
    // QA-only synthetic identity; no valid server credential or persistence.
    // ignore: invalid_use_of_visible_for_testing_member
    ApiClient.instance.setTokenForTest('synthetic-local-reader-only');
    const source = String.fromEnvironment('BOOK_QA_JSON');
    final book = BookData.fromJson(
      source.isNotEmpty
          ? jsonDecode(source) as Map<String, dynamic>
          : {
              'schema_version': 2,
              'textbook_id': 'synthetic-local-experiment',
              'title': '합성 확률 체험 · 저장하지 않는 로컬 QA',
              'chapters': [
                {
                  'title': '확률 실험',
                  'pages': [
                    {
                      'id': 'synthetic-page',
                      'title': '합성 주사위 실험',
                      'template': 'experiment',
                      'blocks': [
                        {
                          'type': 'activity',
                          'activity': _Preview.activities.first,
                        },
                      ],
                    },
                  ],
                },
              ],
            },
    );
    final pages = book.chapters.expand((chapter) => chapter.pages).toList();
    final experimentPage = pages.indexWhere(
      (page) => page.blocks.any(
        (block) => block.activity?.kind == 'discreteExperiment',
      ),
    );
    runApp(
      MaterialApp(
        home: BookWidget(
          book: book,
          initialEntryIndex: experimentPage < 0 ? 0 : experimentPage,
          persistenceEnabled: false,
          bookLoader: (_) async => book,
        ),
      ),
    );
    return;
  }
  runApp(const _Preview());
}

class _Preview extends StatelessWidget {
  const _Preview();
  static final activities = [
    {
      'id': 'qa-dice',
      'kind': 'discreteExperiment',
      'prompt': '확률 체험 QA · 주사위와 짝수 사건',
      'hints': ['짝수 횟수를 전체 시행 횟수로 나눠 보세요.'],
      'experiment': {
        'outcomes': [
          for (var face = 1; face <= 6; face++)
            {
              'label': '$face (${face.isEven ? '짝수' : '홀수'})',
              'weight': 1,
              'success': face.isEven,
            },
        ],
        'max_trials': 50,
        'batch_sizes': [1, 10],
      },
    },
    {
      'id': 'qa-geometry',
      'kind': 'parabolaDistance',
      'prompt': '체험 QA · 두 거리 비교',
      'p': 2,
      'x': 4,
      'hints': ['P를 왼쪽으로 움직이면 PF와 준선까지의 거리는 어떻게 바뀔까요?'],
    },
    {
      'id': 'qa-choice',
      'kind': 'quiz',
      'prompt': '연습 QA · p=2, x=4일 때 y는?',
      'options': ['1', '2', '4'],
      'correct_index': 1,
      'correct_feedback': '맞아요. y=16/8=2입니다.',
      'incorrect_feedback': 'x²/(4p)를 계산해 볼까요?',
      'hints': ['4p를 먼저 계산하세요.'],
    },
    {
      'id': 'qa-numeric',
      'kind': 'quiz',
      'prompt': '입력 QA · 1을 2로 나눈 값은?',
      'answer': .5,
      'tolerance': 0,
      'correct_feedback': '맞아요. 0.5와 1/2 모두 가능합니다.',
      'incorrect_feedback': '분수로도 입력할 수 있어요.',
    },
    {
      'id': 'qa-steps',
      'kind': 'steps',
      'prompt': '단계 QA · 거리에서 식으로',
      'steps': [
        'PF와 준선까지의 거리를 비교하세요.',
        '두 거리는 음수가 아닙니다.',
        '따라서 두 거리를 제곱하여 비교할 수 있습니다.',
      ],
    },
  ];
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(colorSchemeSeed: Colors.black, useMaterial3: true),
    home: Scaffold(
      appBar: AppBar(title: const Text('V2 체험 위젯 · 로컬 QA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('합성 QA 데이터 · 실제 학생 답안이나 원고가 아닙니다.'),
          for (final data in activities)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: BookActivityView(activity: BookActivity.fromJson(data)),
            ),
        ],
      ),
    ),
  );
}
