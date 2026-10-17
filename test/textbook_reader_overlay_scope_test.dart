import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';

const privateBook = BookData(
  id: 'private-overlay-test',
  title: 'A 개인 교재',
  subtitle: '',
  chapters: [
    BookChapter(
      title: 'A 민감 목차',
      intro: ['A 민감 본문'],
      sections: [
        BookSection(title: 'A 민감 절', paragraphs: ['A 민감 검색 내용']),
      ],
    ),
  ],
);

Future<void> pumpPrivate(
  WidgetTester tester,
  Size size, {
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: const BookWidget(book: privateBook, persistenceEnabled: false),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.setTokenForTest('synthetic-overlay-a');
  });
  tearDown(() async {
    await ApiClient.instance.clearToken();
  });

  testWidgets('열린 검색의 query/result를 비우고 오래된 선택이 B의 새 페이지를 pop하지 않는다', (
    tester,
  ) async {
    final navigation = GlobalKey<NavigatorState>();
    await pumpPrivate(tester, const Size(1280, 900), navigatorKey: navigation);
    await tester.tap(find.byIcon(Icons.search_sharp));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '민감');
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    final result = tester.widget<ListTile>(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(ListTile),
          )
          .first,
    );
    final staleSelection = result.onTap!;
    ApiClient.instance.setTokenForTest('synthetic-overlay-b');
    expect(field.controller!.text, isEmpty);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.textContaining('A 민감'),
      ),
      findsNothing,
    );
    expect(find.text('로그인 상태가 바뀌어 이전 교재 창을 닫아야 합니다.'), findsOneWidget);
    navigation.currentState!.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('B 새 페이지'))),
    );
    await tester.pumpAndSettle();
    staleSelection();
    await tester.pumpAndSettle();
    expect(find.text('B 새 페이지'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('열린 목차도 logout 후 A snapshot을 렌더하지 않는다', (tester) async {
    await pumpPrivate(tester, const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('reader-mobile-toc')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('A 민감 목차'),
      ),
      findsOneWidget,
    );
    await tester.runAsync(() => ApiClient.instance.clearToken());
    await tester.pump();
    expect(find.textContaining('A 민감'), findsNothing);
    expect(find.text('로그인 상태가 바뀌어 이전 교재 창을 닫아야 합니다.'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
