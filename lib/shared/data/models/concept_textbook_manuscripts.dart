import 'package:s11/shared/data/models/concept_textbook_editorial.dart';
import 'package:s11/shared/data/models/concept_textbook_graphs.dart';
import 'package:s11/shared/data/models/concept_textbook_visuals.dart';
import 'package:s11/shared/data/models/concept_textbook_lessons.dart';
import 'package:s11/shared/data/models/concept_textbook_units/calculus.dart';
import 'package:s11/shared/data/models/concept_textbook_units/coordinate_geometry.dart';
import 'package:s11/shared/data/models/concept_textbook_units/functions.dart';
import 'package:s11/shared/data/models/concept_textbook_units/logic_probability.dart';
import 'package:s11/shared/data/models/concept_textbook_units/matrix.dart';
import 'package:s11/shared/data/models/concept_textbook_units/polynomial.dart';
import 'package:s11/shared/data/models/concept_textbook_units/quadratic.dart';
import 'package:s11/shared/data/models/concept_textbook_units/sequences.dart';
import 'package:s11/shared/data/models/textbook.dart';

/// 필요한 변수는 개념 키·제목·전체 교육과정 태그다.
/// 작동 원리는 8개 영역 집필기 중 정확히 하나를 선택하고, 영역에 속하지 않는
/// 개념도 해당 개념의 레슨 원고를 바탕으로 독립된 교재 원고를 완성하는 것이다.
List<BookPage> buildConceptManuscriptPages({
  required String key,
  required String title,
  required List<String> tags,
}) {
  if (key == '두점을지나는직선') {
    return buildTwoPointLinePilotPages();
  }

  final copy = _authoredCopyFor(key, title, tags);
  return buildEditorialConceptPages(
    key: key,
    title: title,
    copy: copy,
    graph: conceptGraphFor(key, [...tags, title]),
    definitionVisuals: conceptVisualsFor(key, 'definition'),
    principleVisuals: conceptVisualsFor(key, 'principle'),
  );
}

/// 필요한 변수는 개념 키와 카테고리 태그다.
/// 작동 원리는 8개 교재군 라우터를 순차 적용해 적합한 집필 규칙을 고르고,
/// 맞는 영역이 없는 개념도 제목·레슨·태그를 이용해 독립 원고로 완성한다.
ConceptEditorialCopy _authoredCopyFor(
  String key,
  String title,
  List<String> tags,
) {
  final signal = '$key $title'.toLowerCase();

  if (_containsAny(signal, const ['수열', '등차', '등비', '일반항', '시그마'])) {
    return sequencesCopy(key, title);
  }
  if (supportsSequences(tags)) return sequencesCopy(key, title);

  if (supportsCalculus(tags) ||
      _containsAny(signal, const ['미분', '적분', '극한', '극값', '속도', '가속도'])) {
    return calculusCopy(key, title);
  }

  if (supportsCoordinateGeometry(tags) ||
      _containsAny(signal, const [
        '좌표',
        '점',
        '직선',
        '거리공식',
        '내분점',
        '외분점',
        '중점',
        '중심',
        '반지름',
        '원점',
        '축',
        '대칭',
        '점근',
        '포물선',
        '쌍곡선',
        '직선의',
      ])) {
    return coordinateGeometryCopy(key, title);
  }

  if (supportsLogicProbability(tags) ||
      _containsAny(signal, const [
        '집합',
        '명제',
        '경우의수',
        '경우의',
        '원소',
        '부분집합',
        '사건',
      ])) {
    return logicProbabilityCopy(key, title);
  }

  if (supportsMatrix(tags) ||
      _containsAny(signal, const ['행렬', '역행렬', '스칼라', '가우스'])) {
    return matrixCopy(key, title);
  }

  if (supportsQuadratic(tags) ||
      _containsAny(signal, const ['이차', '판별식', '근의', '최댓값', '최솟값'])) {
    return quadraticCopy(key, title);
  }

  if (supportsFunctions(tags) ||
      _containsAny(signal, const ['함수', '유리', '무리', '로그', '지수', '역함수'])) {
    return functionsCopy(key, title);
  }

  if (supportsPolynomial(tags) ||
      _containsAny(signal, const ['인수분해', '인수정리', '조립', '항등식', '완전제곱', '합차'])) {
    return polynomialCopy(key, title);
  }
  return _authoredGeneralCopy(key, title, tags);
}

