import 'package:s11/shared/data/models/concept_textbook_editorial.dart';
import 'package:s11/shared/data/models/concept_textbook_lessons.dart';

bool supportsCalculus(List<String> tags) => tags.contains('미적분Ⅰ');

ConceptEditorialCopy calculusCopy(String key, String title) {
  final lesson = lessonForConcept(key, title);
  return editorialCopyFromLesson(
    lesson: lesson,
    domainLabel: '미적분Ⅰ',
    openingQuestion:
        '계속 변하는 양을 한순간의 변화 또는 일정 구간의 누적으로 정확히 나타내려면 $title이(가) 왜 필요할까요?',
    intuition:
        '$title은(는) 함수가 가까운 곳에서 어떻게 변하는지, 또는 작은 변화가 전체에 얼마나 누적되는지를 설명하는 개념입니다.',
    symbols: const [
      'Δx: 입력의 작은 변화',
      'f′(x): 순간변화율을 나타내는 도함수',
      'lim: 값이 한없이 가까워지는 과정',
      '∫: 작은 양을 연속해서 더한 누적',
    ],
    derivationSteps: const [
      '먼저 두 점 또는 작은 구간에서의 변화를 식으로 쓴다.',
      '간격을 더 작게 만들었을 때 값의 움직임을 관찰한다.',
      '극한·미분·적분 가운데 필요한 개념으로 정확한 값을 정한다.',
      '그래프의 방향·넓이·단위를 이용해 결과를 검산한다.',
    ],
    exampleTwo: '$title의 구간이나 기준점을 바꾸었을 때 결과가 어떻게 달라지는지 계산하고 그래프로 설명하시오.',
    exampleTwoSolution: const [
      '새 기준점 또는 구간을 식에 표시한다.',
      '정의에 따라 극한·도함수·적분값을 계산한다.',
      '그래프의 증가·감소 또는 넓이와 부호가 일치하는지 확인한다.',
    ],
    practiceBasic: '$title의 정의를 이용해 간단한 함수의 값을 구하시오.',
    practiceAdvanced: '그래프의 조건과 $title을(를) 함께 이용해 미지수 또는 구간을 구하시오.',
    hint: '함숫값, 변화율, 누적값 중 무엇을 묻는지 먼저 구분하세요.',
    answers: const [
      '기본: 정의식에 함수와 기준값을 정확히 대입한 결과다.',
      '적용: 그래프의 부호·방향·구간 조건을 모두 만족하는 값이다.',
    ],
    misconceptions: const [
      '극한값과 그 점의 함숫값을 혼동하지 않는다.',
      'f′(x)=0인 점이 항상 극값인 것은 아니다.',
      '정적분값과 넓이는 함수가 x축 아래에 있을 때 부호 처리가 다르다.',
    ],
    summaryItems: const [
      '극한은 가까워지는 값을 설명한다.',
      '미분은 순간 변화, 적분은 누적을 나타낸다.',
      '식의 결과를 그래프와 단위로 검산한다.',
    ],
  );
}
