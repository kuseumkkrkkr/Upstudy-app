import 'package:s11/shared/data/models/concept_textbook_editorial.dart';
import 'package:s11/shared/data/models/concept_textbook_lessons.dart';

bool supportsFunctions(List<String> tags) => tags.any(
  (tag) =>
      tag == '함수' ||
      tag.contains('유리식') ||
      tag.contains('무리식') ||
      tag == '지수' ||
      tag == '로그' ||
      tag == '지수함수' ||
      tag == '로그함수' ||
      tag.contains('지수방정식') ||
      tag.contains('로그방정식'),
);

ConceptEditorialCopy functionsCopy(String key, String title) {
  final lesson = lessonForConcept(key, title);
  return editorialCopyFromLesson(
    lesson: lesson,
    domainLabel: '함수와 대수',
    openingQuestion:
        '입력값을 바꾸었을 때 출력값이 어떤 규칙으로 움직이는지 $title의 언어로 어떻게 설명할 수 있을까요?',
    intuition:
        '$title은(는) 입력과 출력의 관계를 식과 그래프로 함께 읽는 개념입니다. 계산 전에는 정의역과 허용 조건을 먼저 확인합니다.',
    symbols: const [
      'x: 입력값',
      'f(x): x에 대응하는 출력값',
      '정의역: 입력할 수 있는 값의 범위',
      '치역: 실제로 얻는 출력값의 범위',
    ],
    derivationSteps: const [
      '입력할 수 없는 값을 먼저 제외한다.',
      '식의 안쪽 변화와 바깥쪽 변화를 구분한다.',
      '대표 입력값을 대입해 표와 좌표를 만든다.',
      '식의 성질과 그래프의 모양이 일치하는지 확인한다.',
    ],
    exampleTwo: '$title의 식에서 기준이 되는 상수를 바꾸었을 때 정의역과 그래프의 변화를 설명하시오.',
    exampleTwoSolution: const [
      '바뀐 상수가 식의 안쪽인지 바깥쪽인지 구분한다.',
      '정의역과 기준점을 다시 계산한다.',
      '대표값을 대입해 이동 방향과 증가·감소를 검산한다.',
    ],
    practiceBasic: '$title의 정의역과 대표 함숫값을 구하시오.',
    practiceAdvanced: '$title의 그래프가 주어진 점을 지나도록 상수의 값을 구하시오.',
    hint: '분모, 근호, 로그의 진수처럼 입력을 제한하는 부분부터 표시하세요.',
    answers: const [
      '기본: 제외 조건을 포함한 정의역과 계산값을 함께 쓴다.',
      '적용: 구한 상수를 식에 대입한 뒤 주어진 점을 지나는지 확인한다.',
    ],
    misconceptions: const [
      '정의역 확인을 계산 뒤로 미루지 않는다.',
      'f(x−p)는 오른쪽 p만큼 이동한다.',
      '로그와 무리식에서는 조건을 만족하지 않는 해를 제거한다.',
    ],
    summaryItems: const [
      '함수는 입력과 출력의 규칙이다.',
      '정의역은 모든 계산보다 먼저 확인한다.',
      '식·표·그래프는 같은 관계를 다른 방식으로 표현한다.',
    ],
  );
}
