import 'package:s11/shared/data/models/concept_textbook_lessons.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:flutter/foundation.dart';

/// 필요한 변수는 개념 원고(lesson)·도메인 라벨·편집 인자다.
/// 작동 원리: unit 단원에서 오는 개별 카피를 받아, 제목·개념·원리·연습이
/// 모두 들어간 8~12쪽 명시적 템플릿 페이지로 정규화한다.
class ConceptEditorialCopy {
  const ConceptEditorialCopy({
    required this.lesson,
    required this.domainLabel,
    required this.openingQuestion,
    required this.intuition,
    required this.symbols,
    required this.derivationSteps,
    required this.exampleOneSolution,
    required this.practiceBasic,
    required this.practiceAdvanced,
    required this.hint,
    required this.answers,
    required this.misconceptions,
    required this.summaryItems,
    this.exampleOne,
    this.exampleTwo,
    this.exampleTwoSolution,
    this.exampleOneAnswer,
    this.exampleTwoAnswer,
  });

  final ConceptLesson lesson;
  final String domainLabel;
  final String openingQuestion;
  final String intuition;
  final List<String> symbols;
  final List<String> derivationSteps;
  final String? exampleOne;
  final List<String> exampleOneSolution;
  final String? exampleTwo;
  final List<String>? exampleTwoSolution;
  final String practiceBasic;
  final String practiceAdvanced;
  final String hint;
  final List<String> answers;
  final List<String> misconceptions;
  final List<String> summaryItems;
  final String? exampleOneAnswer;
  final String? exampleTwoAnswer;
}

