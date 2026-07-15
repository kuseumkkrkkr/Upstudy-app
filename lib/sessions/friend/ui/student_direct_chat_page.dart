import 'package:flutter/material.dart';

import 'package:s11/sessions/friend/shared/social_message_hub.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

class StudentDirectChatPage extends StatefulWidget {
  const StudentDirectChatPage({
    super.key,
    required this.peerUsername,
    this.peerTier = 'B Tier',
    this.preview = false,
    this.onMessageSent,
    this.onThreadDeleted,
  });

  final String peerUsername;
  final String peerTier;
  final bool preview;
  final ValueChanged<DirectMessage>? onMessageSent;
  final VoidCallback? onThreadDeleted;

  @override
  State<StudentDirectChatPage> createState() => _StudentDirectChatPageState();
}

class _StudentDirectChatPageState extends State<StudentDirectChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<DirectMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;

  /// 필요한 변수는 미리보기 여부와 상대 사용자명이다.
  /// 작동 원리는 미리보기는 고정 대화를, 실제 화면은 최근 30개 서버 메시지를 로드하고 실시간 허브를 구독하는 것이다.
  @override
  void initState() {
    super.initState();
    SocialMessageHub.addListener(_onIncomingMessage);
    if (widget.preview) {
      final now = DateTime.now();
      _messages = [
        DirectMessage(
          id: 'preview-1',
          from: widget.peerUsername,
          to: 'me',
          text: '오늘 일차함수 챌린지 같이 풀래?',
          createdAt: now.subtract(const Duration(minutes: 8)),
        ),
        DirectMessage(
          id: 'preview-2',
          from: 'me',
          to: widget.peerUsername,
          text: '좋아! 8시에 시작하자.',
          createdAt: now.subtract(const Duration(minutes: 6)),
          isMine: true,
        ),
        DirectMessage(
          id: 'preview-3',
          from: widget.peerUsername,
          to: 'me',
          text: '내 풀이 Flow도 공유할게.',
          createdAt: now.subtract(const Duration(minutes: 4)),
        ),
        DirectMessage(
          id: 'preview-4',
          from: 'me',
          to: widget.peerUsername,
          text: '확인했어. 기울기 설명 좋다!',
          createdAt: now.subtract(const Duration(minutes: 2)),
          isMine: true,
        ),
      ];
      _loading = false;
    } else {
      _loadMessages();
    }
  }

  /// 필요한 변수는 텍스트·스크롤 컨트롤러와 실시간 구독이다.
  /// 작동 원리는 화면 종료 시 입력·스크롤 자원과 메시지 리스너를 모두 정리하는 것이다.
  @override
  void dispose() {
    SocialMessageHub.removeListener(_onIncomingMessage);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 필요한 변수는 서버에서 수신한 DirectMessage다.
  /// 작동 원리는 현재 상대와 관련된 메시지만 최대 2,000개 목록에 추가하고 하단으로 이동하는 것이다.
  void _onIncomingMessage(DirectMessage message) {
    if (message.from != widget.peerUsername &&
        message.to != widget.peerUsername) {
      return;
    }
    if (!mounted) return;
    setState(() {
      final next = [..._messages, message];
      _messages = next.length > 2000 ? next.sublist(next.length - 2000) : next;
    });
    _scrollToBottom();
  }

  /// 필요한 변수는 상대 사용자명이다.
  /// 작동 원리는 최근 메시지를 시간순으로 정렬하고 서버 실패는 빈 대화 상태로 안전하게 표시하는 것이다.
  Future<void> _loadMessages() async {
    try {
      final messages = await ApiClient.instance.fetchDirectMessages(
        peerUsername: widget.peerUsername,
        limit: 30,
      );
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// 필요한 변수는 현재 ScrollController다.
  /// 작동 원리는 새 메시지 렌더 다음 프레임에 대화 끝으로 부드럽게 이동하는 것이다.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  /// 필요한 변수는 입력 문자열과 상대 사용자명이다.
  /// 작동 원리는 실제 화면은 서버로 전송하고 미리보기는 같은 메시지 모델을 로컬에 추가하는 것이다.
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      final sent = widget.preview
          ? DirectMessage(
              id: 'preview-${DateTime.now().microsecondsSinceEpoch}',
              from: 'me',
              to: widget.peerUsername,
              text: text,
              createdAt: DateTime.now(),
              isMine: true,
            )
          : await ApiClient.instance.sendDirectMessage(
              peerUsername: widget.peerUsername,
              text: text,
            );
      if (!mounted) return;
      setState(() => _messages = [..._messages, sent]);
      widget.onMessageSent?.call(sent);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// 필요한 변수는 상대 사용자명과 삭제 콜백이다.
  /// 작동 원리는 확인 후 서버 대화를 삭제하고 소셜 목록이 해당 스레드를 제거하도록 알리는 것이다.
  Future<void> _deleteThread() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대화 삭제'),
        content: const Text('이 대화를 목록에서 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!widget.preview) {
      await ApiClient.instance.deleteConversation(widget.peerUsername);
    }
    widget.onThreadDeleted?.call();
    if (mounted) Navigator.of(context).maybePop();
  }

  /// 필요한 변수는 대화 메시지와 발신자 여부다.
  /// 작동 원리는 상대 메시지는 연회색 왼쪽, 내 메시지는 검은색 오른쪽 말풍선으로 배치하는 것이다.
  Widget _bubble(DirectMessage message) => Align(
    alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 330),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: message.isMine
            ? const Color(0xFF202022)
            : const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(message.isMine ? 18 : 5),
          bottomRight: Radius.circular(message.isMine ? 5 : 18),
        ),
      ),
      child: Text(
        message.text,
        style: TextStyle(
          color: message.isMine ? Colors.white : Colors.black87,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  /// 필요한 변수는 메시지 목록·입력 상태·상대 정보다.
  /// 작동 원리는 HTML의 상단 제목, 새 메시지, 대화 카드, 기능 태그 순서를 실제 API 동작과 결합하는 것이다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: Colors.black,
                showLevelIndicator: false,
                onMenu: () => toggleAppDrawer(context),
                items: const [],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'SOCIAL',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.7,
                        color: Colors.black54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      '채팅',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '친구·그룹 대화와 자료 공유를 실시간 상태로 연결합니다.',
                      style: TextStyle(color: Colors.black45),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => _controller.clear(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF202022),
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text('새 메시지'),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE1E1E3)),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.peerUsername,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '온라인 · ${widget.peerTier}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const _LiveBadge(),
                                  IconButton(
                                    onPressed: _deleteThread,
                                    tooltip: '대화 삭제',
                                    icon: const Icon(Icons.more_horiz),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: _loading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        24,
                                        18,
                                        18,
                                      ),
                                      itemCount: _messages.length,
                                      itemBuilder: (_, index) =>
                                          _bubble(_messages[index]),
                                    ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _controller,
                                      onSubmitted: (_) => _sendMessage(),
                                      decoration: InputDecoration(
                                        hintText: '메시지 입력',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: _sending ? null : _sendMessage,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF202022),
                                      minimumSize: const Size(58, 54),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('전송'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _ChatFeatureChip('대화 목록'),
                        _ChatFeatureChip('메시지 조회'),
                        _ChatFeatureChip('메시지 전송'),
                        _ChatFeatureChip('대화 삭제'),
                        _ChatFeatureChip('읽지 않음'),
                        _ChatFeatureChip('Flow 공유'),
                        _ChatFeatureChip('실시간 소셜 WebSocket'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  /// 필요한 변수는 없으며 현재 대화의 연결 상태를 LIVE 배지로 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F7),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E2E5)),
    ),
    child: const Text(
      'LIVE',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Colors.black54,
      ),
    ),
  );
}

class _ChatFeatureChip extends StatelessWidget {
  const _ChatFeatureChip(this.label);

  final String label;

  /// 필요한 변수는 기능 레이블이다.
  /// 작동 원리는 대화 카드 아래에 시안의 기능 범위를 작은 태그로 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE1E1E3)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: Colors.black54,
      ),
    ),
  );
}
