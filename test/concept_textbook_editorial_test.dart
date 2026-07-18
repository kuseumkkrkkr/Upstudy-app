import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/concept_textbook_graphs.dart';
import 'package:s11/shared/data/models/concept_textbook_manuscripts.dart';
import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/shared/data/models/textbook.dart';

const _requiredTemplates = <BookPageTemplate>{
  BookPageTemplate.opening,
  BookPageTemplate.concept,
  BookPageTemplate.principle,
  BookPageTemplate.example,
  BookPageTemplate.solution,
  BookPageTemplate.practice,
  BookPageTemplate.summary,
  BookPageTemplate.experiment,
};

const _explicitPageCountRange = (start: 8, end: 10);

const _exactTemplateCounts = <BookPageTemplate, int>{
  BookPageTemplate.opening: 1,
  BookPageTemplate.concept: 1,
  BookPageTemplate.principle: 1,
  BookPageTemplate.experiment: 1,
  BookPageTemplate.example: 1,
  BookPageTemplate.solution: 1,
  BookPageTemplate.practice: 1,
  BookPageTemplate.summary: 1,
};

/// 필요한 변수는 기본 교재의 흐름 템플릿이다.
/// 작동 원리는 `도입-개념-원리-실험-예제-해법-연습-정리` 순서를 고정해
/// 지면 구조가 뒤집히지 않게 하기 위함이다.
const _requiredTemplateFlow = <BookPageTemplate>[
  BookPageTemplate.opening,
  BookPageTemplate.concept,
  BookPageTemplate.principle,
  BookPageTemplate.experiment,
  BookPageTemplate.example,
  BookPageTemplate.solution,
  BookPageTemplate.practice,
  BookPageTemplate.summary,
];

/// 필요한 변수는 과밀 텍스트 기준치다.
/// 작동 원리는 한 페이지에서 텍스트 블록이 지나치게 길어져
/// 내부 스크롤이나 넘침이 생기는 패턴을 사전 차단한다.
const _maxPageCharsByEditorial = 2400;

/// 필요한 변수는 특정 문구 의존성이다.
/// 작동 원리는 과거의 뻔한 교재 문구가 남아있으면 편집 품질이 저하되는 패턴을 탐지한다.
const _fallbackPhraseForPilot = <String>[
  '정의-원리-적용-풀이-정리',
  '문항별로 공식만 대입해 풀면',
  '이 단원은 정의를 확인하고 원리를 바로 적용해서 응용을 푸는 흐름으로 구성',
];

const _requiredBlockByTemplate = <BookPageTemplate, Set<BookContentBlockType>>{
  BookPageTemplate.opening: {BookContentBlockType.lead},
  BookPageTemplate.concept: {
    BookContentBlockType.definition,
    BookContentBlockType.paragraph,
    BookContentBlockType.symbols,
  },
  BookPageTemplate.principle: {
    BookContentBlockType.theorem,
    BookContentBlockType.derivation,
  },
  BookPageTemplate.experiment: {BookContentBlockType.lead},
  BookPageTemplate.example: {
    BookContentBlockType.question,
    BookContentBlockType.solutionStep,
    BookContentBlockType.verification,
    BookContentBlockType.answer,
  },
  BookPageTemplate.solution: {
    BookContentBlockType.question,
    BookContentBlockType.solutionStep,
    BookContentBlockType.verification,
    BookContentBlockType.answer,
  },
  BookPageTemplate.practice: {
    BookContentBlockType.question,
    BookContentBlockType.thinking,
    BookContentBlockType.checklist,
    BookContentBlockType.hint,
    BookContentBlockType.answer,
  },
  BookPageTemplate.summary: {BookContentBlockType.summary},
};