/// 필요한 변수는 개념키·제목·단원 카피·그래프·시각자료다.
/// 작동 원리: lesson에서 빠진 핵심은 직전 함수가 보강하고, 템플릿을 고정해
/// 페이지별 필수 블록 누락을 컴파일/테스트 단계에서 막는다.
List<BookPage> buildEditorialConceptPages({
  required String key,
  required String title,
  required ConceptEditorialCopy copy,
  AiFlowGraphDocument? graph,
  List<BookVisual> definitionVisuals = const [],
  List<BookVisual> principleVisuals = const [],
}) {
  final definitionBlocks = <BookContentBlock>[
    if (copy.lesson.definition.trim().isNotEmpty)
      BookContentBlock(
        type: BookContentBlockType.definition,
        title: '정의',
        text: copy.lesson.definition,
      ),
    BookContentBlock(
      type: BookContentBlockType.paragraph,
      title: '왜 이 식으로 시작하는가',
      text: copy.intuition,
    ),
    BookContentBlock(
      type: BookContentBlockType.checklist,
      title: '개념 시작 전 3점검',
      items: const [
        '핵심 대상(항, 점, 조건, 집합, 함수값)을 먼저 고정했는가?',
        '조건으로 배제되는 구간(정의역, 수직 분기, 부호 제한)을 미리 적었는가?',
        '최종 목표(구하려는 값/식)가 무엇인지 한 줄로 적었는가?',
      ],
    ),
    BookContentBlock(
      type: BookContentBlockType.symbols,
      title: '기호와 조건',
      items: copy.symbols,
    ),
  ];
  for (final visual in definitionVisuals) {
    definitionBlocks.add(
      BookContentBlock(type: BookContentBlockType.visual, visual: visual),
    );
  }

  final principleSteps = <String>[
    '한 번 정리: 이 개념은 무엇을 알려 주는지 먼저 문장으로 적는다.',
    ...copy.derivationSteps,
    copy.lesson.principle,
  ];
  final principleBlocks = <BookContentBlock>[
    BookContentBlock(
      type: BookContentBlockType.theorem,
      title: '핵심 원리',
      text: copy.lesson.principle,
    ),
    BookContentBlock(
      type: BookContentBlockType.derivation,
      title: '유도',
      items: principleSteps,
    ),
    const BookContentBlock(
      type: BookContentBlockType.thinking,
      title: '유도 과정에서 놓치기 쉬운 점',
      text:
          '정의에서 만든 식을 실제 식으로 바꿀 때 부호, 배수, 분기 조건은 '
          '항상 별도의 줄에 적고 검산 포인트를 같이 남겨야 실수가 줄어듭니다.',
    ),
  ];
  for (final visual in principleVisuals) {
    principleBlocks.add(
      BookContentBlock(type: BookContentBlockType.visual, visual: visual),
    );
  }

  final exampleOneQuestion = copy.exampleOne?.trim().isNotEmpty == true
      ? copy.exampleOne!.trim()
      : (copy.lesson.example.trim().isNotEmpty
            ? copy.lesson.example
            : '$title의 기본 형태 문제를 식으로 완성하시오.');
  final exampleTwoQuestion = copy.exampleTwo?.trim().isNotEmpty == true
      ? copy.exampleTwo!.trim()
      : copy.lesson.example;

  final answer1 = copy.exampleOneAnswer?.trim().isNotEmpty == true
      ? copy.exampleOneAnswer!.trim()
      : _defaultExampleAnswer(
          example: exampleOneQuestion,
          domain: copy.domainLabel,
        );
  final answer2 = copy.exampleTwoAnswer?.trim().isNotEmpty == true
      ? copy.exampleTwoAnswer!.trim()
      : _defaultExampleAnswer(
          example: exampleTwoQuestion,
          domain: copy.domainLabel,
        );

  final firstSolution = copy.exampleOneSolution.isNotEmpty
      ? copy.exampleOneSolution
      : _defaultSolutionFlow(example: exampleOneQuestion);
  final secondSolution =
      (copy.exampleTwoSolution != null && copy.exampleTwoSolution!.isNotEmpty)
      ? copy.exampleTwoSolution!
      : _defaultSolutionFlow(example: exampleTwoQuestion);

  final practiceChecks = <BookContentBlock>[
    BookContentBlock(
      type: BookContentBlockType.question,
      title: '기본',
      text: copy.practiceBasic,
    ),
    BookContentBlock(
      type: BookContentBlockType.question,
      title: '응용',
      text: copy.practiceAdvanced,
    ),
    const BookContentBlock(
      type: BookContentBlockType.thinking,
      title: '풀이 전 점검',
      text: '모든 조건(정의역, 분기, 기호 범위)을 한 번에 적고, 고정값과 변수를 분리한다.',
    ),
    const BookContentBlock(
      type: BookContentBlockType.hint,
      title: '풀이 힌트',
      text: '문장 → 조건 → 식 → 검산의 4단계를 빠뜨리지 않고 유지하면 조건 꼬임이 줄어듭니다.',
    ),
    const BookContentBlock(
      type: BookContentBlockType.checklist,
      title: '연습 점검',
      items: [
        '문항에서 고정값과 변수를 분리했는가?',
        '분기 조건(예: 분모 0, 정의역 제한)을 먼저 적었는가?',
        '최종식에 두 점 이상 또는 두 조건 이상으로 역대입 검산했는가?',
      ],
    ),
    BookContentBlock(
      type: BookContentBlockType.hint,
      title: '추가 힌트',
      text: copy.hint,
    ),
    BookContentBlock(
      type: BookContentBlockType.answer,
      title: '정답',
      items: [
        '기본 정답: 앞단계의 조건 계산을 기준으로 대입 검산을 마친 값',
        '응용 정답: 전체 조건을 모두 통과하는 최종 계산 결과',
        ...copy.answers,
      ],
    ),
  ];

  final experimentBlocks = <BookContentBlock>[
    const BookContentBlock(
      type: BookContentBlockType.lead,
      title: '실험 지침',
      text: '슬라이더를 바꾸면 식의 결과가 어떻게 반응하는지 관찰한다.',
    ),
    BookContentBlock(
      type: BookContentBlockType.checklist,
      title: '실험 체크포인트',
      items: const [
        '파라미터 하나만 바꾸고 변화량·방향을 기록한다.',
        '특수 조건(분모 0, 정의역 경계)을 따로 분류한다.',
        '바꾼 값의 결과를 예제 공식에 즉시 대입해 검산한다.',
      ],
    ),
    const BookContentBlock(
      type: BookContentBlockType.checklist,
      title: '예측 문장',
      items: [
        '기울기와 절편이 바뀌면 그래프의 각도와 위치가 각각 달라진다.',
        '특수 분기에서는 공식이 아닌 예외식으로 정렬한다.',
      ],
    ),
  ];
  if (graph != null) {
    experimentBlocks.add(
      BookContentBlock(type: BookContentBlockType.graph, graph: graph),
    );
  } else {
    experimentBlocks.add(
      const BookContentBlock(
        type: BookContentBlockType.verification,
        title: '주의',
        text: '그래프 자료가 없는 경우는 핵심 정의식만으로도 동일 조건을 검산한다.',
      ),
    );
  }

  final pages = [
    _editorialPage(
      id: '$key-opening',
      template: BookPageTemplate.opening,
      title: title,
      titleSuffix: '도입',
      blocks: [
        BookContentBlock(
          type: BookContentBlockType.lead,
          title: '학습 시작',
          text: copy.openingQuestion,
        ),
        BookContentBlock(
          type: BookContentBlockType.paragraph,
          title: '학습 목표',
          text:
              '${copy.lesson.objective}\n${_learningRoute(key, copy.domainLabel)}',
        ),
        BookContentBlock(
          type: BookContentBlockType.checklist,
          title: '먼저 점검할 것',
          items: const [
            '정의의 조건(정의역·범위·분기)을 먼저 쓰기',
            '예시의 의미를 먼저 번역하고 계산은 나중에 시작',
            '최종 식에 모든 조건을 다시 넣어 반박되지 않는지 확인',
          ],
        ),
      ],
    ),
    _editorialPage(
      id: '$key-concept',
      template: BookPageTemplate.concept,
      title: '$title 기본 구조',
      titleSuffix: '개념',
      blocks: definitionBlocks,
    ),
    _editorialPage(
      id: '$key-principle',
      template: BookPageTemplate.principle,
      title: '$title 유도와 원리',
      titleSuffix: '원리',
      blocks: principleBlocks,
    ),
    _editorialPage(
      id: '$key-experiment',
      template: BookPageTemplate.experiment,
      title: '$title 그래프 실험',
      titleSuffix: '실험',
      blocks: experimentBlocks,
    ),
    _editorialPage(
      id: '$key-example-1',
      template: BookPageTemplate.example,
      title: '$title 대표 예제 1',
      titleSuffix: '예제',
      blocks: [
    BookContentBlock(
      type: BookContentBlockType.question,
      title: '문제',
      text: exampleOneQuestion,
    ),
    BookContentBlock(
      type: BookContentBlockType.thinking,
      title: '생각 열기',
      text: '문항에서 고정값과 미지수를 먼저 구분하고, 왜 같은 식을 쓸 수 있는지 근거를 표시하라.',
        ),
    BookContentBlock(
      type: BookContentBlockType.solutionStep,
      title: '풀이',
      items: firstSolution,
    ),
    const BookContentBlock(
      type: BookContentBlockType.checklist,
      title: '풀이 직전 체크',
      items: [
        '한 단계에 하나의 근거만 적는지 확인한다.',
        '식 변환 후 단위/부호가 그대로인지 점검한다.',
        '역대입으로 원래 조건을 재검토한다.',
      ],
    ),
    BookContentBlock(
      type: BookContentBlockType.verification,
      title: '검산',
      text: '구한 식을 원래 정의에 대입해 조건(예: 분모, 정의역, 부호, 경계)을 모두 통과하는지 확인한다.',
    ),
        BookContentBlock(
          type: BookContentBlockType.answer,
          title: '정답',
          text: answer1,
        ),
      ],
    ),
    _editorialPage(
      id: '$key-solution-1',
      template: BookPageTemplate.solution,
      title: '$title 대표 예제 2',
      titleSuffix: '해법',
      blocks: [
        BookContentBlock(
          type: BookContentBlockType.question,
          title: '문제',
          text: exampleTwoQuestion,
        ),
        BookContentBlock(
          type: BookContentBlockType.thinking,
          title: '생각 열기',
          text: '해결 가능한 핵심 조건을 하나만 먼저 분리하고 그 조건으로 식을 작성한다.',
        ),
    BookContentBlock(
      type: BookContentBlockType.solutionStep,
      title: '풀이',
      items: secondSolution,
    ),
    const BookContentBlock(
      type: BookContentBlockType.checklist,
      title: '풀이 직전 체크',
      items: [
        '조건 분기가 먼저 정해졌는지 확인한다.',
        '대입 대상(함수값·점·근)을 바꿔도 같은 형태가 유지되는지 확인한다.',
        '끝에서 다시 정의역과 경계 조건을 맞춘다.',
      ],
    ),
    BookContentBlock(
      type: BookContentBlockType.verification,
      title: '검산',
      text: '반대로 한 단계를 대입해도 식이 동일한지, 같은 결과로 복귀하는지 마지막에 재확인한다.',
        ),
        BookContentBlock(
          type: BookContentBlockType.answer,
          title: '정답',
          text: answer2,
        ),
      ],
    ),
    _editorialPage(
      id: '$key-practice',
      template: BookPageTemplate.practice,
      title: '$title 연습',
      titleSuffix: '연습',
      blocks: practiceChecks,
    ),
    _editorialPage(
      id: '$key-summary',
      template: BookPageTemplate.summary,
      title: '$title 정리',
      titleSuffix: '정리',
      blocks: [
        BookContentBlock(
          type: BookContentBlockType.misconception,
          title: '오개념 점검',
          items: _enhanceMisconceptions(copy.misconceptions),
        ),
        BookContentBlock(
          type: BookContentBlockType.summary,
          title: '핵심 한 줄',
          items: copy.summaryItems,
        ),
        BookContentBlock(
          type: BookContentBlockType.checklist,
          title: '자기 점검',
          items: const [
            '조건을 먼저 정리했는가?',
            '풀이 각 단계의 판단 근거를 적었는가?',
            '최종 식을 조건에 다시 넣어 검산했는가?',
            '해의 모양(부호, 범위, 그래프)도 확인했는가?',
          ],
        ),
      ],
    ),
  ];

  if (kDebugMode) {
    for (var index = 0; index < pages.length; index++) {
      final count = _countEditorialPageChars(pages[index]);
      assert(
        count <= _maxEditorialPageChars,
        '개념 "$key"의 ${pages[index].template.name} 페이지가 '
        '내용 과밀로 판정됩니다. index=$index, char=$count, limit=$_maxEditorialPageChars',
      );
    }
  }

  return pages;
}

