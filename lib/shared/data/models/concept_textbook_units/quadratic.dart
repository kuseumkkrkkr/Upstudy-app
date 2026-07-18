import 'package:s11/shared/data/models/concept_textbook_editorial.dart';
import 'package:s11/shared/data/models/concept_textbook_lessons.dart';

bool supportsQuadratic(List<String> tags) =>
    tags.any((tag) => tag == '이차방정식' || tag == '이차부등식' || tag == '이차함수');

ConceptEditorialCopy quadraticCopy(String key, String title) {
  final lesson = lessonForConcept(key, title);
  return editorialCopyFromLesson(
    lesson: lesson,
    domainLabel: '이차식과 이차함수',
    openingQuestion: '이차식의 근, 포물선의 x절편, 부등식의 경계는 왜 같은 숫자로 연결될까요?',
    intuition:
        '$title은(는) 이차식을 식·근·그래프 세 관점으로 읽는 개념입니다. 한 관점에서 막히면 다른 관점으로 바꾸어 구조를 확인합니다.',
    symbols: const [
      'a: 포물선의 열린 방향과 폭',
      'D=b²−4ac: 실근의 개수를 판단하는 값',
      '근: 그래프가 x축과 만나는 x좌표',
      '꼭짓점: 증가와 감소가 바뀌는 기준점',
    ],
    derivationSteps: const [
      '이차식을 인수분해 또는 완전제곱꼴로 바꾼다.',
      '근 또는 꼭짓점을 찾아 그래프의 기준점을 정한다.',
      'a의 부호로 열린 방향을 판단한다.',
      '방정식·부등식 조건에 맞는 점이나 구간을 선택한다.',
    ],
    exampleTwo: '$title에서 최고차항의 부호를 반대로 바꾸면 근·그래프·부호가 어떻게 변하는지 설명하시오.',
    exampleTwoSolution: const [
      '근이 그대로인지 먼저 확인한다.',
      'a의 부호가 바뀌면 그래프의 열린 방향이 뒤집힌다.',
      '각 구간의 부호가 반대로 바뀌는지 대표값으로 검산한다.',
    ],
    practiceBasic: '$title의 기본식을 인수분해 또는 완전제곱하여 핵심 값을 구하시오.',
    practiceAdvanced: '문자 계수가 포함된 이차식이 주어진 조건을 만족하도록 상수의 범위를 구하시오.',
    hint: '근의 개수 문제는 판별식, 최댓값·최솟값 문제는 꼭짓점부터 확인하세요.',
    answers: const [
      '기본: 근과 꼭짓점을 원래 식에 대입해 확인한다.',
      '적용: 등호 포함 여부와 a의 부호를 함께 반영해야 한다.',
    ],
    misconceptions: const [
      '판별식만 보고 a의 부호를 생략하지 않는다.',
      '부등호가 ≤ 또는 ≥이면 경계의 근을 포함한다.',
      '꼭짓점의 x좌표와 최댓값·최솟값을 혼동하지 않는다.',
    ],
    summaryItems: const [
      '근·그래프·부호는 하나의 구조다.',
      'D는 x축과 만나는 횟수를 알려 준다.',
      'a의 부호는 열린 방향과 구간 부호를 결정한다.',
    ],
  );
}
