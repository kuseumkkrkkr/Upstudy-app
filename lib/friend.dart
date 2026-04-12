import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_client.dart';
import 'docx_box.dart' as docx;
import 'package:s11/mainstudent.dart';
import 'study_center.dart' as study_center;
import 'widgets/modals/rating_detail_modal.dart';
import 'widgets/app_drawer.dart';
import 'services/social_notification_store.dart';
import 'services/social_ws_service.dart';

const _green = Color(0xFF1B402B);
const _bgGrey = Color(0xFFF7F7F7);
const _shadow = BoxShadow(
  blurRadius: 4,
  color: Color(0x33000000),
  offset: Offset(0, 2),
);

TextStyle _ts({
  double size = 16,
  FontWeight weight = FontWeight.normal,
  Color color = Colors.black,
  bool scaleUp = true,
}) => TextStyle(
  fontSize: size * (scaleUp ? 1.1 : 1.0),
  fontWeight: weight,
  color: color,
);

BoxDecoration _cardDeco({double radius = 16, Color color = Colors.white}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [_shadow],
    );

double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
  final width = MediaQuery.of(context).size.width;
  final scale = width / 1100;
  if (scale < min) return min;
  if (scale > max) return max;
  return scale;
}

String _formatTimeLabel(DateTime value) {
  final now = DateTime.now();
  if (value.year == now.year &&
      value.month == now.month &&
      value.day == now.day) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  return '${value.month}/${value.day}';
}

enum _FriendRequestDirection { incoming, outgoing }

enum _FriendRequestStatus { pending, accepted, declined, cancelled }

class _FriendRequest {
  _FriendRequest({
    required this.id,
    required this.username,
    required this.direction,
    this.message,
    this.status = _FriendRequestStatus.pending,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String username;
  final _FriendRequestDirection direction;
  final DateTime createdAt;
  final String? message;
  _FriendRequestStatus status;

  bool get isIncoming => direction == _FriendRequestDirection.incoming;
  bool get isPending => status == _FriendRequestStatus.pending;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'direction': direction.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      if (message != null) 'message': message,
    };
  }