/// 필요한 변수는 풀이 텍스트다.
/// 작동 원리: 단일 단계로만 긴 텍스트를 남기지 않고, 계산-판별-검산 순서를 1~4단계로 고정한다.
List<String> _defaultSolutionFlow({required String example}) {
  return [
    '1단계: 문제의 “찾는 값”과 “알고 있는 값”을 분리하고, 왜 분리하는지 적는다.',
    '2단계: 분기 조건(분모 0, 정의역, 부호)을 반영해 기본 식을 만든다.',
    '3단계: 식을 정리하면서 각 변환의 근거를 한 줄씩 남긴다.',
    '4단계: 구한 식을 조건에 다시 넣어 예외까지 모두 통과하는지 역대입 검산한다.',
  ];
}

const int _maxEditorialPageChars = 2400;

int _countEditorialPageChars(BookPage page) {
  var count = 0;
  for (final block in page.blocks) {
    count += block.title.length + block.text.length + block.formula.length;
    for (final item in block.items) {
      count += item.length;
    }
    for (final row in block.rows) {
      for (final cell in row) {
        count += cell.length;
      }
    }
    if (block.graph != null) count += 80;
    if (block.visual != null) count += 40;
  }
  return count;
}

/// 필요한 변수는 도메인 라벨과 문제 분류다.
/// 작동 원리: 수강자의 오개념이 많이 생기는 표현을 미리 제거하도록 경고 문장을 구성한다.
List<String> _enhanceMisconceptions(List<String> items) {
  return items.isNotEmpty
      ? items
      : const [
          '조건을 먼저 정리하지 않은 채 계산을 시작하는 실수',
          '특수 조건(예: 분모 0, 정의역 경계)을 예외 분기로 나누지 않는 실수',
          '결과를 검산하지 않고 식만 정리해 최종 답으로 놓는 실수',
        ];
}

