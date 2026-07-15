// friend_page_redesign.dart
// 원본 friend.dart 기능·엔드포인트·알고리즘 100% 유지, UI 리디자인
// part of 'package:s11/sessions/friend/friend.dart'; 로 사용

part of 'package:s11/sessions/friend/friend.dart';

// ── 색상 토큰 (원본 유지)
// Renamed to avoid duplicate symbol when this part is combined with other files
const Color _greenColor = Color(0xFF1B4D3E);
const Color _bgGreyFriend = Color(0xFFF4F6F2);

// ── 추가 디자인 토큰 ──────────────────────────────────────────
const Color _green50 = Color(0xFFEAF3DE);
const Color _green600 = Color(0xFF3B6D11);
const Color _green800 = Color(0xFF27500A);
const Color _surfaceWhite = Color(0xFFFFFFFF);
const Color _borderColor = Color(0x1A000000); // rgba(0,0,0,0.10)
const Color _textMuted = Color(0xFF6B7280);
const Color _redAccent = Color(0xFFE24B4A);
const String _docxFontFamily = 'Inter';
const int _ratingEstimateMinSolved = 50;

const TextStyle _labelSm = TextStyle(
  fontFamily: _docxFontFamily,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  color: _textMuted,
  letterSpacing: 0.4,
);
const TextStyle _bodyMd = TextStyle(
  fontFamily: _docxFontFamily,
  fontSize: 13,
  color: Color(0xFF1A1A1A),
);
const TextStyle _bodyMdMuted = TextStyle(
  fontFamily: _docxFontFamily,
  fontSize: 12,
  color: _textMuted,
);

// ══════════════════════════════════════════════════════════════
class SoWidget extends StatefulWidget {
  const SoWidget({super.key});

  static String routeName = 'so';
  static String routePath = '/so';

  @override
  State<SoWidget> createState() => _SoWidgetState();
}

class _SoWidgetState extends State<SoWidget> {
  // ── 원본과 동일한 색상 참조 ──────────────────────────────────
  static const Color primaryColor = _greenColor;
  static const Color bgColor = _bgGreyFriend;

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

