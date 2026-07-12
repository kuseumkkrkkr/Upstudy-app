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
  bool _connecting = false;
  final List<SocialEventHandler> _handlers = [];

  void addHandler(SocialEventHandler handler) {
    _handlers.add(handler);
  }

  void removeHandler(SocialEventHandler handler) {
    _handlers.remove(handler);
  }

  Future<void> connect() async {
    if (_connecting || _channel != null) return;
    _connecting = true;
    try {
      final token = await ApiClient.instance.requireToken();
      final uri = ApiContract.webSocketUri(
        ApiPaths.socialWs,
        query: {'token': token},
      );
      _channel = WebSocketChannel.connect(uri);
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

  void _scheduleReconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (_connecting) return;
    _connecting = false;
    Future.delayed(const Duration(seconds: 2), connect);
  }

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

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _connecting = false;
  }
}