/// 필요한 변수는 개념키와 도메인 라벨이다.
/// 작동 원리: 단원이 고정될수록 이동루틴이 같아야 하므로, 도메인별로 “조건-식-검산” 경로를 통일한다.
String _learningRoute(String key, String domainLabel) {
  if (domainLabel == '좌표기하' || key.contains('직선')) {
    return '학습 루트: 점 정리 → 변화량 분기(Δx=0/Δy=0) → 식 완성 → 역대입 검산';
  }
  if (domainLabel == '수열') {
    return '학습 루트: 규칙 추출 → 일반항 세우기 → n대입 → 점검식으로 검산';
  }
  if (domainLabel == '함수와 대수') {
    return '학습 루트: 정의역 확인 → 식 정리 → 그래프 관찰 → 정의역·조건 대입 검산';
  }
  if (domainLabel == '미적분Ⅰ') {
    return '학습 루트: 평균 변화/누적 해석 → 극한/도함수/적분 설정 → 단위 해석 → 조건 검산';
  }
  return '학습 루트: 조건 분해 → 식 정리 → 풀이의 근거 쓰기 → 역대입 점검';
}

/// 필요한 변수는 도메인·문항이다.
/// 작동 원리: 도메인별 정답 문장 템플릿을 써서 문항 유형이 바뀌어도 판단 기준이 일관되게 남도록 한다.
String _defaultExampleAnswer({
  required String example,
  required String domain,
}) {
  if (domain == '좌표기하') {
    return '답: 두 점을 모두 통과하고 분기 조건을 만족하는 식 또는 점 형태로 정리한다.';
  }
  if (domain == '수열') {
    return '답: 일반항/누적식에 식별표(항번호)를 넣어 계산값을 명시한다.';
  }
  if (domain == '함수와 대수') {
    return '답: 정의역과 좌표 조건을 만족하는 함수식 또는 상수값으로 정리한다.';
  }
  if (domain == '미적분Ⅰ') {
    return '답: 정의·단위를 함께 쓴 계산값과 구간 조건을 충족하는 최종값을 제시한다.';
  }
  return '답: 문제식에 대입해 조건이 모두 맞는 최종 식을 정리한다.';
}

