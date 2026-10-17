import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/marketplace/ui/pages/public_textbooks_page.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'invalid catalogue and acquisition responses never look successful',
    (tester) async {
      final api = ApiClient.instance;
      api.setTokenForTest('synthetic-public-actor');
      final scope = await api.requireSessionScope();
      final id = 'published-${List.filled(64, 'a').join()}';
      try {
        api.setHttpClientForTest(
          MockClient((_) async => http.Response('{}', 200)),
        );
        await expectLater(
          api.listPublicTextbooks(expectedScope: scope),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          api.acquirePublicTextbook(id, expectedScope: scope),
          throwsA(isA<ApiException>()),
        );
        api.setHttpClientForTest(
          MockClient((request) async {
            expect(request.url.path, '/marketplace/textbooks');
            return http.Response('{"items":[]}', 200);
          }),
        );
        expect(await api.listPublicTextbooks(expectedScope: scope), isEmpty);
      } finally {
        api.clearTokenForTest();
        api.setHttpClientForTest(http.Client());
      }
    },
  );
  testWidgets('401 is not shown as a catalogue or network failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {'/login': (_) => const Scaffold(body: Text('로그인 화면'))},
        home: PublicTextbooksPage(
          loadItems: () async =>
              throw ApiException(statusCode: 401, message: 'synthetic'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('로그인이 필요합니다. 다시 로그인해 주세요.'), findsOneWidget);
    expect(find.text('공개 교재를 불러오지 못했습니다.'), findsNothing);
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.text('로그인 화면'), findsOneWidget);
  });
  testWidgets(
    'no published bundle shows an empty state without purchase buttons',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PublicTextbooksPage(loadItems: () async => [])),
      );
      await tester.pumpAndSettle();
      expect(find.text('공개된 교재가 없습니다.'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('공개 교재를 불러오지 못했습니다.'), findsNothing);
    },
  );
  testWidgets('free acquisition locks duplicate clicks and opens real book', (
    tester,
  ) async {
    var count = 0;
    BookData? opened;
    final completion = Completer<BookData>();
    await tester.pumpWidget(
      MaterialApp(
        home: PublicTextbooksPage(
          loadItems: () async => [
            {
              'textbook_id': 'published-test',
              'title': '테스트 교재',
              'owned': false,
            },
          ],
          acquireBook: (id) {
            count++;
            return completion.future;
          },
          onOpen: (book) => opened = book,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('공개 교재 · 0코인'), findsOneWidget);
    await tester.tap(find.text('0코인 · 책가방에 담기'));
    await tester.pump();
    expect(find.text('처리 중…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(count, 1);
    completion.complete(
      BookData(
        id: 'published-test',
        title: '테스트 교재',
        subtitle: '',
        chapters: const [],
      ),
    );
    await tester.pumpAndSettle();
    expect(opened?.id, 'published-test');
    expect(find.text('교재 열기'), findsOneWidget);
  });

  testWidgets('refresh during acquisition does not strand busy state', (
    tester,
  ) async {
    final acquisition = Completer<BookData>();
    BookData? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: PublicTextbooksPage(
          loadItems: () async => [
            {
              'textbook_id': 'published-test',
              'title': '테스트 교재',
              'owned': false,
            },
          ],
          acquireBook: (_) => acquisition.future,
          onOpen: (book) => opened = book,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('0코인 · 책가방에 담기'));
    await tester.pump();
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    acquisition.complete(
      BookData(
        id: 'published-test',
        title: '테스트 교재',
        subtitle: '',
        chapters: const [],
      ),
    );
    await tester.pumpAndSettle();
    expect(opened?.id, 'published-test');
    expect(find.text('교재 열기'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('stale catalogue response cannot undo successful acquisition', (
    tester,
  ) async {
    final refresh = Completer<List<Map<String, dynamic>>>();
    var loads = 0;
    Map<String, dynamic> row() => {
      'textbook_id': 'published-test',
      'title': '테스트 교재',
      'owned': false,
    };
    await tester.pumpWidget(
      MaterialApp(
        home: PublicTextbooksPage(
          loadItems: () =>
              loads++ == 0 ? Future.value([row()]) : refresh.future,
          acquireBook: (_) async => BookData(
            id: 'published-test',
            title: '테스트 교재',
            subtitle: '',
            chapters: const [],
          ),
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pending = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.tap(find.text('0코인 · 책가방에 담기'));
    await tester.pumpAndSettle();
    refresh.complete([row()]);
    await pending;
    await tester.pumpAndSettle();
    expect(find.text('교재 열기'), findsOneWidget);
    expect(find.text('0코인 · 책가방에 담기'), findsNothing);
  });

  testWidgets('failure is retryable and empty/search states are distinct', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PublicTextbooksPage(
          loadItems: () async {
            if (loads++ == 0) throw StateError('offline');
            return [
              {
                'textbook_id': 'published-test',
                'title': '공통수학',
                'owned': false,
              },
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('공개 교재를 불러오지 못했습니다.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('공통수학'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '없는 교재');
    await tester.pump();
    expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
    expect(find.text('공개된 교재가 없습니다.'), findsNothing);
  });
}
