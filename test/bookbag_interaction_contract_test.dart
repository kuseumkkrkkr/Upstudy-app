import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
// ignore: depend_on_referenced_packages
import 'package:sqflite_common/src/mixin/import_mixin.dart'
    show buildDatabaseFactory;
import 'package:s11/sessions/textbook/ui/pages/book_page.dart' as reader;
import 'package:s11/sessions/textbook/ui/pages/docx_box.dart' as bookbag;
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/storage/local_db.dart';

const _bookId = 'bookbag-contract-20260831';
const _bookTitle = '실제 API 교재';
const _contentMarker = '실제 API 본문 내용';
final _localValues = <String, String>{};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _localValues.clear();
    sqflite.databaseFactory = buildDatabaseFactory(
      tag: 'bookbag-interaction-contract-test',
      invokeMethod: _localDbTestMethod,
    );
  });

  tearDown(() async {
    ApiClient.instance.setHttpClientForTest(http.Client());
    await ApiClient.instance.clearToken();
    sqflite.databaseFactory = null;
  });

  testWidgets('390·780·1280 책가방은 실제 교재 API와 같은 리더로 이어진다', (tester) async {
    final requests = <http.Request>[];
    await ApiClient.instance.setToken('bookbag-interaction-contract-token');
    await ApiClient.instance.clearUserCache();
    await LocalDb.instance.delete('textbook_cache_v1_$_bookId');
    await LocalDb.instance.delete('recent_pages_json_v1');
    _installBookbagApiMock(requests);

    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_bookbagApp());
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (request) =>
            request.method == 'GET' &&
            request.url.path == '/user/storage/textbook_library_v1',
      ),
      isTrue,
    );
    expect(
      requests.any(
        (request) =>
            request.method == 'GET' && request.url.path == '/textbooks',
      ),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('bookbag-mobile-featured')),
      findsOneWidget,
    );

    await _openLibraryBookFromMobileShortcut(tester);
    await _expectReaderForBook(tester, requests);
    await _returnToBookbag(tester);

    // 선택한 교재가 실제 최근 방문 저장소에 기록되어 모바일 대표 카드가 된다.
    await tester.pumpAndSettle();
    expect(find.text('이어서 보기'), findsOneWidget);
    expect(find.text(_bookTitle), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('bookbag-mobile-featured')));
    await tester.pumpAndSettle();
    await _expectReaderForBook(tester, requests);
    await _returnToBookbag(tester);

    _setViewport(tester, const Size(780, 844));
    await tester.pumpWidget(_bookbagApp());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('bookbag-mobile-shortcut-group')),
      findsOneWidget,
    );
    await _openLibraryBookFromMobileShortcut(tester);
    await _expectReaderForBook(tester, requests);
    await _returnToBookbag(tester);

    _setViewport(tester, const Size(1280, 900));
    await tester.pumpWidget(_bookbagApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bookbag-desktop-body')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('bookbag-desktop-body')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    final desktopOpen = find.text('보관된 교재');
    await tester.ensureVisible(desktopOpen);
    await tester.tap(desktopOpen);
    await tester.pumpAndSettle();
    expect(find.text('보관된 교재'), findsWidgets);
    final desktopBookRow = find.descendant(
      of: find.byType(ListTile),
      matching: find.text(_bookTitle),
    );
    expect(desktopBookRow, findsOneWidget);
    await tester.tap(desktopBookRow);
    await tester.pumpAndSettle();
    await _expectReaderForBook(tester, requests);

    expect(tester.takeException(), isNull);
  });
}

Widget _bookbagApp() => const MaterialApp(home: bookbag.BookWidget());

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openLibraryBookFromMobileShortcut(WidgetTester tester) async {
  final shortcut = find.descendant(
    of: find.byKey(const ValueKey('bookbag-mobile-shortcut-group')),
    matching: find.text('교재'),
  );
  expect(shortcut, findsOneWidget);
  await tester.tap(shortcut);
  await tester.pumpAndSettle();
  expect(find.text('보관된 교재'), findsOneWidget);
  final bookRow = find.descendant(
    of: find.byType(ListTile),
    matching: find.text(_bookTitle),
  );
  expect(bookRow, findsOneWidget);
  await tester.tap(bookRow);
  await tester.pumpAndSettle();
}

