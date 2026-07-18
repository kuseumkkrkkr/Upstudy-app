class ConceptLesson {
  const ConceptLesson({
    required this.objective,
    required this.definition,
    required this.principle,
    required this.example,
    required this.solution,
    required this.warning,
    required this.summary,
  });

  final String objective;
  final String definition;
  final String principle;
  final String example;
  final String solution;
  final String warning;
  final String summary;
}

/// 필요한 변수는 개념 키와 표시 제목이다.
/// 작동 원리는 개념군마다 정의·유도·예제를 실제로 다시 집필하고, 분류되지 않은 항목도 원문을 복사하지 않는 일관된 수업 원고를 반환하는 것이다.
ConceptLesson lessonForConcept(String key, String title) {
  if (key == '계차수열') {
    return const ConceptLesson(
      objective: '앞뒤 항의 차를 새로운 수열로 바꾸어 복잡한 수열의 규칙과 일반항을 찾는다.',
      definition:
          r'수열 {aₙ}의 계차수열은 bₙ = aₙ₊₁ − aₙ으로 정의한다. 항 자체보다 항 사이의 변화량을 보면 숨은 규칙이 드러난다.',
      principle:
          r'aₖ₊₁ = aₖ + bₖ를 k = 1부터 n−1까지 더하면 aₙ = a₁ + Σ(k=1…n−1)bₖ가 된다. 계차수열은 변화량을 누적하는 장치다.',
      example: r'수열 2, 5, 10, 17, 26, …의 일반항을 구하라. 차는 3, 5, 7, 9, …이다.',
      solution:
          r'① bₙ = 2n+1을 찾는다. ② aₙ = 2 + Σ(2k+1) = n²+1을 계산한다. ③ n=1을 대입해 첫째항과 일치하는지 검산한다.',
      warning: '계차수열의 첫 항은 b₁ = a₂−a₁이다. 합의 하한과 상한을 한 항씩 점검한다.',
      summary: r'핵심은 aₙ = a₁ + Σbₖ이다. 차가 등차수열이면 원래 수열은 이차식이 되는 경우가 많다.',
    );
  }
  if (key == '두점을지나는직선' ||
      key == '기울기' ||
      key == '점기울기형' ||
      key == '절편' ||
      key == 'y절편' ||
      key == '평행조건' ||
      key == '수직조건') {
    return const ConceptLesson(
      objective: '좌표 두 개를 변화량의 비로 해석하고, 기울기와 절편으로 직선의 위치를 결정한다.',
      definition:
          r'두 점 A(x₁,y₁), B(x₂,y₂)의 기울기는 m=(y₂−y₁)/(x₂−x₁)이다. 한 점과 기울기가 주어지면 y−y₁=m(x−x₁)로 직선을 정한다.',
      principle:
          r'기울기는 가로로 1만큼 이동할 때 세로로 얼마나 변하는지다. y=mx+b에서 m은 방향, b는 y축과 만나는 위치를 독립적으로 결정한다. 평행선은 기울기가 같고 수직선은 m₁m₂=−1이다.',
      example: r'A(1,2), B(3,6)을 지나는 직선의 방정식을 구하라.',
      solution:
          r'① m=(6−2)/(3−1)=2. ② y−2=2(x−1). ③ y=2x로 정리한다. 두 점을 대입해 검산한다.',
      warning: '분모와 분자의 순서를 다르게 쓰면 기울기의 부호가 바뀐다. x₁=x₂이면 수직선 x=x₁이다.',
      summary: '변화량→기울기→한 점 대입→검산 순서다. m과 b를 움직이면 방향과 위치의 역할을 분리해 볼 수 있다.',
    );
  }
  if (key.contains('인수분해') ||
      key == '완전제곱식' ||
      key == '합차공식' ||
      key == '세제곱공식' ||
      key == '인수정리활용' ||
      key == '조립제법') {
    return const ConceptLesson(
      objective: '전개의 역과정을 구조적으로 판단해 다항식을 곱의 꼴로 바꾸고 방정식 풀이에 연결한다.',
      definition:
          r'인수분해는 다항식을 두 식 이상의 곱으로 나타내는 과정이다. 공통인수, 완전제곱식, 합차, 곱셈공식, 인수정리를 식의 모양에 맞춰 선택한다.',
      principle:
          r'a²−b²=(a+b)(a−b), a²±2ab+b²=(a±b)²는 전개식을 거꾸로 읽은 것이다. f(r)=0이면 x−r이 인수라는 인수정리는 근과 인수를 연결한다.',
      example: r'x³−4x²+x+6을 인수분해하라.',
      solution:
          r'① 정수근 후보에 대입해 f(2)=0을 확인한다. ② x−2로 조립제법을 하면 x²−2x−3이 남는다. ③ (x−2)(x−3)(x+1)을 얻는다.',
      warning: '최고차항·중간항·상수항을 함께 보고 공식을 고른다. 인수분해 뒤 전개 검산은 필수다.',
      summary: '공통인수부터 찾고 공식, 인수정리, 조립제법 순으로 구조를 좁힌다.',
    );
  }
  if (key.contains('이차부등식') ||
      key.contains('이차함수') ||
      key.contains('판별식') ||
      key.contains('근의공식') ||
      key.contains('중근') ||
      key.contains('최댓값(이차') ||
      key.contains('최솟값(이차')) {
    return const ConceptLesson(
      objective: '이차식의 근·그래프·부호를 하나의 흐름으로 연결해 방정식과 부등식을 해결한다.',
      definition:
          r'이차함수 y=ax²+bx+c는 a의 부호로 열린 방향이 정해지고 D=b²−4ac로 x축과의 교점 개수가 정해진다. 부등식은 그래프가 x축 위·아래인 구간을 찾는 문제다.',
      principle:
          r'두 근을 α<β라 하면 a>0일 때 부호는 +,−,+이고 a<0일 때 −,+,−이다. a(x−p)²+q 꼴은 꼭짓점 (p,q)를 즉시 알려 준다.',
      example: r'x²−5x+6<0을 풀고 그래프의 의미를 설명하라.',
      solution:
          r'① (x−2)(x−3)<0으로 인수분해한다. ② 근 2,3을 수직선에 표시한다. ③ 최고차항 계수가 양수이므로 두 근 사이에서 음수다. 답은 2<x<3이다.',
      warning: '부등호가 <인지 ≤인지에 따라 근의 포함 여부가 달라진다. D<0이어도 a의 부호를 확인한다.',
      summary: '근을 찾고 열린 방향을 확인한 뒤 구간별 부호를 읽는다. a,b,c 슬라이더로 각 조건의 역할을 관찰한다.',
    );
  }
  if (key.contains('지수') ||
      key.contains('로그') ||
      key == '밑' ||
      key == '진수' ||
      key.contains('상용로그')) {
    return const ConceptLesson(
      objective: '지수와 로그를 역연산으로 이해하고 밑의 조건·증가성·정의역을 놓치지 않는다.',
      definition:
          r'logₐb=c는 aᶜ=b와 같은 뜻이다. 밑은 a>0, a≠1, 진수는 b>0이어야 한다. a>1이면 증가하고 0<a<1이면 감소한다.',
      principle:
          r'logₐ(MN)=logₐM+logₐN은 지수법칙에서 나온다. 밑변환 logₐb=log꜀b/log꜀a는 같은 수를 다른 기준으로 세는 비율이다.',
      example: r'log₂(x−1)+log₂(x−3)=3을 풀어라.',
      solution:
          r'① 정의역 x>3을 둔다. ② log₂((x−1)(x−3))=3. ③ (x−1)(x−3)=8에서 x=5,−1을 얻고 정의역으로 x=5만 남긴다.',
      warning: '로그의 합은 진수의 곱으로 바꾼다. 풀이 후 진수 조건으로 가짜 해를 걸러낸다.',
      summary: '로그는 지수의 역연산이며 정의역이 풀이의 절반이다. 밑의 변화는 그래프에서 직접 확인한다.',
    );
  }
  if (key.contains('수열') ||
      key == '항' ||
      key == '일반항' ||
      key == '공차' ||
      key == '공비' ||
      key.contains('시그마')) {
    return const ConceptLesson(
      objective: '항 사이의 일정한 차이·비와 누적합을 구분해 일반항과 합 공식을 세운다.',
      definition: r'등차수열은 차가 일정해 aₙ=a₁+(n−1)d, 등비수열은 비가 일정해 aₙ=a₁rⁿ⁻¹이다.',
      principle:
          r'등차수열은 변화량을 누적하므로 선형식이고, 등비수열은 비율을 반복하므로 지수식이다. 등차합은 평균×항수, 등비합은 rS−S로 유도한다.',
      example: r'첫째항 3, 공차 4인 등차수열의 20번째 항과 첫 20항의 합을 구하라.',
      solution:
          r'a₂₀=3+19·4=79, S₂₀=20(3+79)/2=820이다. 항을 직접 더하지 않고 양 끝 항의 평균을 이용한다.',
      warning: '공차는 빼기, 공비는 나누기로 확인한다. 일반항의 n−1을 빠뜨리지 않는다.',
      summary: '차이는 선형 변화, 비는 지수 변화다. 일반항과 합을 분리해 세운다.',
    );
  }
  if (key.contains('미분') ||
      key.contains('극값') ||
      key.contains('접선') ||
      key == '속도' ||
      key == '가속도' ||
      key.contains('도함수')) {
    return const ConceptLesson(
      objective: '평균변화율의 극한으로 미분을 정의하고 도함수의 부호로 그래프의 움직임을 판정한다.',
      definition: r'f′(a)=lim h→0 [f(a+h)−f(a)]/h는 순간변화율이며 그래프에서 접선의 기울기다.',
      principle:
          r'f′>0이면 증가, f′<0이면 감소한다. 부호가 −에서 +로 바뀌면 극소, +에서 −로 바뀌면 극대다. 위치의 미분은 속도, 속도의 미분은 가속도다.',
      example: r'f(x)=x³−3x+2의 극댓값과 극솟값을 구하라.',
      solution:
          r'f′=3(x−1)(x+1). 임계점 −1,1의 부호는 +,−,+이므로 f(−1)=4는 극댓값, f(1)=0은 극솟값이다.',
      warning: 'f′(a)=0만으로 극값이라고 단정하지 않는다. 좌우 부호 변화와 정의역 끝점을 확인한다.',
      summary: '미분은 변화를 측정하고 도함수 부호는 그래프의 방향을 알려 준다.',
    );
  }
  if (key.contains('적분') ||
      key.contains('넓이') ||
      key.contains('구분구적') ||
      key.contains('정적분')) {
    return const ConceptLesson(
      objective: '작은 넓이의 합을 극한으로 보내 적분을 이해하고 미분과의 역관계를 사용한다.',
      definition:
          r'∫ₐᵇf(x)dx는 구간에서 함수와 x축 사이의 부호 있는 넓이다. 부정적분은 도함수가 f(x)인 함수들의 모음이다.',
      principle:
          r'구간을 잘게 나눠 직사각형 넓이를 더하고 분할 수를 무한히 늘리면 정적분이 된다. ∫ₐᵇf=F(b)−F(a) (F′=f)다.',
      example: r'∫₀²(3x²+1)dx를 계산하라.',
      solution:
          r'원시함수 F=x³+x이므로 F(2)−F(0)=10이다. 함수가 x축 아래에 있으면 정적분은 음의 부호를 가진다.',
      warning: '부정적분에는 +C가 필요하고 정적분에서는 소거된다. 넓이는 구간을 근으로 나누어 절댓값을 반영한다.',
      summary: '적분은 누적이며 미분은 순간 변화다. 넓이·거리·누적량을 같은 언어로 표현한다.',
    );
  }
  if (key.contains('집합') ||
      key.contains('원소') ||
      key.contains('부분집합') ||
      key.contains('충분조건') ||
      key.contains('필요조건') ||
      key.contains('명제') ||
      key == '역' ||
      key == '대우') {
    return const ConceptLesson(
      objective: '조건을 진리집합과 논리식으로 번역해 포함 관계와 명제의 참·거짓을 판정한다.',
      definition:
          r'p⇒q가 참이면 p는 q의 충분조건, q는 p의 필요조건이다. p⇔q는 양방향이 모두 참인 필요충분조건이다.',
      principle:
          r'p⇒q의 핵심은 진리집합 P⊆Q다. 대우 ¬q⇒¬p는 원명제와 항상 같은 참값이지만 역 q⇒p는 별도 증명이 필요하다.',
      example: r'p:x=1, q:x²=1일 때 두 조건의 관계를 판정하라.',
      solution:
          r'P={1}, Q={−1,1}이므로 P⊂Q다. p⇒q는 참, q⇒p는 거짓이므로 p는 충분조건이고 필요충분조건은 아니다.',
      warning: '화살표 방향을 말로만 외우지 말고 진리집합 포함 관계로 확인한다.',
      summary: '조건을 집합으로 바꾸고 포함 관계를 확인한 뒤 결론을 문장으로 쓴다.',
    );
  }
  if (key.contains('행렬') ||
      key.contains('역행렬') ||
      key.contains('가우스') ||
      key.contains('벡터') ||
      key == '성분' ||
      key == '스칼라곱') {
    return const ConceptLesson(
      objective: '행과 열의 구조를 유지하며 행렬 연산을 수행하고 연립방정식·벡터 문제에 연결한다.',
      definition:
          r'행렬의 곱은 행과 열의 내적이다. m×n과 n×p를 곱하면 m×p가 된다. 역행렬 A⁻¹은 AA⁻¹=I를 만족한다.',
      principle:
          r'2×2 행렬의 행렬식이 0이 아니어야 역행렬이 존재한다. 가우스 소거법은 기본 행 연산으로 연립방정식을 계단형으로 바꾸는 방법이다.',
      example: r'(1 2; 3 4)(2; 1)을 계산하라.',
      solution: r'첫째 성분은 1·2+2·1=4, 둘째 성분은 3·2+4·1=10이다. 결과는 (4;10)이다.',
      warning: '행렬의 곱은 교환법칙이 성립하지 않는다. 계산 전 차원과 계산 후 각 내적을 확인한다.',
      summary: '행렬은 연립방정식과 변환을 간결하게 표현한다.',
    );
  }
  if (key.contains('순열') ||
      key.contains('조합') ||
      key.contains('팩토리얼') ||
      key.contains('사건의') ||
      key.contains('확률')) {
    return const ConceptLesson(
      objective: '경우를 빠짐없이 나누고 중복을 제거해 순열·조합·확률을 계산한다.',
      definition:
          r'순열은 순서를 고려한 배열이고 조합은 순서를 고려하지 않은 선택이다. n!은 n개를 모두 배열하는 경우의 수이며, nPr=n!/(n−r)!, nCr=n!/{r!(n−r)!}이다.',
      principle:
          r'먼저 한 자리를 정한 뒤 다음 자리를 정하는 곱의 법칙을 사용한다. 순서를 바꿔도 같은 선택이면 r!만큼 중복되므로 순열을 r!로 나누어 조합을 얻는다.',
      example: r'학생 5명 중 회장과 부회장을 한 명씩 뽑는 경우의 수와 대표 2명을 뽑는 경우의 수를 각각 구하라.',
      solution:
          r'직책은 순서가 있으므로 5P2=5·4=20이다. 대표 2명은 순서가 없으므로 5C2=5·4/2=10이다. 같은 사람 쌍을 두 번 센 것이 차이다.',
      warning:
          '자리·역할이 다르면 순열, 단순 선택이면 조합이다. 사건이 서로 겹치는지 확인하지 않고 무조건 곱하거나 더하지 않는다.',
      summary: '경우의 수는 대상, 순서, 중복, 제한 조건을 먼저 문장으로 정리한 뒤 식을 선택한다.',
    );
  }
  if (key.contains('극한') ||
      key.contains('연속') ||
      key.contains('불연속') ||
      key.contains('중간값')) {
    return const ConceptLesson(
      objective: 'x가 한 값에 가까워질 때 함수값의 움직임을 읽고 연속성과 극한을 판정한다.',
      definition:
          r'lim x→a f(x)=L은 x가 a와 같아지는 순간이 아니라 a에 한없이 가까워질 때 f(x)가 L에 가까워진다는 뜻이다. f가 a에서 연속이려면 좌극한·우극한·함숫값이 모두 같아야 한다.',
      principle:
          r'좌극한과 우극한이 다르면 양쪽에서 다가가는 값이 하나로 모이지 않아 극한이 존재하지 않는다. 분모가 0이 되는 식은 인수분해·유리화로 공통 요인을 없앤 뒤 극한을 계산한다.',
      example: r'lim x→2 (x²−4)/(x−2)를 구하고 x=2에서의 연속성을 설명하라.',
      solution:
          r'① x²−4=(x−2)(x+2)로 인수분해한다. ② x≠2에서 식은 x+2와 같으므로 극한은 4다. ③ 원래 식은 x=2에서 정의되지 않으므로 극한은 존재하지만 연속은 아니다.',
      warning: '극한값과 그 점의 함수값은 같은 개념이 아니다. 좌우 극한을 생략하면 점프 불연속을 놓칠 수 있다.',
      summary: '극한은 접근의 언어이고 연속은 극한과 실제 함수값이 만나는 조건이다.',
    );
  }
  if (key.contains('허수') ||
      key.contains('복소수') ||
      key.contains('켤레') ||
      key == '실수와허수') {
    return const ConceptLesson(
      objective: 'i²=−1을 출발점으로 복소수를 좌표평면과 대수식으로 다룬다.',
      definition:
          r'복소수는 a+bi 꼴이며 a는 실수부, b는 허수부, i는 i²=−1을 만족하는 허수단위다. 두 복소수가 같으려면 실수부와 허수부가 각각 같아야 한다.',
      principle:
          r'복소수의 덧셈·뺄셈은 실수부와 허수부를 따로 계산한다. 켤레복소수 a−bi를 곱하면 a²+b²이 되어 분모의 허수 성분을 없앨 수 있다.',
      example: r'(3+2i)/(1−i)를 a+bi 꼴로 나타내라.',
      solution:
          r'분모의 켤레 1+i를 곱한다. 분자는 (3+2i)(1+i)=1+5i, 분모는 (1−i)(1+i)=2다. 따라서 1/2+5/2 i다.',
      warning:
          'i를 일반 변수처럼 약분하지 않는다. i²=−1을 계산할 때 부호를 놓치지 않고 실수부·허수부를 마지막에 분리한다.',
      summary: '복소수는 실수축과 허수축을 가진 평면의 점이며, 켤레는 분모를 실수로 만드는 핵심 도구다.',
    );
  }
  if (key.contains('함수') ||
      key.contains('대응') ||
      key.contains('역함수') ||
      key.contains('평행이동') ||
      key.contains('대칭') ||
      key.contains('증가함수') ||
      key.contains('감소함수')) {
    return const ConceptLesson(
      objective: '함수의 대응 관계와 정의역·치역을 확인하고 그래프 변환을 식으로 표현한다.',
      definition:
          r'함수는 정의역의 각 원소에 치역의 값을 하나씩 대응시키는 관계다. y=f(x)+q는 위아래 q만큼, y=f(x−p)는 오른쪽 p만큼 이동한 그래프다.',
      principle:
          r'입력 x에 먼저 안쪽 변화를 적용하고 바깥쪽 변화가 결과에 적용된다. 역함수는 x와 y를 바꾼 뒤 y에 대해 풀며, 원래 함수와 y=x에 대해 대칭이다.',
      example: r'f(x)=x²의 그래프를 오른쪽 2, 아래 3만큼 이동한 식과 꼭짓점을 구하라.',
      solution:
          r'오른쪽 이동은 x 대신 x−2, 아래 이동은 전체에 −3을 붙인다. 따라서 y=(x−2)²−3이고 꼭짓점은 (2,−3)이다.',
      warning: 'f(x−p)는 왼쪽이 아니라 오른쪽 p 이동이다. 역함수의 정의역과 치역을 서로 바꾸는 것도 잊지 않는다.',
      summary: '함수는 입력과 출력의 규칙이고 그래프 변환은 식의 안쪽·바깥쪽 변화를 읽는 문제다.',
    );
  }
  if (key.contains('유리식') ||
      key.contains('유리함수') ||
      key.contains('무리식') ||
      key.contains('무리함수') ||
      key.contains('유리화') ||
      key == '약분' ||
      key == '통분') {
    return const ConceptLesson(
      objective: '정의되지 않는 값을 먼저 찾고 인수분해·유리화를 이용해 식과 그래프의 구조를 정리한다.',
      definition:
          r'유리식은 다항식의 비이고 분모가 0인 값은 정의역에서 제외한다. 무리식은 근호 안이 실수가 되도록 조건을 세워야 한다.',
      principle:
          r'분수식의 약분은 공통인수를 없애는 과정이지만 약분한 뒤에도 원래 분모가 0인 값은 제외해야 한다. √A−√B는 켤레 √A+√B를 곱해 유리화한다.',
      example: r'(x²−9)/(x−3)을 간단히 하고 x=3에서의 의미를 설명하라.',
      solution:
          r'① x²−9=(x−3)(x+3). ② x≠3에서 x+3으로 약분한다. ③ x=3은 원래 식에서 정의되지 않으므로 그래프에는 (3,6)의 구멍이 남는다.',
      warning: '약분했다고 제외 조건이 사라지지 않는다. 근호 식은 근호 안뿐 아니라 분모가 0인지도 함께 확인한다.',
      summary: '유리·무리식은 계산보다 정의역이 먼저다. 약분과 유리화 뒤 원래 조건으로 검산한다.',
    );
  }
  if (key.contains('좌표') ||
      key.contains('거리공식') ||
      key.contains('내분') ||
      key.contains('외분') ||
      key == '중점' ||
      key == '반지름' ||
      key == '중심' ||
      key.contains('포물선') ||
      key.contains('쌍곡선')) {
    return const ConceptLesson(
      objective: '좌표를 거리·비·대칭의 언어로 읽고 도형의 방정식과 위치 관계를 세운다.',
      definition:
          r'두 점 사이 거리는 √((x₂−x₁)²+(y₂−y₁)²)이고 중점은 좌표의 평균이다. 원은 중심과 반지름으로 (x−a)²+(y−b)²=r²로 표현한다.',
      principle:
          r'거리 공식은 직각삼각형의 피타고라스 정리에서 나온다. 내분점은 선분을 나누는 길이의 비에 따라 좌표를 가중평균하고, 대칭은 기준축까지의 거리가 같다는 조건으로 세운다.',
      example: r'A(1,2), B(5,−4)의 중점과 거리를 구하라.',
      solution:
          r'중점은 ((1+5)/2,(2−4)/2)=(3,−1)이다. 거리는 √((5−1)²+(−4−2)²)=√52=2√13이다.',
      warning: 'x좌표와 y좌표를 섞지 않는다. 내분·외분은 비의 방향과 외분점의 위치를 수직선에 먼저 표시한다.',
      summary: '좌표 문제는 그림을 그리고 기준이 되는 거리·비·대칭 조건을 식으로 번역하는 것이 시작이다.',
    );
  }
  return ConceptLesson(
    objective: '$title의 정의와 핵심 성질을 정확히 말하고 대표 문제에 적용한다.',
    definition:
        '$title은(는) 조건을 수학적 대상과 기호로 번역하는 개념이다. 무엇이 변하고 고정되는지, 정의역과 조건은 무엇인지 먼저 적는다.',
    principle: '$title의 공식은 결과를 외우기보다 정의에서 출발해 한 단계씩 변형할 때 안전하게 사용할 수 있다.',
    example: '$title의 핵심 성질을 이용해 간단한 값을 구하고 사용한 조건을 설명하라.',
    solution: '① 조건과 구할 대상을 분리한다. ② 정의에 맞는 식을 세운다. ③ 정리한 뒤 원래 조건에 대입해 검산한다.',
    warning: '공식의 조건을 생략하지 않는다. 정의역·부호·특수값을 마지막에 확인한다.',
    summary: '$title은 정의와 조건을 먼저 고정하고, 원리를 통해 식을 만들고, 역대입으로 검산한다.',
  );
}
