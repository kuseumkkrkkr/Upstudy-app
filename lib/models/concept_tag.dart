// 개념 태그 데이터 모델
class ConceptTag {
  final String name;
  final String displayName;
  final List<ConceptTag> children;
  bool isExpanded;
  bool isSelected;

  ConceptTag({
    required this.name,
    required this.displayName,
    this.children = const [],
    this.isExpanded = false,
    this.isSelected = false,
  });

  ConceptTag copyWith({
    String? name,
    String? displayName,
    List<ConceptTag>? children,
    bool? isExpanded,
    bool? isSelected,
  }) {
    return ConceptTag(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

// 개념 태그 데이터 생성
final List<ConceptTag> conceptTagData = [
  // 공통수학 1
  ConceptTag(
    name: '다항식',
    displayName: '#다항식',
    children: [
      ConceptTag(
        name: '다항식의연산',
        displayName: '#다항식의연산',
        children: [
          ConceptTag(name: '다항식의덧셈', displayName: '#다항식의덧셈'),
          ConceptTag(name: '다항식의뺄셈', displayName: '#다항식의뺄셈'),
          ConceptTag(name: '다항식의곱셈', displayName: '#다항식의곱셈'),
        ],
      ),
      ConceptTag(
        name: '곱셈공식',
        displayName: '#곱셈공식',
        children: [
          ConceptTag(name: '완전제곱식', displayName: '#완전제곱식'),
          ConceptTag(name: '합차공식', displayName: '#합차공식'),
          ConceptTag(name: '세제곱공식', displayName: '#세제곱공식'),
        ],
      ),
      ConceptTag(
        name: '다항식의나눗셈',
        displayName: '#다항식의나눗셈',
        children: [
          ConceptTag(name: '몫과나머지', displayName: '#몫과나머지'),
          ConceptTag(name: '조립제법', displayName: '#조립제법'),
        ],
      ),
      ConceptTag(
        name: '항등식',
        displayName: '#항등식',
        children: [
          ConceptTag(name: '항등식의성질', displayName: '#항등식의성질'),
          ConceptTag(name: '미정계수법', displayName: '#미정계수법'),
        ],
      ),
      ConceptTag(
        name: '나머지정리',
        displayName: '#나머지정리',
        children: [
          ConceptTag(name: '나머지정리증명', displayName: '#나머지정리증명'),
          ConceptTag(name: '나머지정리활용', displayName: '#나머지정리활용'),
        ],
      ),
      ConceptTag(
        name: '인수정리',
        displayName: '#인수정리',
        children: [
          ConceptTag(name: '인수정리증명', displayName: '#인수정리증명'),
          ConceptTag(name: '인수정리활용', displayName: '#인수정리활용'),
        ],
      ),
      ConceptTag(
        name: '인수분해',
        displayName: '#인수분해',
        children: [
          ConceptTag(name: '인수분해공식', displayName: '#인수분해공식'),
          ConceptTag(name: '고차식인수분해', displayName: '#고차식인수분해'),
        ],
      ),
    ],
  ),
  ConceptTag(
    name: '복소수',
    displayName: '#복소수',
    children: [
      ConceptTag(name: '허수단위', displayName: '#허수단위'),
      ConceptTag(name: '실수와허수', displayName: '#실수와허수'),
      ConceptTag(name: '복소수의연산', displayName: '#복소수의연산'),
      ConceptTag(name: '켤레복소수', displayName: '#켤레복소수'),
    ],
  ),
  ConceptTag(
    name: '이차방정식',
    displayName: '#이차방정식',
    children: [
      ConceptTag(
        name: '이차방정식의풀이',
        displayName: '#이차방정식의풀이',
        children: [
          ConceptTag(name: '인수분해법', displayName: '#인수분해법'),
          ConceptTag(name: '완성제곱법', displayName: '#완성제곱법'),
          ConceptTag(name: '근의공식', displayName: '#근의공식'),
        ],
      ),
      ConceptTag(
        name: '이차방정식의판별식',
        displayName: '#이차방정식의판별식',
        children: [
          ConceptTag(name: '판별식과근의개수', displayName: '#판별식과근의개수'),
          ConceptTag(name: '중근조건', displayName: '#중근조건'),
          ConceptTag(name: '실근조건', displayName: '#실근조건'),
        ],
      ),
      ConceptTag(
        name: '이차방정식의근과계수',
        displayName: '#이차방정식의근과계수',
        children: [
          ConceptTag(name: '근과계수의관계', displayName: '#근과계수의관계'),
          ConceptTag(name: '두근의합', displayName: '#두근의합'),
          ConceptTag(name: '두근의곱', displayName: '#두근의곱'),
        ],
      ),
    ],
  ),
  ConceptTag(
    name: '이차함수',
    displayName: '#이차함수',
    children: [
      ConceptTag(
        name: '이차함수의그래프',
        displayName: '#이차함수의그래프',
        children: [
          ConceptTag(name: '포물선', displayName: '#포물선'),
          ConceptTag(name: '축', displayName: '#축'),
          ConceptTag(name: '꼭짓점', displayName: '#꼭짓점'),
          ConceptTag(name: 'y절편', displayName: '#y절편'),
        ],
      ),
      ConceptTag(name: '이차함수의평행이동', displayName: '#이차함수의평행이동'),
      ConceptTag(name: '이차함수의대칭이동', displayName: '#이차함수의대칭이동'),
      ConceptTag(
        name: '이차함수의최대최소',
        displayName: '#이차함수의최대최소',
        children: [
          ConceptTag(name: '최댓값', displayName: '#최댓값'),
          ConceptTag(name: '최솟값', displayName: '#최솟값'),
          ConceptTag(name: '정의역에서의최대최소', displayName: '#정의역에서의최대최소'),
        ],
      ),
      ConceptTag(name: '이차함수와이차방정식', displayName: '#이차함수와이차방정식'),
      ConceptTag(name: '이차함수와이차부등식', displayName: '#이차함수와이차부등식'),
    ],
  ),
  ConceptTag(
    name: '이차부등식',
    displayName: '#이차부등식',
    children: [
      ConceptTag(name: '이차부등식의풀이', displayName: '#이차부등식의풀이'),
      ConceptTag(name: '이차부등식의해', displayName: '#이차부등식의해'),
    ],
  ),
  ConceptTag(
    name: '경우의수',
    displayName: '#경우의수',
    children: [
      ConceptTag(
        name: '합의법칙',
        displayName: '#합의법칙',
        children: [ConceptTag(name: '사건의합', displayName: '#사건의합')],
      ),
      ConceptTag(
        name: '곱의법칙',
        displayName: '#곱의법칙',
        children: [ConceptTag(name: '사건의곱', displayName: '#사건의곱')],
      ),
      ConceptTag(
        name: '순열',
        displayName: '#순열',
        children: [
          ConceptTag(name: '순열의수', displayName: '#순열의수'),
          ConceptTag(name: '팩토리얼', displayName: '#팩토리얼'),
          ConceptTag(name: '중복순열', displayName: '#중복순열'),
          ConceptTag(name: '원순열', displayName: '#원순열'),
        ],
      ),
      ConceptTag(
        name: '조합',
        displayName: '#조합',
        children: [
          ConceptTag(name: '조합의수', displayName: '#조합의수'),
          ConceptTag(name: '조합의성질', displayName: '#조합의성질'),
          ConceptTag(name: '중복조합', displayName: '#중복조합'),
        ],
      ),
    ],
  ),
  ConceptTag(
    name: '행렬',
    displayName: '#행렬',
    children: [
      ConceptTag(
        name: '행렬의정의',
        displayName: '#행렬의정의',
        children: [
          ConceptTag(name: '행', displayName: '#행'),
          ConceptTag(name: '열', displayName: '#열'),
          ConceptTag(name: '성분', displayName: '#성분'),
        ],
      ),
      ConceptTag(
        name: '행렬의연산',
        displayName: '#행렬의연산',
        children: [
          ConceptTag(name: '행렬의덧셈', displayName: '#행렬의덧셈'),
          ConceptTag(name: '행렬의뺄셈', displayName: '#행렬의뺄셈'),
          ConceptTag(name: '행렬의곱셈', displayName: '#행렬의곱셈'),
          ConceptTag(name: '스칼라곱', displayName: '#스칼라곱'),
        ],
      ),
      ConceptTag(
        name: '역행렬',
        displayName: '#역행렬',
        children: [
          ConceptTag(name: '역행렬의정의', displayName: '#역행렬의정의'),
          ConceptTag(name: '역행렬의성질', displayName: '#역행렬의성질'),
          ConceptTag(name: '역행렬구하기', displayName: '#역행렬구하기'),
        ],
      ),
      ConceptTag(
        name: '연립일차방정식과행렬',
        displayName: '#연립일차방정식과행렬',
        children: [
          ConceptTag(name: '행렬을이용한연립방정식', displayName: '#행렬을이용한연립방정식'),
          ConceptTag(name: '가우스소거법', displayName: '#가우스소거법'),
        ],
      ),
    ],
  ),
];
