import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/features/arena/arena_page.dart';

/// 필요한 변수: 서버 종료 결과 샘플.
/// 작동 원리는 네트워크 없이 봇 승리 보상과 문항 분석이 같은 결과 화면에 렌더링되는지 검증하는 것이다.
void main() {
  testWidgets('봇 경기 종료 즉시 레이팅 보상과 문항 분석을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArenaResultPage(
          matchId: 'result-match',
          initialResult: {
            'practice': true,
            'viewer_user_id': 'student',
            'viewer_team': 0,
            'finish_reason': 'decisive_lead',
            'scores': {
              '0': {'correct': 7, 'attempted': 8, 'remaining': 2},
              '1': {'correct': 4, 'attempted': 9, 'remaining': 1},
            },
            'participants': [
              {
                'user_id': 'student',
                'team': 0,
                'record': 'win',
                'rating_before': 1500,
                'rating_after': 1520,
                'rating_delta': 20,
                'is_bot': false,
              },
              {
                'user_id': 'bot-result',
                'team': 1,
                'record': 'loss',
                'rating_before': 1500,
                'rating_after': 1500,
                'rating_delta': 0,
                'is_bot': true,
              },
            ],
            'analysis': [
              {
                'position': 1,
                'prompt': r'\(1+1\)의 값은?',
                'correct_answer_label': '2',
                'team_answers': {
                  '0': {'answer_label': '2', 'correct': true},
                },
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('승리'), findsOneWidget);
    expect(find.text('+20 레이팅'), findsOneWidget);
    expect(find.text('남은 문항으로 역전할 수 없어 조기 종료됐습니다.'), findsOneWidget);
    expect(find.text('문항별 결과 분석'), findsOneWidget);
    expect(find.text('정답'), findsOneWidget);
    expect(find.text('대결장으로 돌아가기'), findsOneWidget);
  });
}
