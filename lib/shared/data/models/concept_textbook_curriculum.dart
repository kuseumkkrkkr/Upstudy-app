import 'package:s11/shared/data/models/concept_textbook_graphs.dart';
import 'package:s11/shared/data/models/concept_textbook_lessons.dart';
import 'package:s11/shared/data/models/concept_textbook_visuals.dart';
import 'package:s11/shared/data/models/textbook.dart';

/// 필요한 변수는 개념 키·제목·태그와 집필 원고다.
/// 작동 원리는 한 문단짜리 개요를 실제 교재 지면으로 확장하고, 각 지면에 시각 자료와 실험 그래프를 필요한 곳에 배치하는 것이다.
List<BookSection> buildExpandedConceptSections({
  required String key,
  required String title,
  required List<String> tags,
}) {
  final lesson = lessonForConcept(key, title);
  final graph = conceptGraphFor(key, [...tags, title]);
  return [
    BookSection(
      title: '이 단원에서 얻어 갈 것',
      paragraphs: [lesson.objective, _whyThisMatters(key), _learningRoute(key)],
    ),
    BookSection(
      title: '개념의 정의와 출발점',
      paragraphs: [
        lesson.definition,
        _definitionDeepDive(key),
        _definitionCheck(key),
      ],
      visuals: conceptVisualsFor(key, 'definition'),
    ),
    BookSection(
      title: '공식이 나오는 원리',
      paragraphs: [
        lesson.principle,
        _principleDerivation(key),
        _representationBridge(key),
      ],
      graph: graph,
      visuals: conceptVisualsFor(key, 'principle'),
    ),
    BookSection(
      title: '대표 예제',
      paragraphs: [
        lesson.example,
        _secondExample(key),
        _exampleChoiceReason(key),
      ],
      visuals: conceptVisualsFor(key, 'example'),
    ),
    BookSection(
      title: '단계별 풀이',
      paragraphs: [
        lesson.solution,
        _solutionReasoning(key),
        _answerVerification(key),
      ],
      visuals: conceptVisualsFor(key, 'solution'),
    ),
    BookSection(
      title: '스스로 풀어 보기',
      paragraphs: [
        _practiceQuestion(key),
        _practiceHint(key),
        _practiceAnswer(key),
      ],
    ),
    BookSection(
      title: '오개념 점검과 핵심 정리',
      paragraphs: [lesson.warning, lesson.summary, _transferQuestion(key)],
    ),
  ];
}

String _whyThisMatters(String key) {
  if (key.contains('미분') || key.contains('도함수') || key.contains('극값')) {
    return '이 개념은 그래프의 모양을 눈으로만 추측하지 않고, 한 점에서의 변화와 전체 구간의 움직임을 수로 설명하게 해 준다.';
  }
  if (key.contains('적분') || key.contains('넓이')) {
    return '작게 나눈 양을 더해 전체를 구하는 생각은 넓이뿐 아니라 이동 거리, 누적량, 평균값을 해석하는 공통 언어가 된다.';
  }
  if (key.contains('로그') || key.contains('지수')) {
    return '반복되는 곱셈과 큰 수의 크기를 비교할 때 지수와 로그는 계산량을 줄이고 변화의 비율을 읽게 해 준다.';
  }
  if (key.contains('수열') || key == '일반항') {
    return '수열은 규칙을 항 하나의 값으로 압축하는 연습이다. 이 압축이 되어야 먼 번째 항과 누적합을 빠르게 계산할 수 있다.';
  }
  return '이 개념은 문제의 조건을 식·그래프·표 중 가장 알맞은 표현으로 번역하는 기본 도구다.';
}

String _learningRoute(String key) {
  if (key.contains('부등식') || key.contains('방정식')) {
    return '학습 순서: 식의 구조 확인 → 경계가 되는 근 찾기 → 구간 또는 해의 조건 확인 → 원래 식에 검산하기.';
  }
  if (key.contains('함수') || key.contains('직선') || key.contains('좌표')) {
    return '학습 순서: 입력과 출력 구분 → 좌표 한 점 표시 → 변화량 또는 대칭 확인 → 식과 그래프를 서로 검산하기.';
  }
  return '학습 순서: 정의를 자기 말로 설명하기 → 공식의 출발점을 따라가기 → 대표 예제를 변형하기 → 조건을 포함해 답 쓰기.';
}