  // ── 원본과 동일한 state ──────────────────────────────────────
  List<_FriendRank> _friendRanks = [];
  List<_FriendInfo> _friends = [];
  List<_FriendRequest> _friendRequests = [];
  List<_MessageInfo> _messages = [];
  bool _loadingThreads = false;
  bool _threadsHasMore = true;
  String? _threadsBefore;
  bool _refreshingPage = false;
  int _unreadMessages = 0;
  final Set<String> _unreadThreads = {};
  Map<String, TagRating> _tagRatings = {};
  bool _loadingRatingSummary = true;
  String? _ratingSummaryError;
  final List<_GroupInfo> _groups = [];
  bool _loadingRanks = false;
  bool _loadingGroups = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── 원본과 동일한 lifecycle ──────────────────────────────────
  @override
  void initState() {
    super.initState();
    unawaited(ActivityStore.load().catchError((_) => ActivitySnapshot.empty()));
    unawaited(_refreshPageData());
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

  // ── 원본과 동일한 비즈니스 로직 (변경 없음) ──────────────────
  Future<void> _refreshPageData() async {
    if (_refreshingPage) return;
    _refreshingPage = true;
    try {
      await Future.wait([
        _refreshFriends(),
        _loadFriendRanks(),
        _loadMyGroups(),
        _loadFriendRequests(),
        _loadConversationThreads(),
        _loadTagRatings(),
      ]);
    } finally {
      _refreshingPage = false;
    }
  }

  Future<void> _refreshFriends() async {
    try {
      final profiles = await ApiClient.instance.listFriends();
      final ovrByUserId = await _fetchOvrByUserIds(
        profiles.map((p) => p.userId).toSet(),
      );
      if (!mounted) return;
      setState(() {
        _friends = profiles
            .map(
              (profile) => _FriendInfo(
                name: profile.username,
                status: profile.status.isNotEmpty ? profile.status : '상태 없음',
                ovr: ovrByUserId[profile.userId] ?? profile.ovr,
              ),
            )
            .toList();
      });
      _cleanupFulfilledRequests();
    } catch (e, st) {
      debugPrint('_refreshFriends error: $e\n$st');
    }
  }

  Future<Map<String, double>> _fetchOvrByUserIds(Set<String> userIds) async {
    final ids = userIds.where((id) => id.trim().isNotEmpty).toList();
    if (ids.isEmpty) return const {};
    final entries = await Future.wait(
      ids.map((id) async {
        try {
          final rating = await ApiClient.instance.fetchUserRatingByUserId(id);
          return MapEntry(id, rating.ovr);
        } catch (_) {
          return null;
        }
      }),
    );
    final out = <String, double>{};
    for (final entry in entries) {
      if (entry != null) out[entry.key] = entry.value;
    }
    return out;
  }

  Future<void> _loadTagRatings() async {
    setState(() {
      _loadingRatingSummary = true;
      _ratingSummaryError = null;
    });
    try {
      final tags = await ApiClient.instance.fetchTagRatings();
      if (!mounted) return;
      setState(() {
        _tagRatings = {
          for (final item in tags) _normalizeTagKey(item.tag): item,
        };
        _loadingRatingSummary = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ratingSummaryError = '레이팅 정보를 불러오지 못했어요';
        _loadingRatingSummary = false;
      });
    }
  }

  Future<void> _loadFriendRanks() async {
    if (_loadingRanks) return;
    setState(() => _loadingRanks = true);
    try {
      final ranks = await ApiClient.instance.fetchFriendRankings();
      final resolvedRanks = await Future.wait(
        ranks.map((r) async {
          final resolvedOvr = r.isMe
              ? await _resolveMyOvr(fallback: r.visibleOvr)
              : await _resolveUserOvrByUsername(
                  username: r.username,
                  fallback: r.visibleOvr,
                );
          return _FriendRank(
            rank: r.rank,
            name: r.username,
            ovr: resolvedOvr,
            delta: 0,
            isMe: r.isMe,
          );
        }),
      );
      if (!mounted) return;
      setState(() {
        _friendRanks = resolvedRanks;
      });
    } catch (e, st) {
      debugPrint('_loadFriendRanks error: $e\n$st');
    } finally {
      if (mounted) setState(() => _loadingRanks = false);
    }
  }

  Future<double> _resolveMyOvr({required double fallback}) async {
    try {
      final mine = await ApiClient.instance.fetchUserRating();
      return mine.ovr;
    } catch (_) {
      return fallback;
    }
  }

  Future<double> _resolveUserOvrByUsername({
    required String username,
    required double fallback,
  }) async {
    final key = username.trim();
    if (key.isEmpty) return fallback;
    try {
      final candidates = await ApiClient.instance.searchFriends(
        query: key,
        limit: 50,
      );
      FriendProfile? exact;
      for (final candidate in candidates) {
        if (candidate.username == key) {
          exact = candidate;
          break;
        }
      }
      if (exact == null) return fallback;
      final rating = await ApiClient.instance.fetchUserRatingByUserId(
        exact.userId,
      );
      return rating.ovr;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _loadMyGroups() async {
    if (_loadingGroups) return;
    setState(() => _loadingGroups = true);
    try {
      final groups = await ApiClient.instance.listMyStudyGroups();
      if (!mounted) return;
      setState(() {
        _groups
          ..clear()
          ..addAll(
            groups.map(
              (g) => _GroupInfo(
                id: g.groupId,
                name: g.name,
                description: g.description ?? '',
                maxMembers: g.maxMembers,
                members: g.memberIds.length,
                isPublic: g.isPublic,
                logoIndex: g.logoIndex,
                lockEnabled: g.lockEnabled,
                ownerRole: g.ownerRole,
                inviteCode: g.inviteCode,
              ),
            ),
          );
      });
    } catch (e, st) {
      debugPrint('_loadMyGroups error: $e\n$st');
    } finally {
      if (mounted) setState(() => _loadingGroups = false);
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
    } catch (e, st) {
      debugPrint('_loadFriendRequests error: $e\n$st');
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

  bool _isExistingFriend(String username) =>
      _friends.any((f) => f.name.toLowerCase() == username.toLowerCase());

  bool _hasPendingRequest(String username) => _friendRequests.any(
    (req) =>
        req.username.toLowerCase() == username.toLowerCase() && req.isPending,
  );

  void _cleanupFulfilledRequests() {
    final friendNames = _friends.map((f) => f.name.toLowerCase()).toSet();
    final before = _friendRequests.length;
    _friendRequests.removeWhere(
      (req) =>
          req.isPending &&
          friendNames.contains(req.username.toLowerCase()) &&
          req.direction == _FriendRequestDirection.outgoing,
    );
    if (before != _friendRequests.length) setState(() {});
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
      final mapped = <_MessageInfo>[];
      final seen = <String>{};
      for (final dm in fetched) {
        final name = _peerNameForDirectMessage(dm);
        if (name.isEmpty || !seen.add(name)) continue;
        mapped.add(
          _MessageInfo(
            name: name,
            lastMessage: dm.text,
            timeAgo: _formatTimeLabel(dm.createdAt),
          ),
        );
      }
      final combined = <_MessageInfo>[if (loadMore) ..._messages, ...mapped];
      final deduped = <_MessageInfo>[];
      final dedupeNames = <String>{};
      for (final thread in combined) {
        if (dedupeNames.add(thread.name)) deduped.add(thread);
      }
      setState(() {
        _messages = deduped;
        _threadsHasMore = fetched.length >= 15;
        _threadsBefore = fetched.isNotEmpty
            ? fetched.last.createdAt.toIso8601String()
            : _threadsBefore;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingThreads = false);
    }
  }

  String _peerNameForDirectMessage(DirectMessage message) {
    final mineTarget = message.isMine ? message.to : message.from;
    if (mineTarget.trim().isNotEmpty) return mineTarget.trim();
    final fallback = message.isMine ? message.from : message.to;
    return fallback.trim();
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    final payload = event['payload'];
    if (type.isEmpty || payload == null) return;
    Map<String, dynamic>? data;
    if (payload is Map) data = Map<String, dynamic>.from(payload);
    switch (type) {
      case 'direct_message':
        if (data != null) _handleDirectMessageEvent(data);
      case 'friend_request':
        if (data != null) _handleFriendRequestEvent(data);
      case 'friend_request_accepted':
      case 'friend_request_declined':
      case 'friend_request_cancelled':
        if (data != null) _handleFriendRequestStatusEvent(type, data);
    }
  }

  void _handleDirectMessageEvent(Map<String, dynamic> payload) {
    try {
      final message = DirectMessage.fromJson(payload);
      SocialMessageHub.dispatch(message);
    } catch (_) {}
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
      if (req.isPending) _friendRequests.add(req);
    });
    _syncNotificationCounts();
    if (type == 'friend_request_accepted') unawaited(_refreshFriends());
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
      if (request.id.isEmpty) throw Exception('Missing request id');
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
      if (request.id.isEmpty) throw Exception('Missing request id');
      await ApiClient.instance.declineFriendRequest(request.id);
      if (!mounted) return;
      setState(() {
        _friendRequests.removeWhere((req) => req.id == request.id);
      });
      _syncNotificationCounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${request.username}님의 요청을 거절했어요.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('요청 거절에 실패했어요.')));
    }
  }

