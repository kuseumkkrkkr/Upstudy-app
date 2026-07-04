import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';

class AiFlowGraphFormulaSummary {
  const AiFlowGraphFormulaSummary({
    required this.unit,
    required this.title,
    required this.formula,
    required this.summary,
  });

  final String unit;
  final String title;
  final String formula;
  final String summary;

  String get searchIndex => '$unit $title $formula $summary'.toLowerCase();
}

class AiFlowGraphExample {
  const AiFlowGraphExample({
    required this.id,
    required this.subject,
    required this.unit,
    required this.title,
    required this.summary,
    required this.searchTerms,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.document,
  });

  final String id;
  final String subject;
  final String unit;
  final String title;
  final String summary;
  final List<String> searchTerms;
  final String sourceLabel;
  final String sourceUrl;
  final AiFlowGraphDocument document;

  String get searchIndex => [
    subject,
    unit,
    title,
    summary,
    ...searchTerms,
    ...document.items.map((item) => item.label),
    ...document.items.map((item) => item.expression ?? ''),
  ].join(' ').toLowerCase();
}

class AiFlowGraphSubjectCatalog {
  const AiFlowGraphSubjectCatalog({
    required this.subject,
    required this.overview,
    required this.formulaSearchTip,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.formulas,
    required this.examples,
  });

  final String subject;
  final String overview;
  final String formulaSearchTip;
  final String sourceLabel;
  final String sourceUrl;
  final List<AiFlowGraphFormulaSummary> formulas;
  final List<AiFlowGraphExample> examples;

  List<String> get units {
    final ordered = <String>[];
    for (final formula in formulas) {
      if (!ordered.contains(formula.unit)) {
        ordered.add(formula.unit);
      }
    }
    for (final example in examples) {
      if (!ordered.contains(example.unit)) {
        ordered.add(example.unit);
      }
    }
    return ordered;
  }
}

const _defaultViewport = AiFlowGraphViewport(
  left: -8,
  right: 8,
  top: 8,
  bottom: -8,
);

