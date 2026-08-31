import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/sessions/textbook/ui/pages/docx_box.dart' as bookbag;
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';

void main() {
  const books = <BookData>[
    BookData(
      id: 'math',
      title: '공통수학 개념 교재',
      subtitle: '핵심 개념을 순서대로 읽어요',
      chapters: [],
      progress: .42,
    ),
    BookData(
      id: 'algebra',
      title: '대수 유형 정리',
      subtitle: '방정식과 수열',
      chapters: [],
    ),
    BookData(
      id: 'calculus',
      title: '미적분 실전 노트',
      subtitle: '미분과 적분',
      chapters: [],
      progress: .8,
    ),
  ];

  testWidgets('세로형 모바일 책가방은 이어 읽기와 압축 교재 목록을 표시한다', (tester) async {
    // 필요한 변수는 612px 세로 화면과 진행률이 있는 교재 세 권이다.
    // 작동 원리는 데스크톱 문서고 대신 모바일 전용 헤더·재개 카드·구분선 목록이 렌더링되는지 확인한다.
    tester.view.physicalSize = const Size(612, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: BookLibraryPage(libraryTitle: '책가방', books: books),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('bookbag-mobile-redesign')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bookbag-mobile-continue')),
      findsOneWidget,
    );
    expect(find.text('책가방'), findsOneWidget);
    expect(find.text('3권의 교재'), findsOneWidget);
    expect(find.text('이어 읽기'), findsOneWidget);
    expect(find.text('공통수학 개념 교재'), findsOneWidget);
    expect(find.text('다른 교재'), findsOneWidget);
    expect(find.text('대수 유형 정리'), findsOneWidget);
    expect(find.text('미적분 실전 노트'), findsOneWidget);
    expect(find.text('문서고'), findsNothing);
  });

  testWidgets('가로가 넓은 화면은 기존 책가방 페이지를 유지한다', (tester) async {
    // 필요한 변수는 1280px 화면과 고정 교재다.
    // 작동 원리는 모바일 전용 분기가 데스크톱 문서고 구조를 변경하지 않았는지 확인한다.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: BookLibraryPage(libraryTitle: '책가방', books: books),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('bookbag-mobile-redesign')), findsNothing);
    expect(find.text('문서고'), findsOneWidget);
  });

  testWidgets('통합 책가방은 모바일에서 이어 보기와 네 자료 입구만 우선 표시한다', (tester) async {
    // 필요한 변수는 612px 세로 화면과 프리뷰 자료다.
    // 작동 원리는 실제 /bookbag 진입점이 긴 데스크톱 섹션 대신 모바일 전용 핵심 구조를 사용하는지 검증한다.
    tester.view.physicalSize = const Size(612, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: bookbag.BookWidget(previewMode: true)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('bookbag-mobile-redesign')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bookbag-mobile-featured')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bookbag-mobile-shortcut-group')),
      findsOneWidget,
    );
    expect(find.text('내 자료'), findsOneWidget);
    expect(find.text('교재'), findsWidgets);
    expect(find.text('시험지'), findsWidgets);
    expect(find.text('책 북마크'), findsWidgets);
    expect(find.text('문제 북마크'), findsWidgets);
    expect(find.text('찾고, 고정하고,'), findsNothing);
    expect(find.text('진행 중인 코스'), findsNothing);
  });

  testWidgets('781·900px 책가방 본문은 단일 열로 안전하게 전환한다', (tester) async {
    // 필요한 변수는 모바일 셸 바로 다음의 세로형 데스크톱 폭이다.
    // 작동 원리는 좁은 가로 카드/버튼 행을 단일 열로 바꿔 RenderFlex overflow를 막는 것이다.
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in <double>[781, 900]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: KeyedSubtree(
            key: ValueKey('bookbag-width-$width'),
            child: const bookbag.BookWidget(previewMode: true),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: '${width}px overflow');
      expect(
        find.byKey(const ValueKey('bookbag-desktop-body')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bookbag-hero-stacked')),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const ValueKey('bookbag-desktop-body')),
        const Offset(0, -2000),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: '${width}px lower body overflow',
      );
      expect(
        find.byKey(const ValueKey('bookbag-bottom-stacked')),
        findsOneWidget,
      );
      expect(find.textContaining('찾고, 고정하고'), findsOneWidget);
      expect(find.text('진행 중인 코스'), findsOneWidget);
    }
  });

  testWidgets('1280px 책가방은 기존 가로 본문을 유지한다', (tester) async {
    // 필요한 변수는 충분한 데스크톱 폭이다.
    // 작동 원리는 중간 폭 전용 단일 열 전환이 기존 PC 구성을 바꾸지 않는지 확인한다.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: bookbag.BookWidget(previewMode: true)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('bookbag-desktop-body')), findsOneWidget);
    expect(find.byKey(const ValueKey('bookbag-hero-columns')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('bookbag-desktop-body')),
      const Offset(0, -2000),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('bookbag-bottom-columns')),
      findsOneWidget,
    );
    expect(find.textContaining('찾고, 고정하고'), findsOneWidget);
    expect(find.text('진행 중인 코스'), findsOneWidget);
  });

  for (final width in <double>[720, 760, 780]) {
    testWidgets('${width}px 학생 셸 경계에서도 통합 책가방은 모바일 탐색을 쓴다', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: bookbag.BookWidget(previewMode: true)),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('bookbag-mobile-redesign')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bookbag-mobile-featured')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
      expect(find.byType(MobileStudentBottomAppBar), findsNothing);
    });
  }
}
