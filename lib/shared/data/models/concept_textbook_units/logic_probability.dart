import 'package:s11/shared/data/models/concept_textbook_editorial.dart';
import 'package:s11/shared/data/models/concept_textbook_lessons.dart';

bool supportsLogicProbability(List<String> tags) =>
    tags.any((tag) => tag == '집합' || tag == '명제' || tag == '경우의수');

ConceptEditorialCopy logicProbabilityCopy(String key, String title) {
  final lesson = lessonForConcept(key, title);
  return editorialCopyFromLesson(
    lesson: lesson,
    domainLabel: '집합·명제·경우의 수',
    openingQuestion: '조건을 빠짐없이 분류하고 같은 경우를 중복 없이 세려면 $title을(를) 어떻게 사용해야 할까요?',
    intuition: '$title은(는) 말로 주어진 조건을 집합·논리·선택의 구조로 바꾸어 빠짐과 중복을 확인하는 개념입니다.',
    symbols: const [
      '∈: 어떤 원소가 집합에 속함',
      '⊂: 한 집합이 다른 집합에 포함됨',
      '⇒: 앞 조건이면 뒤 조건이 성립함',
      '∩·∪: 공통 부분과 전체 결합',
    ],
    derivationSteps: const [
      '대상과 조건을 짧은 문장으로 분리한다.',
      '집합 그림·표·나무 그림 중 알맞은 표현을 고른다.',
      '겹치는 경우와 순서의 의미를 확인한다.',
      '모든 경우를 더하거나 곱한 뒤 빠짐과 중복을 검산한다.',
    ],
    exampleTwo: '$title의 조건 하나를 반대로 바꾸었을 때 참값이나 경우의 수가 어떻게 달라지는지 구하시오.',
    exampleTwoSolution: const [
      '바뀐 조건의 진리집합 또는 선택 범위를 다시 적는다.',
      '포함 관계나 순서의 의미를 확인한다.',
      '원래 결과와 달라진 경우만 비교해 결론을 쓴다.',
    ],
    practiceBasic: '$title의 정의를 사용해 주어진 조건의 관계 또는 경우의 수를 구하시오.',
    practiceAdvanced: '두 조건이 겹치거나 제한이 있는 상황에서 빠짐없이 경우를 분류하시오.',
    hint: '식을 세우기 전에 순서가 중요한지, 같은 경우를 두 번 세는지 먼저 물어보세요.',
    answers: const [
      '기본: 정의에 맞는 포함 관계 또는 선택 수를 제시한다.',
      '적용: 겹치는 부분을 한 번만 세었는지 확인한 값이다.',
    ],
    misconceptions: const [
      '명제의 역과 대우를 혼동하지 않는다.',
      '합의 법칙을 쓸 때 겹치는 경우를 확인한다.',
      '순서를 바꾸어도 같은 선택이면 조합으로 센다.',
    ],
    summaryItems: const [
      '조건은 집합으로 바꾸면 관계가 보인다.',
      '순서와 중복 여부가 계산 방법을 결정한다.',
      '작은 경우를 직접 나열하면 공식을 검산할 수 있다.',
    ],
  );
}
