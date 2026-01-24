import 'package:flutter/material.dart';

import '../models/content_block.dart';
import '../services/api_client.dart';
import 'quest_picker_page.dart';

class CharacterChatDebugPage extends StatefulWidget {
  const CharacterChatDebugPage({super.key});

  @override
  State<CharacterChatDebugPage> createState() => _CharacterChatDebugPageState();
}

class _CharacterChatDebugPageState extends State<CharacterChatDebugPage> {
  double _affection = 120;
  double _attendanceDays = 7;
  bool _sending = false;
  int _currentInputTokens = 0;
  int _currentOutputTokens = 0;
  int _totalInputTokens = 0;
  int _totalOutputTokens = 0;
  String? _pairSummary;
  String _promptPreview = '';

  String? _selectedQuestId;
  String? _selectedQuestTitle;
  List<String> _selectedQuestTags = [];
  Map<String, int> _learningRatings = {};

  final TextEditingController _problemNumberController =
      TextEditingController();
  final TextEditingController _solutionNotesController =
      TextEditingController();
  final TextEditingController _chatInputController = TextEditingController();

  final List<_ChatMessage> _messages = [];

  @override
  void dispose() {
    _problemNumberController.dispose();
    _solutionNotesController.dispose();
    _chatInputController.dispose();
    super.dispose();
  }

  String _attendanceLabel(int days) {
    if (days <= 7) {
      return '1~7일';
    }
    if (days <= 14) {
      return '8~14일';
    }
    if (days <= 30) {
      return '15~30일';
    }
    return '30일 이상';
  }