  Future<void> _cancelOutgoingRequest(_FriendRequest request) async {
    try {
      if (request.id.isEmpty) throw Exception('Missing request id');
      await ApiClient.instance.cancelFriendRequest(request.id);
      if (!mounted) return;
      setState(() {
        _friendRequests.removeWhere((req) => req.id == request.id);
      });
      _syncNotificationCounts();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('친구 요청을 취소했어요.')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('요청 취소에 실패했어요.')));
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
    final from = message.from.isNotEmpty ? message.from : '알 수 없음';
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

  // ── 원본과 동일한 레이팅 계산 로직 ──────────────────────────
  String _normalizeTagKey(String value) =>
      value.replaceAll('#', '').toLowerCase().trim();
  String _tagLabel(String tag) {
    final normalized = tag.replaceAll('#', '').trim();
    return normalized.isEmpty ? '#-' : '#$normalized';
  }

  double _tagOvrValue(double rating) => rating;
  String _tagOvrLabel(double rating) => rating.isNaN || rating <= 0
      ? '--'
      : _tagOvrValue(rating).round().toString();
  double _visibleDelta(double rating, double delta) =>
      _tagOvrValue(rating) - _tagOvrValue(rating - delta);

  List<TagRating> _topByDelta(bool positive, {int take = 3}) {
    final items = _tagRatings.values
        .where((item) => positive ? item.delta > 0 : item.delta < 0)
        .toList();
    items.sort(
      (a, b) =>
          positive ? b.delta.compareTo(a.delta) : a.delta.compareTo(b.delta),
    );
    return items.take(take).toList();
  }

  List<TagRating> _topByScore(bool strong, {int take = 3}) {
    final items = _tagRatings.values.toList();
    items.sort(
      (a, b) =>
          strong ? b.rating.compareTo(a.rating) : a.rating.compareTo(b.rating),
    );
    return items.take(take).toList();
  }

  // ══════════════════════════════════════════════════════════════
  // UI 헬퍼
  // ══════════════════════════════════════════════════════════════

  /// 책가방 섹션 카드와 동일한 컨테이너 스펙
  BoxDecoration _cardDeco({double radius = 14}) => BoxDecoration(
    color: _surfaceWhite,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const [
      BoxShadow(color: Color(0x1F000000), blurRadius: 14, offset: Offset(0, 6)),
    ],
  );

