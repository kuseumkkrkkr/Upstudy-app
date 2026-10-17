import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/api_contract.dart';

/// Optional event source used by widget tests; production arena traffic is REST-only.
abstract interface class ArenaSocket {
  Stream<Map<String, dynamic>> get events;
  void send(Map<String, dynamic> event);
  Future<void> close();
}

/// 아레나 API 래퍼.
/// GET은 캐시 정책 적용, POST는 실시간 처리로 운영한다.
class ArenaApi {
  ArenaApi._();

  static final ArenaApi instance = ArenaApi._();

  /// 경기 결과 수신 횟수. 대결장 뒤 화면이 즉시 최신 레이팅을 다시 읽도록 알린다.
  final ValueNotifier<int> resultRevision = ValueNotifier<int>(0);

  // POST 응답을 Map 형태로 정규화한다.
  // 필요 변수: path(요청 경로), body(요청 본문).
  // 동작: ApiClient의 authedPost를 사용해 토큰 기반 요청 후
  // 실패 상태면 예외로 변환해 상위에서 일관되게 처리한다.
  Future<Map<String, dynamic>> _postRequest(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = ApiContract.uri(path);
    final response = await ApiClient.instance.authedPost(
      uri,
      body: body ?? const <String, dynamic>{},
    );

    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(utf8.decode(response.bodyBytes)) as Map,
          );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['detail'] ?? '아레나 API 요청이 실패했습니다.');
    }
    return decoded;
  }

  // GET 응답을 캐시와 함께 가져온다.
  // 필요 변수: path(요청 경로), cacheTtl(캐시 유효시간).
  // 동작: APIClient의 authedGetJson를 사용해 인증 + ETag 재검증 + TTL 캐시를 함께 사용한다.
  Future<Map<String, dynamic>> _getCached(
    String path, {
    Duration cacheTtl = const Duration(minutes: 1),
    bool useCache = true,
    bool forceRefresh = false,
  }) async {
    final response = await ApiClient.instance.authedGetJson(
      ApiContract.uri(path),
      useCache: useCache,
      forceRefresh: forceRefresh,
      cacheTtl: cacheTtl,
      parser: (payload) {
        if (payload is Map<String, dynamic>) return payload;
        if (payload is Map) return Map<String, dynamic>.from(payload);
        return const <String, dynamic>{};
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  // 아레나 요약 화면용 데이터 조회.
  // 필요 변수: 없음.
  // 동작: 30초 캐시를 적용해 화면 재갱신 구간의 대역폭을 줄인다.
  Future<Map<String, dynamic>> summary({bool forceRefresh = false}) =>
      _getCached(
        '/arena/summary',
        cacheTtl: const Duration(seconds: 30),
        forceRefresh: forceRefresh,
      );

  /// 필요한 변수: 대결 큐 유형. 봇을 제외한 실제 참가자 랭킹을 짧게 조회한다.
  Future<Map<String, dynamic>> rankings(
    String queueType, {
    int limit = 100,
    int offset = 0,
    String query = '',
    String scope = 'all',
    bool forceRefresh = false,
  }) {
    final search = query.trim();
    if (limit < 1 ||
        limit > 100 ||
        offset < 0 ||
        query.length > 80 ||
        !const {'all', 'my_tier', 'friends'}.contains(scope)) {
      throw ArgumentError('랭킹 페이지 범위가 올바르지 않습니다.');
    }
    return _getCached(
      Uri(
        path: '/arena/rankings',
        queryParameters: {
          'queue_type': queueType,
          'limit': '$limit',
          'offset': '$offset',
          if (search.isNotEmpty) 'query': search,
          if (scope != 'all') 'scope': scope,
        },
      ).toString(),
      cacheTtl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
    );
  }

  // 매칭 큐 참가.
  // 필요 변수: queueType(큐 타입).
  // 동작: 즉시 상태 변경이 필요해 POST로 즉시 반영한다.
  Future<Map<String, dynamic>> join(String queueType) async {
    final result = await _postRequest(
      '/arena/queue/join',
      body: {
        'queue_type': queueType,
        'idempotency_key':
            '${DateTime.now().microsecondsSinceEpoch}-$queueType',
      },
    );
    await ApiClient.instance.invalidateCachePath('/arena');
    return result;
  }

  // 매칭 큐 취소.
  // 필요 변수: 없음.
  // 동작: 큐 상태 변경이 즉시 반영되어야 하므로 캐시 미적용 POST로 처리한다.
  Future<Map<String, dynamic>> cancel() async {
    final result = await _postRequest('/arena/queue/cancel');
    await ApiClient.instance.invalidateCachePath('/arena');
    return result;
  }

  // 특정 매치 상태 조회.
  // 필요 변수: matchId(매치 ID).
  // 동작: 10초 캐시를 적용해 같은 매치의 잦은 재요청 부담을 줄인다.
  Future<Map<String, dynamic>> matchState(String matchId) =>
      _getCached('/arena/matches/$matchId', useCache: false);

  /// 실제 경기·문항·답안을 제출하며 네트워크 재시도에는 같은 [idempotencyKey]를 쓴다.
  /// 응답의 문항과 채점 타입을 검증한다. 서버 멱등 보장은 서버 계약이 별도로 필요하다.
  Future<Map<String, dynamic>> submit(
    String matchId,
    String questionId,
    String answer, {
    String? idempotencyKey,
  }) async {
    if (idempotencyKey != null &&
        (idempotencyKey.trim().isEmpty || idempotencyKey.length > 128)) {
      throw ArgumentError('답안 요청 키가 올바르지 않습니다.');
    }
    final result = await _postRequest(
      '/arena/matches/${Uri.encodeComponent(matchId)}/answers',
      body: {
        'question_id': questionId,
        'answer': answer,
        'idempotency_key':
            idempotencyKey ??
            '${DateTime.now().microsecondsSinceEpoch}-$questionId',
      },
    );
    if (result['correct'] is! bool ||
        result['finished'] is! bool ||
        (result['question_id'] != null &&
            result['question_id'].toString() != questionId)) {
      throw const FormatException('답안 채점 응답을 확인하지 못했습니다.');
    }
    // Legacy canary omits the ID; retain the ID of this accepted HTTP request.
    return {...result, 'question_id': questionId};
  }

  /// 필요한 변수: 종료된 경기 ID.
  /// 작동 원리: 캐시를 사용하지 않고 참가자 전용 결과·문항별 분석을 즉시 조회한다.
  Future<Map<String, dynamic>> matchResult(String matchId) async {
    final result = await _getCached(
      '/arena/matches/$matchId/result',
      useCache: false,
    );
    await invalidateSummary();
    return result;
  }

  /// 결과를 떠난 본인의 임시 답안만 서버에서 파기한다. 계정이 바뀌면 서버가 거절한다.
  Future<void> acknowledgeResult(
    String matchId,
    String expectedViewerUserId,
  ) async {
    await _postRequest(
      '/arena/matches/${Uri.encodeComponent(matchId)}/result/ack',
      body: {'expected_viewer_user_id': expectedViewerUserId},
    );
  }

  /// 필요한 변수 없음. 경기 종료 뒤 요약·랭킹이 이전 레이팅을 재사용하지 않도록 아레나 캐시를 비운다.
  Future<void> invalidateSummary() async {
    await ApiClient.instance.invalidateCachePath('/arena');
    resultRevision.value++;
  }
}
