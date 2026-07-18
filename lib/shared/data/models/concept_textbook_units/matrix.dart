import 'package:s11/shared/data/models/concept_textbook_editorial.dart';
import 'package:s11/shared/data/models/concept_textbook_lessons.dart';

bool supportsMatrix(List<String> tags) => tags.contains('행렬');

ConceptEditorialCopy matrixCopy(String key, String title) {
  final lesson = lessonForConcept(key, title);
  return editorialCopyFromLesson(
    lesson: lesson,
    domainLabel: '행렬',
    openingQuestion: '여러 식과 수를 표 하나로 묶어 동시에 계산하려면 행과 열을 어떤 규칙으로 읽어야 할까요?',
    intuition:
        '$title은(는) 수를 행과 열에 배치해 여러 관계를 한꺼번에 표현하고 계산하는 개념입니다. 연산 전에는 항상 행렬의 크기를 확인합니다.',
    symbols: const [
      'm×n: m개의 행과 n개의 열',
      'aᵢⱼ: i번째 행, j번째 열의 성분',
      'I: 곱셈의 항등원인 단위행렬',
      'A⁻¹: A와 곱해 I를 만드는 역행렬',
    ],
    derivationSteps: const [
      '각 행렬의 행과 열의 개수를 확인한다.',
      '연산이 가능한 크기인지 판단한다.',
      '같은 위치끼리 또는 행과 열의 내적으로 계산한다.',
      '결과 행렬의 크기와 각 성분을 다시 확인한다.',
    ],
    exampleTwo: '$title 연산의 순서를 바꾸었을 때 결과가 같은지 계산하여 설명하시오.',
    exampleTwoSolution: const [
      '두 연산이 모두 가능한 크기인지 먼저 확인한다.',
      '각 방향의 연산을 행과 열의 규칙대로 계산한다.',
      '대응 성분을 비교해 교환 가능 여부를 결론 낸다.',
    ],
    practiceBasic: '$title의 기본 연산을 수행하고 결과 행렬의 크기를 쓰시오.',
    practiceAdvanced: '행렬을 이용해 두 미지수의 연립방정식을 나타내고 해를 구하시오.',
    hint: '곱셈에서는 앞 행렬의 열 수와 뒤 행렬의 행 수가 같아야 합니다.',
    answers: const [
      '기본: 각 성분과 결과 행렬의 크기를 함께 확인한다.',
      '적용: 구한 해를 원래 두 방정식에 대입해 검산한다.',
    ],
    misconceptions: const [
      '행렬 곱셈은 일반적으로 순서를 바꿀 수 없다.',
      '같은 위치끼리 곱하는 것은 행렬 곱셈이 아니다.',
      '행 연산을 할 때는 한 행 전체에 같은 연산을 적용한다.',
    ],
    summaryItems: const [
      '행과 열의 위치가 의미를 가진다.',
      '연산 전 크기 조건을 확인한다.',
      '행렬은 연립방정식과 변환을 압축해 표현한다.',
    ],
  );
}