/// 필요한 변수는 매칭 대상 문자열과 도메인 키워드 목록이다.
/// 작동 원리는 키/제목 문자열에 도메인 트리거가 하나라도 있으면 해당 영역 라우터로
/// 바로 진입하게 해서 잘못 분기되는 사례를 줄이는 것이다.
bool _containsAny(String source, List<String> keywords) {
  return keywords.any((keyword) => source.contains(keyword));
}

/// 필요한 변수는 개념 키·제목·레슨 원문이다.
/// 작동 원리는 기존 레슨의 정의·원리·예제를 중심에 두고 질문·풀이·오개념·정리까지
/// 한 개념의 학습 흐름으로 연결해, 분류되지 않은 개념도 독립 원고로 완성하는 것이다.
ConceptEditorialCopy _authoredGeneralCopy(
  String key,
  String title,
  List<String> tags,
) {
  final lesson = lessonForConcept(key, title);
  final domainLabel = _inferDomainLabel(key, tags);
  final symbolHints = _authoredSymbols(key, tags);
  final derivationFlow = _authoredDerivation(key, lesson, domainLabel);
  final advancedExample = _authoredAdvancedExample(key, title, lesson);
  final advancedSolution = _authoredAdvancedSolution(key, lesson, domainLabel);
  final practiceSet = _authoredPractice(key, title, domainLabel);
  final basicSolution = _authoredBasicSolution(
    lesson.solution,
    key,
    domainLabel,
  );
  final answers = _authoredAnswers(key, lesson);
  final summaryItems = _authoredSummaryItems(key, lesson, domainLabel);

  return editorialCopyFromLesson(
    lesson: lesson,
    domainLabel: domainLabel,
    openingQuestion: _authoredOpeningQuestion(key, title, domainLabel),
    intuition: _authoredIntuition(key, title, lesson, domainLabel),
    symbols: symbolHints,
    derivationSteps: derivationFlow,
    overrideExampleOneSolution: basicSolution,
    overrideExampleOneAnswer: answers.isNotEmpty ? answers[0] : lesson.solution,
    exampleTwo: advancedExample,
    exampleTwoSolution: advancedSolution,
    overrideExampleTwoAnswer: answers.length > 1
        ? answers[1]
        : (advancedSolution.isNotEmpty
              ? advancedSolution.last
              : lesson.solution),
    practiceBasic: practiceSet[0],
    practiceAdvanced: practiceSet[1],
    hint: _authoredHint(
      key,
      title,
      lesson,
      domainLabel,
      practiceSet[0],
      practiceSet[1],
    ),
    answers: answers,
    misconceptions: _authoredMisconceptions(key, lesson),
    summaryItems: summaryItems,
  );
}

/// 필요한 변수는 개념 키·도메인 태그다.
/// 작동 원리는 키워드 힌트 기반으로 기본 교재군 라벨을 정하고, 분류되지 않으면 “일반”로 처리한다.
String _inferDomainLabel(String key, List<String> tags) {
  if (supportsSequences(tags)) return '수열';
  if (supportsCalculus(tags)) return '미적분Ⅰ';
  if (supportsCoordinateGeometry(tags)) return '좌표기하';
  if (supportsLogicProbability(tags)) return '집합·명제·경우의수';
  if (supportsMatrix(tags)) return '행렬';
  if (supportsQuadratic(tags)) return '이차식과 이차함수';
  if (supportsFunctions(tags)) return '함수와 대수';
  if (supportsPolynomial(tags)) {
    if (key.contains('복소수') ||
        key.contains('허수') ||
        key.contains('켤레') ||
        tags.contains('복소수')) {
      return '복소수';
    }
    return '다항식';
  }
  if (key.contains('기하') || key.contains('좌표')) return '좌표기하';
  if (key.contains('극한') ||
      key.contains('미분') ||
      key.contains('적분') ||
      key.contains('극값')) {
    return '미적분Ⅰ';
  }
  return '일반 개념';
}

