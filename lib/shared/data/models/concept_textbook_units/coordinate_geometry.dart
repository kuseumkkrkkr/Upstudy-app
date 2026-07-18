import 'package:s11/shared/data/models/concept_textbook_editorial.dart';
import 'package:s11/shared/data/models/concept_textbook_graphs.dart';
import 'package:s11/shared/data/models/concept_textbook_lessons.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/shared/data/models/textbook.dart';

/// 필요한 변수는 개념 태그 목록이다.
/// 작동 원리는 좌표기하의 핵심 키워드를 한 줄 규칙으로 묶어 해당 단원을 좌표기하 편집 흐름으로 분기하는 것이다.
bool supportsCoordinateGeometry(List<String> tags) {
  const coordinateKeywords = <String>[
    '좌표평면',
    '직선의방정식',
    '원의방정식',
    '점과직선사이의거리',
    '거리공식(점직선)',
    '거리공식(두점)',
    '선분의내분점',
    '두점사이의거리',
    '중점',
    '외분점',
    '내분점공식',
    '평행이동',
    '대칭이동',
    '중심',
    '반지름',
    '원점대칭',
    '직선대칭',
    'x축대칭',
    'y축대칭',
  ];
  return tags.any(
    (tag) => coordinateKeywords.contains(tag) || tag.contains('내분점'),
  );
}

ConceptEditorialCopy coordinateGeometryCopy(String key, String title) {
  final lesson = lessonForConcept(key, title);
  return editorialCopyFromLesson(
    lesson: lesson,
    domainLabel: '좌표기하',
    openingQuestion: '그래프 없이 점 두 개를 보고 두 직선을 구분하려면 무엇을 먼저 확인해야 할까요?',
    intuition:
        '$title은(는) 좌표의 변화량을 같은 규칙으로 번역해 식을 만드는 개념입니다. 핵심은 “가로 변화량과 세로 변화량을 같은 기준으로 계산”하는 것입니다.',
    symbols: const [
      'x: 가로 좌표',
      'y: 세로 좌표',
      'x₂ - x₁: 가로 변화량',
      'y₂ - y₁: 세로 변화량',
    ],
    derivationSteps: const [
      '점 A, B를 각각 (x₁, y₁), (x₂, y₂)로 둔다.',
      '같은 방향을 갖는 값인 Δy/Δx를 세우고 왜 그 비율이 유지되는지 정당화한다.',
      '점-기울기형으로 식을 정리한 뒤 수직선 분기를 먼저 점검한다.',
      '최종식에 두 점 중 하나를 넣고 역대입으로 반례 없이 정리한다.',
    ],
    exampleTwo: '$title의 변형문제로 수직선 분기까지 포함한 직선방정식을 두 개 이상 비교해보세요.',
    exampleTwoSolution: const [
      '두 점을 바꿔 넣어도 방향비가 왜 같은지 다시 점검한다.',
      'Δx=0 분기에서는 점-기울기형이 아니라 x = x₁을 즉시 채택한다.',
      '일반형에서는 y = mx + b 또는 y - y₁ = m(x - x₁)로 마무리해 검산한다.',
    ],
    practiceBasic: '$title의 기본 조건을 사용해 Δx, Δy 계산부터 식 정리, 역대입까지 4단으로 써 보세요.',
    practiceAdvanced: '평행/수직 조건을 동시에 고려하는 조건문으로 분기표를 만들어 비교해 보세요.',
    hint:
        'Δx=0 분기를 먼저 적고, 그 다음에 식을 정리하세요. 계산 뒤에 정의역·분기 조건을 다시 읽으면 실수가 크게 줄어듭니다.',
    answers: const [
      '기본: 두 점 대입 시 계산식이 정확히 성립하고 분기 조건이 충족되는 식',
      '적용: 수평·수직·일반 분기 결과가 서로 뒤섞이지 않는지 검산한 값',
    ],
    misconceptions: const [
      '점을 대입하기 전에 Δx, Δy를 먼저 계산하지 않는 실수',
      'Δx=0인데 점-기울기형을 강제로 쓰는 실수',
      '점 하나로만 끝내고 역대입을 생략하는 실수',
    ],
    summaryItems: const [
      '기본 구조: (Δx, Δy)로 방향을 먼저 고정한다.',
      '일반식: y - y₁ = m(x - x₁), 점의 대입 순서는 바뀌어도 동일한 식으로 정리된다.',
      '예외 처리: Δx = 0이면 수직선 x = x₁으로 분기한다.',
    ],
  );
}

