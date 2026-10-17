import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
// ignore: depend_on_referenced_packages
import 'package:sqflite_common/src/mixin/import_mixin.dart'
    show buildDatabaseFactory;
import 'package:s11/shared/business/repositories/bookmark_store.dart';
import 'package:s11/shared/business/repositories/exam_paper_store.dart';
import 'package:s11/shared/business/repositories/problem_bookmark_store.dart';
import 'package:s11/shared/business/repositories/textbook_store.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/storage/local_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final values = <String, String>{};
  late ApiClient api;
  Completer<List<Map<String, Object>>>? deferredQuery;
  Completer<void>? queryEntered;
  setUp(() async {
    api = ApiClient.instance;
    SharedPreferences.setMockInitialValues({});
    await api.clearToken();
    values.clear();
    deferredQuery = null;
    queryEntered = null;
    sqflite.databaseFactory = buildDatabaseFactory(
      tag: 'private-store-scope',
      invokeMethod: (method, [arguments]) async {
        final map = arguments is Map ? arguments : {};
        final sql = map['sql']?.toString() ?? '';
        final args = map['arguments'] is List
            ? List.from(map['arguments'])
            : [];
        switch (method) {
          case 'getDatabasesPath':
            return '.';
          case 'openDatabase':
            return {'id': 1};
          case 'execute':
          case 'closeDatabase':
            return null;
          case 'query':
            if (sql == 'PRAGMA user_version')
              return [
                {'user_version': 1},
              ];
            if (sql.startsWith('SELECT value') && args.isNotEmpty) {
              if (deferredQuery != null) {
                queryEntered?.complete();
                return deferredQuery!.future;
              }
              final value = values[args.first.toString()];
              return value == null
                  ? []
                  : [
                      {'value': value},
                    ];
            }
            return [];
          case 'insert':
            values[args[0].toString()] = args[1].toString();
            return 1;
          case 'update':
            if (sql.startsWith('DELETE')) values.remove(args.first.toString());
            return 1;
          default:
            throw StateError('Unexpected mock database operation');
        }
      },
    );
    api.setHttpClientForTest(
      MockClient((request) async {
        if (request.url.path == '/marketplace/textbooks/owned') {
          return http.Response('{"items":[]}', 200);
        }
        if (request.url.path == '/textbooks')
          return http.Response(
            '{"textbooks":[{"id":"synthetic-book","title":"synthetic","chapters":[]}]}',
            200,
          );
        return http.Response('{"value":"[]"}', 200);
      }),
    );
  });
  tearDown(() async {
    await api.clearToken();
    api.setHttpClientForTest(http.Client());
    sqflite.databaseFactory = null;
  });

  test(
    'native exam notifier clears immediately and old scoped rows stay isolated',
    () async {
      await api.setToken('synthetic-A');
      await ExamPaperStore.add(
        const ExamPaperEntry(
          examId: 'A-exam',
          questionCount: 1,
          createdAt: 1,
          paperType: 'math',
        ),
      );
      expect(ExamPaperStore.notifier.value.single.examId, 'A-exam');
      final transition = api.setToken('synthetic-B');
      expect(ExamPaperStore.notifier.value, isEmpty);
      await transition;
      expect(await ExamPaperStore.load(), isEmpty);
      await api.setToken('synthetic-A');
      expect((await ExamPaperStore.load()).single.examId, 'A-exam');
    },
  );

  test(
    'legacy bookmarks remain untouched and never migrate to current actor',
    () async {
      await api.setToken('synthetic-A');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bookmarks_v1', '[{"id":"owner-unknown"}]');
      values['bookmarks_v1'] = '[{"id":"owner-unknown"}]';
      expect(await BookmarkStore.load(), isEmpty);
      expect(values['bookmarks_v1'], '[{"id":"owner-unknown"}]');
      expect(prefs.getString('bookmarks_v1'), '[{"id":"owner-unknown"}]');
      await BookmarkStore.add(
        const BookmarkItem(
          id: 'A-mark',
          bookId: 'A-book',
          bookTitle: 'synthetic',
          entryIndex: 0,
          entryTitle: 'synthetic',
          createdAt: 1,
        ),
      );
      await api.setToken('synthetic-B');
      expect(await BookmarkStore.load(), isEmpty);
      expect((await ProblemBookmarkStore.load()).allItems, isEmpty);
    },
  );

  test('late native exam load cannot republish A rows to B notifier', () async {
    await api.setToken('synthetic-A');
    deferredQuery = Completer<List<Map<String, Object>>>();
    queryEntered = Completer<void>();
    final pending = ExamPaperStore.load();
    final rejected = expectLater(pending, throwsA(isA<ApiException>()));
    await queryEntered!.future;
    await api.setToken('synthetic-B');
    deferredQuery!.complete([
      {'value': '[{"exam_id":"A-private"}]'},
    ]);
    await rejected;
    expect(ExamPaperStore.notifier.value, isEmpty);
  });

  test(
    'textbook cache is cleared on transition and an empty personal library is not catalog',
    () async {
      await api.setToken('synthetic-A');
      await TextbookStore.load(forceRefresh: true);
      expect(TextbookStore.cachedBooks, isNotEmpty);
      await api.setToken('synthetic-B');
      expect(TextbookStore.cachedBooks, isEmpty);
      expect(await TextbookStore.loadLibrary(forceRefresh: true), isEmpty);
      await api.clearToken();
      expect(TextbookStore.cachedBooks, isEmpty);
      await expectLater(
        TextbookStore.loadLibrary(),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('explicit obsolete scope cannot write through native LocalDb', () async {
    await api.setToken('synthetic-A');
    final a = await api.requireSessionScope();
    await api.setToken('synthetic-B');
    await expectLater(
      LocalDb.instance.setString('bookmarks_v1', 'A-private', scope: a),
      throwsA(isA<ApiException>()),
    );
    expect(values, isEmpty);
  });

  test(
    'native library outage uses only a known current actor cache, not empty success',
    () async {
      await api.setToken('synthetic-A');
      await LocalDb.instance.setString(
        'textbook_library_v1',
        '[{"id":"A-book","title":"synthetic"}]',
      );
      api.setHttpClientForTest(
        MockClient((_) async => http.Response('{}', 503)),
      );
      expect(
        (await TextbookStore.loadLibrary(forceRefresh: true)).single.id,
        'A-book',
      );
      await api.setToken('synthetic-B');
      await expectLater(
        TextbookStore.loadLibrary(forceRefresh: true),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
      );
      api.setHttpClientForTest(
        MockClient((_) async => http.Response('{}', 403)),
      );
      await expectLater(
        TextbookStore.loadLibrary(forceRefresh: true),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
    },
  );

  test('public acquisitions merge with personal library and never cross accounts', () async {
    await api.setToken('synthetic-A');
    final publishedId = 'published-${List.filled(64, 'a').join()}';
    var ownerA = true;
    api.setHttpClientForTest(MockClient((request) async {
      if (request.url.path == '/marketplace/textbooks/owned') {
        return http.Response(jsonEncode({'items': ownerA ? [
          {'textbook_id': publishedId, 'title': 'Public synthetic', 'price_points': 0}
        ] : []}), 200);
      }
      return http.Response(jsonEncode({'value': ownerA
          ? '[{"id":"A-personal","title":"Personal synthetic"}]' : null}), 200);
    }));
    final a = await TextbookStore.loadLibrary(forceRefresh: true);
    expect(a.map((book) => book.id), containsAll(['A-personal', publishedId]));
    ownerA = false;
    await api.setToken('synthetic-B');
    expect(await TextbookStore.loadLibrary(forceRefresh: true), isEmpty);
  });

  test(
    'late catalog response cannot restore cleared textbook memory cache',
    () async {
      await api.setToken('synthetic-A');
      final response = Completer<http.Response>();
      final entered = Completer<void>();
      api.setHttpClientForTest(
        MockClient((_) {
          entered.complete();
          return response.future;
        }),
      );
      final pending = TextbookStore.load(forceRefresh: true);
      final rejected = expectLater(pending, throwsA(isA<ApiException>()));
      await entered.future;
      await api.setToken('synthetic-B');
      response.complete(
        http.Response(
          '{"textbooks":[{"id":"A-private","title":"synthetic"}]}',
          200,
        ),
      );
      await rejected;
      expect(TextbookStore.cachedBooks, isEmpty);
    },
  );

  for (final codes in <List<String>?>[null, [], ['candidate-only']]) {
    test('library header preserves candidate provenance $codes', () async {
      await api.setToken('synthetic-library-meta');
      await TextbookStore.addToLibrary(BookData(
        id: 'synthetic-metadata-book',
        title: 'Synthetic metadata',
        subtitle: '',
        chapters: const [],
        schemaVersion: 2,
        standardCodes: const ['confirmed-only'],
        candidateStandardCodes: codes,
      ));
      final header = (await TextbookStore.loadLibrary()).single;
      expect(header.schemaVersion, 2);
      expect(header.standardCodes, ['confirmed-only']);
      expect(header.candidateStandardCodes, codes);
    });
  }
}
