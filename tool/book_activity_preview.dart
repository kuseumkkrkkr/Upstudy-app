// Local native-widget QA only. Never used by lib/main.dart or copied to public.
import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();
  static final activities = [
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
