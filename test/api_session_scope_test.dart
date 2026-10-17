import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.clearToken();
  });
  tearDown(() => ApiClient.instance.clearToken());

  test('session change is observable before persistence and invalidates prior scope', () async {
    final client = ApiClient.instance;
    await client.setToken('actor-A');
    final old = await client.requireSessionScope();
    var signals = 0;
    void changed() { signals++; }
    client.sessionChanges.addListener(changed);
    try {
      final pending = client.setToken('actor-B');
      expect(signals, 1);
      expect(client.isCurrentSessionScope(old), isFalse);
      expect(() => client.assertSessionScope(old), throwsA(isA<ApiException>()));
      expect(client.sessionCacheNamespace, hasLength(64));
      expect(client.sessionCacheNamespace, isNot(contains('actor-B')));
      await pending;
      expect(client.isCurrentSessionScope(await client.requireSessionScope()), isTrue);
    } finally { client.sessionChanges.removeListener(changed); }
  });

  test('latest auth transition wins both stored keys; older completions are rejected', () async {
    final client = ApiClient.instance;
    Future<String> outcome(Future<void> operation) async {
      try { await operation; return 'applied'; }
      on ApiException catch (error) { return error.code!; }
    }
    final a = outcome(client.setToken('actor-A', username: 'A'));
    final clear = outcome(client.clearToken());
    final b = outcome(client.setToken('actor-B', username: 'B'));
    expect(await Future.wait([a, clear, b]), ['session_changed', 'session_changed', 'applied']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('jwt_token'), 'actor-B');
    expect(prefs.getString('auth.jwt'), 'actor-B');
    expect(prefs.getString('username'), 'B');
    await client.clearToken(expectedToken: 'actor-A');
    expect(await client.requireToken(), 'actor-B');
  });

  test('concurrent persisted session restoration publishes one scope', () async {
    final client = ApiClient.instance;
    await client.setToken('persisted-actor');
    client.clearTokenForTest();
    final scopes = await Future.wait(List.generate(10, (_) => client.requireSessionScope()));
    expect(scopes.map((scope) => scope.generation).toSet(), hasLength(1));
    expect(scopes.every(client.isCurrentSessionScope), isTrue);
    final clear = client.clearToken();
    final missing = expectLater(client.requireToken(), throwsA(isA<ApiException>()));
    await clear;
    await missing;
    expect(client.hasAuthenticatedSession, isFalse);
  });

  test('storage rejects another scope before sending and preserves server wire keys', () async {
    final client = ApiClient.instance;
    await client.setToken('actor-A');
    final old = await client.requireSessionScope();
    await client.setToken('actor-B');
    final requests = <http.Request>[];
    client.setHttpClientForTest(MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 200, headers: {'content-type': 'application/json'});
    }));
    try {
      await expectLater(client.setUserStorage('bookmarks_v1', 'A-private', scope: old),
        throwsA(isA<ApiException>().having((error) => error.code, 'code', 'session_changed')));
      expect(requests, isEmpty);
      await client.setUserStorage('bookmarks_v1', 'B-data', scope: await client.requireSessionScope());
      expect(requests.single.url.path, '/user/storage/bookmarks_v1');
      expect(requests.single.headers['Authorization'], 'Bearer actor-B');
    } finally { client.setHttpClientForTest(http.Client()); }
  });

  test('HTTP200 semantic storage failure is neither a cache miss nor a successful write', () async {
    final client = ApiClient.instance;
    await client.setToken('semantic-storage-actor');
    client.setHttpClientForTest(MockClient((_) async => http.Response(
      '{"success":false,"data":{"value":"unconfirmed"}}', 200,
      headers: {'content-type': 'application/json'})));
    try {
      final scope = await client.requireSessionScope();
      await expectLater(client.getUserStorage('bookmarks_v1', scope: scope), throwsStateError);
      expect(client.hasMemoryCacheForTest('/user/storage/bookmarks_v1'), isFalse);
      await expectLater(client.setUserStorage('bookmarks_v1', 'not-stored', scope: scope), throwsStateError);
      await expectLater(client.deleteUserStorage('bookmarks_v1', scope: scope), throwsStateError);
    } finally { client.setHttpClientForTest(http.Client()); }
  });
}
