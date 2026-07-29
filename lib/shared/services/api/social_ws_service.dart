import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import 'api_contract.dart';

typedef SocialEventHandler = void Function(Map<String, dynamic> event);

class SocialWebSocketService {
  SocialWebSocketService._();

  static final SocialWebSocketService instance = SocialWebSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _connecting = false;
  int _reconnectAttempt = 0;
  final List<SocialEventHandler> _handlers = [];

  /// 필요한 변수: 소셜 화면의 이벤트 처리 함수.
  /// 작동 원리: 중복 등록을 막아 하나의 서버 이벤트가 여러 번 화면에 반영되지 않게 한다.
  void addHandler(SocialEventHandler handler) {
    if (!_handlers.contains(handler)) _handlers.add(handler);
  }

  /// 필요한 변수: 닫히는 화면의 이벤트 처리 함수.
  /// 작동 원리: 마지막 화면이 사라지면 소켓·재접속 타이머를 함께 정리해 백그라운드 요청을 중단한다.
  void removeHandler(SocialEventHandler handler) {
    _handlers.remove(handler);
    if (_handlers.isEmpty) unawaited(_disconnect());
  }

  /// 필요한 변수: 인증 토큰과 등록된 이벤트 처리 함수.
  /// 작동 원리: 실제 소셜 화면이 열려 있을 때만 한 연결을 만들고 성공하면 재시도 간격을 초기화한다.
  Future<void> connect() async {
    if (_handlers.isEmpty || _connecting || _channel != null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connecting = true;
    try {
      final token = await ApiClient.instance.requireToken();
      final uri = ApiContract.webSocketUri(
        ApiPaths.socialWs,
        query: {'token': token},
      );
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _reconnectAttempt = 0;
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
      );
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  /// 필요한 변수: 연속 연결 실패 횟수와 활성 소셜 화면 여부.
  /// 작동 원리: 2·4·8·16·30초 지수 백오프를 적용하고 마지막 화면이 닫히면 재접속하지 않는다.
  void _scheduleReconnect() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_channel?.sink.close());
    _channel = null;
    _connecting = false;
    _reconnectTimer?.cancel();
    if (_handlers.isEmpty) return;
    const retrySeconds = <int>[2, 4, 8, 16, 30];
    final attemptIndex = _reconnectAttempt < retrySeconds.length
        ? _reconnectAttempt
        : retrySeconds.length - 1;
    final seconds = retrySeconds[attemptIndex];
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), connect);
  }

  /// 필요한 변수: WebSocket이 전달한 문자열 또는 맵 이벤트.
  /// 작동 원리: 유효한 JSON 객체만 복사된 처리 함수 목록에 안전하게 전달한다.
  void _handleMessage(dynamic data) {
    Map<String, dynamic>? parsed;
    if (data is String) {
      try {
        parsed = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
    } else if (data is Map) {
      parsed = Map<String, dynamic>.from(data);
    }
    if (parsed == null) return;
    for (final handler in List<SocialEventHandler>.from(_handlers)) {
      try {
        handler(parsed);
      } catch (_) {
        // ignore individual handler errors
      }
    }
  }

  /// 필요한 변수 없음.
  /// 작동 원리: 재접속 타이머·구독·소켓을 순서대로 닫아 추가 네트워크 요청을 막는다.
  Future<void> _disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _connecting = false;
    _reconnectAttempt = 0;
  }

  /// 필요한 변수 없음.
  /// 작동 원리: 서비스 종료 시 등록된 처리 함수와 모든 연결 자원을 함께 해제한다.
  Future<void> dispose() async {
    _handlers.clear();
    await _disconnect();
  }
}
