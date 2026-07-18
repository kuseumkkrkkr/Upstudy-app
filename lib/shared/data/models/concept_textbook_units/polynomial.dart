import 'package:s11/shared/data/models/concept_textbook_editorial.dart';
import 'package:s11/shared/data/models/concept_textbook_lessons.dart';

bool supportsPolynomial(List<String> tags) =>
    tags.contains('다항식') || tags.contains('복소수');

ConceptEditorialCopy polynomialCopy(String key, String title) {
  final lesson = lessonForConcept(key, title);
  return editorialCopyFromLesson(
    lesson: lesson,
    domainLabel: tagsLabel(key),
    openingQuestion: '복잡해 보이는 $title 계산에서 같은 구조를 먼저 찾으면 계산을 얼마나 줄일 수 있을까요?',
    intuition:
        '$title은(는) 식의 항과 계수를 질서 있게 보고, 전개·인수·나눗셈의 관계를 이용해 복잡한 식을 단순한 구조로 바꾸는 개념입니다.',
    symbols: const [
      '항: 덧셈으로 구분되는 식의 조각',
      '계수: 문자에 곱해진 수',
      '차수: 문자가 곱해진 횟수',
      '인수: 곱을 이루는 각각의 식',
    ],
    derivationSteps: const [
      '같은 차수의 항을 찾아 정렬한다.',
      '공통인수나 이미 아는 곱셈공식이 있는지 확인한다.',
      '전개와 인수분해 중 목적에 맞는 방향을 선택한다.',
      '정리한 식을 다시 전개하거나 대입해 검산한다.',
    ],
    exampleTwo: '$title의 조건을 만족하는 간단한 식을 하나 만들고 두 가지 방법으로 계산하시오.',
    exampleTwoSolution: const [
      '항을 차수의 내림차순으로 정리한다.',
      '공식 또는 인수 관계를 이용해 계산한다.',
      '직접 전개한 결과와 비교해 같은 식인지 확인한다.',
    ],
    practiceBasic: '$title의 정의를 이용해 주어진 식의 구조를 구분하고 계산하시오.',
    practiceAdvanced: '계수가 문자로 주어진 식에서 $title 조건을 만족하도록 미지수를 구하시오.',
    hint: '항을 먼저 정렬하고 공통으로 묶을 수 있는 부분을 표시하세요.',
    answers: const [
      '기본: 정리 전후의 차수와 각 항의 계수가 일치해야 한다.',
      '적용: 구한 값을 원래 식에 넣어 항등적으로 성립하는지 확인한다.',
    ],
    misconceptions: const [
      '서로 다른 차수의 항은 바로 더하지 않는다.',
      '인수분해 뒤에는 반드시 전개 검산을 한다.',
      '복소수 계산에서는 i²=−1의 부호를 놓치지 않는다.',
    ],
    summaryItems: const [
      '식의 구조를 먼저 읽는다.',
      '전개와 인수분해는 서로 반대 과정이다.',
      '대입 또는 전개로 결과를 검산한다.',
    ],
  );
}

String tagsLabel(String key) =>
    key.contains('복소수') || key.contains('허수') || key.contains('켤레')
    ? '복소수'
    : '다항식';
