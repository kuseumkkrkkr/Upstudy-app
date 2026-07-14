import 'package:s11/shared/services/api/api_client.dart';

typedef DirectMessageListener = void Function(DirectMessage message);

class SocialMessageHub {
  static final List<DirectMessageListener> _listeners = [];

  /// 필요한 변수는 수신 메시지 콜백이다.
  /// 작동 원리는 현재 열린 소셜 화면만 중앙 WebSocket 메시지를 구독하도록 중복 없이 등록하는 것이다.
  static void addListener(DirectMessageListener listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  /// 필요한 변수는 해제할 메시지 콜백이다.
  /// 작동 원리는 화면 종료 시 정적 목록에서 제거해 누적 리스너와 메모리 누수를 막는 것이다.
  static void removeListener(DirectMessageListener listener) {
    _listeners.remove(listener);
  }

  /// 필요한 변수는 WebSocket 또는 전송 API가 만든 DirectMessage다.
  /// 작동 원리는 현재 등록된 복사본에만 순차 전달해 구독 중 변경에도 안전하게 유지하는 것이다.
  static void dispatch(DirectMessage message) {
    for (final listener in List<DirectMessageListener>.from(_listeners)) {
      listener(message);
    }
  }
}
