import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../services/api_client.dart';

class _ChatMessage {
  _ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.createdAt,
  });

  final String id;
  final String text;
  final bool isMe;
  final DateTime createdAt;
}


class ServerChatPage extends StatefulWidget {
  const ServerChatPage({super.key});

  @override
  State<ServerChatPage> createState() => _ServerChatPageState();
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.isUser, required this.text, required this.time});

  final bool isUser;
  final String text;
  final String time;

  List<InlineSpan> _spans(BuildContext context) {
    final theme = Theme.of(context);
    final spans = <InlineSpan>[];
    var remaining = text;
    while (remaining.contains(r'$$')) {
      final start = remaining.indexOf(r'$$');
      if (start > 0) {
        spans.add(TextSpan(text: remaining.substring(0, start)));
      }
      final rest = remaining.substring(start + 2);
      final end = rest.indexOf(r'$$');
      if (end < 0) {
        spans.add(TextSpan(text: r' $$')); // unmatched, render literally
        remaining = rest;
        continue;
      }
      final latex = rest.substring(0, end).trim();
      spans.add(
        WidgetSpan(
          baseline: TextBaseline.alphabetic,
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Math.tex(latex, textStyle: theme.textTheme.bodyMedium),
          ),
        ),
      );
      remaining = rest.substring(end + 2);
    }
    if (remaining.isNotEmpty) {
      spans.add(TextSpan(text: remaining));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isUser ? const Color(0xFF1B402B) : Colors.white;
    final textColor = isUser ? Colors.white : Colors.black87;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 4,
                  color: Color(0x14000000),
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: textColor, height: 1.35, fontSize: 14),
                children: _spans(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              time,
              style: const TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerChatPageState extends State<ServerChatPage> {
  final List<_ChatMessage> _messages = [];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  String _character = 'female';
  String _characterName = '';
  String _mode = 'chat'; // chat | problem | counseling
  String? _currentProblem;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final profile = await ApiClient.instance.getServerChatProfile();
      setState(() {
        _character = profile['character'] ?? 'female';
        _characterName = profile['character_name'] ?? '';
      });
    } catch (_) {
      // ignore failures, keep default
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    final userMessage = _ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      isMe: true,
      createdAt: DateTime.now(),
    );
    setState(() => _messages.add(userMessage));
    try {
      final resp = await ApiClient.instance.sendServerChatMessage(
        message: text,
        character: _character,
        mode: _mode,
      );
      setState(() {
        _messages.add(
          _ChatMessage(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            text: resp.assistantMessage,
            isMe: false,
            createdAt: DateTime.now(),
          ),
        );
        _character = resp.character;
        _characterName = resp.characterName.isNotEmpty
            ? resp.characterName
            : _characterName;
      });
      await Future.delayed(const Duration(milliseconds: 80));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } catch (err) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('전송 실패: $err')));
    } finally {
      setState(() => _sending = false);
    }
  }

  void _chooseMode() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('대화 모드'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _mode = 'chat';
                    _currentProblem = null;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment_add),
                title: const Text('문제 모드 (최근 문제 추가 예정)'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _mode = 'problem';
                    _currentProblem = '최근 문제 기반 모드';
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('상담 모드 (태그/활동 기반)'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _mode = 'counseling';
                    _currentProblem = null;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const roleLabel = 'AI 선생님';
    final avatarColor = const Color(0xFF1B4E80);
    final avatarText = (_characterName.isNotEmpty
        ? _characterName.substring(0, 1)
        : '선');
    final modeLabel = switch (_mode) {
      'problem' => '공부모드',
      'counseling' => '상담모드',
      _ => '대화모드',
    };
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: avatarColor,
              child: Text(
                avatarText,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _characterName.isNotEmpty ? _characterName : 'AI 파트너',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  roleLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1B402B),
        foregroundColor: Colors.white,
        actions: const [SizedBox(width: 12)],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            width: (MediaQuery.of(context).size.width * 0.9)
                .clamp(320.0, 760.0),
            height: (MediaQuery.of(context).size.height * 0.85)
                .clamp(420.0, MediaQuery.of(context).size.height - 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 10,
                  color: Color(0x1A000000),
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final item = _messages[index];
                      return _ChatBubble(
                        isUser: item.isMe,
                        text: item.text,
                        time: _formatTime(item.createdAt),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 6,
                        color: Color(0x22000000),
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 4,
                              onSubmitted: (_) => _send(),
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                hintText: r'질문을 입력하세요',
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    modeLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1B402B),
                                    ),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 0,
                                  minHeight: 0,
                                ),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(14),
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(14),
                                  ),
                                  borderSide: BorderSide(color: Color(0xFF45BF63)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _chooseMode,
                            icon: const Icon(Icons.add_circle_outline),
                            color: const Color(0xFF1B402B),
                            tooltip: '모드/문제 추가',
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            onPressed: _sending ? null : _send,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF45BF63),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.send, size: 18),
                            label: const Text('보내기'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
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