final aiFlowGraphCatalog = <AiFlowGraphSubjectCatalog>[
  AiFlowGraphSubjectCatalog(
    subject: '수학 상',
    overview: '다항식, 방정식, 부등식, 함수의 기본 그래프를 좌표평면 감각으로 연결하는 과목입니다.',
    formulaSearchTip: r'추천 검색어: $y-y_1=m(x-x_1)$, $m=\frac{y_2-y_1}{x_2-x_1}$, $y=a(x-p)^2+q$, $y=|x-p|+q$, $\frac{-b\pm\sqrt{b^2-4ac}}{2a}$',
    sourceLabel: '수학방 고등수학 (상), (하) 전체 목차 / 직선의 방정식',
    sourceUrl: 'https://mathbang.net/699',
    formulas: const [
      AiFlowGraphFormulaSummary(
        unit: '직선의 방정식',
        title: '점과 기울기형',
        formula: r'y-y_1=m(x-x_1)',
        summary: '한 점과 기울기가 주어졌을 때 직선을 바로 그래프로 옮길 수 있는 기본형입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '직선의 방정식',
        title: '두 점 사이의 기울기',
        formula: r'm=\frac{y_2-y_1}{x_2-x_1}',
        summary: '두 점을 이용해 직선 그래프의 방향과 증감을 정하는 핵심 공식입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '직선의 방정식',
        title: '기울기-절편형',
        formula: r'y=mx+b',
        summary: '기울기와 y절편을 바꾸며 직선의 회전과 상하 이동을 확인할 수 있습니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '이차함수',
        title: '꼭짓점형 이차함수',
        formula: r'y=a(x-p)^2+q',
        summary: '축과 꼭짓점이 바로 보이므로 포물선 개형을 빠르게 읽기 좋습니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '이차부등식',
        title: '이차식의 부호',
        formula: r'y=ax^2+bx+c',
        summary: 'x축과 만나는 지점을 기준으로 이차부등식의 해 구간을 그래프로 읽을 수 있습니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '이차방정식',
        title: '근의 공식',
        formula: r'x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}',
        summary: '이차함수의 x절편을 계산해 그래프와 방정식을 연결할 때 쓰입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '절댓값함수',
        title: '절댓값 기본형',
        formula: r'y=|x-p|+q',
        summary: '꺾이는 점을 기준으로 V자 개형을 바로 확인할 수 있습니다.',
      ),
    ],
    examples: const [
      AiFlowGraphExample(
        id: 'upper-line',
        subject: '수학 상',
        unit: '직선의 방정식',
        title: '점과 기울기로 만드는 직선',
        summary: '점 A(0, 1)을 지나고 기울기가 3/4인 직선을 기본 형태로 불러옵니다.',
        searchTerms: ['직선', '기울기', '점과 직선', 'A(x1,y1)'],
        sourceLabel: '수학방 직선의 방정식 구하기',
        sourceUrl: 'https://mathbang.net/443',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'line',
              type: AiFlowGraphItemType.function,
              label: 'y = m(x - x1) + y1',
              colorHex: '#2F7CF6',
              expression: 'm*(x-x1)+y1',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: _defaultViewport,
            parameters: [
              AiFlowGraphParameter(
                id: 'm',
                label: '기울기',
                value: 0.75,
                min: -4,
                max: 4,
                step: 0.25,
              ),
              AiFlowGraphParameter(
                id: 'x1',
                label: '점의 x값',
                value: 0,
                min: -5,
                max: 5,
                step: 1,
              ),
              AiFlowGraphParameter(
                id: 'y1',
                label: '점의 y값',
                value: 1,
                min: -5,
                max: 5,
                step: 1,
              ),
            ],
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'upper-quadratic',
        subject: '수학 상',
        unit: '이차함수',
        title: '이차함수의 축과 절편',
        summary: '축 x = 2와 두 근을 시각적으로 확인하기 쉬운 기본 포물선입니다.',
        searchTerms: ['이차함수', '근의 공식', '포물선', '절편'],
        sourceLabel: '수학방 고등수학 (상), (하) 전체 목차',
        sourceUrl: 'https://mathbang.net/699',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'quadratic',
              type: AiFlowGraphItemType.function,
              label: 'y = a(x - h)^2 + k',
              colorHex: '#DD5F34',
              expression: 'a*(x-h)^2+k',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: _defaultViewport,
            parameters: [
              AiFlowGraphParameter(
                id: 'a',
                label: '폭과 방향',
                value: 1,
                min: -3,
                max: 3,
                step: 0.25,
              ),
              AiFlowGraphParameter(
                id: 'h',
                label: '꼭짓점 x값',
                value: 2,
                min: -5,
                max: 5,
                step: 0.5,
              ),
              AiFlowGraphParameter(
                id: 'k',
                label: '꼭짓점 y값',
                value: -1,
                min: -5,
                max: 5,
                step: 0.5,
              ),
            ],
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'upper-absolute',
        subject: '수학 상',
        unit: '절댓값함수',
        title: '절댓값함수의 평행이동',
        summary: '꼭짓점이 이동한 V자형 그래프를 불러와 절댓값 개형을 확인합니다.',
        searchTerms: ['절댓값', 'V자', '평행이동'],
        sourceLabel: '수학방 고등수학 (상), (하) 전체 목차',
        sourceUrl: 'https://mathbang.net/699',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'absolute',
              type: AiFlowGraphItemType.function,
              label: 'y = abs(x - p) + q',
              colorHex: '#238B5E',
              expression: 'abs(x-p)+q',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: _defaultViewport,
            parameters: [
              AiFlowGraphParameter(
                id: 'p',
                label: '꼭짓점 x값',
                value: 1,
                min: -5,
                max: 5,
                step: 0.5,
              ),
              AiFlowGraphParameter(
                id: 'q',
                label: '꼭짓점 y값',
                value: 2,
                min: -5,
                max: 5,
                step: 0.5,
              ),
            ],
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'upper-quadratic-sign',
        subject: '수학 상',
        unit: '이차부등식',
        title: '이차식의 부호 변화',
        summary: '포물선이 x축 위아래로 놓이는 구간을 보며 부등식의 해를 해석합니다.',
        searchTerms: ['이차부등식', '부호', '판별식', 'x축'],
        sourceLabel: 'concept_textbooks 이차부등식 수식 후보',
        sourceUrl: 's11_teacher/lib/models/concept_textbooks.dart',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'quadratic-sign',
              type: AiFlowGraphItemType.function,
              label: 'y = a x^2 + b x + c',
              colorHex: '#8A52E8',
              expression: 'a*x^2+b*x+c',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: _defaultViewport,
            parameters: [
              AiFlowGraphParameter(
                id: 'a',
                label: '이차항 계수',
                value: 1,
                min: -3,
                max: 3,
                step: 0.25,
              ),
              AiFlowGraphParameter(
                id: 'b',
                label: '일차항 계수',
                value: -5,
                min: -8,
                max: 8,
                step: 0.5,
              ),
              AiFlowGraphParameter(
                id: 'c',
                label: '상수항',
                value: 6,
                min: -8,
                max: 8,
                step: 0.5,
              ),
            ],
          ),
        ),
      ),
    ],
  ),
  AiFlowGraphSubjectCatalog(
    subject: '수학 하',
    overview: '도형의 방정식과 기본 함수 변형을 좌표평면에서 읽는 감각이 중심입니다.',
    formulaSearchTip: r'추천 검색어: $x^2+y^2=r^2$, $(x-a)^2+(y-b)^2=r^2$, $y=\pm\sqrt{r^2-x^2}$, $\frac{|ax_1+by_1+c|}{\sqrt{a^2+b^2}}$, $y=\frac{a}{x-p}+q$',
    sourceLabel: '수학방 고등수학 (상), (하) 전체 목차 / 원의 방정식',
    sourceUrl: 'https://mathbang.net/454',
    formulas: const [
      AiFlowGraphFormulaSummary(
        unit: '원의 방정식',
        title: '원점 중심 원',
        formula: r'x^2+y^2=r^2',
        summary: '원점을 중심으로 하는 원의 반지름을 그래프와 바로 연결할 수 있습니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '원의 방정식',
        title: '원의 표준형',
        formula: r'(x-a)^2+(y-b)^2=r^2',
        summary: '중심 이동과 반지름 변화를 한 식으로 읽기 좋습니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '원의 방정식',
        title: '반원 함수형',
        formula: r'y=\pm\sqrt{r^2-x^2}',
        summary: '원을 현재 그래프 엔진에서 함수 두 개로 분리해 안정적으로 표현할 수 있습니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '도형의 방정식',
        title: '점과 직선 사이의 거리',
        formula: r'd=\frac{|ax_1+by_1+c|}{\sqrt{a^2+b^2}}',
        summary: '접선 조건과 도형의 위치 관계를 거리로 정리할 때 핵심입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '유리함수',
        title: '평행이동된 유리함수',
        formula: r'y=\frac{a}{x-p}+q',
        summary: '점근선과 그래프의 위치 변화를 시각적으로 해석하기 좋습니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '무리함수',
        title: '평행이동된 무리함수',
        formula: r'y=a\sqrt{x-p}+q',
        summary: '시작점과 증가 방향이 식의 계수에 따라 어떻게 바뀌는지 실습하기 좋습니다.',
      ),
    ],
    examples: const [
      AiFlowGraphExample(
        id: 'lower-circle',
        subject: '수학 하',
        unit: '원의 방정식',
        title: '반원 두 개로 보는 원의 그래프',
        summary: '원의 방정식을 윗반원과 아랫반원 함수로 분리해 한 화면에 띄웁니다.',
        searchTerms: ['원', '반원', 'sqrt', '도형의 방정식'],
        sourceLabel: '수학방 원의 방정식, 원의 방정식 표준형',
        sourceUrl: 'https://mathbang.net/454',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'upper-semicircle',
              type: AiFlowGraphItemType.function,
              label: 'y = sqrt(r^2 - x^2)',
              colorHex: '#238B5E',
              expression: 'sqrt(r^2-x^2)',
            ),
            AiFlowGraphItem(
              id: 'lower-semicircle',
              type: AiFlowGraphItemType.function,
              label: 'y = -sqrt(r^2 - x^2)',
              colorHex: '#8A52E8',
              expression: '-sqrt(r^2-x^2)',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: -4, right: 4, top: 4, bottom: -4),
            parameters: [
              AiFlowGraphParameter(
                id: 'r',
                label: '반지름',
                value: 3,
                min: 1,
                max: 6,
                step: 0.5,
              ),
            ],
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'lower-rational',
        subject: '수학 하',
        unit: '유리함수',
        title: '점근선을 가진 유리함수',
        summary: '수직·수평 점근선을 가지는 기본 유리함수 이동형을 확인합니다.',
        searchTerms: ['유리함수', '점근선', '쌍곡선형'],
        sourceLabel: '수학방 고등수학 (상), (하) 전체 목차',
        sourceUrl: 'https://mathbang.net/699',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'rational',
              type: AiFlowGraphItemType.function,
              label: 'y = a/(x - p) + q',
              colorHex: '#2F7CF6',
              expression: 'a/(x-p)+q',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: -6, right: 6, top: 6, bottom: -6),
            parameters: [
              AiFlowGraphParameter(
                id: 'a',
                label: '분자 계수',
                value: 2,
                min: -5,
                max: 5,
                step: 0.5,
              ),
              AiFlowGraphParameter(
                id: 'p',
                label: '수직 점근선',
                value: 1,
                min: -4,
                max: 4,
                step: 0.5,
              ),
              AiFlowGraphParameter(
                id: 'q',
                label: '수평 점근선',
                value: 1,
                min: -4,
                max: 4,
                step: 0.5,
              ),
            ],
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'lower-radical',
        subject: '수학 하',
        unit: '무리함수',
        title: '무리함수의 시작점과 방향',
        summary: '루트 그래프의 시작점과 위아래 반전, 상하 이동을 변수로 조절합니다.',
        searchTerms: ['무리함수', '루트', '시작점', '평행이동'],
        sourceLabel: '수학방 고등수학 (상), (하) 전체 목차',
        sourceUrl: 'https://mathbang.net/699',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'radical',
              type: AiFlowGraphItemType.function,
              label: 'y = a sqrt(x - p) + q',
              colorHex: '#DD5F34',
              expression: 'a*sqrt(x-p)+q',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: -4, right: 8, top: 6, bottom: -6),
            parameters: [
              AiFlowGraphParameter(
                id: 'a',
                label: '방향과 폭',
                value: 1,
                min: -3,
                max: 3,
                step: 0.25,
              ),
              AiFlowGraphParameter(
                id: 'p',
                label: '시작 x값',
                value: 0,
                min: -4,
                max: 4,
                step: 0.5,
              ),
              AiFlowGraphParameter(
                id: 'q',
                label: '상하 이동',
                value: 0,
                min: -4,
                max: 4,
                step: 0.5,
              ),
            ],
          ),
        ),
      ),
    ],
  ),
  AiFlowGraphSubjectCatalog(
    subject: '수학 1',
    overview: '지수, 로그, 삼각함수, 수열처럼 변화 패턴을 식과 개형으로 읽는 과목입니다.',
    formulaSearchTip: r'추천 검색어: $y=a^x$, $y=\log_a x$, $y=a\sin(bx+c)+d$, $a_n=a_1+(n-1)d$, $a_n=a_1r^{n-1}$',
    sourceLabel: '수학방 고등학교 대수 전체 목차',
    sourceUrl: 'https://mathbang.net/724',
    formulas: const [
      AiFlowGraphFormulaSummary(
        unit: '지수함수와 로그함수',
        title: '지수함수',
        formula: r'y=a^x\ (a>0,\ a\neq1)',
        summary: '빠른 증가와 감소 패턴을 그리기에 가장 직관적인 함수입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '지수함수와 로그함수',
        title: '로그함수',
        formula: r'y=\log_a x\ (a>0,\ a\neq1)',
        summary: '지수함수의 역함수로서 정의역 제한과 증가율을 함께 읽습니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '삼각함수',
        title: '사인함수 이동형',
        formula: r'y=a\sin(bx+c)+d',
        summary: '진폭, 주기, 위상 이동, 수직 이동을 한 번에 표현합니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '삼각함수',
        title: '탄젠트함수 이동형',
        formula: r'y=a\tan(bx+c)+d',
        summary: '반복되는 점근선과 기울기 변화를 함께 살펴볼 수 있는 그래프입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '수열',
        title: '등차수열 일반항',
        formula: r'a_n=a_1+(n-1)d',
        summary: '항 번호를 x축처럼 보면 직선형 증가를 시각화하기 좋습니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '수열',
        title: '등비수열 일반항',
        formula: r'a_n=a_1r^{n-1}',
        summary: '항 번호에 따라 지수적으로 커지거나 줄어드는 패턴을 보여줍니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '수열',
        title: '이차식으로 정의된 수열',
        formula: r'a_n=n^2+1',
        summary: '항 번호가 커질수록 차이가 더 빠르게 커지는 패턴을 점으로 확인할 수 있습니다.',
      ),
    ],
    examples: const [
      AiFlowGraphExample(
        id: 'math1-exp-log',
        subject: '수학 1',
        unit: '지수함수와 로그함수',
        title: '지수함수와 로그함수 비교',
        summary: '증가 속도와 역함수 감각을 같은 화면에서 비교하는 기본 예제입니다.',
        searchTerms: ['지수함수', '로그함수', '역함수', '밑'],
        sourceLabel: '수학방 고등학교 대수 전체 목차',
        sourceUrl: 'https://mathbang.net/724',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'exp',
              type: AiFlowGraphItemType.function,
              label: 'y = a^x',
              colorHex: '#2F7CF6',
              expression: 'a^x',
            ),
            AiFlowGraphItem(
              id: 'log',
              type: AiFlowGraphItemType.function,
              label: 'y = ln(x)/ln(a)',
              colorHex: '#DD5F34',
              expression: 'ln(x)/ln(a)',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: -3, right: 6, top: 6, bottom: -3),
            parameters: [
              AiFlowGraphParameter(
                id: 'a',
                label: '밑',
                value: 2,
                min: 1.2,
                max: 5,
                step: 0.2,
              ),
            ],
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'math1-trig',
        subject: '수학 1',
        unit: '삼각함수',
        title: '사인과 코사인의 주기 비교',
        summary: '주기와 위상 차이를 가장 간단하게 비교할 수 있는 조합입니다.',
        searchTerms: ['삼각함수', '사인', '코사인', '주기', '진폭'],
        sourceLabel: '수학방 고등학교 대수 전체 목차',
        sourceUrl: 'https://mathbang.net/724',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'sin',
              type: AiFlowGraphItemType.function,
              label: 'y = A sin(Bx + C) + D',
              colorHex: '#238B5E',
              expression: 'A*sin(B*x+C)+D',
            ),
            AiFlowGraphItem(
              id: 'cos',
              type: AiFlowGraphItemType.function,
              label: 'y = A cos(Bx + C) + D',
              colorHex: '#8A52E8',
              expression: 'A*cos(B*x+C)+D',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: -7, right: 7, top: 2, bottom: -2),
            parameters: [
              AiFlowGraphParameter(
                id: 'A',
                label: '진폭',
                value: 1,
                min: 0.2,
                max: 3,
                step: 0.2,
              ),
              AiFlowGraphParameter(
                id: 'B',
                label: '주기 계수',
                value: 1,
                min: 0.5,
                max: 3,
                step: 0.25,
              ),
              AiFlowGraphParameter(
                id: 'C',
                label: '좌우 이동',
                value: 0,
                min: -3.14,
                max: 3.14,
                step: 0.157,
              ),
              AiFlowGraphParameter(
                id: 'D',
                label: '상하 이동',
                value: 0,
                min: -2,
                max: 2,
                step: 0.25,
              ),
            ],
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'math1-geometric',
        subject: '수학 1',
        unit: '수열',
        title: '등비수열의 연속형 개형',
        summary: '등비수열 일반항의 성장 감각을 지수함수형 그래프로 단순화해 봅니다.',
        searchTerms: ['수열', '등비수열', '지수성장'],
        sourceLabel: '수학방 고등학교 대수 전체 목차',
        sourceUrl: 'https://mathbang.net/724',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'sequence-growth',
              type: AiFlowGraphItemType.function,
              label: 'y = a r^x',
              colorHex: '#D6477C',
              expression: 'a*r^x',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: _defaultViewport,
            parameters: [
              AiFlowGraphParameter(
                id: 'a',
                label: '첫 크기',
                value: 1,
                min: 0.5,
                max: 5,
                step: 0.5,
              ),
              AiFlowGraphParameter(
                id: 'r',
                label: '공비',
                value: 1.5,
                min: 0.5,
                max: 3,
                step: 0.1,
              ),
            ],
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'math1-tangent',
        subject: '수학 1',
        unit: '삼각함수',
        title: '탄젠트함수의 점근선 감각',
        summary: '탄젠트 그래프의 주기와 기울기 변화를 변수로 조절합니다.',
        searchTerms: ['삼각함수', '탄젠트', '점근선', '주기'],
        sourceLabel: '수학방 고등학교 대수 전체 목차',
        sourceUrl: 'https://mathbang.net/724',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'tan',
              type: AiFlowGraphItemType.function,
              label: 'y = a tan(bx)',
              colorHex: '#927A1F',
              expression: 'a*tan(b*x)',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: -4, right: 4, top: 6, bottom: -6),
            parameters: [
              AiFlowGraphParameter(
                id: 'a',
                label: '세로 배율',
                value: 1,
                min: 0.5,
                max: 3,
                step: 0.25,
              ),
              AiFlowGraphParameter(
                id: 'b',
                label: '주기 계수',
                value: 1,
                min: 0.5,
                max: 3,
                step: 0.25,
              ),
            ],
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'math1-quadratic-sequence',
        subject: '수학 1',
        unit: '수열',
        title: 'a_n = n^2 + 1 점 그래프',
        summary: '개념 파일에서 추출된 수열 공식을 점 그래프로 옮겨 항의 증가 속도를 확인합니다.',
        searchTerms: ['수열', 'an', 'n^2+1', '점그래프'],
        sourceLabel: 'concept_textbooks 수열 수식 후보',
        sourceUrl: 's11_teacher/lib/models/concept_textbooks.dart',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'quadratic-sequence',
              type: AiFlowGraphItemType.scatter,
              label: 'a_n = n^2 + 1',
              colorHex: '#2F7CF6',
              xValues: [1, 2, 3, 4, 5, 6],
              yValues: [2, 5, 10, 17, 26, 37],
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: 0, right: 7, top: 42, bottom: 0),
          ),
        ),
      ),
    ],
  ),
  AiFlowGraphSubjectCatalog(
    subject: '수학 2',
    overview: '함수의 극한, 미분, 적분을 그래프 해석과 연결해 변화율과 넓이를 다루는 과목입니다.',
    formulaSearchTip: "추천 검색어: \$\\lim_{x\\to a}f(x)\$, \$f''(x)=\\lim_{h\\to0}\\frac{f(x+h)-f(x)}{h}\$, \$y=f(a)+f'(a)(x-a)\$, \$\\int_a^bf(x)\\,dx\$, \$\\frac{f(b)-f(a)}{b-a}\$",
    sourceLabel: '중·고등수학 자료방 수학2 총정리',
    sourceUrl: 'https://mathcloud.tistory.com/7',
    formulas: const [
      AiFlowGraphFormulaSummary(
        unit: '함수의 극한',
        title: '함수의 극한',
        formula: r'\lim_{x\to a}f(x)',
        summary: '함수값보다 접근하는 y값의 흐름을 그래프로 읽게 만드는 기본 개념입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '미분',
        title: '미분계수',
        formula: "f''(x)=\\lim_{h\\to0}\\frac{f(x+h)-f(x)}{h}",
        summary: '접선의 기울기를 정의하는 식이라 함수와 직선을 함께 보는 예제와 잘 맞습니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '미분',
        title: '접선의 방정식',
        formula: "y=f(a)+f'(a)(x-a)",
        summary: '한 점에서의 접선 그래프를 직접 만드는 데 바로 쓰입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '적분',
        title: '정적분',
        formula: r'\int_a^bf(x)\,dx',
        summary: '구간 안 누적량과 넓이 해석의 기반이 되는 공식입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '미분',
        title: '평균변화율',
        formula: r'\frac{f(b)-f(a)}{b-a}',
        summary: '두 점을 잇는 할선 기울기와 순간변화율을 비교할 때 사용합니다.',
      ),
    ],
    examples: const [
      AiFlowGraphExample(
        id: 'math2-tangent',
        subject: '수학 2',
        unit: '미분',
        title: '포물선과 한 점에서의 접선',
        summary: '함수와 접선의 기울기 관계를 바로 확인할 수 있도록 만든 기본 예제입니다.',
        searchTerms: ['미분계수', '접선', '포물선', '기울기'],
        sourceLabel: '중·고등수학 자료방 수학2 총정리',
        sourceUrl: 'https://mathcloud.tistory.com/7',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'parabola',
              type: AiFlowGraphItemType.function,
              label: 'y = x^2',
              colorHex: '#2F7CF6',
              expression: 'x^2',
            ),
            AiFlowGraphItem(
              id: 'tangent',
              type: AiFlowGraphItemType.function,
              label: '접점 t에서의 접선',
              colorHex: '#D6477C',
              expression: '2*t*(x-t)+t^2',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: _defaultViewport,
            parameters: [
              AiFlowGraphParameter(
                id: 't',
                label: '접점 x값',
                value: -1,
                min: -4,
                max: 4,
                step: 0.25,
              ),
            ],
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'math2-average-rate',
        subject: '수학 2',
        unit: '미분',
        title: '함수와 평균변화율 직선',
        summary: '삼차함수와 직선을 함께 배치해 변화율 감각을 읽는 예제입니다.',
        searchTerms: ['평균변화율', '할선', '삼차함수'],
        sourceLabel: '중·고등수학 자료방 수학2 총정리',
        sourceUrl: 'https://mathcloud.tistory.com/7',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'cubic-base',
              type: AiFlowGraphItemType.function,
              label: 'y = x^3 - x',
              colorHex: '#238B5E',
              expression: 'x^3-x',
            ),
            AiFlowGraphItem(
              id: 'secant-like',
              type: AiFlowGraphItemType.function,
              label: 'y = 3x - 2',
              colorHex: '#8A52E8',
              expression: '3*x-2',
            ),
          ],
          settings: AiFlowGraphSettings(viewport: _defaultViewport),
        ),
      ),
    ],
  ),
  AiFlowGraphSubjectCatalog(
    subject: '미적분',
    overview: '수열의 극한, 지수·로그·삼각함수의 미분, 적분을 더 깊게 그래프로 읽는 과목입니다.',
    formulaSearchTip: r'추천 검색어: $\frac{d}{dx}\ln x=\frac1x$, $\frac{d}{dx}e^x=e^x$, $\frac{d}{dx}\sin x=\cos x$, $\sum_{k=1}^{n}a_k$, $\int f(x)\,dx$',
    sourceLabel: '중·고등수학 자료방 미적분 개념 총정리',
    sourceUrl: 'https://mathcloud.tistory.com/12',
    formulas: const [
      AiFlowGraphFormulaSummary(
        unit: '미분법',
        title: '자연로그의 미분',
        formula: r'\frac{d}{dx}\ln x=\frac1x',
        summary: '원함수와 도함수의 관계를 가장 명확하게 비교할 수 있는 대표 예시입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '미분법',
        title: '지수함수의 미분',
        formula: r'\frac{d}{dx}e^x=e^x',
        summary: '함수와 도함수의 모양이 같아지는 대표적인 변화율 예제입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '미분법',
        title: '삼각함수의 미분',
        formula: r'\frac{d}{dx}\sin x=\cos x',
        summary: '주기함수의 기울기 변화를 시각적으로 비교할 수 있습니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '적분법',
        title: '부정적분',
        formula: r'\int f(x)\,dx',
        summary: '도함수와 원시함수 관계를 그래프 쌍으로 읽을 때 쓰입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '수열의 극한',
        title: '급수의 기본형',
        formula: r'\sum_{k=1}^{n}a_k',
        summary: '누적량이라는 관점에서 적분과 연결되는 이산적 모델입니다.',
      ),
    ],
    examples: const [
      AiFlowGraphExample(
        id: 'calculus-log-derivative',
        subject: '미적분',
        unit: '미분법',
        title: 'ln(x)와 1/x 비교',
        summary: '원함수와 도함수를 동시에 보며 기울기의 크기 변화를 읽는 예제입니다.',
        searchTerms: ['미적분', 'ln', '1/x', '도함수', '로그 미분'],
        sourceLabel: '중·고등수학 자료방 미적분 개념 총정리',
        sourceUrl: 'https://mathcloud.tistory.com/12',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'ln',
              type: AiFlowGraphItemType.function,
              label: 'y = ln(x)',
              colorHex: '#DD5F34',
              expression: 'ln(x)',
            ),
            AiFlowGraphItem(
              id: 'inverse',
              type: AiFlowGraphItemType.function,
              label: 'y = 1/x',
              colorHex: '#238B5E',
              expression: '1/x',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: -1, right: 8, top: 4, bottom: -4),
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'calculus-cubic-derivative',
        subject: '미적분',
        unit: '미분법',
        title: '삼차함수와 도함수',
        summary: '증가·감소 구간과 도함수 부호를 한 화면에서 확인할 수 있습니다.',
        searchTerms: ['삼차함수', '도함수', '증가감소', '부호'],
        sourceLabel: '중·고등수학 자료방 미적분 개념 총정리',
        sourceUrl: 'https://mathcloud.tistory.com/12',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'cubic',
              type: AiFlowGraphItemType.function,
              label: 'y = x^3 - 3x',
              colorHex: '#2F7CF6',
              expression: 'x^3-3*x',
            ),
            AiFlowGraphItem(
              id: 'cubic-derivative',
              type: AiFlowGraphItemType.function,
              label: 'y = 3x^2 - 3',
              colorHex: '#8A52E8',
              expression: '3*x^2-3',
            ),
          ],
          settings: AiFlowGraphSettings(viewport: _defaultViewport),
        ),
      ),
      AiFlowGraphExample(
        id: 'calculus-exp-derivative',
        subject: '미적분',
        unit: '미분법',
        title: 'e^x와 자기 자신인 도함수',
        summary: '함수와 도함수가 일치하는 지수함수의 대표적 성질을 그래프로 확인합니다.',
        searchTerms: ['e^x', '도함수', '지수함수'],
        sourceLabel: '중·고등수학 자료방 미적분 개념 총정리',
        sourceUrl: 'https://mathcloud.tistory.com/12',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'exp-self',
              type: AiFlowGraphItemType.function,
              label: 'y = e^x',
              colorHex: '#D6477C',
              expression: 'e^x',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: -4, right: 4, top: 8, bottom: -1),
          ),
        ),
      ),
    ],
  ),
  AiFlowGraphSubjectCatalog(
    subject: '기하',
    overview: '이차곡선과 벡터를 좌표평면에서 해석하는 과목이라 표준형 방정식을 곧바로 그래프로 옮기기 좋습니다.',
    formulaSearchTip: r'추천 검색어: $\frac{x^2}{a^2}+\frac{y^2}{b^2}=1$, $y^2=4px$, $\frac{x^2}{a^2}-\frac{y^2}{b^2}=1$, $y=\pm b\sqrt{\frac{x^2}{a^2}-1}$, $\vec{a}\cdot\vec{b}=|\vec{a}||\vec{b}|\cos\theta$',
    sourceLabel: '중·고등수학 자료방 기하 개념 총정리',
    sourceUrl: 'https://mathcloud.tistory.com/14',
    formulas: const [
      AiFlowGraphFormulaSummary(
        unit: '이차곡선',
        title: '타원의 표준형',
        formula: r'\frac{x^2}{a^2}+\frac{y^2}{b^2}=1',
        summary: '위아래 반쪽으로 나누면 함수형으로 안정적으로 표현할 수 있습니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '이차곡선',
        title: '포물선의 표준형',
        formula: r'y^2=4px',
        summary: '꼭짓점과 축 방향이 식에 바로 드러나는 대표 이차곡선입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '이차곡선',
        title: '쌍곡선의 표준형',
        formula: r'\frac{x^2}{a^2}-\frac{y^2}{b^2}=1',
        summary: '점근선과 두 갈래 가지를 동시에 해석하게 만드는 곡선입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '이차곡선',
        title: '쌍곡선의 함수형',
        formula: r'y=\pm b\sqrt{\frac{x^2}{a^2}-1}',
        summary: '쌍곡선을 현재 엔진에서 직접 그리기 좋은 분리형입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '벡터',
        title: '벡터의 내적',
        formula: r'\vec{a}\cdot\vec{b}=|\vec{a}||\vec{b}|\cos\theta',
        summary: '방향과 각을 수치화하는 식으로 직선 방향 비교에 연결할 수 있습니다.',
      ),
    ],
    examples: const [
      AiFlowGraphExample(
        id: 'geometry-ellipse',
        subject: '기하',
        unit: '이차곡선',
        title: '타원의 위아래 반쪽',
        summary: '표준형 타원을 위·아래 함수 두 개로 나눠 곡선 전체 모양을 확인합니다.',
        searchTerms: ['기하', '타원', '이차곡선', '표준형'],
        sourceLabel: '중·고등수학 자료방 기하 개념 총정리',
        sourceUrl: 'https://mathcloud.tistory.com/14',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'ellipse-upper',
              type: AiFlowGraphItemType.function,
              label: 'y = b sqrt(1 - x^2/a^2)',
              colorHex: '#2F7CF6',
              expression: 'b*sqrt(1-x^2/(a^2))',
            ),
            AiFlowGraphItem(
              id: 'ellipse-lower',
              type: AiFlowGraphItemType.function,
              label: 'y = -b sqrt(1 - x^2/a^2)',
              colorHex: '#DD5F34',
              expression: '-b*sqrt(1-x^2/(a^2))',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: -4, right: 4, top: 3, bottom: -3),
            parameters: [
              AiFlowGraphParameter(
                id: 'a',
                label: '가로 반지름',
                value: 3,
                min: 1,
                max: 6,
                step: 0.5,
              ),
              AiFlowGraphParameter(
                id: 'b',
                label: '세로 반지름',
                value: 2,
                min: 1,
                max: 5,
                step: 0.5,
              ),
            ],
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'geometry-parabola',
        subject: '기하',
        unit: '이차곡선',
        title: '포물선의 기본 개형',
        summary: '꼭짓점과 축이 눈에 바로 들어오는 가장 단순한 포물선입니다.',
        searchTerms: ['기하', '포물선', '이차곡선', '꼭짓점'],
        sourceLabel: '중·고등수학 자료방 기하 개념 총정리',
        sourceUrl: 'https://mathcloud.tistory.com/14',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'geometry-parabola-function',
              type: AiFlowGraphItemType.function,
              label: 'y = 0.25x^2',
              colorHex: '#238B5E',
              expression: '0.25*x^2',
            ),
          ],
          settings: AiFlowGraphSettings(viewport: _defaultViewport),
        ),
      ),
      AiFlowGraphExample(
        id: 'geometry-hyperbola',
        subject: '기하',
        unit: '이차곡선',
        title: '쌍곡선의 위아래 가지',
        summary: '쌍곡선을 함수 두 개로 나눠 대칭적인 개형과 점근 방향을 확인합니다.',
        searchTerms: ['기하', '쌍곡선', '이차곡선', '점근선'],
        sourceLabel: '중·고등수학 자료방 기하 개념 총정리',
        sourceUrl: 'https://mathcloud.tistory.com/14',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'hyperbola-upper',
              type: AiFlowGraphItemType.function,
              label: 'y = b sqrt(x^2/a^2 - 1)',
              colorHex: '#8A52E8',
              expression: 'b*sqrt(x^2/(a^2)-1)',
            ),
            AiFlowGraphItem(
              id: 'hyperbola-lower',
              type: AiFlowGraphItemType.function,
              label: 'y = -b sqrt(x^2/a^2 - 1)',
              colorHex: '#D6477C',
              expression: '-b*sqrt(x^2/(a^2)-1)',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: -6, right: 6, top: 6, bottom: -6),
            parameters: [
              AiFlowGraphParameter(
                id: 'a',
                label: '가로 기준',
                value: 2,
                min: 1,
                max: 5,
                step: 0.5,
              ),
              AiFlowGraphParameter(
                id: 'b',
                label: '세로 기준',
                value: 1,
                min: 0.5,
                max: 4,
                step: 0.5,
              ),
            ],
          ),
        ),
      ),
    ],
  ),
  AiFlowGraphSubjectCatalog(
    subject: '확률과통계',
    overview: '경우의 수, 확률, 통계를 수치와 분포로 읽는 과목이라 산점도와 분포형 예제가 잘 맞습니다.',
    formulaSearchTip: r'추천 검색어: $P(A)=\frac{n(A)}{n(S)}$, $E(X)=\sum xp(x)$, $V(X)=E(X^2)-\{E(X)\}^2$, $r=\frac{1}{n}\sum \left(\frac{x_i-\bar{x}}{s_x}\right)\left(\frac{y_i-\bar{y}}{s_y}\right)$, $z=\frac{x-\mu}{\sigma}$',
    sourceLabel: '중·고등수학 자료방 확률과 통계 개념 총정리',
    sourceUrl: 'https://mathcloud.tistory.com/13',
    formulas: const [
      AiFlowGraphFormulaSummary(
        unit: '확률',
        title: '확률의 기본식',
        formula: r'P(A)=\frac{n(A)}{n(S)}',
        summary: '사건과 표본공간의 크기 관계를 정리하는 가장 기본적인 공식입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '확률분포',
        title: '기댓값',
        formula: r'E(X)=\sum xp(x)',
        summary: '확률변수의 중심 위치를 표현해 분포 해석의 기준이 됩니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '확률분포',
        title: '분산',
        formula: r'V(X)=E(X^2)-\{E(X)\}^2',
        summary: '분포가 퍼진 정도를 수치화하며 그래프의 넓은 퍼짐과 연결됩니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '통계',
        title: '상관계수',
        formula: r'r=\frac{1}{n}\sum \left(\frac{x_i-\bar{x}}{s_x}\right)\left(\frac{y_i-\bar{y}}{s_y}\right)',
        summary: '산점도의 선형 경향을 하나의 수로 요약하는 대표 지표입니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '통계',
        title: '표준점수',
        formula: r'z=\frac{x-\mu}{\sigma}',
        summary: '분포 안에서 상대적 위치를 비교할 때 쓰이며 중심과 퍼짐 해석에 연결됩니다.',
      ),
      AiFlowGraphFormulaSummary(
        unit: '확률분포',
        title: '종 모양 분포 함수',
        formula: r'y=e^{-\frac{(x-\mu)^2}{2\sigma^2}}',
        summary: '평균과 표준편차가 분포의 중심과 퍼짐을 어떻게 바꾸는지 그래프로 확인할 수 있습니다.',
      ),
    ],
    examples: const [
      AiFlowGraphExample(
        id: 'stats-scatter',
        subject: '확률과통계',
        unit: '통계',
        title: '산점도로 보는 양의 상관',
        summary: '공부 시간과 점수의 우상향 경향을 간단한 데이터로 시각화합니다.',
        searchTerms: ['확률과통계', '산점도', '상관', '통계'],
        sourceLabel: '중·고등수학 자료방 확률과 통계 개념 총정리',
        sourceUrl: 'https://mathcloud.tistory.com/13',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'scatter',
              type: AiFlowGraphItemType.scatter,
              label: '공부 시간 / 점수',
              colorHex: '#238B5E',
              xValues: [1, 2, 2.5, 3, 4, 5, 6, 7],
              yValues: [42, 48, 52, 57, 63, 71, 78, 84],
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: 0, right: 8, top: 90, bottom: 35),
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'stats-frequency-line',
        subject: '확률과통계',
        unit: '통계',
        title: '도수분포의 꺾은선형 패턴',
        summary: '계급값에 따른 도수 변화를 선형 데이터로 빠르게 확인하는 예제입니다.',
        searchTerms: ['도수분포', '통계', '분포', '꺾은선그래프'],
        sourceLabel: '중·고등수학 자료방 확률과 통계 개념 총정리',
        sourceUrl: 'https://mathcloud.tistory.com/13',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'frequency-line',
              type: AiFlowGraphItemType.line,
              label: '도수분포',
              colorHex: '#8A52E8',
              xValues: [10, 20, 30, 40, 50, 60],
              yValues: [2, 6, 11, 8, 4, 1],
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: 5, right: 65, top: 13, bottom: 0),
          ),
        ),
      ),
      AiFlowGraphExample(
        id: 'stats-bell-shape',
        subject: '확률과통계',
        unit: '확률분포',
        title: '종 모양 분포 감각',
        summary: '연속적인 분포 개형 감각을 위해 중앙이 높은 종 모양 함수를 단순화해 보여줍니다.',
        searchTerms: ['분포', '정규분포', '종모양', '확률분포'],
        sourceLabel: '중·고등수학 자료방 확률과 통계 개념 총정리',
        sourceUrl: 'https://mathcloud.tistory.com/13',
        document: AiFlowGraphDocument(
          items: [
            AiFlowGraphItem(
              id: 'bell',
              type: AiFlowGraphItemType.function,
              label: 'y = e^-((x - mu)^2 / 2sigma^2)',
              colorHex: '#2F7CF6',
              expression: 'e^(-((x-mu)^2)/(2*sigma^2))',
            ),
          ],
          settings: AiFlowGraphSettings(
            viewport: AiFlowGraphViewport(left: -8, right: 8, top: 1.5, bottom: -0.2),
            parameters: [
              AiFlowGraphParameter(
                id: 'mu',
                label: '중심',
                value: 0,
                min: -4,
                max: 4,
                step: 0.5,
              ),
              AiFlowGraphParameter(
                id: 'sigma',
                label: '퍼짐',
                value: 2,
                min: 0.8,
                max: 4,
                step: 0.2,
              ),
            ],
          ),
        ),
      ),
    ],
  ),
];

final aiFlowGraphExampleSubjects = List<String>.unmodifiable(
  aiFlowGraphCatalog.map((subject) => subject.subject),
);

final aiFlowGraphExamples = List<AiFlowGraphExample>.unmodifiable(
  aiFlowGraphCatalog.expand((subject) => subject.examples),
);
