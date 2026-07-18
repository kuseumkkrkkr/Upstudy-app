import 'package:s11/shared/data/models/concept_textbook_editorial.dart';
import 'package:s11/shared/data/models/concept_textbook_lessons.dart';

bool supportsSequences(List<String> tags) => tags.contains('수열');

ConceptEditorialCopy sequencesCopy(String key, String title) {
  final lesson = lessonForConcept(key, title);
  return editorialCopyFromLesson(
    lesson: lesson,
    domainLabel: '수열',
    openingQuestion: '앞의 몇 항만 보고 멀리 떨어진 n번째 항을 계산하려면 어떤 규칙을 찾아야 할까요?',
    intuition:
        '$title은(는) 항의 위치와 값 사이의 규칙을 찾고, 반복되는 변화나 누적을 하나의 식으로 압축하는 개념입니다.',
    symbols: const [
      'n: 항의 위치',
      'aₙ: n번째 항의 값',
      'd: 일정한 차이인 공차',
      'r: 일정한 비인 공비',
      'Sₙ: 첫 n개 항의 합',
    ],
    derivationSteps: const [
      '항의 위치 n과 값 aₙ을 표에 나란히 쓴다.',
      '연속한 항의 차 또는 비를 계산한다.',
      '찾은 규칙으로 일반항을 세운다.',
      'n=1,2를 대입해 처음 항과 맞는지 확인한다.',
    ],
    exampleTwo: '$title의 첫 조건을 바꾸었을 때 일반항과 합이 어떻게 달라지는지 구하시오.',
    exampleTwoSolution: const [
      '바뀐 값이 첫째항, 공차, 공비 중 무엇인지 구분한다.',
      '일반항의 해당 기호만 새 값으로 바꾼다.',
      '처음 두 항을 직접 계산해 새 수열과 일치하는지 확인한다.',
    ],
    practiceBasic: '$title의 규칙을 이용해 10번째 항을 구하시오.',
    practiceAdvanced: '주어진 합 또는 중항 조건을 이용해 첫째항이나 공차·공비를 구하시오.',
    hint: 'n은 항의 값이 아니라 위치입니다. 먼저 n=1일 때 식이 첫째항과 맞는지 보세요.',
    answers: const [
      '기본: 일반항에 n=10을 대입한 값이다.',
      '적용: 구한 값을 원래 합 또는 중항 조건에 다시 넣어 확인한다.',
    ],
    misconceptions: const [
      '일반항의 n−1을 빠뜨리지 않는다.',
      '공차는 빼기로, 공비는 나누기로 확인한다.',
      '합의 마지막 항 번호와 항의 개수를 혼동하지 않는다.',
    ],
    summaryItems: const [
      'n은 위치, aₙ은 값이다.',
      '차이는 선형 변화, 비는 지수 변화를 만든다.',
      '일반항과 합 공식을 구분해 사용한다.',
    ],
  );
}