  Future<void> _openQuestPicker() async {
    final quest = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const QuestPickerPage()),
    );
    if (quest == null) {
      return;
    }

    final header = quest['header'] as Map<String, dynamic>? ?? {};
    final info = quest['info'] as Map<String, dynamic>? ?? {};
    final data = quest['data'] as Map<String, dynamic>? ?? {};
    final questId = header['quest_id']?.toString();
    final titleBlocks = parseContentBlocks(data['quest_title']);
    final titleText = contentBlocksToPlainText(titleBlocks);
    final tags = (info['hash_tag'] as List<dynamic>? ?? [])
        .map((tag) => tag.toString())
        .where((tag) => tag.trim().isNotEmpty)
        .toList();

    setState(() {
      _selectedQuestId = questId;
      _selectedQuestTitle = titleText.isEmpty ? 'untitled' : titleText;
      _selectedQuestTags = tags;
      _learningRatings = {
        for (final tag in tags) tag: _learningRatings[tag] ?? 128,
      };
    });
  }

  void _clearQuestSelection() {
    setState(() {
      _selectedQuestId = null;
      _selectedQuestTitle = null;
      _selectedQuestTags = [];
      _learningRatings = {};
      _problemNumberController.clear();
      _solutionNotesController.clear();
    });
  }

  List<Map<String, String>> _buildRecentPairs() {
    final pairs = <Map<String, String>>[];
    String? pendingUser;
    for (final message in _messages) {
      if (message.isUser) {
        pendingUser = message.text;
      } else if (pendingUser != null) {
        pairs.add({'user': pendingUser, 'assistant': message.text});
        pendingUser = null;
      }
    }
    if (pairs.isEmpty) {
      return [];
    }
    return [pairs.last];
  }

  Future<void> _sendMessage() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    final recentPairs = _buildRecentPairs();

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(text: text, isUser: true));
      _chatInputController.clear();
    });

    try {
      final response = await ApiClient.instance.sendTestChatMessage(
        userMessage: text,
        affection: _affection.round(),
        attendanceDays: _attendanceDays.round(),
        questId: _selectedQuestId,
        problemNumber: _problemNumberController.text.trim().isEmpty
            ? null
            : _problemNumberController.text.trim(),
        solutionNotes: _solutionNotesController.text.trim().isEmpty
            ? null
            : _solutionNotesController.text.trim(),
        learningRatings: _learningRatings,
        recentPairs: recentPairs,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _ChatMessage(text: response.assistantMessage, isUser: false),
        );
        _pairSummary = response.pairSummary;
        _promptPreview = response.prompt;
        _currentInputTokens = response.inputTokenEstimate;
        _currentOutputTokens = response.outputTokenEstimate;
        _totalInputTokens += response.inputTokenEstimate;
        _totalOutputTokens += response.outputTokenEstimate;
        _sending = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
      });
      _showMessage('채팅 전송 실패');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasQuest = _selectedQuestId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('캐릭터챗 디버깅')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('테스트 변수'),
          _buildSliderCard(
            label: '호감도 (1~255, 256 금지)',
            value: _affection,
            min: 1,
            max: 255,
            divisions: 254,
            valueLabel: _affection.round().toString(),
            onChanged: (value) => setState(() => _affection = value),
          ),
          const SizedBox(height: 12),
          _buildSliderCard(
            label: '연속 출석일수',
            value: _attendanceDays,
            min: 1,
            max: 60,
            divisions: 59,
            valueLabel:
                '${_attendanceDays.round()}일 (${_attendanceLabel(_attendanceDays.round())})',
            onChanged: (value) => setState(() => _attendanceDays = value),
          ),
          const SizedBox(height: 20),
          _sectionTitle('문제 선택'),
          Row(
            children: [
              ElevatedButton(
                onPressed: _openQuestPicker,
                child: const Text('문제 찾아보기'),
              ),
              const SizedBox(width: 12),
              if (hasQuest)
                OutlinedButton(
                  onPressed: _clearQuestSelection,
                  child: const Text('선택 해제'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasQuest) _buildQuestSummaryCard() else const Text('문제를 선택하세요.'),
          const SizedBox(height: 20),
          _sectionTitle('학습 Rating'),
          if (!hasQuest)
            const Text('문제를 먼저 선택해야 Rating을 설정할 수 있어요.')
          else
            ..._selectedQuestTags.map(_buildRatingSlider).toList(),
          const SizedBox(height: 20),
          _sectionTitle('문제풀이데이터'),
          TextField(
            controller: _problemNumberController,
            enabled: hasQuest,
            decoration: const InputDecoration(
              labelText: '문제번호',
              hintText: '사용자가 푼 문제번호 입력',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _solutionNotesController,
            enabled: hasQuest,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '풀이 내역',
              hintText: '풀이 과정을 직접 입력',
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('채팅 디버깅'),
          _buildTokenPanel(),
          const SizedBox(height: 12),
          _buildPromptPreview(),
          const SizedBox(height: 12),
          _buildChatHistory(),
          const SizedBox(height: 12),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSliderCard({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 4),
            Text(
              valueLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('quest_id: ${_selectedQuestId ?? '-'}'),
            const SizedBox(height: 4),
            Text('제목: ${_selectedQuestTitle ?? '-'}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _selectedQuestTags
                  .map((tag) => Chip(label: Text(tag)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSlider(String tag) {
    final rating = _learningRatings[tag] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tag),
              const SizedBox(height: 4),
              Text(
                'Rating: $rating',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Slider(
                value: rating.toDouble(),
                min: 0,
                max: 256,
                divisions: 256,
                onChanged: (value) {
                  setState(() {
                    _learningRatings[tag] = value.round();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('입력 토큰: $_currentInputTokens'),
            const SizedBox(height: 4),
            Text('출력 토큰: $_currentOutputTokens'),
            const SizedBox(height: 8),
            Text('총 입력 토큰: $_totalInputTokens'),
            const SizedBox(height: 4),
            Text('총 출력 토큰: $_totalOutputTokens'),
            const SizedBox(height: 6),
            Text("페어 요약: ${_pairSummary ?? '없음'}"),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptPreview() {
    if (_promptPreview.isEmpty) {
      return const SizedBox.shrink();
    }
    return ExpansionTile(
      title: const Text('프롬프트 미리보기'),
      childrenPadding: const EdgeInsets.all(12),
      children: [SelectableText(_promptPreview)],
    );
  }

  Widget _buildChatHistory() {
    if (_messages.isEmpty) {
      return const Text('대화 내역이 없습니다.');
    }
    return Column(
      children: _messages
          .map(
            (message) => Align(
              alignment: message.isUser
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? Colors.pink.shade50
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(message.text),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildChatInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _chatInputController,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '채팅 입력'),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _sending ? null : _sendMessage,
          child: Text(_sending ? '전송중' : '전송'),
        ),
      ],
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}