/// 필요한 변수는 블록 리스트와 제목 장식이다.
/// 작동 원리: 페이지 생성 중 반복 문자열을 통일하고 각 페이지의 출처 id를 유지한다.
BookPage _editorialPage({
  required String id,
  required BookPageTemplate template,
  required String title,
  required String titleSuffix,
  required List<BookContentBlock> blocks,
}) {
  return BookPage(
    id: id,
    template: template,
    title: title,
    kicker: titleSuffix,
    blocks: blocks,
  );
}

/// 필요한 변수는 lesson·카피 내용이다.
/// 작동 원리: unit이 넘겨주는 오버라이드 문자열을 우선 사용해도
/// 누락이 없도록 기본 카피를 보완한다.
ConceptEditorialCopy editorialCopyFromLesson({
  required ConceptLesson lesson,
  required String domainLabel,
  required String openingQuestion,
  required String intuition,
  required List<String> symbols,
  required List<String> derivationSteps,
  List<String>? overrideExampleOneSolution,
  String? overrideExampleOneAnswer,
  String? exampleTwo,
  List<String>? exampleTwoSolution,
  String? overrideExampleTwoAnswer,
  String? practiceBasic,
  String? practiceAdvanced,
  String? hint,
  List<String>? answers,
  List<String>? misconceptions,
  List<String>? summaryItems,
}) {
  final normalizedAnswers = (answers == null || answers.isEmpty)
      ? const ['조건을 모두 확인한 정리식', '역대입 검산을 통과한 최종값']
      : answers;
  final normalizedMisconceptions =
      (misconceptions == null || misconceptions.isEmpty)
      ? const ['조건을 생략한 채 식을 정리한다', '역대입 검산을 생략한다']
      : misconceptions;

  return ConceptEditorialCopy(
    lesson: lesson,
    domainLabel: domainLabel,
    openingQuestion: openingQuestion,
    intuition: intuition,
    symbols: symbols,
    derivationSteps: derivationSteps,
    exampleOne: lesson.example,
    exampleOneSolution: overrideExampleOneSolution?.isNotEmpty == true
        ? overrideExampleOneSolution!
        : _defaultSolutionFlow(example: lesson.example),
    exampleTwo:
        exampleTwo ??
        _fallbackAdvancedExampleByDomain(
          domainLabel: domainLabel,
          lesson: lesson,
        ),
    exampleTwoSolution:
        exampleTwoSolution ??
        _defaultSolutionFlow(
          example:
              exampleTwo ??
              _fallbackAdvancedExampleByDomain(
                domainLabel: domainLabel,
                lesson: lesson,
              ),
        ),
    exampleOneAnswer:
        overrideExampleOneAnswer ??
        (normalizedAnswers.isNotEmpty ? normalizedAnswers[0] : null),
    exampleTwoAnswer:
        overrideExampleTwoAnswer ??
        (normalizedAnswers.length > 1 ? normalizedAnswers[1] : null),
    practiceBasic:
        practiceBasic ??
        (lesson.summary.isNotEmpty
            ? '${lesson.summary.substring(0, lesson.summary.length.clamp(0, 22))}에 맞는 기본문제를 해결한다.'
            : '주어진 조건을 표기하고 단계를 따라 푸는 기본문제를 푼다.'),
    practiceAdvanced:
        practiceAdvanced ?? '주어진 핵심 조건을 활용해 확장형 문제를 하나 더 설계하고 풀이한다.',
    hint: hint ?? '정의-식-역대입 순서를 한 번에 쓰면 오답이 줄어든다.',
    answers: normalizedAnswers,
    misconceptions: normalizedMisconceptions,
    summaryItems: summaryItems?.isNotEmpty == true
        ? summaryItems!
        : _fallbackSummaryItems(lesson, domainLabel),
  );
}

