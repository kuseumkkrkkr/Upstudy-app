import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/theme/app_colors.dart';

const int _maxInputChars = 250;

class ServerChatPage extends StatefulWidget {
  const ServerChatPage({
    super.key,
    this.initialContext,
    this.initialMode,
    this.ephemeral = false,
  });

  final Map<String, dynamic>? initialContext;
  final String? initialMode;
  final bool ephemeral;

  @override
  State<ServerChatPage> createState() => _ServerChatPageState();
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.createdAt,
  });

  final String text;
  final bool isUser;
  final DateTime createdAt;
}

class _ServerChatPageState extends State<ServerChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];

  bool _sending = false;
  DateTime? _blockedUntil;
  Timer? _blockTimer;

  String? get _questTitle => widget.initialContext?['quest_title']?.toString();
  String? get _flow {
    final answer = widget.initialContext?['answer_riddle']?.toString() ?? '';
    final formulas = widget.initialContext?['all_formulas']?.toString() ?? '';
    return [answer, formulas].where((e) => e.trim().isNotEmpty).join('\n');
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialContext != null) {
      _messages.add(
        _ChatMessage(
          text: '문제 맥락이 연결되었습니다.',
          isUser: false,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _blockTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _inputBlocked {
    final until = _blockedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  bool get _canSend => !_sending && !_inputBlocked;

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

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

  Future<void> _send({
    String? overrideText,
    bool includeUserData = false,
  }) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || !_canSend) return;
    if (text.length > _maxInputChars) {
      _showError('입력은 $_maxInputChars자까지만 가능합니다.');
      return;
    }

    setState(() {
      _sending = true;
      _messages.add(
        _ChatMessage(text: text, isUser: true, createdAt: DateTime.now()),
      );
      if (overrideText == null) _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await ApiClient.instance.sendServerChatMessage(
        message: text,
        mode: widget.initialMode == 'problem' ? 'problem' : 'chat',
        ephemeral: widget.ephemeral,
        includeUserData: includeUserData,
        questTitle: _questTitle,
        flow: _flow,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: response.assistantMessage,
            isUser: false,
            createdAt: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      _applyRateBlock(error);
      _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _askFaq(String text) {
    _send(overrideText: text);
  }

  void _askWithMyData() {
    _send(
      overrideText: '내 학습 현황을 바탕으로 지금 무엇을 먼저 공부하면 좋을지 짧게 상담해줘.',
      includeUserData: true,
    );
  }

  void _applyRateBlock(Object error) {
    if (error is! ApiException || error.statusCode != 429) return;
    final retryAfter =
        error.retryAfterSeconds ??
        (error.message.contains('너무 짧습니다') ? 30 : null);
    if (retryAfter == null || retryAfter <= 0 || retryAfter > 60) return;
    _blockTimer?.cancel();
    setState(() {
      _blockedUntil = DateTime.now().add(Duration(seconds: retryAfter));
    });
    _blockTimer = Timer(Duration(seconds: retryAfter), () {
      if (!mounted) return;
      setState(() => _blockedUntil = null);
    });
  }

  String _friendlyError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 429) {
        return error.message.isNotEmpty ? error.message : '잠시 후 다시 시도해 주세요.';
      }
      if (error.statusCode == 400) {
        return '입력값을 확인해 주세요.';
      }
      return error.message;
    }
    return '응답을 가져오지 못했습니다.';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _close() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = (size.width - 32).clamp(340.0, 760.0);
    final height = (size.height - 32).clamp(520.0, 760.0);

    return Material(
      color: Colors.black.withValues(alpha: 0.32),
      child: Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              _ChatHeader(onClose: _close),
              const Divider(height: 1),
              Expanded(
                child: Stack(
                  children: [
                    const Positioned.fill(child: _Watermark()),
                    _messages.isEmpty
                        ? const _EmptyChat()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final item = _messages[index];
                              return _MessageBubble(
                                message: item,
                                time: _formatTime(item.createdAt),
                              );
                            },
                          ),
                  ],
                ),
              ),
              _ChatInput(
                controller: _controller,
                sending: _sending,
                blocked: _inputBlocked,
                onSend: () => _send(),
                onFaq: _askFaq,
                onMyData: _askWithMyData,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 챗봇',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'AI 튜터에게 물어보세요',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '닫기',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'AI 튜터에게 물어보세요',
        style: TextStyle(
          color: Colors.black54,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Watermark extends StatelessWidget {
  const _Watermark();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Text(
          'AIFlow',
          style: TextStyle(
            color: AppColors.primary.withValues(alpha: 0.045),
            fontSize: 72,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.time});

  final _ChatMessage message;
  final String time;

  List<InlineSpan> _spans(BuildContext context) {
    final spans = <InlineSpan>[];
    var rest = message.text;
    while (rest.contains(r'$$')) {
      final start = rest.indexOf(r'$$');
      if (start > 0) spans.add(TextSpan(text: rest.substring(0, start)));
      final afterStart = rest.substring(start + 2);
      final end = afterStart.indexOf(r'$$');
      if (end < 0) {
        spans.add(TextSpan(text: rest.substring(start)));
        rest = '';
        break;
      }
      final latex = afterStart.substring(0, end).trim();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Math.tex(
              latex,
              textStyle: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
      rest = afterStart.substring(end + 2);
    }
    if (rest.isNotEmpty) spans.add(TextSpan(text: rest));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubbleColor = isUser ? AppColors.primary : const Color(0xFFF6F7F4);
    final textColor = isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(8),
                    topRight: const Radius.circular(8),
                    bottomLeft: Radius.circular(isUser ? 8 : 2),
                    bottomRight: Radius.circular(isUser ? 2 : 8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        height: 1.42,
                      ),
                      children: _spans(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                time,
                style: const TextStyle(fontSize: 10, color: Colors.black38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.sending,
    required this.blocked,
    required this.onSend,
    required this.onFaq,
    required this.onMyData,
  });

  final TextEditingController controller;
  final bool sending;
  final bool blocked;
  final VoidCallback onSend;
  final ValueChanged<String> onFaq;
  final VoidCallback onMyData;

  static const List<String> _faqs = <String>[
    '오늘 뭐부터 공부할까?',
    '오답을 줄이는 방법은?',
    '개념을 짧게 정리해줘',
    '풀이 힌트만 알려줘',
  ];

  @override
  Widget build(BuildContext context) {
    final inputEnabled = !sending && !blocked;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBF8),
        border: Border(top: BorderSide(color: Color(0xFFE4E8DE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final faq in _faqs)
                ActionChip(
                  label: Text(faq),
                  onPressed: inputEnabled ? () => onFaq(faq) : null,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: inputEnabled ? onMyData : null,
              icon: const Icon(Icons.analytics_outlined, size: 18),
              label: const Text('나의 데이터로 상담하기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: Color(0xFFD5DFCE)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: inputEnabled,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: _maxInputChars,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(_maxInputChars),
                  ],
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: blocked ? '잠시 후 다시 입력하세요' : '메시지 입력',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Color(0xFFDDE3D6)),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Color(0xFFDDE3D6)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton.filled(
                  tooltip: '전송',
                  onPressed: inputEnabled ? onSend : null,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFB7C2B0),
                  ),
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
