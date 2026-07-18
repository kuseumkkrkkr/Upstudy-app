import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';

const _conceptViewport = AiFlowGraphViewport(
  left: -6,
  right: 6,
  top: 8,
  bottom: -6,
);

bool _containsAny(String source, List<String> keywords) =>
    keywords.any((keyword) => source.contains(keyword));

/// 필요한 변수는 검색 키워드(title, 태그)와 뷰포트이다.
/// 작동 원리는 핵심 개념 키워드가 들어오면 해당 개념에 맞는 JSXGraph 기본 문서를 즉시 반환해
/// 초벌 교재의 실험 페이지가 항상 동일한 인터랙티브 동작을 갖도록 보장하는 것이다.
AiFlowGraphDocument? conceptGraphFor(String title, List<String> tags) {
  final query = ([title, ...tags]).join(' ').replaceAll('#', '').toLowerCase();

  if (query.contains('직선') ||
      query.contains('두점') ||
      query.contains('두 점') ||
      query.contains('점기울기형') ||
      query.contains('직선의방정식') ||
      query.contains('두점을지나는직선')) {
    return const AiFlowGraphDocument(
      items: [
        AiFlowGraphItem(
          id: 'line-textbook',
          type: AiFlowGraphItemType.function,
          label: 'y = mx + b',
          colorHex: '#1B402B',
          expression: 'm*x+b',
        ),
      ],
      settings: AiFlowGraphSettings(
        viewport: AiFlowGraphViewport(left: -8, right: 8, top: 8, bottom: -8),
        parameters: [
          AiFlowGraphParameter(
            id: 'm',
            label: '기울기 m',
            value: 1,
            min: -3,
            max: 3,
          ),
          AiFlowGraphParameter(
            id: 'b',
            label: '절편 b',
            value: 0,
            min: -5,
            max: 5,
          ),
        ],
      ),
    );
  }

  if (_containsAny(query, const ['절댓값', '절대값', 'abs', 'absolute'])) {
    return const AiFlowGraphDocument(
      items: [
        AiFlowGraphItem(
          id: 'abs-graph',
          type: AiFlowGraphItemType.function,
          label: 'y = |x - a| + b',
          colorHex: '#F97316',
          expression: 'abs(x-a)+b',
        ),
      ],
      settings: AiFlowGraphSettings(
        viewport: AiFlowGraphViewport(left: -6, right: 6, top: 10, bottom: -2),
        parameters: [
          AiFlowGraphParameter(
            id: 'a',
            label: 'x축 이동량 a',
            value: 0,
            min: -3,
            max: 3,
          ),
          AiFlowGraphParameter(
            id: 'b',
            label: 'y축 이동량 b',
            value: 0,
            min: -4,
            max: 4,
          ),
        ],
      ),
    );
  }

  if (_containsAny(query, const ['유리', '무리', '유리식', '무리식', '분모'])) {
    return const AiFlowGraphDocument(
      items: [
        AiFlowGraphItem(
          id: 'rational-graph',
          type: AiFlowGraphItemType.function,
          label: 'y = (x + a)/(x + b)',
          colorHex: '#2563EB',
          expression: '(x+a)/(x+b)',
        ),
      ],
      settings: AiFlowGraphSettings(
        viewport: AiFlowGraphViewport(left: -6, right: 6, top: 8, bottom: -8),
        parameters: [
          AiFlowGraphParameter(
            id: 'a',
            label: '분자 이동량 a',
            value: 0,
            min: -3,
            max: 3,
          ),
          AiFlowGraphParameter(
            id: 'b',
            label: '분모 이동량 b',
            value: 1,
            min: -3,
            max: 3,
          ),
        ],
      ),
    );
  }

  if (_containsAny(query, const ['제곱근', '근호', '무리함수', '루트'])) {
    return const AiFlowGraphDocument(
      items: [
        AiFlowGraphItem(
          id: 'root-graph',
          type: AiFlowGraphItemType.function,
          label: 'y = √(x-a) + b',
          colorHex: '#0EA5A0',
          expression: 'sqrt(x-a)+b',
        ),
      ],
      settings: AiFlowGraphSettings(
        viewport: AiFlowGraphViewport(left: -1, right: 10, top: 7, bottom: -3),
        lockViewport: true,
        parameters: [
          AiFlowGraphParameter(
            id: 'a',
            label: '이동량 a',
            value: 0,
            min: 0,
            max: 4,
          ),
          AiFlowGraphParameter(
            id: 'b',
            label: '상수 b',
            value: 0,
            min: -3,
            max: 3,
          ),
        ],
      ),
    );
  }

  if (query.contains('이차') || query.contains('포물선') || query.contains('이차함수')) {
    return const AiFlowGraphDocument(
      items: [
        AiFlowGraphItem(
          id: 'quadratic-textbook',
          type: AiFlowGraphItemType.function,
          label: 'y = ax² + bx + c',
          colorHex: '#245CFF',
          expression: 'a*x^2+b*x+c',
        ),
      ],
      settings: AiFlowGraphSettings(
        viewport: _conceptViewport,
        parameters: [
          AiFlowGraphParameter(id: 'a', label: 'a', value: 1, min: -3, max: 3),
          AiFlowGraphParameter(id: 'b', label: 'b', value: -4, min: -6, max: 6),
          AiFlowGraphParameter(id: 'c', label: 'c', value: 3, min: -6, max: 6),
        ],
      ),
    );
  }

  if (query.contains('로그') || query.contains('지수')) {
    return const AiFlowGraphDocument(
      items: [
        AiFlowGraphItem(
          id: 'exp-textbook',
          type: AiFlowGraphItemType.function,
          label: 'y = aˣ',
          colorHex: '#8B5CF6',
          expression: 'a^x',
        ),
      ],
      settings: AiFlowGraphSettings(
        viewport: AiFlowGraphViewport(left: -4, right: 4, top: 10, bottom: -1),
        parameters: [
          AiFlowGraphParameter(
            id: 'a',
            label: 'a',
            value: 2,
            min: 0.2,
            max: 5,
            step: 0.1,
          ),
        ],
      ),
    );
  }

  if (query.contains('미분') || query.contains('도함수') || query.contains('극값')) {
    return const AiFlowGraphDocument(
      items: [
        AiFlowGraphItem(
          id: 'derivative-func',
          type: AiFlowGraphItemType.function,
          label: 'f(x) = x³ - 3x + 2',
          colorHex: '#E05A47',
          expression: 'x^3-3*x+2',
        ),
        AiFlowGraphItem(
          id: 'derivative-line',
          type: AiFlowGraphItemType.function,
          label: "f'(x) = 3x² - 3",
          colorHex: '#245CFF',
          expression: '3*x^2-3',
        ),
      ],
      settings: AiFlowGraphSettings(
        viewport: AiFlowGraphViewport(left: -3, right: 3, top: 8, bottom: -4),
      ),
    );
  }

  if (query.contains('수열') || query.contains('일반항') || query.contains('등차')) {
    return const AiFlowGraphDocument(
      items: [
        AiFlowGraphItem(
          id: 'sequence-points',
          type: AiFlowGraphItemType.scatter,
          label: 'an = n² + 1',
          colorHex: '#245CFF',
          xValues: [1, 2, 3, 4, 5, 6],
          yValues: [2, 5, 10, 17, 26, 37],
        ),
        AiFlowGraphItem(
          id: 'sequence-curve',
          type: AiFlowGraphItemType.function,
          label: 'y = x² + 1',
          colorHex: '#1B402B',
          expression: 'x^2+1',
        ),
      ],
      settings: AiFlowGraphSettings(
        lockViewport: true,
        viewport: AiFlowGraphViewport(left: 0, right: 7, top: 42, bottom: -2),
      ),
    );
  }

  if (query.contains('극한')) {
    return const AiFlowGraphDocument(
      items: [
        AiFlowGraphItem(
          id: 'limit-graph',
          type: AiFlowGraphItemType.function,
          label: 'y = sin(x) / x',
          colorHex: '#8B5CF6',
          expression: 'sin(x)/x',
        ),
      ],
      settings: AiFlowGraphSettings(
        viewport: AiFlowGraphViewport(left: -8, right: 8, top: 2, bottom: -1),
      ),
    );
  }

  if (query.contains('적분') || query.contains('넓이')) {
    return const AiFlowGraphDocument(
      items: [
        AiFlowGraphItem(
          id: 'integral-graph',
          type: AiFlowGraphItemType.function,
          label: 'y = x²',
          colorHex: '#E05A47',
          expression: 'x^2',
        ),
      ],
      settings: AiFlowGraphSettings(
        viewport: AiFlowGraphViewport(left: -4, right: 4, top: 10, bottom: -1),
      ),
    );
  }

  return null;
}