const _requiredKickerByTemplate = <BookPageTemplate, String>{
  BookPageTemplate.opening: '도입',
  BookPageTemplate.concept: '개념',
  BookPageTemplate.principle: '원리',
  BookPageTemplate.experiment: '실험',
  BookPageTemplate.example: '예제',
  BookPageTemplate.solution: '해법',
  BookPageTemplate.practice: '연습',
  BookPageTemplate.summary: '정리',
};

/// 필요한 변수는 한 지면의 텍스트 블록이다.
/// 작동 원리는 제목·문장·목록·수식 길이를 합산해 한 화면 추정치 초과를 탐지한다.
int _countEditorialChars(BookPage page) {
  return page.blocks.fold<int>(0, (total, block) {
    var next = total + block.title.length + block.text.length;
    for (final item in block.items) {
      next += item.length;
    }
    if (block.formula.isNotEmpty) {
      next += block.formula.length + 4;
    }
    return next;
  });
}

bool _hasMeaningfulContent(BookContentBlock block) {
  // 필요한 변수: 블록의 텍스트/수식/항목/시각요소.
  // 작동 원리: 한 블록이 비어 있는지 확인해 빈 카드 노출로 인한 UX 단절을 방지한다.
  if (block.visual != null) return true;
  if (block.graph != null) return true;
  if (block.formula.trim().isNotEmpty) return true;
  if (block.text.trim().isNotEmpty) return true;
  if (block.items.any((item) => item.trim().isNotEmpty)) return true;
  if (block.rows.isNotEmpty) return true;
  return false;
}

bool _containsBannedCopy(BookPage page) {
  const banned = <String>['정의-원리-적용-검산', '정의→원리', '원리→적용', '필수 조건만 먼저 적고'];
  bool hasBanned(String text) => banned.any((item) => text.contains(item));
  for (final block in page.blocks) {
    if (hasBanned(block.title) ||
        hasBanned(block.text) ||
        hasBanned(block.formula)) {
      return true;
    }
    for (final item in block.items) {
      if (hasBanned(item)) return true;
    }
  }
  return false;
}

void _expectTemplateHasRequiredBlocks({
  required String conceptKey,
  required BookPageTemplate template,
  required List<BookContentBlock> blocks,
}) {
  // 필요한 변수: 템플릿별 필수 블록 타입 집합과 실제 블록 리스트.
  // 작동 원리: 교재 지면마다 규칙을 고정해 오탈자처럼 빠지는 유형을 즉시 검출한다.
  final requiredBlocks =
      _requiredBlockByTemplate[template] ?? const <BookContentBlockType>{};
  for (final type in requiredBlocks) {
    expect(
      blocks.any((block) => block.type == type),
      isTrue,
      reason: '$conceptKey - template:$template - missing $type',
    );
  }
}

void _expectTemplateHasExpectedKicker({
  required String conceptKey,
  required BookPageTemplate template,
  required String kicker,
}) {
  final required = _requiredKickerByTemplate[template];
  if (required == null) return;
  expect(
    kicker.contains(required),
    isTrue,
    reason:
        '$conceptKey - ${template.name} - expected kicker includes "$required"',
  );
}

void _expectTemplateTemplateCount({
  required String conceptKey,
  required BookPageTemplate template,
  required int count,
}) {
  final expectedCount = _exactTemplateCounts[template];
  if (expectedCount == null) return;
  expect(count, equals(expectedCount), reason: conceptKey);
}

void _expectTemplateHasBlockCount({
  required String conceptKey,
  required String pageId,
  required Set<BookContentBlockType> requiredTypes,
  required List<BookContentBlock> blocks,
}) {
  for (final type in requiredTypes) {
    expect(
      blocks.where((block) => block.type == type).length,
      greaterThanOrEqualTo(1),
      reason: '$conceptKey - $pageId - $type',
    );
  }
}