String _authoredOpeningQuestion(String key, String title, String domainLabel) {
  if (domainLabel == '수열') {
    return '$title은(는) 첫 항에서 시작해 규칙이 어떻게 누적되는지 보는 단원입니다. '
        '가장 먼저 “어떤 값이 변하고, 어떤 값이 기준인지”를 분리해 보세요.';
  }
  if (domainLabel == '함수와 대수') {
    return '$title은(는) 입력과 출력의 대응을 한 번에 정리하는 단원입니다. '
        '그래프와 식을 잇는 “정의역 조건”을 먼저 잡아 계산을 시작해 보세요.';
  }
  if (domainLabel == '집합·명제·경우의수') {
    return '$title을(를) 풀 때는 “무엇이 포함되고 빠지는지”를 구분하는 분류가 핵심입니다. '
        '정의표를 먼저 만들어 진리의 경계를 잡아야 계산이 정확해집니다.';
  }
  if (domainLabel == '행렬') {
    return '$title은(는) 연산이 가능한 크기를 점검한 뒤 계산하는 단원입니다. '
        '행과 열이 맞지 않으면 아무리 계산해도 정답이 되지 않습니다.';
  }
  if (domainLabel == '이차식과 이차함수') {
    return '$title은(는) 모양별로 구조를 먼저 판별해야 실수가 줄어드는 단원입니다. '
        '그래프/근/부호가 같은 문제인지 먼저 분해해 보세요.';
  }
  if (domainLabel == '미적분Ⅰ') {
    return '$title은(는) 미소 변화와 누적량을 각각 다른 관점으로 읽어야 하는 단원입니다. '
        '왜 그 식을 쓰는지 한 줄씩 말로 적는 습관이 정답의 핵심입니다.';
  }
  if (domainLabel == '좌표기하') {
    return '$title은(는) 점 두 개의 관계를 변화량으로 정리하는 단원입니다. '
        '가로변화와 세로변화를 먼저 쓰면 분기(수직/수평/일반) 판단이 쉬워집니다.';
  }
  if (domainLabel == '복소수') {
    return '$title은(는) 실수 연산과 다른 규칙을 가진 수의 계산 습관을 고정하는 단원입니다. '
        '허수부와 실수부를 분리해 계산하면 반례를 많이 줄일 수 있습니다.';
  }
  return '$title을(를) 배울 때 가장 먼저 “무엇이 고정값인지, 무엇이 변화값인지”를 나누면 어떤 게 달라질까요?';
}

/// 필요한 변수는 개념 키·도메인 라벨·레슨 원문이다.
/// 작동 원리는 기본 정의를 쉬운 문장으로 재정렬하고 핵심 조건 분기를 함께 노출하는 것이다.
String _authoredIntuition(
  String key,
  String title,
  ConceptLesson lesson,
  String domainLabel,
) {
  final core = lesson.definition;
  if (domainLabel == '수열') {
    return '$title은(는) 항의 변화를 n으로 추적해 전체 구조를 만드는 개념입니다. '
        '항의 차이나 비가 일정한지 확인한 뒤, n=1,2를 넣어 규칙을 검증하는 순서가 중요합니다.';
  }
  if (domainLabel == '미적분Ⅰ') {
    return '$title은(는) “한 점의 순간변화”와 “구간의 누적”을 다루는 개념입니다. '
        '문제는 작은 구간을 크게 보는 관점이 아니라 큰 구간을 작은 변화로 쪼개는 관점으로 읽습니다.';
  }
  if (domainLabel == '좌표기하') {
    return '$title은(는) 한 개념으로 두 점을 읽는 단원입니다. '
        '$core 를 기반으로 수평/수직 특수 케이스를 먼저 분기해야 오해가 줄어듭니다.';
  }
  if (domainLabel == '집합·명제·경우의수') {
    return '$title은(는) 사건을 빠짐없이 분해하고 중복을 제거하는 구조입니다. '
        '$core 를 말문으로 바꿔 놓으면 계산 단계가 정리되어 오답이 줄어듭니다.';
  }
  if (domainLabel == '행렬') {
    return '$title은(는) 표의 크기와 위치가 그대로 의미가 되기 때문에, '
        '$core 의 적용 가능 조건을 먼저 확인해야 합니다.';
  }
  if (domainLabel == '함수와 대수') {
    return '$title은(는) 함수의 정의역을 먼저 쓰고, 다음으로 증가/감소, 이동량을 확인하는 구조입니다. '
        '입력값 하나를 잡아 식을 세우면 식의 모순을 빠르게 잡을 수 있습니다.';
  }
  return '$title은(는) $core를 중심으로 조건 분해와 검산이 동시에 움직여야 제대로 완성됩니다.';
}

