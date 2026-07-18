import 'package:s11/shared/data/models/textbook.dart';

/// 필요한 변수는 개념 키와 지면 역할이다.
/// 작동 원리는 글로 설명한 원리를 공식 카드·표·부호선·풀이 흐름으로 다시 표현해 학습자가 여러 표상 사이를 오가게 하는 것이다.
List<BookVisual> conceptVisualsFor(String key, String section) {
  if (section == 'overview') {
    return [
      BookVisual(
        kind: 'flow',
        title: '이 단원의 학습 지도',
        items: const ['상황에서 조건 찾기', '정의와 기호 연결', '원리·그래프로 확인', '예제와 연습으로 전이'],
        caption: '$key은(는) 공식을 먼저 외우는 단원이 아니라, 조건을 표현으로 바꾸는 단원이다.',
      ),
    ];
  }
  if (section == 'definition' && (key.contains('이차') || key.contains('판별식'))) {
    return const [
      BookVisual(
        kind: 'formula',
        title: '핵심 구조',
        formula: r'y = ax² + bx + c',
        caption: 'a는 열린 방향, b와 c는 그래프의 위치와 모양을 바꾼다.',
      ),
    ];
  }
  if (section == 'definition' &&
      (key.contains('미분') || key.contains('도함수') || key.contains('극값'))) {
    return const [
      BookVisual(
        kind: 'formula',
        title: '순간변화율의 정의',
        formula: r"f'(a)=\lim_{h\to0}\frac{f(a+h)-f(a)}{h}",
        caption: '할선의 기울기를 두 점이 만나는 순간까지 좁힌 값이다.',
      ),
    ];
  }
  if (section == 'definition' &&
      (key.contains('수열') || key == '항' || key == '일반항')) {
    return const [
      BookVisual(
        kind: 'table',
        title: '항을 읽는 표',
        rows: [
          ['순서', '1', '2', '3', 'n'],
          ['항', 'a₁', 'a₂', 'a₃', 'aₙ'],
          ['역할', '출발', '두 번째', '세 번째', '일반 위치'],
        ],
        caption: 'n은 항의 값이 아니라 항의 위치를 나타낸다.',
      ),
    ];
  }
  if (section == 'principle' && (key.contains('이차부등식') || key.contains('부호'))) {
    return const [
      BookVisual(
        kind: 'signChart',
        title: '근 사이의 부호',
        items: ['x < α', 'α < x < β', 'x > β'],
        rows: [
          ['a > 0', '+', '−', '+'],
          ['a < 0', '−', '+', '−'],
        ],
        caption: '최고차항의 부호가 양끝 구간의 부호를 결정한다.',
      ),
    ];
  }
  if (section == 'principle' && (key.contains('극한') || key.contains('연속'))) {
    return const [
      BookVisual(
        kind: 'flow',
        title: '극한을 판정하는 순서',
        items: ['좌측에서 접근', '우측에서 접근', '두 값 비교', '함숫값과 비교'],
        caption: '좌극한과 우극한이 같고 실제 함숫값도 같아야 연속이다.',
      ),
    ];
  }
  if (section == 'example' &&
      (key.contains('순열') || key.contains('조합') || key.contains('사건'))) {
    return const [
      BookVisual(
        kind: 'table',
        title: '경우의 수 선택표',
        rows: [
          ['질문', '예', '선택'],
          ['순서를 바꾸면?', '회장·부회장', '순열'],
          ['순서를 바꿔도 같은가?', '대표 2명', '조합'],
        ],
        caption: '식부터 고르지 말고 순서의 의미부터 확인한다.',
      ),
    ];
  }
  if (section == 'solution') {
    return [
      BookVisual(
        kind: 'steps',
        title: '풀이 체크리스트',
        items: const ['조건 옮기기', '핵심 공식 선택', '계산 및 정리', '답의 조건 검산'],
        caption: '$key 문제는 계산보다 조건을 먼저 표시하면 실수가 줄어든다.',
      ),
    ];
  }
  return const [];
}