  factory _FriendRequest.fromJson(Map<String, dynamic> json) {
    final directionRaw = json['direction']?.toString() ?? 'incoming';
    final statusRaw = json['status']?.toString() ?? 'pending';
    final id = json['id']?.toString() ?? '';
    _FriendRequestDirection direction;
    switch (directionRaw) {
      case 'outgoing':
        direction = _FriendRequestDirection.outgoing;
        break;
      default:
        direction = _FriendRequestDirection.incoming;
        break;
    }
    _FriendRequestStatus status;
    switch (statusRaw) {
      case 'accepted':
        status = _FriendRequestStatus.accepted;
        break;
      case 'declined':
        status = _FriendRequestStatus.declined;
        break;
      case 'cancelled':
      case 'canceled':
        status = _FriendRequestStatus.cancelled;
        break;
      default:
        status = _FriendRequestStatus.pending;
        break;
    }
    return _FriendRequest(
      id: id,
      username: json['username']?.toString() ?? '',
      direction: direction,
      status: status,
      message: json['message']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  factory _FriendRequest.fromApi(FriendRequest req) {
    _FriendRequestDirection direction;
    switch (req.direction.toLowerCase()) {
      case 'outgoing':
        direction = _FriendRequestDirection.outgoing;
        break;
      default:
        direction = _FriendRequestDirection.incoming;
        break;
    }
    _FriendRequestStatus status;
    switch (req.status.toLowerCase()) {
      case 'accepted':
        status = _FriendRequestStatus.accepted;
        break;
      case 'declined':
        status = _FriendRequestStatus.declined;
        break;
      case 'cancelled':
        status = _FriendRequestStatus.cancelled;
        break;
      default:
        status = _FriendRequestStatus.pending;
        break;
    }
    return _FriendRequest(
      id: req.id,
      username: req.username,
      direction: direction,
      status: status,
      message: req.message,
      createdAt: req.createdAt,
    );
  }
}

typedef DirectMessageListener = void Function(DirectMessage message);

class SocialMessageHub {
  static final List<DirectMessageListener> _listeners = [];

  static void addListener(DirectMessageListener listener) {
    _listeners.add(listener);
  }

  static void removeListener(DirectMessageListener listener) {
    _listeners.remove(listener);
  }

  static void dispatch(DirectMessage message) {
    for (final listener in List<DirectMessageListener>.from(_listeners)) {
      listener(message);
    }
  }
}

class SoWidget extends StatefulWidget {
  const SoWidget({super.key});

  static String routeName = 'so';
  static String routePath = '/so';

  @override
  State<SoWidget> createState() => _SoWidgetState();
}

class _SoWidgetState extends State<SoWidget> {
  static const Color primaryColor = _green;
  static const Color bgColor = _bgGrey; // primaryBackground 대체

  static const TextStyle navStyle = TextStyle(
    color: primaryColor,
    fontSize: 30,
    fontWeight: FontWeight.normal,
  );
  static const List<IconData> _groupLogoIcons = [
    Icons.auto_awesome,
    Icons.bolt,
    Icons.eco,
    Icons.book,
    Icons.calculate,
    Icons.school,
    Icons.psychology,
    Icons.public,
    Icons.lightbulb,
    Icons.star,
  ];
  static const List<Color> _groupLogoColors = [
    Color(0xFF1B402B),
    Color(0xFF2D5F8B),
    Color(0xFF8B4A2D),
    Color(0xFF6A5B2E),
    Color(0xFF4E5F8B),
    Color(0xFF7B3B5F),
    Color(0xFF2E6A5B),
    Color(0xFF8B5F2D),
    Color(0xFF5B4E8B),
    Color(0xFF3B7B5F),
  ];

  final List<_FriendRank> _friendRanks = const [];

  List<_FriendInfo> _friends = [];

  List<_FriendRequest> _friendRequests = [];

  List<_MessageInfo> _messages = [];
  bool _loadingThreads = false;
  bool _threadsHasMore = true;
  String? _threadsBefore;

  int _unreadMessages = 0;
  final Set<String> _unreadThreads = {};

  final List<_GroupInfo> _groups = [];

  final List<_GroupInfo> _groupSearchCatalog = const [];

  final List<String> _groupSearchHistory = [];

  @override
  void initState() {
    super.initState();
    _refreshFriends();
    unawaited(_loadFriendRequests());
    unawaited(_loadConversationThreads());
    SocialMessageHub.addListener(_handleIncomingDirectMessage);
    SocialWebSocketService.instance.addHandler(_handleSocketEvent);
    unawaited(SocialWebSocketService.instance.connect());
  }

  @override
  void dispose() {
    SocialWebSocketService.instance.removeHandler(_handleSocketEvent);
    SocialMessageHub.removeListener(_handleIncomingDirectMessage);
    super.dispose();
  }

  Future<void> _refreshFriends() async {
    try {
      final profiles = await ApiClient.instance.listFriends();
      if (!mounted) return;
      setState(() {
        _friends = profiles
            .map(
              (profile) => _FriendInfo(
                name: profile.username,
                status: profile.status.isNotEmpty ? profile.status : '상태 없음',
                ovr: profile.ovr,
              ),
            )
            .toList();
      });
      _cleanupFulfilledRequests();
    } catch (_) {
      // Ignore fetch failures for now.
    }
  }

  Future<void> _loadFriendRequests() async {
    try {
      final requests = await ApiClient.instance.listFriendRequests();
      if (mounted) {
        setState(
          () => _friendRequests = requests
              .map(_FriendRequest.fromApi)
              .where((req) => req.username.isNotEmpty)
              .toList(),
        );
      }
    } catch (_) {
      // ignore fetch errors
    } finally {
      _syncNotificationCounts();
    }
  }

  List<_FriendRequest> get _incomingRequests =>
      _friendRequests.where((req) => req.isIncoming).toList();

  List<_FriendRequest> get _outgoingRequests =>
      _friendRequests.where((req) => !req.isIncoming).toList();

  List<_FriendRequest> get _pendingIncomingRequests =>
      _incomingRequests.where((req) => req.isPending).toList();

  List<_FriendRequest> get _pendingOutgoingRequests =>
      _outgoingRequests.where((req) => req.isPending).toList();

  void _syncNotificationCounts({int? friendRemovals}) {
    final currentRemovals =
        friendRemovals ?? SocialNotificationStore.notifier.value.friendRemovals;
    SocialNotificationStore.update(
      unreadMessages: _unreadMessages,
      friendRequests: _pendingIncomingRequests.length,
      friendRemovals: currentRemovals,
    );
  }

  bool _isExistingFriend(String username) {
    return _friends.any(
      (friend) => friend.name.toLowerCase() == username.toLowerCase(),
    );
  }

  bool _hasPendingRequest(String username) {
    return _friendRequests.any(
      (req) =>
          req.username.toLowerCase() == username.toLowerCase() && req.isPending,
    );
  }

  void _cleanupFulfilledRequests() {
    final friendNames = _friends
        .map((friend) => friend.name.toLowerCase())
        .toSet();
    final before = _friendRequests.length;
    _friendRequests.removeWhere(
      (req) =>
          req.isPending &&
          friendNames.contains(req.username.toLowerCase()) &&
          req.direction == _FriendRequestDirection.outgoing,
    );
    if (before != _friendRequests.length) {
      setState(() {});
    }
    _syncNotificationCounts();
  }

  Future<void> _loadConversationThreads({bool loadMore = false}) async {
    if (_loadingThreads || (!_threadsHasMore && loadMore)) return;
    setState(() => _loadingThreads = true);
    try {
      final fetched = await ApiClient.instance.fetchConversationThreads(
        limit: 15,
        before: loadMore ? _threadsBefore : null,
      );
      if (!mounted) return;
      final mapped = fetched.map((dm) {
        final name = dm.from.isNotEmpty ? dm.from : dm.to;
        return _MessageInfo(
          name: name,
          lastMessage: dm.text,
          timeAgo: _formatTimeLabel(dm.createdAt),
        );
      }).toList();
      final combined = loadMore ? [..._messages, ...mapped] : mapped;
      combined.sort((a, b) => b.timeAgo.compareTo(a.timeAgo));
      setState(() {
        _messages = combined;
        _threadsHasMore = fetched.length >= 15;
        _threadsBefore = fetched.isNotEmpty ? fetched.last.createdAt.toIso8601String() : _threadsBefore;
      });
    } catch (_) {
      // ignore load errors for conversation list to avoid blocking UI
    } finally {
      if (mounted) setState(() => _loadingThreads = false);
    }
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    final payload = event['payload'];
    if (type.isEmpty || payload == null) return;
    Map<String, dynamic>? data;
    if (payload is Map) {
      data = Map<String, dynamic>.from(payload as Map);
    }
    switch (type) {
      case 'direct_message':
        if (data != null) _handleDirectMessageEvent(data);
        break;
      case 'friend_request':
        if (data != null) _handleFriendRequestEvent(data);
        break;
      case 'friend_request_accepted':
      case 'friend_request_declined':
      case 'friend_request_cancelled':
        if (data != null) _handleFriendRequestStatusEvent(type, data);
        break;
      default:
        break;
    }
  }

  void _handleDirectMessageEvent(Map<String, dynamic> payload) {
    try {
      final message = DirectMessage.fromJson(payload);
      SocialMessageHub.dispatch(message);
    } catch (_) {
      // ignore malformed payloads
    }
  }

  void _handleFriendRequestEvent(Map<String, dynamic> payload) {
    final req = _FriendRequest.fromJson(payload);
    if (req.id.isEmpty) return;
    setState(() {
      _friendRequests.removeWhere((r) => r.id == req.id);
      _friendRequests.add(req);
    });
    _syncNotificationCounts();
  }

  void _handleFriendRequestStatusEvent(
    String type,
    Map<String, dynamic> payload,
  ) {
    final req = _FriendRequest.fromJson(payload);
    if (req.id.isEmpty) return;
    setState(() {
      _friendRequests.removeWhere((r) => r.id == req.id);
      if (req.isPending) {
        _friendRequests.add(req);
      }
    });
    _syncNotificationCounts();
    if (type == 'friend_request_accepted') {
      unawaited(_refreshFriends());
    }
  }

  Future<void> _sendFriendRequest({
    required _FriendInfo friend,
    required BuildContext rootContext,
  }) async {
    if (_isExistingFriend(friend.name)) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('Already added as a friend.')),
      );
      return;
    }
    if (_hasPendingRequest(friend.name)) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('A friend request is already pending.')),
      );
      return;
    }
    try {
      final created = await ApiClient.instance.sendFriendRequest(
        username: friend.name,
        message: friend.status,
      );
      if (!mounted) return;
      setState(() {
        _friendRequests.add(_FriendRequest.fromApi(created));
      });
      _syncNotificationCounts();
      ScaffoldMessenger.of(
        rootContext,
      ).showSnackBar(const SnackBar(content: Text('Friend request sent.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('Failed to send friend request.')),
      );
    }
  }

  Future<void> _acceptRequest(_FriendRequest request) async {
    try {
      if (request.id.isEmpty) {
        throw Exception('Missing request id');
      }
      await ApiClient.instance.acceptFriendRequest(request.id);
      await _refreshFriends();
      if (!mounted) return;
      setState(() {
        _friendRequests.removeWhere((req) => req.id == request.id);
      });
      _syncNotificationCounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request.username}님을 친구로 추가했어요.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구 추가를 완료하지 못했어요. 다시 시도해주세요.')),
      );
    }
  }

  Future<void> _declineRequest(_FriendRequest request) async {
    try {
      if (request.id.isEmpty) {
        throw Exception('Missing request id');
      }
      await ApiClient.instance.declineFriendRequest(request.id);
      if (!mounted) return;
      setState(() {
        _friendRequests.removeWhere((req) => req.id == request.id);
      });
      _syncNotificationCounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${request.username}?? ??? ?????.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?? ??? ?????.')),
      );
    }
  }

  Future<void> _cancelOutgoingRequest(_FriendRequest request) async {
    try {
      if (request.id.isEmpty) {
        throw Exception('Missing request id');
      }
      await ApiClient.instance.cancelFriendRequest(request.id);
      if (!mounted) return;
      setState(() {
        _friendRequests.removeWhere((req) => req.id == request.id);
      });
      _syncNotificationCounts();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('?? ?? ??? ?????.')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?? ??? ?????.')),
      );
    }
  }

  Future<void> _removeFriend(_FriendInfo friend) async {
    try {
      await ApiClient.instance.removeFriend(friend.name);
      await _refreshFriends();
      final nextRemoval =
          SocialNotificationStore.notifier.value.friendRemovals + 1;
      _syncNotificationCounts(friendRemovals: nextRemoval);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구가 삭제됐어요')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구 삭제에 실패했어요')));
    }
  }

  void _upsertThreadPreview(String name, String text, {DateTime? at}) {
    final label = _formatTimeLabel(at ?? DateTime.now());
    setState(() {
      _messages = [
        _MessageInfo(name: name, lastMessage: text, timeAgo: label),
        ..._messages.where((msg) => msg.name != name),
      ];
    });
  }

  void _incrementUnreadMessage({String? from, String? preview, DateTime? at}) {
    if (from != null) {
      _upsertThreadPreview(from, preview ?? '새 쪽지', at: at);
      _unreadThreads.add(from);
    }
    setState(() => _unreadMessages = _unreadThreads.length);
    _syncNotificationCounts();
  }

  void _markMessagesRead({String? thread}) {
    if (thread != null) {
      _unreadThreads.remove(thread);
    } else {
      _unreadThreads.clear();
    }
    setState(() => _unreadMessages = _unreadThreads.length);
    _syncNotificationCounts();
  }

  void _handleIncomingDirectMessage(DirectMessage message) {
    if (message.isMine) return;
    final from = message.from.isNotEmpty ? message.from : '? ? ??';
    _incrementUnreadMessage(
      from: from,
      preview: message.text,
      at: message.createdAt,
    );
  }

  _MessageInfo _ensureMessageThreadForFriend(_FriendInfo friend) {
    final existing = _messages.firstWhere(
      (msg) => msg.name == friend.name,
      orElse: () => _MessageInfo(
        name: friend.name,
        lastMessage: '새 대화를 시작했어요.',
        timeAgo: _formatTimeLabel(DateTime.now()),
      ),
    );
    _upsertThreadPreview(friend.name, existing.lastMessage);
    return _messages.firstWhere((msg) => msg.name == friend.name);
  }

  void _openFriendActionModal(_FriendInfo friend) {
    _showBlurDialog(
      _dialogShell(
        title: '${friend.name} 작업',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '마우스 우클릭 또는 길게 눌러 열 수 있는 메뉴입니다.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('프로필 보기 기능은 준비 중입니다.')),
                );
              },
              icon: const Icon(Icons.person),
              label: const Text('프로필 보기'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: const BorderSide(color: primaryColor),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                final info = _ensureMessageThreadForFriend(friend);
                _openMessageThread(info);
              },
              icon: const Icon(Icons.mail_outline),
              label: const Text('쪽지 보내기'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _removeFriend(friend);
              },
              icon: const Icon(Icons.person_remove_alt_1, color: Colors.red),
              label: const Text('친구 삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestTile(_FriendRequest request, {required bool incoming}) {
    final name = request.username;
    final createdLabel =
        '${request.createdAt.month}/${request.createdAt.day} 요청';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primaryColor.withOpacity(0.12),
            child: Text(
              name.isNotEmpty ? name.substring(0, 1) : '?',
              style: const TextStyle(color: primaryColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  incoming ? '친구 요청 · 대기 중' : '보낸 요청 · 대기 중',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  createdLabel,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (incoming) ...[
            TextButton(
              onPressed: () => _declineRequest(request),
              child: const Text('거절'),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(72, 36),
              ),
              onPressed: () => _acceptRequest(request),
              child: const Text('수락'),
            ),
          ] else ...[
            TextButton(
              onPressed: () => _cancelOutgoingRequest(request),
              child: const Text('취소'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _requestSection({
    required String title,
    required List<_FriendRequest> requests,
    required bool incoming,
  }) {
    if (requests.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: incoming ? 136 : 110,
          child: ListView.separated(
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _requestTile(requests[index], incoming: incoming),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Future<void> _showBlurDialog(Widget child) async {
    await showGeneralDialog(
      context: context,
      barrierLabel: 'dialog',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.2),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Center(
            child: Material(color: Colors.transparent, child: child),
          ),
        );
      },
      transitionBuilder: (_, animation, __, dialogChild) {
        return FadeTransition(opacity: animation, child: dialogChild);
      },
    );
  }

  void _openAddFriendModal() {
    String query = '';
    List<_FriendInfo> results = [];
    bool isSearching = false;
    String? errorMessage;
    final rootContext = context;
    _showBlurDialog(
      _dialogShell(
        title: '친구 추가',
        width: 640,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> performSearch() async {
              final keyword = query.trim();
              if (keyword.isEmpty) {
                setModalState(() {
                  results = [];
                  errorMessage = null;
                });
                return;
              }
              setModalState(() {
                isSearching = true;
                errorMessage = null;
              });
              try {
                final profiles = await ApiClient.instance.searchFriends(
                  query: keyword,
                  limit: 20,
                );
                if (!context.mounted) return;
                setModalState(() {
                  results = profiles
                      .map(
                        (profile) => _FriendInfo(
                          name: profile.username,
                          status: profile.status.isNotEmpty
                              ? profile.status
                              : '상태 없음',
                          ovr: profile.ovr,
                        ),
                      )
                      .toList();
                });
              } catch (_) {
                if (!context.mounted) return;
                setModalState(() {
                  results = [];
                  errorMessage = '검색에 실패했어요';
                });
              } finally {
                if (!context.mounted) return;
                setModalState(() {
                  isSearching = false;
                });
              }
            }

            final keyword = query.trim();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '친구의 닉네임을 검색해 친구 요청을 보낼 수 있어요. 상대방이 수락해야 친구로 등록됩니다.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setModalState(() {
                            query = value;
                            results = [];
                            errorMessage = null;
                          });
                        },
                        onSubmitted: (_) {
                          FocusScope.of(context).unfocus();
                        },
                        decoration: InputDecoration(
                          hintText: '닉네임 검색',
                          filled: true,
                          fillColor: bgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: primaryColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 44,
                      width: 88,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          FocusScope.of(context).unfocus();
                          await performSearch();
                        },
                        child: const Text('검색'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '검색 결과',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 260,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: keyword.isEmpty
                        ? _emptyState('닉네임을 입력해 주세요')
                        : isSearching
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: primaryColor,
                            ),
                          )
                        : errorMessage != null
                        ? _emptyState(errorMessage!)
                        : results.isEmpty
                        ? _emptyState('검색 결과가 없어요')
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final friend = results[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: primaryColor.withOpacity(
                                        0.12,
                                      ),
                                      child: Text(
                                        friend.name.substring(0, 1),
                                        style: const TextStyle(
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            friend.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            friend.status,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'OVR ${friend.ovr}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                        side: const BorderSide(
                                          color: primaryColor,
                                        ),
                                      ),
                                      onPressed: () async {
                                        await _sendFriendRequest(
                                          friend: friend,
                                          rootContext: rootContext,
                                        );
                                      },
                                      child: const Text('요청'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openInboxModal() async {
    await _showBlurDialog(
      _dialogShell(
        title: '쪽지함',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('최근 쪽지 목록', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            if (_messages.isEmpty)
              SizedBox(height: 120, child: _emptyState('쪽지가 없어요!'))
            else
              ..._messages.map((message) {
                final hasUnread = _unreadThreads.contains(message.name);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      _openMessageThread(message);
                    },
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: primaryColor.withOpacity(0.15),
                                child: Text(
                                  message.name.substring(0, 1),
                                  style: const TextStyle(color: primaryColor),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message.lastMessage,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: Text(
                                  message.timeAgo,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasUnread)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
    _markMessagesRead();
  }

  void _openMessageThread(_MessageInfo info) {
    _markMessagesRead(thread: info.name);
    _showBlurDialog(
      _MessengerDialog(
        info: info,
        onMessageSent: (message) {
          _upsertThreadPreview(info.name, message.text, at: message.createdAt);
        },
        onDeleteThread: () => _removeThread(info.name),
      ),
    );
  }

  void _removeThread(String name) {
    setState(() {
      _messages.removeWhere((m) => m.name == name);
      _unreadThreads.remove(name);
      _unreadMessages = _unreadThreads.length;
    });
    _syncNotificationCounts();
  }

  void _openGroupSearchModal() {
    String query = '';
    _showBlurDialog(
      _dialogShell(
        title: '그룹스터디 찾기',
        width: 680,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            final keyword = query.trim();
            final lowerKeyword = keyword.toLowerCase();
            final results = keyword.isEmpty
                ? <_GroupInfo>[]
                : _groupSearchCatalog
                      .where(
                        (group) =>
                            group.name.toLowerCase().contains(lowerKeyword),
                      )
                      .toList();

            void applySearch() {
              final trimmed = query.trim();
              if (trimmed.isEmpty) return;
              setState(() {
                _groupSearchHistory.removeWhere((item) => item == trimmed);
                _groupSearchHistory.insert(0, trimmed);
                if (_groupSearchHistory.length > 8) {
                  _groupSearchHistory.removeRange(
                    8,
                    _groupSearchHistory.length,
                  );
                }
              });
              setModalState(() {});
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '스터디 이름으로 검색해 참여할 그룹을 찾아보세요.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setModalState(() => query = value);
                        },
                        onSubmitted: (_) {
                          FocusScope.of(context).unfocus();
                          applySearch();
                        },
                        decoration: InputDecoration(
                          hintText: '스터디 이름 검색',
                          filled: true,
                          fillColor: bgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: primaryColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 44,
                      width: 96,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          applySearch();
                        },
                        child: const Text('검색'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '검색 내역',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                if (_groupSearchHistory.isEmpty)
                  const Text(
                    '검색 내역이 없어요',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _groupSearchHistory
                        .map(
                          (item) => ActionChip(
                            label: Text(item),
                            onPressed: () {
                              setModalState(() => query = item);
                              applySearch();
                            },
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 16),
                const Text(
                  '검색 결과',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 260,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: keyword.isEmpty
                        ? _emptyState('스터디 이름을 입력해 주세요')
                        : results.isEmpty
                        ? _emptyState('검색 결과가 없어요')
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final group = results[index];
                              final logoIndex = group.logoIndex ?? 0;
                              final color =
                                  _groupLogoColors[logoIndex %
                                      _groupLogoColors.length];
                              final icon =
                                  _groupLogoIcons[logoIndex %
                                      _groupLogoIcons.length];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: color.withOpacity(0.15),
                                      child: Icon(icon, color: color),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            group.description,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                        side: const BorderSide(
                                          color: primaryColor,
                                        ),
                                      ),
                                      onPressed: () {},
                                      child: const Text('요청'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openGroupCreateModal() async {
    await _showBlurDialog(
      _dialogShell(
        title: '그룹스터디 만들기',
        width: 700,
        child: _GroupCreateDialogBody(
          onCreate: (group) {
            setState(() {
              _groups.add(group);
            });
          },
        ),
      ),
    );
  }

  void _openGroupModal(_GroupInfo group) {
    _showBlurDialog(
      _dialogShell(
        title: group.name,
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          color: primaryColor,
          onPressed: () {
            Navigator.of(context).pop();
            _openGroupSearchModal();
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(group.description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              children: [
                _infoPill('인원 ${group.members}명'),
                const SizedBox(width: 8),
                _infoPill(group.isPublic ? '공개' : '비공개'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('그룹 열기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogShell({
    required String title,
    required Widget child,
    Widget? trailing,
    double width = 520,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: width,
      padding: padding,
      decoration: _cardDeco(radius: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _infoPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _tagChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5F0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '#$text',
        style: const TextStyle(
          fontSize: 12,
          color: primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _ratingSummary(double scale) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 12 * scale,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '894',
                style: _ts(
                  size: 36 * scale,
                  weight: FontWeight.w900,
                  color: primaryColor,
                  scaleUp: false,
                ),
              ),
              SizedBox(width: 8 * scale),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+ 5.9',
                    style: _ts(
                      size: 10 * scale,
                      weight: FontWeight.w600,
                      color: Colors.red,
                      scaleUp: false,
                    ),
                  ),
                  Text(
                    '상위 34%',
                    style: _ts(
                      size: 10 * scale,
                      weight: FontWeight.w600,
                      color: Colors.black87,
                      scaleUp: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Divider(height: 16 * scale, thickness: 1),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8 * scale),
              onTap: () => showRatingDetailModal(context: context),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 6 * scale,
                  horizontal: 4 * scale,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '레이팅 상세보기 및 보고서 보기',
                      style: _ts(
                        size: 12 * scale,
                        weight: FontWeight.w600,
                        color: Colors.black87,
                        scaleUp: false,
                      ),
                    ),
                    SizedBox(width: 6 * scale),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12 * scale,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagGroup({
    required String title,
    required List<String> tags,
    required double scale,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: _ts(
            size: 13 * scale,
            weight: FontWeight.w700,
            color: primaryColor,
            scaleUp: false,
          ),
        ),
        SizedBox(height: 6 * scale),
        Row(
          children: tags
              .map(
                (tag) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 6 * scale),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 11 * scale,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final baseWidth = screenWidth < 1900 ? screenWidth : 1900.0;
    final contentWidth = baseWidth > 20 ? baseWidth - 20 : 0.0;
    const cardGap = 10.0;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: bgColor,
        drawer: const AppDrawer(),
        body: SafeArea(
          top: true,
          child: Stack(
            children: [
              SingleChildScrollView(
                primary: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // ── 헤더 ──────────────────────────────────────
                    Container(
                      width: double.infinity,
                      height: 72 * scale,
                      color: Colors.white,
                      child: Row(
                        children: [
                          SizedBox(width: 16 * scale),
                          Builder(
                            builder: (context) => IconButton(
                              iconSize: 28 * scale,
                              icon: const Icon(
                                Icons.menu_outlined,
                                color: primaryColor,
                              ),
                              onPressed: () => toggleAppDrawer(context),
                            ),
                          ),
                          SizedBox(width: 12 * scale),
                          SizedBox(width: 12 * scale),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const MainStudentPage(),
                                ),
                                (route) => false,
                              );
                            },
                            child: Text(
                              'AIFlow',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 36 * scale,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 120 * scale),
                          Expanded(
                            child: Container(
                              color: Colors.white,
                              height: 72 * scale,
                              alignment: Alignment.centerRight,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final label in [
                                      '학습터',
                                      '문서고',
                                      '친구/소셜',
                                      '마켓플레이스',
                                    ])
                                      Padding(
                                        padding: EdgeInsets.only(
                                          right: label == '마켓플레이스'
                                              ? 24 * scale
                                              : 0,
                                        ),
                                        child: GestureDetector(
                                          onTap: label == '학습터'
                                              ? () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const study_center.SoWidget(),
                                                    ),
                                                  );
                                                }
                                              : label == '문서고'
                                              ? () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const docx.BookWidget(),
                                                    ),
                                                  );
                                                }
                                              : null,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12 * scale,
                                            ),
                                            child: Text(
                                              label,
                                              style: navStyle.copyWith(
                                                fontSize: 16 * scale,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    SizedBox(width: 16 * scale),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── 친구랭킹 / 나의정보 카드 ─────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      child: Container(
                        width: contentWidth,
                        height: 400,
                        decoration: _cardDeco(radius: 16),
                        padding: const EdgeInsets.fromLTRB(26, 16, 26, 20),
                        child: Column(
                          children: [
                            Row(
                              children: const [
                                Expanded(
                                  child: Text(
                                    '친구랭킹',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Text(
                                    '나의 정보',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '친구 OVR 순위',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Expanded(
                                          child: _friendRanks.isEmpty
                                              ? _emptyState('친구가 없어요!')
                                              : ListView.separated(
                                                  physics:
                                                      const NeverScrollableScrollPhysics(),
                                                  itemCount:
                                                      _friendRanks.length,
                                                  separatorBuilder: (_, __) =>
                                                      const SizedBox(height: 8),
                                                  itemBuilder: (context, index) {
                                                    final rank =
                                                        _friendRanks[index];
                                                    return Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: bgColor,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 36,
                                                            height: 36,
                                                            alignment: Alignment
                                                                .center,
                                                            decoration: BoxDecoration(
                                                              color: primaryColor
                                                                  .withOpacity(
                                                                    0.12,
                                                                  ),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: Text(
                                                              '${rank.rank}',
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    primaryColor,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              rank.name,
                                                              style: const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                          Text(
                                                            'OVR ${rank.ovr}',
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Text(
                                                            rank.delta >= 0
                                                                ? '+${rank.delta}'
                                                                : '${rank.delta}',
                                                            style: TextStyle(
                                                              color:
                                                                  rank.delta >=
                                                                      0
                                                                  ? primaryColor
                                                                  : Colors
                                                                        .black54,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _ratingSummary(scale),
                                        SizedBox(height: 12 * scale),
                                        _tagGroup(
                                          title: '약점 태그',
                                          tags: const [
                                            '시간관리',
                                            '도형',
                                            '영어',
                                            '서술',
                                            '실수',
                                            '속도',
                                            '집중',
                                            '어휘',
                                          ],
                                          scale: scale,
                                        ),
                                        SizedBox(height: 12 * scale),
                                        _tagGroup(
                                          title: '강점 태그',
                                          tags: const [
                                            '수학',
                                            '국어',
                                            '집중력',
                                            '논리',
                                            '암기',
                                            '추론',
                                            '계산',
                                            '문해',
                                          ],
                                          scale: scale,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 중간 카드 영역
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: contentWidth,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final availableWidth = constraints.maxWidth;
                              final gap = cardGap;
                              final cardW = (availableWidth - gap) / 2;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(right: gap),
                                    child: Container(
                                      width: cardW,
                                      height: 400,
                                      decoration: _cardDeco(radius: 16),
                                      padding: const EdgeInsets.fromLTRB(
                                        22,
                                        18,
                                        22,
                                        16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                '친구',
                                                style: TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.person_add_alt_1,
                                                  color: primaryColor,
                                                ),
                                                onPressed: _openAddFriendModal,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          _requestSection(
                                            title: '받은 친구 요청',
                                            requests: _pendingIncomingRequests,
                                            incoming: true,
                                          ),
                                          _requestSection(
                                            title: '보낸 친구 요청',
                                            requests: _pendingOutgoingRequests,
                                            incoming: false,
                                          ),
                                          Expanded(
                                            child: _friends.isEmpty
                                                ? _emptyState('친구가 없어요!')
                                                : ListView.separated(
                                                    physics:
                                                        const NeverScrollableScrollPhysics(),
                                                    itemCount: _friends.length,
                                                    separatorBuilder: (_, __) =>
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                    itemBuilder: (context, index) {
                                                      final friend =
                                                          _friends[index];
                                                      return _FriendTile(
                                                        friend: friend,
                                                        onOpenActions: () =>
                                                            _openFriendActionModal(
                                                              friend,
                                                            ),
                                                      );
                                                    },
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: cardW,
                                    height: 400,
                                    decoration: _cardDeco(radius: 16),
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      18,
                                      22,
                                      16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              '쪽지함',
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 18,
                                                color: primaryColor,
                                              ),
                                              onPressed: _openInboxModal,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Expanded(
                                          child: _messages.isEmpty
                                              ? _emptyState('친구가 없어요!')
                                              : ListView.separated(
                                                  physics:
                                                      const NeverScrollableScrollPhysics(),
                                                  itemCount: _messages.length,
                                                  separatorBuilder: (_, __) =>
                                                      const SizedBox(height: 8),
                                                  itemBuilder: (context, index) {
                                                    final message =
                                                        _messages[index];
                                                    final hasUnread =
                                                        _unreadThreads.contains(
                                                            message.name);
                                                    return InkWell(
                                                      onTap: () =>
                                                          _openMessageThread(
                                                            message,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      child: Stack(
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 14,
                                                              vertical: 10,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: bgColor,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                12,
                                                              ),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                CircleAvatar(
                                                                  backgroundColor:
                                                                      primaryColor
                                                                          .withOpacity(
                                                                    0.12,
                                                                  ),
                                                                  child: Text(
                                                                    message.name
                                                                        .substring(
                                                                      0,
                                                                      1,
                                                                    ),
                                                                    style:
                                                                        const TextStyle(
                                                                      color:
                                                                          primaryColor,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 12,
                                                                ),
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        message
                                                                            .name,
                                                                        style:
                                                                            const TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            4,
                                                                      ),
                                                                      Text(
                                                                        message
                                                                            .lastMessage,
                                                                        style:
                                                                            const TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                        ),
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                    right: 20,
                                                                  ),
                                                                  child: Text(
                                                                    message
                                                                        .timeAgo,
                                                                    style:
                                                                        const TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          if (hasUnread)
                                                            Positioned(
                                                              right: 8,
                                                              top: 8,
                                                              child: Container(
                                                                width: 12,
                                                                height: 12,
                                                                decoration:
                                                                    const BoxDecoration(
                                                                  color:
                                                                      Colors.red,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // 그룹스터디 섹션
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      child: Container(
                        width: contentWidth,
                        height: 400,
                        decoration: _cardDeco(radius: 16),
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '그룹스터디',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    OutlinedButton(
                                      onPressed: _openGroupSearchModal,
                                      child: const Text('그룹스터디 찾기'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: _openGroupCreateModal,
                                      child: const Text('그룹스터디 만들기'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: _groups.isEmpty
                                  ? Center(
                                      child: InkWell(
                                        onTap: _openGroupSearchModal,
                                        child: const Text(
                                          '그룹스터디가 없어요',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _groups.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        final group = _groups[index];
                                        return InkWell(
                                          onTap: () => _openGroupModal(group),
                                          child: Container(
                                            width: 320,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      backgroundColor:
                                                          _groupLogoColors[(group
                                                                          .logoIndex ??
                                                                      0) %
                                                                  _groupLogoColors
                                                                      .length]
                                                              .withOpacity(
                                                                0.15,
                                                              ),
                                                      child: Icon(
                                                        _groupLogoIcons[(group
                                                                    .logoIndex ??
                                                                0) %
                                                            _groupLogoIcons
                                                                .length],
                                                        color:
                                                            _groupLogoColors[(group
                                                                        .logoIndex ??
                                                                    0) %
                                                                _groupLogoColors
                                                                    .length],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        group.name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  '최대 ${group.maxMembers}명',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  group.description,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const Spacer(),
                                                Row(
                                                  children: [
                                                    _infoPill(
                                                      '${group.members}명',
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _infoPill(
                                                      group.isPublic
                                                          ? '공개'
                                                          : '비공개',
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCreateDialogBody extends StatefulWidget {
  const _GroupCreateDialogBody({required this.onCreate});

  final void Function(_GroupInfo group) onCreate;

  @override
  State<_GroupCreateDialogBody> createState() => _GroupCreateDialogBodyState();
}

class _GroupCreateDialogBodyState extends State<_GroupCreateDialogBody> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _lockEnabled = false;
  int? _selectedLogo;
  bool _nameInvalid = false;
  bool _descriptionInvalid = false;
  bool _maxInvalid = false;
  bool _passwordInvalid = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidPassword(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 4 || trimmed.length > 10) return false;
    return RegExp(r'^\d+$').hasMatch(trimmed);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final maxMembers = int.tryParse(_maxController.text.trim()) ?? 0;
    final password = _passwordController.text.trim();

    final nameOk = name.isNotEmpty;
    final descriptionOk = description.isNotEmpty;
    final maxOk = maxMembers > 0;
    final passwordOk = !_lockEnabled || _isValidPassword(password);

    setState(() {
      _nameInvalid = !nameOk;
      _descriptionInvalid = !descriptionOk;
      _maxInvalid = !maxOk;
      _passwordInvalid = _lockEnabled && !passwordOk;
    });

    if (!nameOk || !descriptionOk || !maxOk || !passwordOk) return;

    final logoIndex =
        _selectedLogo ??
        Random().nextInt(_SoWidgetState._groupLogoIcons.length);

    setState(() {
      _isSubmitting = true;
    });

    try {
      final group = await ApiClient.instance.createStudyGroup(
        name: name,
        description: description,
        maxMembers: maxMembers,
        isPublic: !_lockEnabled,
        logoIndex: logoIndex,
        lockEnabled: _lockEnabled,
        password: _lockEnabled ? password : null,
      );
      if (!mounted) return;
      widget.onCreate(
        _GroupInfo(
          name: group.name,
          description: group.description,
          maxMembers: group.maxMembers,
          members: group.memberIds.length,
          isPublic: group.isPublic,
          logoIndex: group.logoIndex,
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('그룹스터디 생성에 실패했어요.')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPassword = _lockEnabled;
    final primaryColor = _SoWidgetState.primaryColor;
    final bgColor = _SoWidgetState.bgColor;
    final groupLogoIcons = _SoWidgetState._groupLogoIcons;
    final groupLogoColors = _SoWidgetState._groupLogoColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('새 그룹스터디를 만들어 친구를 초대하세요.', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: '그룹스터디 이름',
            errorText: _nameInvalid ? '이름을 입력해 주세요' : null,
            filled: true,
            fillColor: bgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: '그룹스터디 설명',
            errorText: _descriptionInvalid ? '설명을 입력해 주세요' : null,
            filled: true,
            fillColor: bgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _maxController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            hintText: '그룹스터디 최대 인원',
            helperText: '숫자만 입력',
            errorText: _maxInvalid ? '최대 인원을 입력해 주세요' : null,
            filled: true,
            fillColor: bgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '프로필 사진',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('업로드 기능 준비 중')));
              },
              icon: const Icon(Icons.upload),
              label: const Text('업로드'),
            ),
            const SizedBox(width: 12),
            const Text(
              '로고 선택 또는 미선택 시 랜덤',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(groupLogoIcons.length, (index) {
            final color = groupLogoColors[index];
            final icon = groupLogoIcons[index];
            final isSelected = _selectedLogo == index;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedLogo = index;
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              '비밀번호 설정',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Switch(
              value: _lockEnabled,
              activeColor: primaryColor,
              onChanged: (value) {
                setState(() {
                  _lockEnabled = value;
                  _passwordInvalid = false;
                });
              },
            ),
          ],
        ),
        if (showPassword) ...[
          TextField(
            controller: _passwordController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              hintText: '숫자 4~10자리',
              helperText: '잠금 시 숫자만 입력할 수 있어요',
              errorText: _passwordInvalid ? '4~10자리 숫자를 입력해 주세요' : null,
              filled: true,
              fillColor: bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: const Text('만들기'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onOpenActions});

  final _FriendInfo friend;
  final VoidCallback onOpenActions;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTap: onOpenActions,
      onLongPress: onOpenActions,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _SoWidgetState.bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _SoWidgetState.primaryColor.withOpacity(0.12),
              child: Text(
                friend.name.substring(0, 1),
                style: const TextStyle(color: _SoWidgetState.primaryColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(friend.status, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Text(
              'OVR ${friend.ovr}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.more_horiz, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.createdAt,
  });

  final String id;
  final String text;
  final bool isMe;
  final DateTime createdAt;

  String get timeLabel => _formatTimeLabel(createdAt);
}

class _MessengerDialog extends StatefulWidget {
  const _MessengerDialog({
    required this.info,
    this.onMessageSent,
    this.onDeleteThread,
  });

  final _MessageInfo info;
  final ValueChanged<_ChatMessage>? onMessageSent;
  final VoidCallback? onDeleteThread;

  @override
  State<_MessengerDialog> createState() => _MessengerDialogState();
}

class _MessengerDialogState extends State<_MessengerDialog> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<_ChatMessage> _chatMessages = [];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _loadError;
  String? _beforeMessageId;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    SocialMessageHub.addListener(_handleHubMessage);
    _loadLatest();
  }

  @override
  void dispose() {
    SocialMessageHub.removeListener(_handleHubMessage);
    _scrollController.removeListener(_handleScroll);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _handleScroll() {
    if (_scrollController.positions.isEmpty) return;
    if (_scrollController.position.pixels <= 40 && _hasMore && !_loadingMore) {
      _loadOlder();
    }
  }

  void _handleHubMessage(DirectMessage message) {
    final peer = widget.info.name;
    if (message.from != peer && message.to != peer) return;
    final chat = _fromDirectMessage(message);
    setState(() {
      _chatMessages = [..._chatMessages, chat];
      _capMessages();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  _ChatMessage _fromDirectMessage(DirectMessage message) {
    return _ChatMessage(
      id: message.id,
      text: message.text,
      isMe: message.isMine,
      createdAt: message.createdAt,
    );
  }

  void _capMessages() {
    const cap = 2000;
    if (_chatMessages.length > cap) {
      _chatMessages = _chatMessages.sublist(_chatMessages.length - cap);
      _beforeMessageId = _chatMessages.first.id;
    }
  }

  Future<void> _loadLatest() async {
    setState(() {
      _initialLoading = true;
      _loadError = null;
    });
    try {
      final fetched = await ApiClient.instance.fetchDirectMessages(
        peerUsername: widget.info.name,
        limit: 30,
      );
      fetched.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final mapped = fetched.map(_fromDirectMessage).toList();
      setState(() {
        _chatMessages = mapped;
        _beforeMessageId = mapped.isNotEmpty ? mapped.first.id : null;
        _hasMore = fetched.length >= 30;
        _capMessages();
      });
      if (mapped.isNotEmpty) {
        widget.onMessageSent?.call(mapped.last);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loadError = '채팅을 불러오지 못했어요. (${err.toString()})';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('채팅을 불러오지 못했어요: $err')),
      );
    } finally {
      if (mounted) {
        setState(() => _initialLoading = false);
      }
    }
  }

  Future<void> _loadOlder() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    final beforeId = _beforeMessageId;
    if (beforeId == null || beforeId.isEmpty) {
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
      return;
    }
    final oldMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldPixels = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    try {
      final fetched = await ApiClient.instance.fetchDirectMessages(
        peerUsername: widget.info.name,
        limit: 30,
        beforeMessageId: beforeId,
      );
      if (fetched.isEmpty) {
        setState(() {
          _hasMore = false;
        });
        return;
      }
      fetched.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final mapped = fetched.map(_fromDirectMessage).toList();
      setState(() {
        _chatMessages = [...mapped, ..._chatMessages];
        _beforeMessageId = _chatMessages.first.id;
        _hasMore = fetched.length >= 30;
        _capMessages();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final newMax = _scrollController.position.maxScrollExtent;
        final delta = newMax - oldMax;
        _scrollController.jumpTo(oldPixels + delta);
      });
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이전 메시지를 불러오지 못했어요: $err')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      final sent = await ApiClient.instance.sendDirectMessage(
        peerUsername: widget.info.name,
        text: text,
      );
      final message = _fromDirectMessage(sent);
      setState(() {
        _chatMessages = [..._chatMessages, message];
        _capMessages();
      });
      widget.onMessageSent?.call(message);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('쪽지 전송에 실패했습니다.')));
    }
  }

  Future<void> _deleteThread() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      await ApiClient.instance.deleteConversation(widget.info.name);
      if (widget.onDeleteThread != null) {
        widget.onDeleteThread!.call();
      }
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('쪽지함 삭제 실패: $err')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _buildBubble(_ChatMessage message) {
    final isMe = message.isMe;
    final bubbleColor = isMe ? _green : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 4,
                  color: Color(0x14000000),
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              message.timeLabel,
              style: const TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final targetWidth = (size.width * 0.9) + 500;
    final targetHeight = (size.height * 0.8) + 500;
    final width = targetWidth.clamp(320.0, size.width - 40);
    final height = targetHeight.clamp(420.0, size.height - 40);

    return Container(
      width: width,
      height: height,
      decoration: _cardDeco(radius: 18),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _green.withOpacity(0.12),
                child: Text(
                  widget.info.name.substring(0, 1),
                  style: const TextStyle(color: _green),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.info.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                const Text(
                  '로컬 저장 없이 서버에 최근 2,000개의 메시지만 보관합니다.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _deleting ? null : _deleteThread,
            child: Text(
              '나가기',
              style: TextStyle(
                color: _deleting ? Colors.grey : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: _green,
            onPressed: () => Navigator.of(context).pop(),
          ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _bgGrey,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _initialLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _green),
                    )
                  : _loadError != null
                  ? Center(child: Text(_loadError!))
                  : _chatMessages.isEmpty
                  ? const Center(child: Text('쪽지가 없습니다.'))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _chatMessages.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_loadingMore && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final msg =
                            _chatMessages[index - (_loadingMore ? 1 : 0)];
                        return _buildBubble(msg);
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: '쪽지를 입력하세요',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0x22000000)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _sendMessage,
                  child: const Text('전송'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FriendRank {
  const _FriendRank({
    required this.rank,
    required this.name,
    required this.ovr,
    required this.delta,
  });

  final int rank;
  final String name;
  final int ovr;
  final int delta;
}

class _FriendInfo {
  const _FriendInfo({
    required this.name,
    required this.status,
    required this.ovr,
  });

  final String name;
  final String status;
  final int ovr;
}

class _MessageInfo {
  const _MessageInfo({
    required this.name,
    required this.lastMessage,
    required this.timeAgo,
  });

  final String name;
  final String lastMessage;
  final String timeAgo;
}

class _GroupInfo {
  const _GroupInfo({
    required this.name,
    required this.description,
    required this.maxMembers,
    required this.members,
    required this.isPublic,
    this.logoIndex,
  });

  final String name;
  final String description;
  final int maxMembers;
  final int members;
  final bool isPublic;
  final int? logoIndex;
}