String _definitionDeepDive(String key) {
  if (key.contains('수열')) {
    return '수열에서 n은 값이 아니라 위치다. 따라서 aₙ을 읽을 때 먼저 “몇 번째 항인가?”를 묻고, 그 위치와 항의 값을 혼동하지 않는다.';
  }
  if (key.contains('로그')) {
    return '로그의 진수는 결과로 만들어지는 수이고 밑은 반복의 기준이다. 밑과 진수의 역할을 바꾸면 전혀 다른 식이 된다.';
  }
  if (key.contains('함수')) {
    return '정의역은 입력할 수 있는 값의 집합, 치역은 실제로 나온 값의 집합이다. 공역은 출력이 들어 있다고 약속한 더 큰 집합일 수 있다.';
  }
  if (key.contains('집합') || key.contains('조건')) {
    return '조건을 만족하는 값들을 모으면 진리집합이 된다. 말로 된 조건을 집합으로 바꾸면 포함·교집합·여집합으로 관계를 확인할 수 있다.';
  }
  return '정의의 각 기호가 무엇을 가리키는지 표시해 두면 공식의 적용 조건과 예외를 놓치지 않는다.';
}

String _definitionCheck(String key) {
  return '정의 확인: 이 개념에서 변하는 양, 고정된 양, 허용되는 값의 범위를 각각 한 줄씩 적어 보라.';
}

String _principleDerivation(String key) {
  if (key.contains('직선') || key == '기울기') {
    return r'기울기 공식은 “세로 변화량 ÷ 가로 변화량”이라는 정의에서 바로 나온다. 같은 직선 위의 다른 두 점을 골라도 이 비가 같다는 것이 직선의 핵심 성질이다.';
  }
  if (key.contains('인수분해')) {
    return r'인수분해 공식은 전개식을 역으로 읽은 결과다. 예를 들어 (x+a)(x+b)를 전개하면 x²+(a+b)x+ab이므로, 가운데 계수의 합과 상수항의 곱을 동시에 맞춘다.';
  }
  if (key.contains('이차') || key.contains('판별식')) {
    return r'완전제곱으로 식을 바꾸면 y=a(x−p)²+q가 되고 꼭짓점과 최솟값이 보인다. 근의 공식의 √D는 x축과 만나는 위치를 결정하는 거리 역할을 한다.';
  }
  if (key.contains('미분') || key.contains('도함수')) {
    return r'평균변화율에서 두 점 사이의 간격 h를 0으로 보내면 한 점에서의 접선 기울기가 된다. 도함수는 그래프의 높이가 아니라 그래프가 움직이는 방향을 측정한다.';
  }
  if (key.contains('적분') || key.contains('넓이')) {
    return r'직사각형의 폭을 Δx, 높이를 f(x)로 두고 합을 만든 뒤 Δx를 0으로 보내면 정적분 정의가 된다. 그래서 적분은 넓이의 근삿값을 정확한 값으로 보내는 과정이다.';
  }
  if (key.contains('순열') || key.contains('조합')) {
    return '곱의 법칙은 첫 선택 뒤 가능한 두 번째 선택을 곱하는 원리다. 같은 대상을 순서만 바꿔 중복으로 센다면 그 중복 수를 나누어야 한다.';
  }
  return '공식의 양변이 같은 이유를 작은 수나 간단한 그림으로 먼저 확인한 뒤 일반 기호로 확장한다. 이 과정이 공식 암기를 원리 이해로 바꾼다.';
}

