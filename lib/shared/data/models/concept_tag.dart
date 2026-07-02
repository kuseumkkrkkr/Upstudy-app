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

// 개념 태그 데이터
final List<ConceptTag> conceptTagData = [
  ConceptTag(
    name: '공통수학1',
    displayName: '#공통수학1',
    children: [
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
          ConceptTag(
            name: '이차함수의평행이동',
            displayName: '#이차함수의평행이동',
          ),
          ConceptTag(
            name: '이차함수의대칭이동',
            displayName: '#이차함수의대칭이동',
          ),
          ConceptTag(
            name: '이차함수의최대최소',
            displayName: '#이차함수의최대최소',
            children: [
              ConceptTag(name: '최댓값(이차함수)', displayName: '#최댓값'),
              ConceptTag(name: '최솟값(이차함수)', displayName: '#최솟값'),
              ConceptTag(
                name: '정의역에서의최대최소',
                displayName: '#정의역에서의최대최소',
              ),
            ],
          ),
          ConceptTag(
            name: '이차함수와이차방정식',
            displayName: '#이차함수와이차방정식',
          ),
          ConceptTag(
            name: '이차함수와이차부등식',
            displayName: '#이차함수와이차부등식',
          ),
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
            children: [
              ConceptTag(name: '사건의합', displayName: '#사건의합'),
            ],
          ),
          ConceptTag(
            name: '곱의법칙',
            displayName: '#곱의법칙',
            children: [
              ConceptTag(name: '사건의곱', displayName: '#사건의곱'),
            ],
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
              ConceptTag(
                name: '행렬을이용한연립방정식',
                displayName: '#행렬을이용한연립방정식',
              ),
              ConceptTag(name: '가우스소거법', displayName: '#가우스소거법'),
            ],
          ),
        ],
      ),
    ],
  ),
  ConceptTag(
    name: '공통수학2',
    displayName: '#공통수학2',
    children: [
      ConceptTag(
        name: '좌표평면',
        displayName: '#좌표평면',
        children: [
          ConceptTag(
            name: '두점사이의거리',
            displayName: '#두점사이의거리',
            children: [
              ConceptTag(name: '거리공식(두점)', displayName: '#거리공식'),
            ],
          ),
          ConceptTag(
            name: '선분의내분점',
            displayName: '#선분의내분점',
            children: [
              ConceptTag(name: '내분점공식', displayName: '#내분점공식'),
              ConceptTag(name: '외분점', displayName: '#외분점'),
              ConceptTag(name: '중점', displayName: '#중점'),
            ],
          ),
          ConceptTag(
            name: '직선의방정식',
            displayName: '#직선의방정식',
            children: [
              ConceptTag(name: '기울기', displayName: '#기울기'),
              ConceptTag(name: '절편', displayName: '#절편'),
              ConceptTag(name: '점기울기형', displayName: '#점기울기형'),
              ConceptTag(name: '두점을지나는직선', displayName: '#두점을지나는직선'),
            ],
          ),
          ConceptTag(
            name: '두직선의위치관계',
            displayName: '#두직선의위치관계',
            children: [
              ConceptTag(name: '평행조건', displayName: '#평행조건'),
              ConceptTag(name: '수직조건', displayName: '#수직조건'),
              ConceptTag(name: '일치조건', displayName: '#일치조건'),
            ],
          ),
          ConceptTag(
            name: '점과직선사이의거리',
            displayName: '#점과직선사이의거리',
            children: [
              ConceptTag(name: '거리공식(점직선)', displayName: '#거리공식'),
            ],
          ),
        ],
      ),
      ConceptTag(
        name: '원의방정식',
        displayName: '#원의방정식',
        children: [
          ConceptTag(
            name: '원의표준형',
            displayName: '#원의표준형',
            children: [
              ConceptTag(name: '중심', displayName: '#중심'),
              ConceptTag(name: '반지름', displayName: '#반지름'),
            ],
          ),
          ConceptTag(
            name: '원의일반형',
            displayName: '#원의일반형',
            children: [
              ConceptTag(
                name: '일반형을표준형으로',
                displayName: '#일반형을표준형으로',
              ),
            ],
          ),
          ConceptTag(
            name: '평행이동',
            displayName: '#평행이동',
            children: [
              ConceptTag(name: 'x방향이동', displayName: '#x방향이동'),
              ConceptTag(name: 'y방향이동', displayName: '#y방향이동'),
            ],
          ),
          ConceptTag(
            name: '대칭이동',
            displayName: '#대칭이동',
            children: [
              ConceptTag(name: 'x축대칭', displayName: '#x축대칭'),
              ConceptTag(name: 'y축대칭', displayName: '#y축대칭'),
              ConceptTag(name: '원점대칭', displayName: '#원점대칭'),
              ConceptTag(name: '직선대칭', displayName: '#직선대칭'),
            ],
          ),
        ],
      ),
      ConceptTag(
        name: '집합',
        displayName: '#집합',
        children: [
          ConceptTag(
            name: '집합의표현',
            displayName: '#집합의표현',
            children: [
              ConceptTag(name: '원소나열법', displayName: '#원소나열법'),
              ConceptTag(name: '조건제시법', displayName: '#조건제시법'),
            ],
          ),
          ConceptTag(
            name: '집합의연산',
            displayName: '#집합의연산',
            children: [
              ConceptTag(name: '합집합', displayName: '#합집합'),
              ConceptTag(name: '교집합', displayName: '#교집합'),
              ConceptTag(name: '차집합', displayName: '#차집합'),
              ConceptTag(name: '여집합', displayName: '#여집합'),
            ],
          ),
          ConceptTag(
            name: '집합의포함관계',
            displayName: '#집합의포함관계',
            children: [
              ConceptTag(name: '부분집합', displayName: '#부분집합'),
              ConceptTag(name: '진부분집합', displayName: '#진부분집합'),
            ],
          ),
        ],
      ),
      ConceptTag(
        name: '명제',
        displayName: '#명제',
        children: [
          ConceptTag(name: '명제의참거짓', displayName: '#명제의참거짓'),
          ConceptTag(
            name: '명제의역과대우',
            displayName: '#명제의역과대우',
            children: [
              ConceptTag(name: '역', displayName: '#역'),
              ConceptTag(name: '대우', displayName: '#대우'),
              ConceptTag(name: '이', displayName: '#이'),
            ],
          ),
          ConceptTag(
            name: '충분조건과필요조건',
            displayName: '#충분조건과필요조건',
            children: [
              ConceptTag(name: '필요조건', displayName: '#필요조건'),
              ConceptTag(name: '충분조건', displayName: '#충분조건'),
              ConceptTag(name: '필요충분조건', displayName: '#필요충분조건'),
            ],
          ),
        ],
      ),
      ConceptTag(
        name: '함수',
        displayName: '#함수',
        children: [
          ConceptTag(
            name: '함수의정의',
            displayName: '#함수의정의',
            children: [
              ConceptTag(name: '정의역(함수)', displayName: '#정의역'),
              ConceptTag(name: '공역', displayName: '#공역'),
              ConceptTag(name: '치역', displayName: '#치역'),
              ConceptTag(name: '대응', displayName: '#대응'),
            ],
          ),
          ConceptTag(
            name: '합성함수',
            displayName: '#합성함수',
            children: [
              ConceptTag(name: '합성함수의정의', displayName: '#합성함수의정의'),
              ConceptTag(name: '합성함수의성질', displayName: '#합성함수의성질'),
            ],
          ),
          ConceptTag(
            name: '역함수',
            displayName: '#역함수',
            children: [
              ConceptTag(name: '일대일함수', displayName: '#일대일함수'),
              ConceptTag(name: '일대일대응', displayName: '#일대일대응'),
              ConceptTag(name: '역함수구하기', displayName: '#역함수구하기'),
              ConceptTag(name: '역함수의그래프', displayName: '#역함수의그래프'),
            ],
          ),
        ],
      ),
      ConceptTag(
        name: '유리식과유리함수',
        displayName: '#유리식과유리함수',
        children: [
          ConceptTag(
            name: '유리식',
            displayName: '#유리식',
            children: [
              ConceptTag(name: '유리식의계산', displayName: '#유리식의계산'),
              ConceptTag(name: '약분', displayName: '#약분'),
              ConceptTag(name: '통분', displayName: '#통분'),
            ],
          ),
          ConceptTag(
            name: '유리함수의그래프',
            displayName: '#유리함수의그래프',
            children: [
              ConceptTag(name: '점근선', displayName: '#점근선'),
              ConceptTag(name: '쌍곡선', displayName: '#쌍곡선'),
              ConceptTag(name: '유리함수의평행이동', displayName: '#유리함수의평행이동'),
            ],
          ),
        ],
      ),
      ConceptTag(
        name: '무리식과무리함수',
        displayName: '#무리식과무리함수',
        children: [
          ConceptTag(
            name: '무리식',
            displayName: '#무리식',
            children: [
              ConceptTag(name: '무리식의계산', displayName: '#무리식의계산'),
              ConceptTag(name: '유리화', displayName: '#유리화'),
            ],
          ),
          ConceptTag(
            name: '무리함수의그래프',
            displayName: '#무리함수의그래프',
            children: [
              ConceptTag(name: '정의역(무리함수)', displayName: '#정의역'),
              ConceptTag(name: '무리함수의평행이동', displayName: '#무리함수의평행이동'),
            ],
          ),
        ],
      ),
    ],
  ),
  ConceptTag(
    name: '대수',
    displayName: '#대수',
    children: [
      ConceptTag(
        name: '지수',
        displayName: '#지수',
        children: [
          ConceptTag(
            name: '지수의확장',
            displayName: '#지수의확장',
            children: [
              ConceptTag(name: '정수지수', displayName: '#정수지수'),
              ConceptTag(name: '유리수지수', displayName: '#유리수지수'),
              ConceptTag(name: '실수지수', displayName: '#실수지수'),
            ],
          ),
          ConceptTag(
            name: '지수법칙',
            displayName: '#지수법칙',
            children: [
              ConceptTag(name: '지수법칙의성질', displayName: '#지수법칙의성질'),
            ],
          ),
        ],
      ),
      ConceptTag(
        name: '지수함수',
        displayName: '#지수함수',
        children: [
          ConceptTag(name: '지수함수의그래프', displayName: '#지수함수의그래프'),
          ConceptTag(name: '지수함수의성질', displayName: '#지수함수의성질'),
          ConceptTag(name: '지수함수의평행이동', displayName: '#지수함수의평행이동'),
        ],
      ),
      ConceptTag(
        name: '로그',
        displayName: '#로그',
        children: [
          ConceptTag(
            name: '로그의정의',
            displayName: '#로그의정의',
            children: [
              ConceptTag(name: '밑', displayName: '#밑'),
              ConceptTag(name: '진수', displayName: '#진수'),
            ],
          ),
          ConceptTag(
            name: '로그의성질',
            displayName: '#로그의성질',
            children: [
              ConceptTag(name: '로그법칙', displayName: '#로그법칙'),
              ConceptTag(name: '밑의변환', displayName: '#밑의변환'),
              ConceptTag(name: '상용로그', displayName: '#상용로그'),
            ],
          ),
        ],
      ),
      ConceptTag(
        name: '로그함수',
        displayName: '#로그함수',
        children: [
          ConceptTag(name: '로그함수의그래프', displayName: '#로그함수의그래프'),
          ConceptTag(name: '로그함수의성질', displayName: '#로그함수의성질'),
          ConceptTag(name: '로그함수의평행이동', displayName: '#로그함수의평행이동'),
        ],
      ),
      ConceptTag(
        name: '지수방정식과지수부등식',
        displayName: '#지수방정식과지수부등식',
        children: [
          ConceptTag(name: '지수방정식', displayName: '#지수방정식'),
          ConceptTag(name: '지수부등식', displayName: '#지수부등식'),
        ],
      ),
      ConceptTag(
        name: '로그방정식과로그부등식',
        displayName: '#로그방정식과로그부등식',
        children: [
          ConceptTag(name: '로그방정식', displayName: '#로그방정식'),
          ConceptTag(name: '로그부등식', displayName: '#로그부등식'),
          ConceptTag(name: '진수조건', displayName: '#진수조건'),
        ],
      ),
      ConceptTag(
        name: '수열',
        displayName: '#수열',
        children: [
          ConceptTag(
            name: '수열의정의',
            displayName: '#수열의정의',
            children: [
              ConceptTag(name: '항', displayName: '#항'),
              ConceptTag(name: '일반항', displayName: '#일반항'),
              ConceptTag(name: '수열의표현', displayName: '#수열의표현'),
            ],
          ),
          ConceptTag(
            name: '등차수열',
            displayName: '#등차수열',
            children: [
              ConceptTag(name: '공차', displayName: '#공차'),
              ConceptTag(name: '등차수열의일반항', displayName: '#등차수열의일반항'),
              ConceptTag(name: '등차수열의합', displayName: '#등차수열의합'),
              ConceptTag(name: '등차중항', displayName: '#등차중항'),
            ],
          ),
          ConceptTag(
            name: '등비수열',
            displayName: '#등비수열',
            children: [
              ConceptTag(name: '공비', displayName: '#공비'),
              ConceptTag(name: '등비수열의일반항', displayName: '#등비수열의일반항'),
              ConceptTag(name: '등비수열의합', displayName: '#등비수열의합'),
              ConceptTag(name: '등비중항', displayName: '#등비중항'),
            ],
          ),
          ConceptTag(
            name: '합의기호시그마',
            displayName: '#합의기호시그마',
            children: [
              ConceptTag(name: '시그마의성질', displayName: '#시그마의성질'),
              ConceptTag(name: '시그마공식', displayName: '#시그마공식'),
            ],
          ),
          ConceptTag(
            name: '여러가지수열의합',
            displayName: '#여러가지수열의합',
            children: [
              ConceptTag(
                name: '자연수의거듭제곱의합',
                displayName: '#자연수의거듭제곱의합',
              ),
              ConceptTag(name: '계차수열', displayName: '#계차수열'),
              ConceptTag(name: '부분분수', displayName: '#부분분수'),
            ],
          ),
          ConceptTag(
            name: '수학적귀납법',
            displayName: '#수학적귀납법',
            children: [
              ConceptTag(name: '귀납법의원리', displayName: '#귀납법의원리'),
              ConceptTag(name: '귀납법증명', displayName: '#귀납법증명'),
            ],
          ),
        ],
      ),
    ],
  ),
  ConceptTag(
    name: '미적분Ⅰ',
    displayName: '#미적분Ⅰ',
    children: [
      ConceptTag(
        name: '함수의극한',
        displayName: '#함수의극한',
        children: [
          ConceptTag(
            name: '극한의정의',
            displayName: '#극한의정의',
            children: [
              ConceptTag(name: '좌극한', displayName: '#좌극한'),
              ConceptTag(name: '우극한', displayName: '#우극한'),
            ],
          ),
          ConceptTag(
            name: '극한의성질',
            displayName: '#극한의성질',
            children: [
              ConceptTag(name: '극한의사칙연산', displayName: '#극한의사칙연산'),
            ],
          ),
          ConceptTag(
            name: '극한값계산',
            displayName: '#극한값계산',
            children: [
              ConceptTag(
                name: '인수분해를이용한극한',
                displayName: '#인수분해를이용한극한',
              ),
              ConceptTag(
                name: '유리화를이용한극한',
                displayName: '#유리화를이용한극한',
              ),
              ConceptTag(name: '무한대의극한', displayName: '#무한대의극한'),
            ],
          ),
        ],
      ),
      ConceptTag(
        name: '함수의연속',
        displayName: '#함수의연속',
        children: [
          ConceptTag(name: '연속의정의', displayName: '#연속의정의'),
          ConceptTag(name: '불연속', displayName: '#불연속'),
          ConceptTag(name: '연속함수의성질', displayName: '#연속함수의성질'),
          ConceptTag(name: '중간값정리', displayName: '#중간값정리'),
        ],
      ),
      ConceptTag(
        name: '미분계수',
        displayName: '#미분계수',
        children: [
          ConceptTag(name: '미분계수의정의', displayName: '#미분계수의정의'),
          ConceptTag(
            name: '미분계수의기하적의미',
            displayName: '#미분계수의기하적의미',
          ),
        ],
      ),
      ConceptTag(
        name: '도함수',
        displayName: '#도함수',
        children: [
          ConceptTag(name: '도함수의정의', displayName: '#도함수의정의'),
          ConceptTag(name: '미분가능', displayName: '#미분가능'),
          ConceptTag(
            name: '도함수공식',
            displayName: '#도함수공식',
            children: [
              ConceptTag(name: '거듭제곱의미분', displayName: '#거듭제곱의미분'),
              ConceptTag(name: '상수배의미분', displayName: '#상수배의미분'),
              ConceptTag(name: '합차의미분', displayName: '#합차의미분'),
            ],
          ),
        ],
      ),
      ConceptTag(
        name: '접선의방정식',
        displayName: '#접선의방정식',
        children: [
          ConceptTag(name: '접선의기울기', displayName: '#접선의기울기'),
          ConceptTag(name: '접선방정식구하기', displayName: '#접선방정식구하기'),
        ],
      ),
      ConceptTag(
        name: '함수의증가와감소',
        displayName: '#함수의증가와감소',
        children: [
          ConceptTag(name: '증가함수', displayName: '#증가함수'),
          ConceptTag(name: '감소함수', displayName: '#감소함수'),
          ConceptTag(name: '도함수의부호', displayName: '#도함수의부호'),
        ],
      ),
      ConceptTag(
        name: '함수의극대와극소',
        displayName: '#함수의극대와극소',
        children: [
          ConceptTag(name: '극댓값', displayName: '#극댓값'),
          ConceptTag(name: '극솟값', displayName: '#극솟값'),
          ConceptTag(name: '극값의판정', displayName: '#극값의판정'),
        ],
      ),
      ConceptTag(
        name: '미분과최대최소',
        displayName: '#미분과최대최소',
        children: [
          ConceptTag(name: '최댓값(미분)', displayName: '#최댓값'),
          ConceptTag(name: '최솟값(미분)', displayName: '#최솟값'),
          ConceptTag(name: '최대최소문제', displayName: '#최대최소문제'),
        ],
      ),
      ConceptTag(
        name: '속도와가속도',
        displayName: '#속도와가속도',
        children: [
          ConceptTag(name: '위치함수', displayName: '#위치함수'),
          ConceptTag(name: '속도', displayName: '#속도'),
          ConceptTag(name: '가속도', displayName: '#가속도'),
        ],
      ),
      ConceptTag(
        name: '부정적분',
        displayName: '#부정적분',
        children: [
          ConceptTag(name: '부정적분의정의', displayName: '#부정적분의정의'),
          ConceptTag(name: '부정적분공식', displayName: '#부정적분공식'),
          ConceptTag(name: '부정적분의성질', displayName: '#부정적분의성질'),
        ],
      ),
      ConceptTag(
        name: '정적분',
        displayName: '#정적분',
        children: [
          ConceptTag(
            name: '정적분의정의',
            displayName: '#정적분의정의',
            children: [
              ConceptTag(name: '구분구적법', displayName: '#구분구적법'),
            ],
          ),
          ConceptTag(
            name: '정적분의계산',
            displayName: '#정적분의계산',
            children: [
              ConceptTag(name: '미적분의기본정리', displayName: '#미적분의기본정리'),
            ],
          ),
          ConceptTag(
            name: '정적분의성질',
            displayName: '#정적분의성질',
            children: [
              ConceptTag(name: '정적분의선형성', displayName: '#정적분의선형성'),
              ConceptTag(name: '구간의분할', displayName: '#구간의분할'),
            ],
          ),
        ],
      ),
      ConceptTag(
        name: '정적분과넓이',
        displayName: '#정적분과넓이',
        children: [
          ConceptTag(name: '곡선과x축사이의넓이', displayName: '#곡선과x축사이의넓이'),
          ConceptTag(name: '두곡선사이의넓이', displayName: '#두곡선사이의넓이'),
        ],
      ),
      ConceptTag(
        name: '정적분과속도',
        displayName: '#정적분과속도',
        children: [
          ConceptTag(name: '속도와거리', displayName: '#속도와거리'),
          ConceptTag(name: '위치변화량', displayName: '#위치변화량'),
        ],
      ),
    ],
  ),
];