/// 필요한 변수는 lesson·도메인 라벨이다.
/// 작동 원리: domain label로 요약 문장을 보정해 테스트 문구 없이 개념별 핵심문장을 남긴다.
List<String> _fallbackSummaryItems(ConceptLesson lesson, String domainLabel) {
  if (lesson.summary.trim().isNotEmpty) {
    return [
      lesson.summary,
      '정의에서 시작해 조건 분기와 식의 근거를 적고, 항상 역대입으로 검산한다.',
      '유도식이 맞았는지는 단일 수치가 아니라 전체 조건 충족으로 확인한다.',
    ];
  }
  if (domainLabel == '좌표기하') {
    return const [
      '가로 변화량/세로 변화량을 먼저 정해 분기를 정렬한다.',
      '기울기와 절편의 역할을 분리해 식을 완성한다.',
      '각각의 분기(수평·수직)를 모두 점검한다.',
    ];
  }
  return const [
    '조건을 먼저 분해해 기호를 고정한다.',
    '식의 각 단계에서 판단 근거를 기록한다.',
    '마지막에 역대입으로 반드시 검산한다.',
  ];
}

/// 필요한 변수는 도메인 라벨과 단원 원고다.
/// 작동 원리: 도메인별로 예제 난이도를 높일 때 조건 분기와 계산 포인트를 자동 보강한다.
String _fallbackAdvancedExampleByDomain({
  required String domainLabel,
  required ConceptLesson lesson,
}) {
  if (domainLabel == '좌표기하') {
    return '좌표 조건을 바꿔 수직선 또는 수평선 분기까지 포함한 사례를 하나 더 만들어 구하시오.';
  }
  if (domainLabel == '수열') {
    return '첫째항·일반항 중 하나를 바꿔 전체 합 또는 중항 문제로 확장해 풀어 보시오.';
  }
  if (domainLabel == '함수와 대수') {
    return '주어진 식의 정의역을 바꾸고 그래프 이동을 포함해 조건을 다시 세워 해석하시오.';
  }
  if (domainLabel == '이차식과 이차함수') {
    return '부등식 범위와 근, 꼭짓점을 동시에 다루는 변형문제로 전개하시오.';
  }
  if (domainLabel == '미분Ⅰ' || domainLabel == '미적분Ⅰ') {
    return '기본 정의식을 바꾸어 경계값·해석 구간을 달리한 사례를 비교해 풀어보시오.';
  }
  if (domainLabel == '집합·명제·경우의수') {
    return '기준 조건을 반대로 잡아 경우가 달라지는 응용문제를 스스로 설계해 풀어보시오.';
  }
  if (domainLabel == '행렬') {
    return '행렬의 크기 조건을 바꿔 가능한 연산과 불가능한 연산을 구분해 확인하시오.';
  }
  if (domainLabel == '복소수') {
    return '분자·분모 분리를 바꿔 켤레를 적용했을 때 실수부/허수부 분리가 달라지는 사례를 비교하시오.';
  }
  return lesson.summary.isNotEmpty
      ? '${lesson.summary}를 바탕으로 조건을 하나 변경한 연습문제를 설계하시오.'
      : '정의와 원리를 이용해 조건이 달라진 유사 문제를 직접 만들어 풀이하시오.';
}