/// 필요한 변수는 개념 키·태그다.
/// 작동 원리는 도메인별 빈도 패턴을 유지하면서도 오개념이 많이 생기는 조건 분기를 강조하는 것이다.
List<String> _authoredSymbols(String key, List<String> tags) {
  if (supportsSequences(tags) ||
      key.contains('수열') ||
      key.contains('등차') ||
      key.contains('등비')) {
    return const [
      'n: 항의 위치(항수 표시)',
      'aₙ: n번째 항의 값(끝값이 아니라 항의 위치)',
      'd 또는 r: 차 또는 공비(형태별 정리값)',
      'Sₙ: 누적 합을 구할 때 쓰는 표기',
    ];
  }
  if (supportsQuadratic(tags) || key.contains('이차')) {
    return const [
      'a, b, c: 이차식 y = ax²+bx+c의 계수',
      'D: 판별식 b²−4ac',
      'α, β: x축과의 교점 좌표',
      '근/부호: 부등식 판정에서 경계의 역할이 되는 값',
    ];
  }
  if (supportsFunctions(tags) ||
      key.contains('함수') ||
      key.contains('로그') ||
      key.contains('지수')) {
    return const [
      'x: 입력값(정의역에서 가능한 값만 사용)',
      'f(x): 출력값(치역을 판별할 값)',
      '정의역 조건: 분모·근호·로그 진수에서 빠지면 안 되는 조건',
      '매개변수: 그래프 이동/늘림을 결정하는 상수',
    ];
  }
  if (supportsCoordinateGeometry(tags) ||
      key.contains('직선') ||
      key.contains('기하')) {
    return const [
      'x: 가로축 좌표',
      'y: 세로축 좌표',
      '점: (x, y) 한 번에 표기',
      '특수 경우: 분모 0, 정의역 경계(예외)로 먼저 분리',
    ];
  }
  if (supportsLogicProbability(tags) ||
      key.contains('집합') ||
      key.contains('조건')) {
    return const [
      'P, Q: 조건 진리집합',
      '⇒, ⇔: 함축 및 동치 관계',
      'n(P), n(Q): 경우의 수 표기(중복/순서 주의)',
      '보완·교집합: 전체 분해의 핵심 연산',
    ];
  }
  if (supportsMatrix(tags) || key.contains('행렬')) {
    return const [
      'm×n: 행렬 크기(연산 가능성 판단의 출발점)',
      'aᵢⱼ: 행렬의 성분(인덱스 오차 방지)',
      'A⁻¹: 역행렬(역행렬 존재 조건은 D ≠ 0)',
      'I: 항등행렬(변형 검산의 기준점)',
    ];
  }
  if (key.contains('복소수') || key.contains('허수') || key.contains('켤레')) {
    return const [
      'i: 허수 단위(i² = -1)',
      'a+bi: 실수부+허수부 형태',
      '켤레복소수: a-bi로 실수부 성분을 분리',
      'z·z̄: 켤레와의 곱은 실수가 된다',
    ];
  }
  return const [
    '알려진 값: 문제 조건에서 직접 얻을 수 있는 값',
    '구해야 하는 값: 식이 구하려는 대상',
    '구간·조건: 절댓값, 음수 배제, 정의역 제한',
    '검산 기준: 원문 식으로 되돌아가 반례 점검하기',
  ];
}

/// 필요한 변수는 키워드와 레슨 원고다.
/// 작동 원리는 원리 유도를 “왜 이 식을 세우는지” 관점으로 고정하는 것이다.
List<String> _authoredDerivation(
  String key,
  ConceptLesson lesson,
  String domainLabel,
) {
  if (lesson.principle.contains('기울기') || key.contains('직선')) {
    return const [
      '문제 조건을 수식 관계로 바꿔 “고정 변수”와 “변화량”을 구분한다.',
      '비율은 방향 판단량이므로 분자/분모의 순서를 통일한다.',
      '식의 형태를 단일 식으로 정리하고 검산 가능한 형태로 바꾼다.',
      '예외 조건이 생기면 일반식에서 분기 규칙을 따로 분리한다.',
    ];
  }
  if (lesson.principle.contains('Σ') || key.contains('수열')) {
    return const [
      '항을 표로 세워 앞항/뒤항 관계를 먼저 만든다.',
      '변화량 또는 비율이 일정한 규칙을 검증한다.',
      '일반항까지 압축한 뒤 n=1,2를 대입해 형태를 검증한다.',
      '최종식이 원래 조건(합, 일반항, 방정식)과 일치하는지 체크한다.',
    ];
  }
  if (lesson.principle.contains('극한') ||
      lesson.principle.contains('적분') ||
      lesson.principle.contains('미분')) {
    return const [
      '한 문장으로 정의를 고정하고, 변수의 의미(기준점, 구간, 변화량)를 정한다.',
      '기호의 단위를 바꿔 적는 순간마다 결과가 어떤 값인지 적어둔다.',
      '도출식에 n 또는 구간 경계를 넣어 결과값의 방향을 확인한다.',
      '마지막으로 부호/단위까지 반영해 최종 정리한다.',
    ];
  }
  if (domainLabel == '복소수') {
    return const [
      '허수부/실수부를 분리해 계산 규칙을 먼저 고정한다.',
      '분모를 실수로 바꾸기 위해 켤레복소수를 적용한다.',
      '실수부·허수부를 나누어 동일한 차수끼리 정리한다.',
      '목표 형태(a+bi)와 일치하는지 마지막에 비교한다.',
    ];
  }
  if (domainLabel == '집합·명제·경우의수') {
    return const [
      '대상과 조건을 사건군으로 분해해 겹침과 누락을 보인다.',
      '포함관계/교집합/합집합으로 계산 경로를 분기한다.',
      '순서가 필요한지, 아닌지를 나눈 뒤 계산 공식을 선택한다.',
      '작은 사례로 한 번 검산해서 중복이 없는지 확인한다.',
    ];
  }
  return const [
    '문제에서 쓰이는 “필수 조건”을 먼저 쓴다.',
    '관계식(동치식·포함관계·일대일 대응)을 세워 핵심을 남긴다.',
    '분기를 나눈 뒤 단계별로 식을 정리한다.',
    '마지막은 원래 조건으로 역대입해 위/아래 조건을 점검한다.',
  ];
}