  Widget _emptyState(String message) => Center(
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _textMuted,
      ),
    ),
  );

  Widget? _rankMedal(int rank) {
    IconData? icon;
    Color? color;
    switch (rank) {
      case 1:
        icon = Icons.emoji_events;
        color = Colors.amber;
      case 2:
        icon = Icons.emoji_events;
        color = const Color(0xFF9EA7B3);
      case 3:
        icon = Icons.emoji_events;
        color = const Color(0xFFCD7F32);
      default:
        return null;
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: color.withOpacity(0.15),
      foregroundColor: color,
      child: Icon(icon, size: 16),
    );
  }

  bool _isTopRank(int rank) => rank >= 1 && rank <= 3;

  Color _rankBorderColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFE3B341);
      case 2:
        return const Color(0xFFB8BEC8);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return _borderColor;
    }
  }

  double _rankBorderWidth(int rank) => _isTopRank(rank) ? 2.2 : 1.2;

  // ── 레이팅 칩 ──────────────────────────────────────────────
  Widget _ratingChip({
    required String label,
    String? metric,
    Color? chipBg,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: chipBg ?? bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor ?? primaryColor,
            ),
          ),
          if (metric != null) ...[
            const SizedBox(width: 4),
            Text(
              metric,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: (textColor ?? primaryColor).withOpacity(0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ratingSectionRow({
    required String title,
    required List<TagRating> items,
    required String emptyLabel,
    required String Function(TagRating) metricBuilder,
    Color? chipBg,
    Color? textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: primaryColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text(emptyLabel, style: _bodyMdMuted)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map(
                  (item) => _ratingChip(
                    label: _tagLabel(item.tag),
                    metric: metricBuilder(item),
                    chipBg: chipBg,
                    textColor: textColor,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  /// 레이팅 섹션: 2열 그리드로, 스크롤 없이 전체 표시
  Widget _ratingSummaryGrid() {
    if (_loadingRatingSummary) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
      );
    }
    if (_ratingSummaryError != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_ratingSummaryError!, style: _bodyMdMuted),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loadTagRatings,
            child: const Text('다시 시도'),
          ),
        ],
      );
    }
    final rising = _topByDelta(true);
    final falling = _topByDelta(false);
    final strong = _topByScore(true);
    final weak = _topByScore(false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2열: 상승/강점 | 하락/약점
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ratingSectionRow(
                      title: '상승 태그',
                      items: rising,
                      emptyLabel: '없음',
                      chipBg: const Color(0xFFFFEBEB),
                      textColor: const Color(0xFFA32D2D),
                      metricBuilder: (item) =>
                          '+${_visibleDelta(item.rating, item.delta).toStringAsFixed(1)}',
                    ),
                    const SizedBox(height: 12),
                    _ratingSectionRow(
                      title: '강점',
                      items: strong,
                      emptyLabel: '데이터가 부족해요',
                      chipBg: _green50,
                      textColor: _green800,
                      metricBuilder: (item) =>
                          'OVR ${_tagOvrLabel(item.rating)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              VerticalDivider(color: _borderColor, width: 1),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ratingSectionRow(
                      title: '하락 태그',
                      items: falling,
                      emptyLabel: '없음',
                      chipBg: const Color(0xFFE6F1FB),
                      textColor: const Color(0xFF0C447C),
                      metricBuilder: (item) => _visibleDelta(
                        item.rating,
                        item.delta,
                      ).toStringAsFixed(1),
                    ),
                    const SizedBox(height: 12),
                    _ratingSectionRow(
                      title: '약점',
                      items: weak,
                      emptyLabel: '데이터가 부족해요',
                      chipBg: const Color(0xFFF1EFE8),
                      textColor: const Color(0xFF5F5E5A),
                      metricBuilder: (item) =>
                          'OVR ${_tagOvrLabel(item.rating)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => showRatingDetailModal(context: context),
            icon: const Icon(Icons.bar_chart, color: primaryColor, size: 15),
            label: const Text(
              '레이팅 상세 보기',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ),
      ],
    );
  }

  // ── 친구 요청 타일 ──────────────────────────────────────────
  Widget _ratingSummaryLocked(BuildContext context, int remainingCount) {
    final safeRemaining = remainingCount < 0 ? 0 : remainingCount;
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: _textMuted, size: 28),
            const SizedBox(height: 8),
            const Text('아직 레이팅을 볼 수 없어요', style: _bodyMd),
            const SizedBox(height: 4),
            Text('레이팅 추정까지 $safeRemaining문제 남았어요', style: _bodyMdMuted),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LevelTestHomePage()),
                );
              },
              child: const Text('문제 풀러 가기'),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: _listCardDeco(color: _green50, radius: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: primaryColor.withOpacity(0.15),
            child: Text(
              name.isNotEmpty ? name.substring(0, 1) : '?',
              style: const TextStyle(
                color: primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  incoming ? '받은 요청 · $createdLabel' : '보낸 요청 · 대기 중',
                  style: _bodyMdMuted,
                ),
              ],
            ),
          ),
          if (incoming) ...[
            TextButton(
              onPressed: () => _declineRequest(request),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                foregroundColor: _textMuted,
              ),
              child: const Text('거절', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _acceptRequest(request),
              child: const Text('수락'),
            ),
          ] else
            TextButton(
              onPressed: () => _cancelOutgoingRequest(request),
              style: TextButton.styleFrom(
                foregroundColor: _textMuted,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              child: const Text('취소', style: TextStyle(fontSize: 12)),
            ),
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
        Text(title, style: _labelSm),
        const SizedBox(height: 6),
        ...requests.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _requestTile(r, incoming: incoming),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── 다이얼로그 공통 쉘 ─────────────────────────────────────
  Future<void> _showBlurDialog(Widget child) async {
    await showGeneralDialog(
      context: context,
      barrierLabel: 'dialog',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Center(
          child: Material(color: Colors.transparent, child: child),
        ),
      ),
      transitionBuilder: (_, animation, __, dialogChild) =>
          FadeTransition(opacity: animation, child: dialogChild),
    );
  }

  Widget _dialogShell({
    required String title,
    required Widget child,
    double width = 1200,
    double height = 680,
    EdgeInsets padding = const EdgeInsets.all(22),
  }) {
    final screen = MediaQuery.of(context).size;
    final resolvedWidth = min(width, screen.width * 0.96);
    final resolvedHeight = min(height, screen.height * 0.92);
    return Container(
      width: resolvedWidth,
      constraints: BoxConstraints(maxHeight: resolvedHeight),
      padding: padding,
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: SingleChildScrollView(
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
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  // ── 친구 추가 모달 (원본 로직 동일) ────────────────────────
  void _openAddFriendModal() {
    String query = '';
    List<_FriendInfo> results = [];
    bool isSearching = false;
    String? errorMessage;
    final rootContext = context;

    _showBlurDialog(
      _dialogShell(
        title: '친구 추가',
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
                final ovrByUserId = await _fetchOvrByUserIds(
                  profiles.map((p) => p.userId).toSet(),
                );
                if (!context.mounted) return;
                setModalState(() {
                  results = profiles
                      .map(
                        (p) => _FriendInfo(
                          name: p.username,
                          status: p.status.isNotEmpty ? p.status : '상태 없음',
                          ovr: ovrByUserId[p.userId] ?? p.ovr,
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
                setModalState(() => isSearching = false);
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '친구의 닉네임을 검색해 친구 요청을 보낼 수 있어요.',
                  style: TextStyle(fontSize: 13, color: _textMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setModalState(() {
                          query = v;
                          results = [];
                          errorMessage = null;
                        }),
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        style: _bodyMd,
                        decoration: InputDecoration(
                          hintText: '닉네임 검색',
                          hintStyle: _bodyMdMuted,
                          filled: true,
                          fillColor: bgColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: primaryColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        onPressed: () async {
                          FocusScope.of(context).unfocus();
                          await performSearch();
                        },
                        child: const Text(
                          '검색',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('검색 결과', style: _labelSm),
                const SizedBox(height: 8),
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: query.trim().isEmpty
                      ? _emptyState('닉네임을 입력해 주세요')
                      : isSearching
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: primaryColor,
                            strokeWidth: 2,
                          ),
                        )
                      : errorMessage != null
                      ? _emptyState(errorMessage!)
                      : results.isEmpty
                      ? _emptyState('검색 결과가 없어요')
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final friend = results[i];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: _listCardDeco(radius: 9),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: primaryColor.withOpacity(
                                      0.12,
                                    ),
                                    child: Text(
                                      friend.name.substring(0, 1),
                                      style: const TextStyle(
                                        color: primaryColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          friend.status,
                                          style: _bodyMdMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'OVR ${_formatOvrLabel(friend.ovr)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: _textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: const BorderSide(
                                        color: primaryColor,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () async => _sendFriendRequest(
                                      friend: friend,
                                      rootContext: rootContext,
                                    ),
                                    child: const Text('요청'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 쪽지함 모달 (원본 로직 동일) ────────────────────────────
  Future<void> _openInboxModal() async {
    await _showBlurDialog(
      _dialogShell(
        title: '쪽지함',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('최근 쪽지 목록', style: _bodyMdMuted),
            const SizedBox(height: 14),
            if (_messages.isEmpty)
              SizedBox(height: 100, child: _emptyState('쪽지가 없어요!'))
            else
              ..._messages.map((message) {
                final hasUnread = _unreadThreads.contains(message.name);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      _openMessageThread(message);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: _listCardDeco(radius: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: primaryColor.withOpacity(0.12),
                            child: Text(
                              message.name.substring(0, 1),
                              style: const TextStyle(
                                color: primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  message.lastMessage,
                                  style: _bodyMdMuted,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            message.timeAgo,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (hasUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _openMessageThread(_MessageInfo info) {
    _markMessagesRead(thread: info.name);
    _showBlurDialog(
      _MessengerDialog(
        info: info,
        onMessageSent: (message) => _upsertThreadPreview(
          info.name,
          message.text,
          at: message.createdAt,
        ),
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

  // ── 친구 액션 모달 ──────────────────────────────────────────
  void _openFriendActionModal(_FriendInfo friend) {
    _showBlurDialog(
      _dialogShell(
        title: friend.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '친구를 클릭하거나 길게 눌러 열 수 있는 메뉴입니다.',
              style: TextStyle(fontSize: 13, color: _textMuted),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('프로필 보기 기능은 준비 중입니다.')),
                );
              },
              icon: const Icon(Icons.person_outline, size: 17),
              label: const Text(
                '프로필 보기',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: const BorderSide(color: primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                final info = _ensureMessageThreadForFriend(friend);
                _openMessageThread(info);
              },
              icon: const Icon(Icons.mail_outline, size: 17),
              label: const Text(
                '쪽지 보내기',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _removeFriend(friend);
              },
              icon: const Icon(Icons.person_remove_alt_1_outlined, size: 17),
              label: const Text(
                '친구 삭제',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 그룹 검색 모달 (원본 로직 동일) ─────────────────────────
  void _openGroupSearchModal() {
    String query = '';
    String inviteCode = '';
    List<_GroupInfo> results = [];
    bool isSearching = false;
    bool isJoiningByCode = false;
    String? errorMessage;
    String? joiningId;
    bool hasSearched = false;

    _showBlurDialog(
      _dialogShell(
        title: '그룹스터디 찾기',
        width: 620,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> performSearch() async {
              final keyword = query.trim();
              if (keyword.isEmpty) {
                setModalState(() {
                  results = [];
                  errorMessage = null;
                  hasSearched = false;
                });
                return;
              }
              setModalState(() {
                isSearching = true;
                errorMessage = null;
                hasSearched = true;
              });
              try {
                final groups = await ApiClient.instance.searchStudyGroups(
                  query: keyword,
                  limit: 20,
                );
                if (!context.mounted) return;
                setModalState(() {
                  results = groups
                      .map(
                        (g) => _GroupInfo(
                          id: g.groupId,
                          name: g.name,
                          description: g.description ?? '',
                          maxMembers: g.maxMembers,
                          members: g.members,
                          isPublic: g.isPublic,
                          logoIndex: g.logoIndex,
                          lockEnabled: g.lockEnabled,
                          ownerRole: g.ownerRole,
                          inviteCode: g.inviteCode,
                        ),
                      )
                      .toList();
                });
              } catch (_) {
                if (!context.mounted) return;
                setModalState(() => errorMessage = '검색에 실패했어요');
              } finally {
                if (!context.mounted) return;
                setModalState(() => isSearching = false);
              }
            }

            Future<void> joinGroup(_GroupInfo group) async {
              setModalState(() => joiningId = group.id);
              try {
                await ApiClient.instance.joinStudyGroup(groupId: group.id);
                if (!mounted) return;
                setState(() {
                  if (_groups.every((g) => g.id != group.id)) {
                    _groups.add(group);
                  }
                });
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('${group.name}에 참여했어요')));
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('참여에 실패했어요')));
              } finally {
                if (!context.mounted) return;
                setModalState(() => joiningId = null);
              }
            }

            Future<void> joinGroupByCode() async {
              final code = inviteCode.trim();
              if (code.isEmpty) {
                setModalState(() => errorMessage = '참여코드를 입력해 주세요');
                return;
              }
              setModalState(() {
                isJoiningByCode = true;
                errorMessage = null;
              });
              try {
                final group = await ApiClient.instance
                    .joinStudyGroupByInviteCode(inviteCode: code);
                if (!mounted) return;
                final joined = _GroupInfo(
                  id: group.groupId,
                  name: group.name,
                  description: group.description ?? '',
                  maxMembers: group.maxMembers,
                  members: group.memberIds.length,
                  isPublic: group.isPublic,
                  logoIndex: group.logoIndex,
                  lockEnabled: group.lockEnabled,
                  ownerRole: group.ownerRole,
                  inviteCode: group.inviteCode,
                );
                setState(() {
                  _groups.removeWhere((g) => g.id == joined.id);
                  _groups.add(joined);
                });
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${joined.name}에 참여했어요')),
                );
                Navigator.of(context).pop();
              } catch (_) {
                if (!context.mounted) return;
                setModalState(() => errorMessage = '참여코드를 확인해 주세요');
              } finally {
                if (!context.mounted) return;
                setModalState(() => isJoiningByCode = false);
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '스터디 이름으로 검색하거나, 참여코드로 바로 들어갈 수 있어요.',
                  style: TextStyle(fontSize: 13, color: _textMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setModalState(() {
                          query = v;
                          results = [];
                          errorMessage = null;
                          hasSearched = false;
                        }),
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        style: _bodyMd,
                        decoration: InputDecoration(
                          hintText: '스터디 이름을 입력해주세요',
                          hintStyle: _bodyMdMuted,
                          filled: true,
                          fillColor: bgColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: primaryColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          performSearch();
                        },
                        child: const Text(
                          '검색',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => inviteCode = v,
                        textCapitalization: TextCapitalization.characters,
                        style: _bodyMd,
                        decoration: InputDecoration(
                          hintText: '참여코드 입력',
                          hintStyle: _bodyMdMuted,
                          filled: true,
                          fillColor: bgColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: primaryColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: const BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isJoiningByCode ? null : joinGroupByCode,
                        child: isJoiningByCode
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('코드 참여'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('검색 결과', style: _labelSm),
                const SizedBox(height: 8),
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: !hasSearched
                      ? _emptyState('스터디 이름을 입력해 주세요')
                      : isSearching
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: primaryColor,
                            strokeWidth: 2,
                          ),
                        )
                      : errorMessage != null
                      ? _emptyState(errorMessage!)
                      : results.isEmpty
                      ? _emptyState('검색 결과가 없어요')
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (ctx, i) {
                            final group = results[i];
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
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: _surfaceWhite,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: color.withOpacity(0.15),
                                    child: Icon(icon, color: color, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          group.description,
                                          style: _bodyMdMuted,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${group.members}/${group.maxMembers}명 · ${group.isPublic ? '공개' : '비공개'}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: _textMuted,
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      minimumSize: Size.zero,
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: joiningId == group.id
                                        ? null
                                        : () => joinGroup(group),
                                    child: joiningId == group.id
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child:
                                                CircularProgressIndicator.adaptive(
                                                  strokeWidth: 2,
                                                ),
                                          )
                                        : const Text('참여'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 그룹 만들기 & 상세 모달 (원본 로직 동일) ─────────────────
  Future<void> _openGroupCreateModal() async {
    await _showBlurDialog(
      _dialogShell(
        title: '그룹스터디 만들기',
        width: 640,
        child: _GroupCreateDialogBody(
          onCreate: (group) => setState(() => _groups.add(group)),
        ),
      ),
    );
  }

  void _openGroupModal(_GroupInfo group) =>
      _showBlurDialog(_GroupDetailDialog(group: group));

  // ── 랭킹 뱃지 ───────────────────────────────────────────────
  Widget? _rankMedalOrNum(int rank) {
    if (rank <= 3) return _rankMedal(rank);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _green50, shape: BoxShape.circle),
      child: Text(
        '$rank',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: primaryColor,
          fontSize: 12,
        ),
      ),
    );
  }

  // ── 정보 pill ────────────────────────────────────────────────
  Widget _infoPill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _textMuted,
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseWidth = screenWidth < 1900 ? screenWidth : 1900.0;
    final contentWidth = baseWidth > 20 ? baseWidth - 20 : 0.0;
    const cardGap = 10.0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: _scaffoldKey,
        // ── 배경: 흰색 ────────────────────────────────────────
        backgroundColor: _surfaceWhite,
        drawer: const AppDrawer(),
        body: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: _docxFontFamily),
          child: SafeArea(
            top: true,
            child: Column(
              children: [
                // ────────────────────────────────────────────────────
                // 앱바: 원본 그대로
                // ────────────────────────────────────────────────────
                Ios26TopBar(
                  brandColor: primaryColor,
                  onMenu: () {
                    final state = _scaffoldKey.currentState;
                    if (state == null) return;
                    state.isDrawerOpen
                        ? Navigator.of(context).pop()
                        : state.openDrawer();
                  },
                  onTitleTap: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainStudentPage()),
                    (route) => false,
                  ),
                  items: [
                    Ios26NavItem(
                      label: '학습터',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const study_center.SoWidget(),
                        ),
                      ),
                    ),
                    Ios26NavItem(
                      label: '책가방',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const docx.BookWidget(),
                        ),
                      ),
                    ),
                    const Ios26NavItem(label: '친구/소셜', active: true),
                    const Ios26NavItem(label: '마켓플레이스'),
                  ],
                ),

                // ────────────────────────────────────────────────────
                // 컨텐츠 영역 (배경: 흰색)
                // ────────────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    primary: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          // ── 친구랭킹 + 나의 레이팅 (2열) ──────────────
                          Container(
                            width: contentWidth,
                            decoration: _cardDeco(radius: 14),
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 왼쪽: 친구 OVR 랭킹
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        22,
                                        18,
                                        18,
                                        18,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '친구 OVR 랭킹',
                                            style: TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          if (_loadingRanks)
                                            const Center(
                                              child: CircularProgressIndicator(
                                                color: primaryColor,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          else if (_friendRanks.isEmpty)
                                            _emptyState('친구가 없어요!')
                                          else
                                            Builder(
                                              builder: (context) {
                                                final topRanks =
                                                    _friendRanks
                                                        .where(
                                                          (r) => _isTopRank(
                                                            r.rank,
                                                          ),
                                                        )
                                                        .toList()
                                                      ..sort(
                                                        (a, b) => a.rank
                                                            .compareTo(b.rank),
                                                      );
                                                final restRanks = _friendRanks
                                                    .where(
                                                      (r) =>
                                                          !_isTopRank(r.rank),
                                                    )
                                                    .toList();

                                                Widget rankTile(
                                                  _FriendRank rank,
                                                ) {
                                                  final isFirst =
                                                      rank.rank == 1;
                                                  return Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 6,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                    decoration: _listCardDeco(
                                                      radius: 10,
                                                      color: isFirst
                                                          ? Colors.white
                                                          : (rank.isMe
                                                                ? _green50
                                                                : Colors.white),
                                                      borderColor:
                                                          _rankBorderColor(
                                                            rank.rank,
                                                          ),
                                                      borderWidth:
                                                          _rankBorderWidth(
                                                            rank.rank,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        _rankMedalOrNum(
                                                              rank.rank,
                                                            ) ??
                                                            const SizedBox(
                                                              width: 28,
                                                            ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            rank.name,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: rank.isMe
                                                                  ? primaryColor
                                                                  : const Color(
                                                                      0xFF1A1A1A,
                                                                    ),
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          'OVR ${_formatOvrLabel(rank.ovr)}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 12,
                                                            color: rank.isMe
                                                                ? primaryColor
                                                                : _textMuted,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        SizedBox(
                                                          width: 32,
                                                          child: Text(
                                                            rank.delta >= 0
                                                                ? '+${rank.delta}'
                                                                : '${rank.delta}',
                                                            textAlign:
                                                                TextAlign.right,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  rank.delta >=
                                                                      0
                                                                  ? _green600
                                                                  : _textMuted,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }

                                                return Column(
                                                  children: [
                                                    ...topRanks.map(rankTile),
                                                    if (restRanks
                                                        .isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      SizedBox(
                                                        height: 170,
                                                        child: ListView.builder(
                                                          itemCount:
                                                              restRanks.length,
                                                          itemBuilder:
                                                              (
                                                                context,
                                                                i,
                                                              ) => rankTile(
                                                                restRanks[i],
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // 세로 구분선
                                  VerticalDivider(
                                    color: _borderColor,
                                    width: 1,
                                    thickness: 1,
                                  ),

                                  // 오른쪽: 나의 레이팅 (2열 그리드, 스크롤 없음)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        18,
                                        22,
                                        18,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Expanded(
                                                child: Text(
                                                  '나의 레이팅',
                                                  style: TextStyle(
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          ValueListenableBuilder<
                                            ActivitySnapshot
                                          >(
                                            valueListenable:
                                                ActivityStore.notifier,
                                            builder:
                                                (context, activitySnapshot, _) {
                                                  final remainingCount =
                                                      _ratingEstimateMinSolved -
                                                      activitySnapshot
                                                          .totalSolvedCount;
                                                  final isEligible =
                                                      remainingCount <= 0;
                                                  return isEligible
                                                      ? _ratingSummaryGrid()
                                                      : _ratingSummaryLocked(
                                                          context,
                                                          remainingCount,
                                                        );
                                                },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: cardGap),

                          // ── 친구 카드 + 쪽지함 카드 (2열) ────────────
                          SizedBox(
                            width: contentWidth,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final cardW =
                                    (constraints.maxWidth - cardGap) / 2;
                                return Row(
                                  children: [
                                    // 친구 카드
                                    Container(
                                      width: cardW,
                                      height: 380,
                                      decoration: _cardDeco(radius: 14),
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        16,
                                        18,
                                        14,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Expanded(
                                                child: Text(
                                                  '친구',
                                                  style: TextStyle(
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              // 아이콘 버튼 — 테두리/컨테이너 없음
                                              IconButton(
                                                icon: const Icon(
                                                  Icons
                                                      .person_add_alt_1_outlined,
                                                  color: primaryColor,
                                                  size: 20,
                                                ),
                                                onPressed: _openAddFriendModal,
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                splashRadius: 18,
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
                                                          height: 4,
                                                        ),
                                                    itemBuilder: (context, i) {
                                                      final friend =
                                                          _friends[i];
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

                                    SizedBox(width: cardGap),

                                    // 쪽지함 카드
                                    Container(
                                      width: cardW,
                                      height: 380,
                                      decoration: _cardDeco(radius: 14),
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        16,
                                        18,
                                        14,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Expanded(
                                                child: Text(
                                                  '쪽지함',
                                                  style: TextStyle(
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              // 아이콘 버튼 — 테두리/컨테이너 없음
                                              IconButton(
                                                icon: const Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  color: primaryColor,
                                                  size: 17,
                                                ),
                                                onPressed: _openInboxModal,
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                splashRadius: 18,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Expanded(
                                            child: _messages.isEmpty
                                                ? _emptyState('쪽지가 없어요!')
                                                : ListView.separated(
                                                    physics:
                                                        const NeverScrollableScrollPhysics(),
                                                    itemCount: _messages.length,
                                                    separatorBuilder: (_, __) =>
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                    itemBuilder: (context, i) {
                                                      final message =
                                                          _messages[i];
                                                      final hasUnread =
                                                          _unreadThreads
                                                              .contains(
                                                                message.name,
                                                              );
                                                      return InkWell(
                                                        onTap: () =>
                                                            _openMessageThread(
                                                              message,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 9,
                                                              ),
                                                          decoration:
                                                              _listCardDeco(
                                                                radius: 10,
                                                              ),
                                                          child: Row(
                                                            children: [
                                                              CircleAvatar(
                                                                radius: 15,
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
                                                                  style: const TextStyle(
                                                                    color:
                                                                        primaryColor,
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 10,
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
                                                                      style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        fontSize:
                                                                            13,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 2,
                                                                    ),
                                                                    Text(
                                                                      message
                                                                          .lastMessage,
                                                                      style:
                                                                          _bodyMdMuted,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              Text(
                                                                message.timeAgo,
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  color:
                                                                      _textMuted,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              if (hasUnread)
                                                                Container(
                                                                  width: 8,
                                                                  height: 8,
                                                                  decoration: const BoxDecoration(
                                                                    color:
                                                                        _redAccent,
                                                                    shape: BoxShape
                                                                        .circle,
                                                                  ),
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
                                  ],
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: cardGap),

                          // ── 그룹스터디 카드 ───────────────────────────
                          Container(
                            width: contentWidth,
                            height: 380,
                            decoration: _cardDeco(radius: 14),
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        '그룹스터디',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                        side: BorderSide(color: _borderColor),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: _openGroupSearchModal,
                                      child: const Text('그룹스터디 찾기'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: _openGroupCreateModal,
                                      child: const Text('그룹스터디 만들기'),
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
                                                fontSize: 14,
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
                                              const SizedBox(width: 10),
                                          itemBuilder: (context, i) {
                                            final group = _groups[i];
                                            final logoIndex =
                                                group.logoIndex ?? 0;
                                            final color =
                                                _groupLogoColors[logoIndex %
                                                    _groupLogoColors.length];
                                            final icon =
                                                _groupLogoIcons[logoIndex %
                                                    _groupLogoIcons.length];
                                            return InkWell(
                                              onTap: () =>
                                                  _openGroupModal(group),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: Container(
                                                width: 220,
                                                padding: const EdgeInsets.all(
                                                  14,
                                                ),
                                                decoration: _listCardDeco(
                                                  radius: 14,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 16,
                                                          backgroundColor: color
                                                              .withOpacity(
                                                                0.15,
                                                              ),
                                                          child: Icon(
                                                            icon,
                                                            color: color,
                                                            size: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 9,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            group.name,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 13,
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      '최대 ${group.maxMembers}명',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: _textMuted,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Text(
                                                      group.description,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: _textMuted,
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
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
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

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