/// 필요한 변수는 두 점의 좌표와 슬라이더 그래프이다.
/// 작동 원리는 8~10 페이지 안에서 도입-개념-원리-실험-예제-연습-정리의 흐름이
/// 교재처럼 읽히도록 문장·근거·검산 포인트를 고정하는 것이다.
List<BookPage> buildTwoPointLinePilotPages() {
  final graph =
      conceptGraphFor('두점을지나는직선', const ['좌표평면', '직선의방정식']) ??
      const AiFlowGraphDocument(
        items: [
          AiFlowGraphItem(
            id: 'line-textbook-fallback',
            type: AiFlowGraphItemType.function,
            label: 'y = mx + b',
            colorHex: '#1B402B',
            expression: 'm*x+b',
          ),
        ],
        settings: AiFlowGraphSettings(
          viewport: AiFlowGraphViewport(left: -6, right: 6, top: 8, bottom: -6),
          parameters: [
            AiFlowGraphParameter(
              id: 'm',
              label: '기울기 m',
              value: 1,
              min: -3,
              max: 3,
            ),
            AiFlowGraphParameter(
              id: 'b',
              label: '절편 b',
              value: 0,
              min: -5,
              max: 5,
            ),
          ],
        ),
      );

  BookContentBlock text(BookContentBlockType type, String title, String body) =>
      BookContentBlock(type: type, title: title, text: body);

  BookContentBlock list(
    BookContentBlockType type,
    String title,
    List<String> items,
  ) => BookContentBlock(type: type, title: title, items: items);

  return [
    BookPage(
      id: '두점을지나는직선-opening',
      template: BookPageTemplate.opening,
      kicker: '좌표기하 도입',
      title: '두 점을 지나는 직선',
      blocks: [
        text(
          BookContentBlockType.lead,
          '학습 시작',
          '좌표평면의 점 두 개를 알면, 직선의 방향과 위치는 유일하게 결정됩니다. '
              '따라서 계산 전에 “역할 분리(방향·위치) + 분기 조건”을 문장으로 먼저 정리합니다.',
        ),
        text(
          BookContentBlockType.paragraph,
          '도입 질문',
          '점 A(x₁,y₁), B(x₂,y₂)가 있을 때 직선식은 어디부터 만들지 정해야 할까요? '
              '정답은 “Δx·Δy 계산 → 분기 판정(Δx=0) → 점-기울기형 또는 분기식 선택 → 역대입 검산”입니다.',
        ),
        list(BookContentBlockType.checklist, '한눈에 보기', const [
          '점의 좌표를 고정한다: A(x₁, y₁), B(x₂, y₂)',
          'Δx = x₂ - x₁, Δy = y₂ - y₁를 계산해 방향비를 만든다',
          'Δx = 0 분기를 먼저 점검한다',
          '최종식에 A와 B를 넣어 역대입 검산한다',
        ]),
      ],
    ),
    BookPage(
      id: '두점을지나는직선-change',
      template: BookPageTemplate.concept,
      kicker: '개념 이해 1',
      title: '좌표의 변화량',
      blocks: [
        const BookContentBlock(
          type: BookContentBlockType.definition,
          title: '정의',
          formula: r'\Delta x = x_2 - x_1,\; \Delta y = y_2 - y_1',
        ),
        const BookContentBlock(
          type: BookContentBlockType.paragraph,
          title: '왜 이 정의를 쓰나',
          text:
              '점 A에서 B로 가는 이동을 가로·세로 성분으로 분해하면, 같은 직선 위에서는 방향비가 일정합니다. '
              '그래서 Δx와 Δy로 방향을 정의하면 이후 계산의 분기 조건을 안정적으로 잡을 수 있습니다.',
        ),
        list(BookContentBlockType.symbols, '기호 해설', const [
          'Δx = x₂ - x₁: 가로 변화량(분모 후보)',
          'Δy = y₂ - y₁: 세로 변화량(분자 후보)',
          'x₁ ≠ x₂: Δx로 나눌 수 있는지 확인하는 조건',
          'Δx = 0이면 점-기울기형이 아니라 수직선 분기',
        ]),
      ],
    ),
    BookPage(
      id: '두점을지나는직선-slope',
      template: BookPageTemplate.concept,
      kicker: '개념 이해 2',
      title: '기울기는 변화량의 비',
      blocks: [
        const BookContentBlock(
          type: BookContentBlockType.definition,
          title: '정의',
          formula: r'm=\frac{y_2-y_1}{x_2-x_1}\, (x_1 \ne x_2)',
        ),
        const BookContentBlock(
          type: BookContentBlockType.paragraph,
          title: '왜 이 식을 세우나',
          text:
              '직선 위에서는 같은 간격 이동에서 “가로 변화량 대비 세로 변화량 비율”이 항상 같아야 합니다. '
              '그래서 이 비율을 기울기 m으로 두어 방정식의 출발점을 정합니다.',
        ),
        list(BookContentBlockType.symbols, '빠른 해석 포인트', const [
          'Δy = 0 → m = 0: 수평선',
          'Δx = 0 → 점-기울기형 불가: 수직선',
          'm > 0: 우상향, m < 0: 우하향',
        ]),
      ],
    ),
    BookPage(
      id: '두점을지나는직선-derivation',
      template: BookPageTemplate.principle,
      kicker: '원리 유도',
      title: '점-기울기형 유도',
      blocks: [
        const BookContentBlock(
          type: BookContentBlockType.theorem,
          title: '기본 원리',
          text:
              '직선 위 임의 점 P(x,y)와 고정점 A(x₁,y₁)는 기울기가 같아야 합니다. '
              '그래서 (y-y₁)/(x-x₁)=m을 세울 수 있고, 이는 “같은 직선에서 방향이 유지된다”는 판단 근거입니다.',
        ),
        list(BookContentBlockType.derivation, '유도 과정', const [
          '같은 방향 조건에서 비율식을 세운다.',
          'x-x₁≠0 조건을 함께 두고 양변에 (x-x₁)을 곱한다.',
          'y-y₁ = m(x-x₁)로 정리하고 필요하면 y = mx + b 형태로 바꾼다.',
          'Δx=0이면 점-기울기형이 아니므로 x = x₁로 분기한다.',
        ]),
        const BookContentBlock(
          type: BookContentBlockType.formula,
          title: '최종 정리',
          formula: r'y-y_1=m(x-x_1)',
        ),
        const BookContentBlock(
          type: BookContentBlockType.verification,
          title: '검산 기준',
          text: '도출식이 나오면 A 또는 B를 넣어 다시 점을 통과하는지 확인해야 합니다.',
        ),
      ],
    ),
    BookPage(
      id: '두점을지나는직선-experiment',
      template: BookPageTemplate.experiment,
      kicker: '직접 실험',
      title: 'm, b 슬라이더로 반응 확인',
      blocks: [
        text(
          BookContentBlockType.lead,
          '실험 지침',
          '슬라이더는 식의 구조가 실제로 맞는지 검증하는 장치입니다. '
              '먼저 m만 바꾸어 방향 반응을 보고, 다음에 b만 바꿔 평행이동 반응을 확인합니다.',
        ),
        list(BookContentBlockType.checklist, '실험 체크포인트', const [
          'm=1,2,3에서 기울기 변화만 비교',
          'b를 바꿔 절편 이동량만 확인',
          '예측한 점 하나를 임의 선택해 식이 계속 통과하는지 검산',
        ]),
        BookContentBlock(type: BookContentBlockType.graph, graph: graph),
      ],
    ),
    BookPage(
      id: '두점을지나는직선-example-1',
      template: BookPageTemplate.example,
      kicker: '대표 예제 1',
      title: '기본 조건을 식으로 정리하기',
      blocks: [
        text(
          BookContentBlockType.question,
          '문제',
          '점 A(1, 2), B(3, 6)이 지나는 직선의 방정식을 구하시오.',
        ),
        const BookContentBlock(
          type: BookContentBlockType.thinking,
          title: '생각 열기',
          text: 'Δx, Δy를 먼저 쓰고 분기 조건을 판별한 뒤 점-기울기형을 쓰는 순서를 고정합니다.',
        ),
        list(BookContentBlockType.solutionStep, '풀이', const [
          '1단계: Δx = 3-1 = 2, Δy = 6-2 = 4',
          '2단계: m = Δy/Δx = 4/2 = 2 (방향비는 직선에서 고정)',
          '3단계: y-2 = 2(x-1), A(1,2)를 대입해 정리',
          '4단계: 정리한 식으로 A, B를 각각 검산',
        ]),
        const BookContentBlock(
          type: BookContentBlockType.verification,
          title: '검산',
          text: 'x=1 → y=2, x=3 → y=6이 모두 성립해야 최종 정답입니다.',
        ),
        const BookContentBlock(
          type: BookContentBlockType.answer,
          title: '정답',
          text: 'y = 2x',
        ),
      ],
    ),
    BookPage(
      id: '두점을지나는직선-example-2',
      template: BookPageTemplate.solution,
      kicker: '해법',
      title: '응용: 분기 판단까지 같이 처리',
      blocks: [
        text(
          BookContentBlockType.question,
          '문제',
          '문항 1: 점(5,4), (5,-2), 문항 2: 점(-1,1), (1,1). '
              '각각의 직선식을 구하고 형태를 비교하세요.',
        ),
        const BookContentBlock(
          type: BookContentBlockType.thinking,
          title: '생각 열기',
          text: '두 문항을 한 번에 계산하면 분기 조건이 섞입니다. '
              '분기 기준(Δx=0 또는 Δy=0)을 먼저 정해 각 문항을 독립 처리합니다.',
        ),
        list(BookContentBlockType.solutionStep, '풀이', const [
          '문항 1: Δx=5-5=0 → 점-기울기형 불가, 분기 처리하여 x=5',
          '문항 2: Δy=1-1=0, Δx=1-(-1)=2 → 수평선, y=1',
          '각 식에 점을 넣어 통과 여부를 확인',
        ]),
        const BookContentBlock(
          type: BookContentBlockType.verification,
          title: '검산',
          text: '문항 1은 x=5이므로 임의의 점의 x좌표가 5인지 확인하고, 문항 2는 y=1인지 검산합니다.',
        ),
        const BookContentBlock(
          type: BookContentBlockType.answer,
          title: '정답',
          text: '문항 1: x = 5, 문항 2: y = 1',
        ),
      ],
    ),
    BookPage(
      id: '두점을지나는직선-practice',
      template: BookPageTemplate.practice,
      kicker: '연습',
      title: '연습 문제',
      blocks: [
        text(
          BookContentBlockType.question,
          '기본',
          '기본: 점(2, 1)과 (6, 5)를 지나는 직선을 구하세요.',
        ),
        text(
          BookContentBlockType.question,
          '적용',
          '응용: 점(0, -3),(4, -3)와 점(1,2),(3,5)의 식을 각각 비교하세요.',
        ),
        const BookContentBlock(
          type: BookContentBlockType.thinking,
          title: '생각 열기',
          text: '각 문항을 풀기 전에 Δx·Δy를 계산해 수직/수평 분기를 미리 나눕니다.',
        ),
        const BookContentBlock(
          type: BookContentBlockType.hint,
          title: '풀이 힌트',
          items: [
            '문항 1: Δx, Δy 계산 후 분기(Δx=0, Δy=0) 판별',
            '문항 2: 각 문항을 식으로 정리해 역대입',
          ],
        ),
        const BookContentBlock(
          type: BookContentBlockType.checklist,
          title: '연습 점검',
          items: ['분기 조건이 보였는가?', '최종식이 점 통과 검산됐는가?'],
        ),
        const BookContentBlock(
          type: BookContentBlockType.answer,
          title: '정답',
          text: '기본 y = x - 1, 응용: y=-3 또는 y=x+1',
        ),
      ],
    ),
    BookPage(
      id: '두점을지나는직선-misconception',
      template: BookPageTemplate.summary,
      kicker: '정리',
      title: '오개념 점검',
      blocks: [
        list(BookContentBlockType.misconception, '오해가 자주 나는 지점', const [
          'Δx,Δy를 계산하기 전에 점을 식에 넣는 실수',
          'Δx=0인데도 점-기울기형을 강제 적용하는 실수',
          '한 점만 대입하고 역대입 검산을 생략하는 실수',
        ]),
        list(BookContentBlockType.checklist, '자기 점검', const [
          '분기 조건(Δx=0)을 먼저 확인했는가?',
          '점-기울기형으로 전환하는 이유를 문장으로 남겼는가?',
          '최종식에 두 점 중 하나를 더 넣어 교차점을 검산했는가?',
        ]),
        list(BookContentBlockType.summary, '한눈에 복습', const [
          '한 개념은 (Δx,Δy) → m 산출 → 점-기울기형 or 수직선 분기 → 역대입 검산입니다.',
          '방향은 m이, 위치는 절편이 결정합니다.',
          '분모가 0이 되는 상황을 놓치면 단원 전체가 무너집니다.',
        ]),
      ],
    ),
    BookPage(
      id: '두점을지나는직선-summary',
      template: BookPageTemplate.summary,
      kicker: '핵심 정리',
      title: '핵심 공식 지도',
      blocks: [
        const BookContentBlock(
          type: BookContentBlockType.formula,
          title: '기본 식',
          formula: r'm=\frac{y_2-y_1}{x_2-x_1}\,(x_2\ne x_1)',
        ),
        const BookContentBlock(
          type: BookContentBlockType.formula,
          title: '점-기울기형',
          formula: r'y-y_1=m(x-x_1)',
        ),
        const BookContentBlock(
          type: BookContentBlockType.formula,
          title: '수직선 예외식',
          formula: r'x=x_1\;(\Delta x = 0)',
        ),
        list(BookContentBlockType.summary, '한 줄 정리', const [
          '점-기울기형은 방향(기울기)과 위치(점)로 직선을 완성한다.',
          '최종 답은 “최종식 + 역대입 검산”이 함께 있어야 완성된다.',
          '분기 조건은 기호로 먼저 표시하고 마지막에 다시 확인한다.',
        ]),
      ],
    ),
  ];
}
