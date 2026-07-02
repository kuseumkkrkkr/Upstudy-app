import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/theme/app_colors.dart';

const _green = Color(0xFF1B402B);
const _bgGrey = Color(0xFFF3F3F3);

class _ChatAction {
  const _ChatAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class _ChatMessage {
  _ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.createdAt,
    this.isSystem = false,
    this.actions = const <_ChatAction>[],
  });

  final String id;
  final String text;
  final bool isMe;
  final bool isSystem;
  final List<_ChatAction> actions;
  final DateTime createdAt;
}

class _ProblemEntry {
  const _ProblemEntry({
    required this.number,
    required this.dateKey,
  });

  final String number;
  final String dateKey;

  String get dateLabel {
    final parts = dateKey.split('-');
    if (parts.length == 3) {
      return '${parts[1]}.${parts[2]}';
    }
    return dateKey;
  }

  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase();
    return number.toLowerCase().contains(q) || dateKey.contains(q);
  }
}

class ServerChatPage extends StatefulWidget {
  const ServerChatPage({
    super.key,
    this.initialContext,
    this.initialMode,
    this.ephemeral = false,
  });

  /// {quest_title, answer_riddle, all_formulas}
  final Map<String, dynamic>? initialContext;
  /// 'chat' | 'problem'
  final String? initialMode;
  /// skip history/persistence when true
  final bool ephemeral;