Future<void> _expectReaderForBook(
  WidgetTester tester,
  List<http.Request> requests,
) async {
  expect(
    find.byWidgetPredicate(
      (widget) => widget is reader.BookWidget && widget.book?.id == _bookId,
    ),
    findsOneWidget,
  );
  expect(find.text(_contentMarker), findsOneWidget);
  expect(
    requests.any(
      (request) =>
          request.method == 'GET' && request.url.path == '/textbooks/$_bookId',
    ),
    isTrue,
  );
}

Future<void> _returnToBookbag(WidgetTester tester) async {
  final back = find.byTooltip('교재함으로 돌아가기');
  expect(back, findsOneWidget);
  await tester.tap(back);
  await tester.pumpAndSettle();
}

void _installBookbagApiMock(List<http.Request> requests) {
  ApiClient.instance.setHttpClientForTest(
    MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        switch (request.url.path) {
          case '/user/storage/textbook_library_v1':
            return _json(<String, Object?>{'value': null});
          case '/textbooks':
            return _json({
              'textbooks': [
                {
                  'textbook_id': _bookId,
                  'title': _bookTitle,
                  'subtitle': '실제 저장된 교재 메타데이터',
                  'category': 'custom',
                  'tags': ['계약', '교재'],
                  'progress': 0.4,
                },
              ],
            });
          case '/textbooks/$_bookId':
            return _json({
              'textbook_id': _bookId,
              'title': _bookTitle,
              'subtitle': '실제 저장된 교재 메타데이터',
              'category': 'custom',
              'tags': ['계약', '교재'],
              'chapters': [
                {
                  'title': '실제 API 단원',
                  'intro': [_contentMarker],
                  'sections': [
                    {
                      'title': '첫 번째 절',
                      'paragraphs': [_contentMarker],
                    },
                  ],
                },
              ],
            });
        }
      }
      if (request.method == 'POST' &&
          request.url.path == '/account/activity-score') {
        return _json(<String, Object>{});
      }
      return _json({
        'detail': 'unexpected ${request.method} ${request.url.path}',
      }, 404);
    }),
  );
}

http.Response _json(Object body, [int statusCode = 200]) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Future<dynamic> _localDbTestMethod(String method, [Object? arguments]) async {
  final map = arguments is Map ? arguments : const <Object?, Object?>{};
  final sql = map['sql']?.toString() ?? '';
  final values = map['arguments'] is List
      ? List<Object?>.from(map['arguments'] as List)
      : const <Object?>[];

  switch (method) {
    case 'getDatabasesPath':
      return '.';
    case 'openDatabase':
      return <String, Object>{'id': 1};
    case 'execute':
    case 'closeDatabase':
      return null;
    case 'query':
      if (sql == 'PRAGMA user_version') {
        return <Map<String, Object>>[
          <String, Object>{'user_version': 1},
        ];
      }
      if (sql.startsWith('SELECT value') && values.isNotEmpty) {
        final value = _localValues[values.first?.toString() ?? ''];
        return value == null
            ? <Map<String, Object>>[]
            : <Map<String, Object>>[
                <String, Object>{'value': value},
              ];
      }
      return <Map<String, Object>>[];
    case 'insert':
      if (values.length >= 2) {
        _localValues[values[0]?.toString() ?? ''] = values[1]?.toString() ?? '';
      }
      return 1;
    case 'update':
      if (sql.startsWith('DELETE') && values.isNotEmpty) {
        _localValues.remove(values.first?.toString() ?? '');
      }
      return 1;
    default:
      throw StateError('Unexpected local database method: $method');
  }
}
