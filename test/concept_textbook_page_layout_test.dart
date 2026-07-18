import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/shared/data/models/textbook.dart';

/// 필요한 변수는 화면 크기와 초벌 단원의 지면 번호다.
/// 작동 원리는 실제 교재 위젯을 해당 지면에서 열고 렌더링 예외가 없는지 확인한다.
Future<void> _pumpPilotPage(
  WidgetTester tester, {
  required Size size,
  required BookData book,
  required int pageIndex,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BookWidget(
        key: ValueKey('book-${book.id}-$pageIndex-${size.width}'),
        book: book,
        initialEntryIndex: pageIndex,
        persistenceEnabled: false,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull, reason: '$size / page $pageIndex');
}

List<int> _representativeEntryIndexes(BookData book) {
  final pages = book.chapters.single.pages;
  if (pages.isEmpty) return const [];
  final indexByTemplate = <BookPageTemplate, int>{};
  for (var i = 0; i < pages.length; i++) {
    indexByTemplate.putIfAbsent(pages[i].template, () => i);
  }

  final indexes = <int>{
    0,
    pages.length - 1,
    if (indexByTemplate[BookPageTemplate.opening] != null)
      indexByTemplate[BookPageTemplate.opening]!,
    if (indexByTemplate[BookPageTemplate.concept] != null)
      indexByTemplate[BookPageTemplate.concept]!,
    if (indexByTemplate[BookPageTemplate.experiment] != null)
      indexByTemplate[BookPageTemplate.experiment]!,
    if (indexByTemplate[BookPageTemplate.example] != null)
      indexByTemplate[BookPageTemplate.example]!,
    if (indexByTemplate[BookPageTemplate.practice] != null)
      indexByTemplate[BookPageTemplate.practice]!,
    if (indexByTemplate[BookPageTemplate.summary] != null)
      indexByTemplate[BookPageTemplate.summary]!,
  };
  return indexes.toList()..sort();
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('데스크톱 도입·정의·예제·연습 지면에 overflow가 없다', (tester) async {
    for (final pageIndex in const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]) {
      await _pumpPilotPage(
        tester,
        size: const Size(1280, 900),
        book: kConceptTextbooks['두점을지나는직선']!,
        pageIndex: pageIndex,
      );
    }
  });

  testWidgets('모바일도 같은 지면 의미 구조를 유지하고 overflow가 없다', (tester) async {
    for (final pageIndex in const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]) {
      await _pumpPilotPage(
        tester,
        size: const Size(390, 844),
        book: kConceptTextbooks['두점을지나는직선']!,
        pageIndex: pageIndex,
      );
    }
  });

  testWidgets('199개 개념 핵심 지면(도입/개념/실험/예제/연습/정리) 샘플 렌더링이 터지지 않아야 한다', (
    tester,
  ) async {
    final allBooks = kConceptTextbooks.values.toList();
    for (var i = 0; i < allBooks.length; i++) {
      final book = allBooks[i];
      print('CHECK concept=${book.id}');
      final indexes = _representativeEntryIndexes(book);
      for (final pageIndex in indexes) {
        print('  page=$pageIndex');
        await _pumpPilotPage(
          tester,
          size: const Size(1280, 900),
          book: book,
          pageIndex: pageIndex,
        );
      }
    }
  });

  testWidgets('모바일 390x844에서도 대표 지면이 오버플로우 없이 렌더링되어야 한다', (
    tester,
  ) async {
    final allBooks = kConceptTextbooks.values.toList();
    for (var i = 0; i < allBooks.length; i++) {
      final book = allBooks[i];
      final indexes = _representativeEntryIndexes(book);
      final pageIndex = indexes.isNotEmpty ? indexes[0] : 0;
      await _pumpPilotPage(
        tester,
        size: const Size(390, 844),
        book: book,
        pageIndex: pageIndex,
      );
    }
  });
}