  @override
  State<ServerChatPage> createState() => _ServerChatPageState();
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.isUser,
    required this.isSystem,
    required this.text,
    required this.time,
    this.actions = const <_ChatAction>[],
  });

  final bool isUser;
  final bool isSystem;
  final String text;
  final String time;
  final List<_ChatAction> actions;

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
    final bubbleColor = isSystem
        ? const Color(0xFFF6F6F6)
        : (isUser ? _green : Colors.white);
    final textColor = isSystem
        ? Colors.black87
        : (isUser ? Colors.white : Colors.black87);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          height: 1.35,
                          fontSize: 14,
                        ),
                    children: _spans(context),
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: actions
                        .map(
                          (action) => OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _green,
                              side: const BorderSide(color: _green),
                            ),
                            onPressed: action.onPressed,
                            child: Text(action.label),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
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
  String _mode = 'chat'; // chat | problem
  _ProblemEntry? _selectedProblem;
  int _problemQuestionCount = 0;
  bool get _isEphemeral => widget.ephemeral == true;
  bool _awaitingDevPassword = false;
  String _lastOutgoingPrompt = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
    if (widget.initialMode != null &&
        (widget.initialMode == 'chat' || widget.initialMode == 'problem')) {
      _mode = widget.initialMode!;
    }
    if (widget.initialContext != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _bootFromContext(widget.initialContext!),
      );
    }
  }

  @override
  void dispose() {
    _messages.clear();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final profile = await ApiClient.instance.getServerChatProfile();
      if (!mounted) return;
      setState(() {
        _character = profile['character'] ?? 'female';
        _characterName = profile['character_name'] ?? '';
      });
    } catch (_) {
      // ignore failures, keep default
    }

    if (widget.initialContext != null) {
      _bootFromContext(widget.initialContext!);
    }
  }

  void _bootFromContext(Map<String, dynamic> ctx) {
    final questTitle = ctx['quest_title']?.toString() ?? '';
    final answerRiddle = ctx['answer_riddle']?.toString() ?? '';
    final formulas = ctx['all_formulas']?.toString() ?? '';
    final buffer = StringBuffer()
      ..writeln('���� ����: $questTitle')
      ..writeln('���� Ǯ�� ���: $answerRiddle');
    if (formulas.isNotEmpty) {
      buffer.writeln('����� Ǯ�� ����: $formulas');
    }
    _appendSystemMessage('��ȭ �ƶ��� �ҷ��Ծ��. �� ���븸 ������ �ּ���. ������ ������� �ʽ��ϴ�.');
    _appendMessageText(buffer.toString(), isMe: true);
    _send(
      overrideText:
          '�� �ƶ��� ������� �ٷ� �亯�� ������ ��. ���� ���: ${_mode == 'problem' ? '��ũ���׽��� �н����' : '�ﰢ �ǵ�� �������'}.',
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _appendMessageText(
    String text, {
    bool isMe = false,
    bool isSystem = false,
  }) {
    _appendMessage(
      _ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: text,
        isMe: isMe,
        isSystem: isSystem,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _appendMessage(_ChatMessage message) {
    if (!mounted) return;
    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  void _appendSystemMessage(
    String text, {
    List<_ChatAction> actions = const <_ChatAction>[],
  }) {
    _appendMessage(
      _ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: text,
        isMe: false,
        isSystem: true,
        actions: actions,
        createdAt: DateTime.now(),
      ),
    );
  }

  String _decorateOutgoingText(String text) {
    if (_mode == 'problem' && _selectedProblem != null) {
      final p = _selectedProblem!;
      return '[�������|��ȣ:${p.number}|Ǯ����:${p.dateLabel}] $text';
    }
    return text;
  }

  void _resetConversation() {
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _controller.clear();
      _selectedProblem = null;
      _problemQuestionCount = 0;
      _mode = 'chat';
      _awaitingDevPassword = false;
      _lastOutgoingPrompt = '';
    });
  }

  Future<bool> _onWillPop() async {
    _resetConversation();
    return true;
  }

  void _exitChat() {
    _resetConversation();
    Navigator.of(context).maybePop();
  }

  Future<void> _send({String? overrideText}) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    // ������ ���: ��й�ȣ üũ �÷ο�
    if (_awaitingDevPassword) {
      _controller.clear();
      if (text == 'aiflow') {
        _awaitingDevPassword = false;
        _appendSystemMessage(
          '������ ��� Ȱ��ȭ: �ֱ� ���� ������Ʈ ������ ǥ���մϴ�.\n---\n$_lastOutgoingPrompt',
        );
      } else {
        _appendSystemMessage('��й�ȣ�� ��ġ���� �ʽ��ϴ�. �ٽ� �Է��ϼ���.');
      }
      return;
    }

    if (text == '/�����ڸ��') {
      _controller.clear();
      _awaitingDevPassword = true;
      _appendSystemMessage('������ ��带 ���÷��� ��й�ȣ�� �Է��ϼ���.');
      return;
    }

    setState(() => _sending = true);
    if (overrideText == null) _controller.clear();

    final userMessage = _ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      isMe: true,
      createdAt: DateTime.now(),
    );
    _appendMessage(userMessage);

    try {
      final resp = await ApiClient.instance.sendServerChatMessage(
        message: _decorateOutgoingText(text),
        character: _character,
        mode: _mode,
        ephemeral: widget.ephemeral,
      );
      _appendMessage(
        _ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: resp.assistantMessage,
          isMe: false,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _character = resp.character;
        _characterName =
            resp.characterName.isNotEmpty ? resp.characterName : _characterName;
        if (_mode == 'problem' && _selectedProblem != null) {
          _problemQuestionCount += 1;
        }
      });
      _maybeAutoExitProblemMode();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('���� ����: $err')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }

    _lastOutgoingPrompt = _decorateOutgoingText(text);
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
                title: const Text('��ȭ ���'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _mode = 'chat';
                    _selectedProblem = null;
                    _problemQuestionCount = 0;
                  });
                  _appendSystemMessage('��ȭ ���� ��ȯ�߾��.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment_add),
                title: const Text('���� ���'),
                onTap: () {
                  Navigator.pop(ctx);
                  _enterProblemMode();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modeChips() {
    return Wrap(
      spacing: 6,
      children: [
        ChoiceChip(
          label: const Text('�н����'),
          selected: _mode == 'problem',
          onSelected: (_) => setState(() {
            _mode = 'problem';
            _selectedProblem = null;
            _problemQuestionCount = 0;
          }),
        ),
        ChoiceChip(
          label: const Text('�������'),
          selected: _mode == 'chat',
          onSelected: (_) => setState(() {
            _mode = 'chat';
            _selectedProblem = null;
            _problemQuestionCount = 0;
          }),
        ),
      ],
    );
  }

  void _enterProblemMode() {
    setState(() {
      _mode = 'problem';
      _selectedProblem = null;
      _problemQuestionCount = 0;
    });
    _appendSystemMessage(
      '���� ��带 �׾��. ��ȭ�� ������ �����ϼ���.',
      actions: [
        _ChatAction(label: '���� ����', onPressed: _openProblemPicker),
        _ChatAction(label: '��� ����', onPressed: _exitProblemMode),
      ],
    );
  }

  void _exitProblemMode() {
    setState(() {
      _mode = 'chat';
      _selectedProblem = null;
      _problemQuestionCount = 0;
    });
    _appendSystemMessage('���� ��带 �����߾��.');
  }

  List<_ProblemEntry> _problemEntriesFromSnapshot(ActivitySnapshot snapshot) {
    final seen = <String>{};
    final entries = <_ProblemEntry>[];
    final days = snapshot.sortedDays();
    for (final day in days) {
      for (final number in day.problemNumbers) {
        final trimmed = number.trim();
        if (trimmed.isEmpty || seen.contains(trimmed)) continue;
        seen.add(trimmed);
        entries.add(_ProblemEntry(number: trimmed, dateKey: day.dateKey));
      }
    }
    return entries;
  }

  Future<void> _openProblemPicker() async {
    if (_isEphemeral) {
      _appendSystemMessage('�� ���ǿ����� ���� ����� �ҷ����� �ʽ��ϴ�.');
      return;
    }
    final snapshot = await ActivityStore.load();
    if (!mounted) return;
    final items = _problemEntriesFromSnapshot(snapshot);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('����Ǯ�� �̷��� �����ϴ�.')),
      );
      return;
    }

    final picked = await showModalBottomSheet<_ProblemEntry>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String query = '';
        String? selected = _selectedProblem?.number;
        List<_ProblemEntry> filtered = items;
        void applyFilter(StateSetter setModalState) {
          setModalState(() {
            filtered =
                items.where((e) => e.matches(query)).toList(growable: false);
          });
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '���� ����',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('�ݱ�'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: '���� ��ȣ �˻�',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        onChanged: (value) {
                          query = value;
                          applyFilter(setModalState);
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (_, index) {
                            final item = filtered[index];
                            return ListTile(
                              onTap: () {
                                setModalState(() => selected = item.number);
                              },
                              leading: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected == item.number
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).dividerColor,
                                    width: 2,
                                  ),
                                  color: selected == item.number
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                ),
                                child: selected == item.number
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              title: Text(item.number),
                              subtitle: Text('Ǯ���� ${item.dateLabel}'),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      ElevatedButton(
                        onPressed: selected == null
                            ? null
                            : () {
                                final picked = items.firstWhere(
                                  (e) => e.number == selected,
                                );
                                Navigator.of(ctx).pop(picked);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                        ),
                        child: const Text('���� ����'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (!mounted || picked == null) return;
    _handleProblemSelected(picked);
  }

  void _handleProblemSelected(_ProblemEntry entry) {
    setState(() {
      _selectedProblem = entry;
      _mode = 'problem';
      _problemQuestionCount = 0;
    });
    _appendSystemMessage(
      '������ �����Ǿ����: ${entry.number} (${entry.dateLabel}). ���� ��ũ���׽��� ������ �����ؿ�.',
    );
    _startProblemDialogue(entry);
  }

  Future<void> _startProblemDialogue(_ProblemEntry entry) async {
    final kickoff =
        '������ ���� ${entry.number}�� ������� ��ũ���׽��� ������ ������ ��.';
    await _send(overrideText: kickoff);
  }

  void _maybeAutoExitProblemMode() {
    if (_mode != 'problem' || _selectedProblem == null) return;
    if (_problemQuestionCount < 50) return;
    _appendSystemMessage(
      '������ 50ȸ�� �Ѿ����. ���� ��带 �����մϴ�.',
    );
    setState(() {
      _mode = 'chat';
      _selectedProblem = null;
      _problemQuestionCount = 0;
    });
  }

  Widget _modeBadge() {
    final inProblem = _mode == 'problem';
    final label = inProblem
        ? '�������${_selectedProblem != null ? ' �� ${_selectedProblem!.number}' : ''}'
        : '��ȭ���';
    final color = inProblem ? _green : const Color(0xFF1B4E80);
    final bg = inProblem ? const Color(0xFFE6F4EA) : const Color(0xFFE8F0FE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const roleLabel = 'AI ������';
    final avatarColor = const Color(0xFF1B4E80);
    final avatarText = (_characterName.isNotEmpty
        ? _characterName.substring(0, 1)
        : '��');
    final size = MediaQuery.of(context).size;
    final targetWidth = (size.width * 0.9) + 500;
    final targetHeight = (size.height * 0.8) + 500;
    final width = targetWidth.clamp(360.0, size.width - 40);
    final height = targetHeight.clamp(520.0, size.height - 40);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _onWillPop();
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          height: height,
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
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: avatarColor.withValues(alpha: 0.12),
                    child: Text(
                      avatarText,
                      style: TextStyle(color: avatarColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _characterName.isNotEmpty ? _characterName : 'AI ��Ʈ��',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          roleLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _modeBadge(),
                  const SizedBox(width: 8),
                  _modeChips(),
                  IconButton(
                    tooltip: '��� ��ȯ',
                    onPressed: _chooseMode,
                    icon: const Icon(Icons.tune, color: _green),
                  ),
                  TextButton(
                    onPressed: _exitChat,
                    child: const Text(
                      '������',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: _green,
                    onPressed: _exitChat,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _bgGrey,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            '��ȭ�� ������ ������.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final item = _messages[index];
                            return _ChatBubble(
                              isUser: item.isMe,
                              isSystem: item.isSystem,
                              text: item.text,
                              actions: item.actions,
                              time: _formatTime(item.createdAt),
                            );
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
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: r'������ �Է��ϼ���',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Text(
                            _mode == 'problem' ? '�������' : '��ȭ���',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _green,
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide(color: Color(0x22000000)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide(color: _green),
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
                      onPressed: _sending ? null : _send,
                      child: const Text('������'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
