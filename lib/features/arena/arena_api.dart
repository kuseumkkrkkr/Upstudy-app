import 'dart:convert';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/api_contract.dart';

/// 아레나 API 래퍼.
/// GET은 캐시 정책 적용, POST는 실시간 처리로 운영한다.
class ArenaApi {
  ArenaApi._();

  static final ArenaApi instance = ArenaApi._();

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
  }) async {
    final response = await ApiClient.instance.authedGetJson(
      ApiContract.uri(path),
      useCache: true,
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
  Future<Map<String, dynamic>> summary() => _getCached(
        '/arena/summary',
        cacheTtl: const Duration(seconds: 30),
      );

  // 매칭 큐 참가.
  // 필요 변수: queueType(큐 타입).
  // 동작: 즉시 상태 변경이 필요해 POST로 즉시 반영한다.
  Future<Map<String, dynamic>> join(String queueType) => _postRequest(
        '/arena/queue/join',
        body: {
          'queue_type': queueType,
          'idempotency_key': '${DateTime.now().microsecondsSinceEpoch}-$queueType',
        },
      );

  // 매칭 큐 취소.
  // 필요 변수: 없음.
  // 동작: 큐 상태 변경이 즉시 반영되어야 하므로 캐시 미적용 POST로 처리한다.
  Future<void> cancel() async {
    await _postRequest('/arena/queue/cancel');
  }

  // 특정 매치 상태 조회.
  // 필요 변수: matchId(매치 ID).
  // 동작: 10초 캐시를 적용해 같은 매치의 잦은 재요청 부담을 줄인다.
  Future<Map<String, dynamic>> matchState(String matchId) => _getCached(
        '/arena/matches/$matchId',
        cacheTtl: const Duration(seconds: 10),
      );

  // 답안 제출.
  // 필요 변수: matchId, questionId, answer.
  // 동작: 정답 제출은 매번 상태 변경이 일어나므로 캐시 미적용 POST로 처리한다.
  Future<Map<String, dynamic>> submit(
    String matchId,
    String questionId,
    String answer,
  ) =>
      _postRequest(
        '/arena/matches/$matchId/answers',
        body: {
          'question_id': questionId,
          'answer': answer,
          'idempotency_key': '${DateTime.now().microsecondsSinceEpoch}-$questionId',
        },
      );

  // 매치 채팅 전송.
  // 필요 변수: matchId, message.
  // 동작: 채팅은 실시간성 때문에 즉시 처리 POST로 호출한다.
  Future<void> chat(String matchId, String message) async {
    await _postRequest(
      '/arena/matches/$matchId/chat',
      body: {'message': message},
    );
  }
}