void _expectTemplateFlow({
  required String conceptKey,
  required List<BookPage> pages,
}) {
  // 필요한 변수는 템플릿별 최초 인덱스와 흐름 배열이다.
  // 작동 원리는 개념·원리·실험·예제·해법·연습·정리의 순서를 깨지지 않게 하는 것이다.
  final firstIndexByTemplate = <BookPageTemplate, int>{};
  for (var i = 0; i < pages.length; i++) {
    firstIndexByTemplate.putIfAbsent(pages[i].template, () => i);
  }

  for (var i = 0; i < _requiredTemplateFlow.length - 1; i++) {
    final current = _requiredTemplateFlow[i];
    final next = _requiredTemplateFlow[i + 1];
    expect(
      firstIndexByTemplate[current] != null,
      isTrue,
      reason: '$conceptKey - missing ${current.name}',
    );
    expect(
      firstIndexByTemplate[next] != null,
      isTrue,
      reason: '$conceptKey - missing ${next.name}',
    );
    expect(
      firstIndexByTemplate[current]!,
      lessThan(firstIndexByTemplate[next]!),
      reason: '$conceptKey - flow ${current.name} -> ${next.name}',
    );
  }

  expect(
    pages.first.template,
    equals(BookPageTemplate.opening),
    reason: '$conceptKey - first page should be opening',
  );
  expect(
    pages.last.template,
    equals(BookPageTemplate.summary),
    reason: '$conceptKey - last page should be summary',
  );
}

void _expectNoFallbackPilotPhrase({
  required String conceptKey,
  required List<BookPage> pages,
}) {
  if (conceptKey != '두점을지나는직선') return;
  final allText = pages
      .expand((page) => page.blocks)
      .map(
        (block) =>
            '${block.title} ${block.text} '
            '${block.items.join(' ')} ${block.formula}',
      )
      .join('\n');
  for (final phrase in _fallbackPhraseForPilot) {
    expect(allText, isNot(contains(phrase)), reason: '$conceptKey - $phrase');
  }
}

void _expectPageSizeBudget({
  required String conceptKey,
  required List<BookPage> pages,
}) {
  // 필요한 변수는 페이지와 길이 상한이다.
  // 작동 원리는 교재형 배치를 깨뜨리는 과도한 텍스트를 초기에 차단한다.
  for (final page in pages) {
    expect(
      _countEditorialChars(page),
      lessThanOrEqualTo(_maxPageCharsByEditorial),
      reason: '$conceptKey - ${page.id}',
    );
  }
}

void _expectContentfulBlocks({
  required String conceptKey,
  required BookPage page,
}) {
  // 필요한 변수: 개념키와 지면 객체.
  // 작동 원리: 모든 지면이 최소 1개 이상의 의미 있는 블록을 갖도록 강제한다.
  expect(page.id, isNotEmpty, reason: conceptKey);
  expect(page.blocks, isNotEmpty, reason: conceptKey);

  for (final block in page.blocks) {
    if (block.type == BookContentBlockType.visual) {
      expect(block.visual, isNotNull, reason: '$conceptKey - ${page.id}');
      continue;
    }
    if (block.type == BookContentBlockType.graph) {
      expect(block.graph, isNotNull, reason: '$conceptKey - ${page.id}');
      continue;
    }
    expect(
      _hasMeaningfulContent(block),
      isTrue,
      reason: '$conceptKey - ${page.id} - ${block.type}',
    );
  }
}