/// 필요한 변수는 개념 키·표제와 레슨 원고다.
/// 작동 원리는 개념의 기본 예제를 한 단계 확장해 변형 연습 문장을 만드는 것이다.
String _authoredAdvancedExample(
  String key,
  String title,
  ConceptLesson lesson,
) {
  if (key.contains('직선') || key.contains('직선의방정식')) {
    return '$title의 기본 조건에 한 점의 좌표를 바꾸어 같은 공식이 유지되는지 계산해 보세요.';
  }
  if (key.contains('이차') || key.contains('부등식')) {
    return '$title의 핵심 조건은 유지하되 계수의 부호만 바꿔 해의 형태가 어떻게 바뀌는지 비교해 보세요.';
  }
  if (key.contains('수열') || key.contains('일반항') || key.contains('합')) {
    return '$title의 일반항에서 n이 커질수록 값이 어떻게 달라지는지 추적하고 첫째항 재검산을 다시 해보세요.';
  }
  if (lesson.example.isNotEmpty) {
    return '${lesson.example}을(를) 같은 구조로 조건 하나만 바꿔 다시 풀어 보세요.';
  }
  return '$title의 연산을 한 번 바꾼 변형문제를 직접 만들고 직접 계산해 보세요.';
}

/// 필요한 변수는 키워드와 레슨 원고다.
/// 작동 원리는 예제풀이를 “조건 추출 → 식 구성 → 정리 → 역대입” 형식으로 고정하는 것이다.
List<String> _authoredAdvancedSolution(
  String key,
  ConceptLesson lesson,
  String domainLabel,
) {
  final generic = const [
    '1) 문제의 “필수 조건”만 먼저 적고, 왜 분리해야 하는지 적는다.',
    '2) 목표에 맞는 기본식을 세우고 단위를 맞춰 정리한다.',
    '3) 중간 단계에서 단위·부호·절댓값 부호를 다시 확인한다.',
    '4) 마지막에 역대입해 조건을 충족하는지 검산한다.',
  ];

  if (key.contains('집합') || key.contains('명제') || key.contains('경우의수')) {
    return const [
      '1) 대상 집합과 조건을 기호로 바꾼 뒤 분해 근거를 표시한다.',
      '2) 포함·교집합·합집합 관계를 사용해 계산 경로를 분리한다.',
      '3) 경우가 겹치면 중복 카운트를 제거하고 누락 여부를 확인한다.',
      '4) 계산값을 구체 사례에 넣어 역검산하고 결론을 고정한다.',
    ];
  }
  if (domainLabel == '복소수') {
    return const [
      '1) 켤레복소수로 분모를 실수로 바꿀 수 있는지 판단한다.',
      '2) 분자·분모를 전개해 실수부와 허수부를 분리한다.',
      '3) a+bi 형태로 정리해 최종 답을 고정한다.',
      '4) 원래 식에 대입해 허수부/실수부 검산을 한다.',
    ];
  }
  if (domainLabel == '행렬') {
    return const [
      '1) 연산 가능 크기 조건을 먼저 확인한다.',
      '2) 성분 계산을 행과 열 기준으로 일관되게 전개한다.',
      '3) 결과 행렬의 크기를 본래 문제 기대치와 맞춘다.',
      '4) 연립방정식 해석이면 다시 식에 대입해 검산한다.',
    ];
  }
  if (lesson.solution.isNotEmpty) {
    final splitSolution = lesson.solution
        .replaceAll('  ', ' ')
        .replaceAll('①', '.')
        .replaceAll('②', '.')
        .replaceAll('③', '.')
        .replaceAll('④', '.')
        .replaceAll('⑤', '.')
        .split(RegExp(r'[\\.。]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return [
      '1) 해설의 첫 방향과 같은 방식으로 식을 다시 정렬한다.',
      for (var i = 0; i < splitSolution.length && i < 4; i++)
        '${i + 2}) ${splitSolution[i]}',
    ];
  }
  return generic;
}

/// 필요한 변수는 정리할 풀이 문자열·개념 키·영역 라벨이다.
/// 작동 원리는 예제 정답 과정 문장을 분해해 "조건-계산-검산" 흐름으로 고정해
/// 기본 예제 풀이의 판단 근거를 일관되게 노출하는 것이다.
List<String> _authoredBasicSolution(
  String solution,
  String key,
  String domainLabel,
) {
  final reasoningSteps = _splitReasoningText(solution);
  if (reasoningSteps.isEmpty) {
    return const [
      '1단계: 문제의 정의역·조건·목표값을 먼저 정리한다.',
      '2단계: 주어진 정의/원리에 맞게 식을 구성하고 왜 그렇게 쓰는지 표시한다.',
      '3단계: 최종 계산 결과를 원래 조건에 대입해 반례가 없는지 검산한다.',
    ];
  }

  final filtered = <String>[];
  for (final step in reasoningSteps) {
    final text = step.trim();
    if (text.isEmpty) continue;
    final cleaned = text.replaceAll(RegExp(r'^\d+\)\s*'), '');
    if (cleaned.isEmpty) continue;
    filtered.add(cleaned);
    if (filtered.length >= 3) break;
  }

  int stepNo = 2;
  final normalized = <String>[];
  for (final item in filtered) {
    normalized.add('$stepNo) $item');
    stepNo++;
  }

  final base = <String>[
    '1) 문제 조건을 “찾는 값”과 “이미 알려진 값”으로 나누어 정리한다.',
    ...normalized,
    '$stepNo) 계산한 결과를 대입해 예외 조건과 부호·범위를 다시 확인한다.',
  ];
  if (base.length < 4) {
    base.insert(1, '2) 핵심식의 단위를 먼저 확인한다.');
  }
  if (base.length > 4) {
    return base.take(4).toList();
  }
  return base;
}

/// 필요한 변수는 문자열이다.
/// 작동 원리는 공통 원고의 번호 매기기 문자를 문장 단위로 바꿔
/// 화면 렌더링에서 안정적으로 잘려 보이도록 만드는 것이다.
List<String> _splitReasoningText(String text) {
  if (text.trim().isEmpty) return const [];
  return text
      .replaceAll('  ', ' ')
      .replaceAll('①', '1)')
      .replaceAll('②', '2)')
      .replaceAll('③', '3)')
      .replaceAll('④', '4)')
      .replaceAll('⑤', '5)')
      .split(RegExp(r'[\\.。]'))
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

/// 필요한 변수는 개념 키·제목·도메인 라벨이다.
/// 작동 원리는 기본·적용 문제를 한 쌍으로 고정해 훈련 난이도를 조절한다.
List<String> _authoredPractice(String key, String title, String domainLabel) {
  if (domainLabel == '복소수') {
    return [
      '$title의 식에서 허수부와 실수부를 분리해 계산하고 a+bi 형태를 쓰세요.',
      '$title의 결과가 실제 문제 조건을 만족하는지 점검하는 확장형 문제를 만들어 보세요.',
    ];
  }
  if (domainLabel == '수열') {
    return [
      '$title의 일반항을 사용해 임의의 n 값을 바꿔 직접 계산해 보세요.',
      '$title의 합 또는 중간항 정보를 조건으로 바꿔 미지수를 결정해 보세요.',
    ];
  }
  if (domainLabel == '미적분Ⅰ') {
    return [
      '$title의 정의를 이용해 간단한 함수의 미분/적분 값을 구하세요.',
      '$title의 그래프·구간 조건을 바꿔 극한/면적/속도값의 변화를 비교하세요.',
    ];
  }
  if (domainLabel == '행렬') {
    return [
      '$title의 기본 연산 조건을 확인하고 결과 행렬의 크기와 성분까지 쓰세요.',
      '$title을 이용해 연립방정식 2개를 만들고 미지수를 푸는 응용문제를 풀어 보세요.',
    ];
  }
  if (domainLabel == '집합·명제·경우의수') {
    return [
      '$title의 조건을 사건군으로 나누고 빠짐없이 집합 분류한 뒤 기본 문제를 풀이하세요.',
      '$title의 조건이 겹치는 응용형 문제를 만들고 반례를 넣어 중복을 제거하세요.',
    ];
  }
  if (domainLabel == '좌표기하' || key.contains('직선') || key.contains('점기울기형')) {
    return [
      '$title의 기본 형태로 점 두 개를 넣어 식을 완성해 보세요.',
      '$title의 예외 조건(분모 0, 수평·수직)을 함께 고려해 확장형으로 풀어보세요.',
    ];
  }
  if (key.contains('이차') || key.contains('부등식')) {
    return [
      '$title의 기본 식으로 부등식/방정식을 하나씩 정리해 보세요.',
      '$title의 그래프 경계(근, 꼭짓점) 조건을 함께 써서 결과를 설명해 보세요.',
    ];
  }
  if (key.contains('로그') || key.contains('지수')) {
    return [
      '$title의 정의역을 먼저 지정하고 진수·조건을 명시한 기본문제를 풀어보세요.',
      '$title의 결과로 점 하나를 주고 그래프 이동으로 역으로 파라미터를 구해보세요.',
    ];
  }
  return [
    '$title의 정의를 한 번 더 써서 기본형 문제를 직접 구성하고 풀이해 보세요.',
    '$title의 조건을 하나 추가해 적용형 문제를 만들고, 마지막에 역대입으로 반례를 걸러보세요.',
  ];
}

/// 필요한 변수는 개념 키·도메인 라벨 및 연습문제다.
/// 작동 원리는 핵심 체크포인트를 한 문장에 정리해 학습자의 판단 기준을 고정하는 것이다.
String _authoredHint(
  String key,
  String title,
  ConceptLesson lesson,
  String domainLabel,
  String basic,
  String advanced,
) {
  if (domainLabel == '미적분Ⅰ') {
    return '미분/적분은 단위와 부호가 바뀌면 결과가 즉시 달라집니다. '
        '결과를 구한 뒤 구간·끝점 조건까지 역대입해 맞는지 확인하세요.';
  }
  if (domainLabel == '복소수') {
    return '허수단위를 i로만 보지 말고 실수부/허수부를 분리해 검사하세요. '
        '케일레벨을 바꿔 본 뒤 반드시 a+bi 형태로 정리합니다.';
  }
  if (domainLabel == '집합·명제·경우의수') {
    return '경우를 나눌 때 “중복”과 “누락”이 가장 먼저 검사 포인트입니다. '
        '문항을 푸는 동안 사건군표를 계속 확인하고, 각 분기가 본래 사건을 모두 덮는지 점검하세요.';
  }
  if (domainLabel == '행렬') {
    return '행렬 곱셈은 계산 순서와 차원 조건이 맞지 않으면 바로 틀립니다. '
        '연산 전 크기 검증과 역대입 검산을 빠뜨리지 마세요.';
  }
  if (domainLabel == '좌표기하') {
    return '수직선(Δx=0), 수평선(Δy=0)은 일반식 분기를 무시하면 즉시 오답입니다. '
        '두 점 좌표 대입 후 항상 역대입 검사까지 하세요.';
  }
  return '문장 → 조건 → 식 → 역대입의 4단을 계속 유지하세요. '
      '각 단계에 “왜”를 한 글자라도 남기면 실수가 크게 줄어듭니다.';
}

/// 필요한 변수는 키와 레슨 원고다.
/// 작동 원리는 오개념을 “초반 실수/중반 실수/끝단 실수”로 분리해 교차검증한다.
List<String> _authoredMisconceptions(String key, ConceptLesson lesson) {
  final warnings = <String>['정의의 적용 대상(조건·정의역·범위)을 확정하지 않은 채 계산을 시작하는 실수.'];
  if (lesson.warning.isNotEmpty) {
    warnings.add(lesson.warning);
  }
  if (key.contains('부등식') || key.contains('이차')) {
    warnings.add('등호 포함 여부(≤, ≥)를 무시하면 구간이 크게 달라집니다.');
  }
  if (key.contains('집합') || key.contains('명제')) {
    warnings.add('명제의 역과 대우를 구분하지 않으면 같은 기호를 잘못 적용합니다.');
  }
  if (key.contains('로그') || key.contains('지수')) {
    warnings.add('로그 진수 조건을 끝나고 확인하면 허수·불능 값이 침투합니다.');
  }
  warnings.add('구한 해를 조건에 넣어 검산하지 않으면 최종 정답이 오답일 수 있습니다.');
  return warnings;
}

/// 필요한 변수는 개념 키와 레슨 원문이다.
/// 작동 원리는 기본형/응용형에 모두 같은 검증 루틴을 쓰도록 답 문장을 정형화하는 것이다.
List<String> _authoredAnswers(String key, ConceptLesson lesson) {
  final checkpoint =
      key.contains('직선') || key.contains('점') || key.contains('좌표')
      ? '두 점/조건 대입'
      : '정의역·부호 검사';
  return [
    '기본: 식이 정의역을 만족하고 계산값을 조건에 대입해 확인한 해.',
    '$checkpoint을 거친 뒤 ${lesson.summary.isNotEmpty ? '원문 요약 형식' : '결과식'}으로 정리한 값.',
  ];
}

/// 필요한 변수는 개념 키·원문·영역 라벨이다.
/// 작동 원리는 각 단원 핵심 문장을 한 줄씩 정리해 요약 블록에서 바로 점검 가능한 형태로 만드는 것이다.
List<String> _authoredSummaryItems(
  String key,
  ConceptLesson lesson,
  String domainLabel,
) {
  final base = lesson.summary.isNotEmpty
      ? lesson.summary
      : '$key은(는) 단계별로 정의·조건·계산을 나눠 보는 개념입니다.';
  return [
    base,
    '정의에서 시작해 원리로 정당화하고, 마지막에 역대입으로 검산하면 실수율이 낮아집니다.',
    '문제의 모양이 바뀌면 같은 조건 판별 기준부터 바꿔서 동일한 판단 틀을 재사용한다.',
  ];
}

/// 필요한 변수는 개념 교재 맵과 페이지 역할 집합이다.
/// 작동 원리는 앱에 노출되기 전에 각 개념이 실제 지면 원고를 갖췄는지 검사하고,
/// 페이지 수·필수 역할·핵심 학습 블록·금지된 범용 문구를 한 번에 보고하는 것이다.
List<String> auditConceptTextbookPages(Map<String, BookData> books) {
  const requiredTemplates = <BookPageTemplate>{
    BookPageTemplate.opening,
    BookPageTemplate.concept,
    BookPageTemplate.principle,
    BookPageTemplate.experiment,
    BookPageTemplate.example,
    BookPageTemplate.solution,
    BookPageTemplate.practice,
    BookPageTemplate.summary,
  };
  const bannedPhrases = <String>[
    '정의->원리->적용->풀이->정리',
    '정의 → 원리 → 적용 → 풀이 → 정리',
    '문항별로 공식만 대입해 풀면',
  ];

  final errors = <String>[];
  for (final entry in books.entries) {
    final pages =
        entry.value.chapters.singleOrNull?.pages ?? const <BookPage>[];
    if (pages.length < 8 || pages.length > 10) {
      errors.add('${entry.key}: 페이지 수 ${pages.length} (허용 8~10)');
    }

    final templates = pages.map((page) => page.template).toSet();
    for (final template in requiredTemplates) {
      if (!templates.contains(template)) {
        errors.add('${entry.key}: ${template.name} 지면 누락');
      }
    }

    final blocks = pages.expand((page) => page.blocks).toList(growable: false);
    for (final type in const [
      BookContentBlockType.question,
      BookContentBlockType.solutionStep,
      BookContentBlockType.thinking,
      BookContentBlockType.derivation,
      BookContentBlockType.verification,
      BookContentBlockType.misconception,
      BookContentBlockType.summary,
      BookContentBlockType.answer,
    ]) {
      if (!blocks.any((block) => block.type == type)) {
        errors.add('${entry.key}: ${type.name} 블록 누락');
      }
    }

    final manuscript = blocks
        .map(
          (block) =>
              '${block.title} ${block.text} ${block.items.join(' ')} ${block.formula}',
        )
        .join(' ');
    for (final phrase in bannedPhrases) {
      if (manuscript.contains(phrase)) {
        errors.add('${entry.key}: 범용 문구 "$phrase" 사용');
      }
    }
  }
  return errors;
}

extension on List<BookChapter> {
  /// 필요한 변수는 장 목록이다.
  /// 작동 원리는 빈 장 목록을 안전하게 처리하면서 첫 장만 사용하는 개념서 구조를 명시한다.
  BookChapter? get singleOrNull => length == 1 ? first : null;
}