String _representationBridge(String key) {
  if (key.contains('함수') || key.contains('직선') || key.contains('이차')) {
    return '식의 계수를 바꾸었을 때 그래프에서 무엇이 이동하거나 뒤집히는지 JSXGraph로 확인하면 기호의 역할이 시각적으로 고정된다.';
  }
  if (key.contains('수열') || key.contains('시그마')) {
    return '항을 표와 점의 배열로 함께 나타내면 일반항은 점의 위치 규칙, 합은 점들의 누적량이라는 두 관점이 연결된다.';
  }
  return '식·말·표·그림 중 두 가지 이상으로 같은 내용을 다시 표현해 보면 계산 절차와 개념 의미를 구분할 수 있다.';
}

String _secondExample(String key) {
  if (key.contains('직선') || key == '기울기') {
    return r'변형 예제: 기울기가 −1/2이고 점 (4,1)을 지나는 직선은 y−1=−1/2(x−4), 즉 y=−1/2x+3이다.';
  }
  if (key.contains('이차') || key.contains('부등식')) {
    return r'변형 예제: (x−2)²≤0은 제곱이 음수가 될 수 없으므로 x=2 한 점만 해가 된다.';
  }
  if (key.contains('로그')) {
    return r'변형 예제: log₃9=2는 3²=9를 로그 기호로 다시 쓴 것이다. 같은 수라도 밑이 달라지면 값이 달라진다.';
  }
  if (key.contains('미분') || key.contains('극값')) {
    return r'변형 예제: f(x)=x²의 도함수는 2x이고 x=0에서 부호가 −에서 +로 바뀌므로 극솟값은 0이다.';
  }
  return '변형 예제에서는 숫자나 조건 하나만 바꾸어 같은 원리가 그대로 작동하는지 확인한다.';
}

String _exampleChoiceReason(String key) {
  return '이 예제를 고른 이유: 계산 결과보다 문제의 조건이 어떤 표현으로 바뀌는지 관찰하기 좋은 최소 사례이기 때문이다.';
}

String _solutionReasoning(String key) {
  if (key.contains('부등식')) {
    return '풀이의 핵심은 경계값 자체가 아니라 경계 사이 구간의 부호다. 임의의 대표값을 하나씩 넣으면 그래프를 그리지 않아도 부호표를 검증할 수 있다.';
  }
  if (key.contains('로그')) {
    return '로그 방정식은 식을 정리하기 전에 진수 조건을 적어야 한다. 마지막에 그 조건을 다시 대입하는 것이 해의 검증 단계다.';
  }
  return '각 줄에서 사용한 정의나 성질을 옆에 짧게 적으면 계산이 맞아도 논리적으로 건너뛴 부분을 발견할 수 있다.';
}

String _answerVerification(String key) {
  return '검산: 얻은 답을 원래 식 또는 그래프의 조건에 직접 넣어 보라. 답이 조건 밖이면 계산이 맞아 보여도 최종 답으로 채택하지 않는다.';
}

String _practiceQuestion(String key) {
  if (key.contains('직선') || key == '기울기') {
    return r'연습: 점 (−2,3)을 지나고 기울기가 4인 직선의 방정식을 구하라.';
  }
  if (key.contains('수열')) {
    return r'연습: 첫째항 5, 공차 3인 등차수열의 12번째 항과 첫 12항의 합을 구하라.';
  }
  if (key.contains('미분') || key.contains('극값')) {
    return r'연습: f(x)=x³−3x²의 증가·감소 구간과 극값을 판정하라.';
  }
  return '$key의 정의를 사용해야만 풀 수 있는 간단한 예제를 스스로 만들고 풀이하라.';
}

String _practiceHint(String key) {
  return '힌트: 문제에서 먼저 경계값·정의역·초기값 중 무엇이 주어졌는지 표시한 뒤 핵심 공식의 기호와 대응시킨다.';
}

String _practiceAnswer(String key) {
  return '정답 확인 방법: 결과만 비교하지 말고 풀이의 첫 식이 정의와 조건을 모두 반영했는지 확인한다. 풀이가 다르면 서로의 첫 단계부터 비교한다.';
}

String _transferQuestion(String key) {
  return '다음 단원으로 연결: 이 개념을 식이 아니라 그래프·표·실제 변화 상황으로 설명하면 어떤 모습인지 한 번 더 말해 보라.';
}