void main() {
  group('개념서 초벌 원고 검증', () {
    test('전체 개념이 저자 원고 감사 규칙을 통과한다', () {
      expect(auditConceptTextbookPages(kConceptTextbooks), isEmpty);
    });

    test('199개 개념이 존재한다', () {
      expect(kConceptTextbooks, hasLength(199));
    });

    test('모든 개념은 8~10쪽 명시적 페이지를 가진다', () {
      for (final entry in kConceptTextbooks.entries) {
        final pages = entry.value.chapters.single.pages;
        expect(pages, isNotEmpty, reason: entry.key);
        expect(
          pages.length,
          inInclusiveRange(
            _explicitPageCountRange.start,
            _explicitPageCountRange.end,
          ),
          reason: entry.key,
        );

        final templateCounts = <BookPageTemplate, int>{};
        for (final page in pages) {
          templateCounts[page.template] =
              (templateCounts[page.template] ?? 0) + 1;
          expect(page.id, isNotEmpty, reason: entry.key);
          expect(page.blocks, isNotEmpty, reason: '${entry.key} - ${page.id}');
        }
        expect(
          templateCounts.keys.toSet(),
          containsAll(_requiredTemplates),
          reason: entry.key,
        );
        if (entry.key != '두점을지나는직선') {
          for (final template in _exactTemplateCounts.keys) {
            _expectTemplateTemplateCount(
              conceptKey: entry.key,
              template: template,
              count: templateCounts[template] ?? 0,
            );
          }
        } else {
          for (final template in _requiredTemplates) {
            expect(
              templateCounts[template],
              greaterThanOrEqualTo(1),
              reason: '${entry.key}: ${template.name}',
            );
          }
        }
      }
    });

    test('필수 페이지 역할과 필수 블록이 채워진다', () {
      for (final entry in kConceptTextbooks.entries) {
        final pages = entry.value.chapters.single.pages;
        final templates = pages.map((page) => page.template).toSet();
        final blocks = pages.expand((page) => page.blocks).toList();
        final practicePages = pages
            .where((page) => page.template == BookPageTemplate.practice)
            .toList(growable: false);

        expect(templates, containsAll(_requiredTemplates), reason: entry.key);
        _expectTemplateFlow(conceptKey: entry.key, pages: pages);
        _expectPageSizeBudget(conceptKey: entry.key, pages: pages);
        _expectNoFallbackPilotPhrase(conceptKey: entry.key, pages: pages);

        final requiredGraph = conceptGraphFor(entry.key, entry.value.tags);
        if (requiredGraph != null) {
          expect(
            templates.contains(BookPageTemplate.experiment),
            isTrue,
            reason: '${entry.key}-experiment',
          );
        }

        expect(
          blocks
                  .where((block) => block.type == BookContentBlockType.question)
                  .length >=
              4,
          isTrue,
          reason: entry.key,
        );
        expect(
          blocks.any((block) => block.type == BookContentBlockType.thinking),
          isTrue,
          reason: entry.key,
        );
        expect(
          blocks.any((block) => block.type == BookContentBlockType.derivation),
          isTrue,
          reason: entry.key,
        );
        expect(
          blocks.any((block) => block.type == BookContentBlockType.summary),
          isTrue,
          reason: entry.key,
        );
        expect(
          blocks
                  .where(
                    (block) => block.type == BookContentBlockType.solutionStep,
                  )
                  .length >=
              2,
          isTrue,
          reason: entry.key,
        );
        expect(
          blocks.any(
            (block) => block.type == BookContentBlockType.misconception,
          ),
          isTrue,
          reason: entry.key,
        );
        expect(
          blocks.any(
            (block) => block.type == BookContentBlockType.verification,
          ),
          isTrue,
          reason: entry.key,
        );
        expect(
          blocks.any((block) => block.type == BookContentBlockType.answer),
          isTrue,
          reason: entry.key,
        );
        expect(practicePages.isNotEmpty, isTrue, reason: entry.key);

        for (final required in _requiredTemplates) {
          final targetPages = pages
              .where((page) => page.template == required)
              .toList(growable: false);
          expect(
            targetPages.isNotEmpty,
            isTrue,
            reason: '${entry.key} - $required',
          );
          for (final targetPage in targetPages) {
            _expectTemplateHasRequiredBlocks(
              conceptKey: entry.key,
              template: required,
              blocks: targetPage.blocks,
            );
            _expectTemplateHasExpectedKicker(
              conceptKey: entry.key,
              template: required,
              kicker: targetPage.kicker,
            );
          }
        }

        expect(
          pages
              .where((page) => page.template == BookPageTemplate.summary)
              .expand((page) => page.blocks)
              .any((block) => block.type == BookContentBlockType.misconception),
          isTrue,
          reason: '${entry.key} - summary misconception',
        );

        for (final page in pages) {
          expect(
            _containsBannedCopy(page),
            isFalse,
            reason: '${entry.key} - ${page.id}',
          );
          _expectContentfulBlocks(conceptKey: entry.key, page: page);
        }

        for (final practicePage in practicePages) {
          expect(
            practicePage.blocks
                .where((block) => block.type == BookContentBlockType.question)
                .length,
            greaterThanOrEqualTo(2),
            reason: '${entry.key} - ${practicePage.id}',
          );
          _expectTemplateHasBlockCount(
            conceptKey: entry.key,
            pageId: practicePage.id,
            requiredTypes: const {
              BookContentBlockType.question,
              BookContentBlockType.thinking,
              BookContentBlockType.hint,
              BookContentBlockType.checklist,
              BookContentBlockType.answer,
            },
            blocks: practicePage.blocks,
          );
          expect(
            practicePage.blocks.any(
              (block) => block.type == BookContentBlockType.checklist,
            ),
            isTrue,
            reason: '${entry.key} - ${practicePage.id}',
          );
        }

        expect(
          pages
              .where((page) => page.template == BookPageTemplate.example)
              .length,
          greaterThanOrEqualTo(1),
          reason: entry.key,
        );
        expect(
          pages
              .where((page) => page.template == BookPageTemplate.solution)
              .length,
          greaterThanOrEqualTo(1),
          reason: entry.key,
        );

        expect(
          pages
              .where((page) => page.template == BookPageTemplate.practice)
              .expand((page) => page.blocks)
              .where((block) => block.type == BookContentBlockType.question)
              .length,
          greaterThanOrEqualTo(2),
          reason: entry.key,
        );
      }
    });

    test('두 점을 지나는 직선 원고의 기본 지면 내용을 점검한다', () {
      final pages = kConceptTextbooks['두점을지나는직선']!.chapters.single.pages;
      expect(pages, hasLength(10));
      expect(
        pages.map((page) => page.template),
        contains(BookPageTemplate.experiment),
      );
      expect(
        pages
            .expand((page) => page.blocks)
            .any(
              (block) =>
                  block.type == BookContentBlockType.graph &&
                  block.graph != null,
            ),
        isTrue,
      );
      final graph = pages
          .expand((page) => page.blocks)
          .firstWhere((block) => block.type == BookContentBlockType.graph)
          .graph!;

      expect(graph.items.single.expression, 'm*x+b');
      expect(graph.settings.parameters.map((parameter) => parameter.id), [
        'm',
        'b',
      ]);

      expect(
        pages.map((page) => page.title),
        allOf(
          contains('좌표의 변화량'),
          contains('기울기는 변화량의 비'),
          contains('오개념 점검'),
          contains('핵심 공식 지도'),
        ),
      );
    });

    test('필요한 개념은 그래프가 있으면 지면에 렌더링된다', () {
      for (final entry in kConceptTextbooks.entries) {
        final tags = entry.value.tags;
        final expectedGraph = conceptGraphFor(entry.key, tags);
        if (expectedGraph == null) {
          continue;
        }

        final hasGraph = entry.value.chapters.single.pages
            .expand((page) => page.blocks)
            .any(
              (block) =>
                  block.type == BookContentBlockType.graph &&
                  block.graph != null,
            );
        expect(hasGraph, isTrue, reason: entry.key);

        final hasExperimentTemplate = entry.value.chapters.single.pages.any(
          (page) => page.template == BookPageTemplate.experiment,
        );
        expect(hasExperimentTemplate, isTrue, reason: entry.key);
        final experimentPages = entry.value.chapters.single.pages
            .where((page) => page.template == BookPageTemplate.experiment)
            .toList();
        final hasGraphInExperiment = experimentPages
            .expand((page) => page.blocks)
            .any(
              (block) =>
                  block.type == BookContentBlockType.graph &&
                  block.graph != null,
            );
        expect(hasGraphInExperiment, isTrue, reason: entry.key);
      }
    });

    test('함수군 개념도 인터랙티브 지면을 기본적으로 확보한다', () {
      final functionCases = <String, List<String>>{
        '절댓값함수': const ['함수', '절댓값'],
        '유리함수': const ['함수', '유리함수'],
        '무리함수': const ['무리함수', '루트'],
      };
      for (final entry in functionCases.entries) {
        final graph = conceptGraphFor(entry.key, entry.value);
        expect(graph, isNotNull, reason: entry.key);
      }

      final graphKeysWithFunction = kConceptTextbooks.entries
          .where((entry) {
            final tags = entry.value.tags.join(' ');
            return tags.contains('함수') ||
                tags.contains('유리식') ||
                tags.contains('무리식') ||
                entry.key.contains('루트') ||
                entry.key.contains('절댓값');
          })
          .toList(growable: false);

      for (final entry in graphKeysWithFunction) {
        final hasExperiment = entry.value.chapters.single.pages.any(
          (page) => page.template == BookPageTemplate.experiment,
        );
        expect(hasExperiment, isTrue, reason: entry.key);
      }
    });

    test('일반 문구 의존(정의→원리→적용→풀이→정리) 패턴은 제거한다', () {
      const bannedPhrases = <String>[
        '정의->원리->적용->풀이->정리',
        '정의 → 원리 → 적용 → 풀이 → 정리',
        '정의\u2192원리\u2192적용\u2192풀이\u2192정리',
        '이 단원은 정의를 확인하고 원리를 바로 적용해서 응용을 푸는 흐름으로 구성',
        '문항별로 공식만 대입해 풀면',
      ];
      for (final entry in kConceptTextbooks.entries) {
        final manuscript = entry.value.chapters.single.pages
            .expand((page) => page.blocks)
            .map(
              (block) =>
                  '${block.title} ${block.text} ${block.items.join(' ')} ${block.formula}',
            )
            .join(' ');

        for (final phrase in bannedPhrases) {
          expect(
            manuscript,
            isNot(contains(phrase)),
            reason: '${entry.key}: $phrase',
          );
        }
      }
    });

    test('명시적 지면은 한 화면 추정치(2400자) 기준으로 넘치지 않는다', () {
      for (final entry in kConceptTextbooks.entries) {
        for (final page in entry.value.chapters.single.pages) {
          final length = _countEditorialChars(page);
          expect(
            length,
            lessThanOrEqualTo(2400),
            reason: '${entry.key} - ${page.id}',
          );
        }
      }
    });

    test('명시적 지면은 JSON 직렬화와 역직렬화에서 동일해야 한다', () {
      for (final entry in kConceptTextbooks.entries) {
        final source = entry.value;
        final encoded = jsonEncode(source.toJson());
        final decoded = BookData.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );
        final sourcePages = source.chapters.single.pages;
        final decodedPages = decoded.chapters.single.pages;

        expect(decodedPages.length, sourcePages.length, reason: entry.key);
        expect(
          decodedPages.first.template,
          sourcePages.first.template,
          reason: entry.key,
        );
        expect(
          decodedPages.first.blocks.first.type,
          sourcePages.first.blocks.first.type,
          reason: entry.key,
        );

        final sourceHasGraph = sourcePages
            .expand((page) => page.blocks)
            .any((block) => block.type == BookContentBlockType.graph);
        if (sourceHasGraph) {
          final decodedHasGraph = decodedPages
              .expand((page) => page.blocks)
              .any((block) => block.type == BookContentBlockType.graph);
          expect(decodedHasGraph, isTrue, reason: entry.key);
        }
      }
    });
  });
}
