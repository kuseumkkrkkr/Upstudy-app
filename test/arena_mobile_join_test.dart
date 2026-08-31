import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/features/arena/arena_page.dart';

void main() {
  testWidgets('모바일 대결은 확인 시트를 거친 뒤에만 매칭 요청을 보낸다', (tester) async {
    // 필요한 변수는 참가 가능한 1v1 큐와 요청 횟수를 기록하는 모의 참가 함수다.
    // 작동 원리는 첫 버튼은 정보 시트만 열고 최종 매칭 시작 버튼이 눌렸을 때만
    // 큐 참가 함수를 한 번 호출한 뒤 화면을 매칭 취소 상태로 바꾸는지 확인한다.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final joinedQueues = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ArenaPage(
          initialSummary: const {
            'profile': {
              'rating': 1500,
              'wins': 0,
              'losses': 0,
              'draws': 0,
              'tier': 'E',
            },
            'queues': [
              {
                'queue_type': 'duel_exam',
                'coming_soon': false,
                'question_count': 10,
                'duration_minutes': 20,
                'estimated_wait_seconds': 12,
              },
            ],
          },
          joinQueue: (queueType) async {
            joinedQueues.add(queueType);
            return const <String, dynamic>{};
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('arena-mobile-join-button')));
    await tester.pumpAndSettle();

    expect(joinedQueues, isEmpty);
    expect(
      find.byKey(const ValueKey('arena-mobile-confirm-join')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('arena-mobile-confirm-sheet')),
        matching: find.text('10문항 · 20분 · 약 12초 대기'),
      ),
      findsOneWidget,
    );
    expect(find.text('실전 대결 결과는 티어와 레이팅에 반영될 수 있습니다.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('arena-mobile-confirm-join')));
    await tester.pumpAndSettle();

    expect(joinedQueues, ['duel_exam']);
    expect(find.text('매칭 취소'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('대결 요약 실패는 원시 예외 대신 재시도 가능한 모바일 카드로 복구한다', (tester) async {
    // 필요한 변수는 390×844 화면과 HTML 응답 파싱 실패를 흉내 내는 요약 함수다.
    // 작동 원리는 실패 후 진행 표시기가 사라지고 학생용 안내·재시도 버튼·하단 앱 셸이 남는지 확인한다.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ArenaPage(
          loadSummary: () async =>
              throw const FormatException('Unexpected token <'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('대결 정보를 불러오지 못했어요.'), findsOneWidget);
    expect(find.textContaining('Unexpected token'), findsNothing);
    expect(
      find.byKey(const ValueKey('arena-mobile-retry-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
