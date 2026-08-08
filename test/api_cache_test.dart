import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/api_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    ApiClient.instance.setHttpClientForTest(http.Client());
  });

  test('사용자 캐시 네임스페이스는 SHA-256으로 격리된다', () {
    final client = ApiClient.instance;
    const token = 'student-token-with-private-value';
    final expected = sha256.convert(utf8.encode(token)).toString();

    expect(client.userCacheTagForTest(token), expected);
    expect(client.userCacheTagForTest(token), hasLength(64));
    expect(client.userCacheTagForTest(token), isNot(contains(token)));
  });

  test('동시 GET은 원시 응답만 한 번 받고 호출자별 parser를 적용한다', () async {
    final client = ApiClient.instance;
    await client.setToken('parser-isolation-token');
    var requestCount = 0;
    final gate = Completer<void>();
    client.setHttpClientForTest(
      MockClient((_) async {
        requestCount += 1;
        await gate.future;
        return http.Response('{"data":{"value":7}}', 200);
      }),
    );

    final first = client.authedGetJson<int>(
      ApiContract.uri('/cache/parser-test'),
      useCache: true,
      parser: (value) => (value as Map<String, dynamic>)['value'] as int,
    );
    final second = client.authedGetJson<String>(
      ApiContract.uri('/cache/parser-test'),
      useCache: true,
      parser: (value) => '값:${(value as Map<String, dynamic>)['value']}',
    );
    await Future<void>.delayed(Duration.zero);
    gate.complete();

    expect((await first).data, 7);
    expect((await second).data, '값:7');
    expect(requestCount, 1);
  });

  test('경로 무효화와 로그아웃은 해당 사용자 캐시를 정리한다', () async {
    final client = ApiClient.instance;
    await client.setToken('cache-cleanup-token');
    await client.seedCacheForTest('/courses/v2', '{"data":[]}');
    await client.seedCacheForTest('/arena/summary', '{"queues":[]}');

    await client.invalidateCachePath('/courses');
    expect(client.hasMemoryCacheForTest('/courses/v2'), isFalse);
    expect(client.hasMemoryCacheForTest('/arena/summary'), isTrue);

    await client.clearToken();
    await client.setToken('cache-cleanup-token');
    expect(client.hasMemoryCacheForTest('/arena/summary'), isFalse);
  });

  test('오답 저장 후 풀이 이력 캐시를 즉시 무효화한다', () async {
    final client = ApiClient.instance;
    await client.setToken('wrong-answer-token');
    await client.seedCacheForTest('/history/solve', '{"items":[]}');
    Map<String, dynamic>? requestBody;
    client.setHttpClientForTest(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/history/solve');
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"item":{}}', 200);
      }),
    );

    await client.recordSolveHistory(questId: 'quest-wrong-1', isCorrect: false);

    expect(requestBody?['quest_id'], 'quest-wrong-1');
    expect(requestBody?['is_correct'], isFalse);
    expect(client.hasMemoryCacheForTest('/history/solve'), isFalse);
  });

  test('그룹 생성 후 내 그룹 목록 캐시를 즉시 무효화한다', () async {
    final client = ApiClient.instance;
    await client.setToken('study-group-token');
    await client.seedCacheForTest('/social/study-groups/mine', '{"groups":[]}');
    client.setHttpClientForTest(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/social/study-groups');
        return http.Response(
          '{"group_id":"group-1","name":"매일 수학","members":1}',
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final group = await client.createStudyGroup(name: '매일 수학', maxMembers: 12);

    expect(group.id, 'group-1');
    expect(client.hasMemoryCacheForTest('/social/study-groups/mine'), isFalse);
  });

  test('그룹 참가 후 내 그룹과 검색 캐시를 즉시 무효화한다', () async {
    final client = ApiClient.instance;
    await client.setToken('study-group-join-token');
    await client.seedCacheForTest('/social/study-groups/mine', '{"groups":[]}');
    await client.seedCacheForTest(
      '/social/study-groups/search',
      '{"groups":[]}',
    );
    client.setHttpClientForTest(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/social/study-groups/group-1/join');
        return http.Response('{}', 200);
      }),
    );

    await client.joinStudyGroup(groupId: 'group-1');

    expect(client.hasMemoryCacheForTest('/social/study-groups/mine'), isFalse);
    expect(
      client.hasMemoryCacheForTest('/social/study-groups/search'),
      isFalse,
    );
  });
}
