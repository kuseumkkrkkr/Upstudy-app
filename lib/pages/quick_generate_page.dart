import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'flow_view_page.dart';
import 'solution_view_page.dart';
import '../models/content_block.dart';
import '../widgets/content_blocks_view.dart';

class QuickGeneratePage extends StatefulWidget {
  const QuickGeneratePage({super.key});

  @override
  State<QuickGeneratePage> createState() => _QuickGeneratePageState();
}

class _QuickGeneratePageState extends State<QuickGeneratePage> {
  static const Map<int, _TierParams> _tierParams = {
    1: _TierParams(solvesCount: 2, strategyLevel: 1, branchConditions: 0),
    2: _TierParams(solvesCount: 3, strategyLevel: 1, branchConditions: 0),
    3: _TierParams(solvesCount: 4, strategyLevel: 2, branchConditions: 1),
    4: _TierParams(solvesCount: 5, strategyLevel: 2, branchConditions: 1),
    5: _TierParams(solvesCount: 6, strategyLevel: 3, branchConditions: 2),
  };

  final TextEditingController _tagsController =
      TextEditingController(text: '#다항식');
  final TextEditingController _referenceController = TextEditingController();
  double _difficultyTier = 3;
  int _solvesCount = 4;
  int _strategyLevel = 2;
  int _branchConditions = 1;
  bool _strictTags = false;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _quest;

  @override
  void initState() {
    super.initState();
    _applyTierParams(_difficultyTier.round());
  }

  @override
  void dispose() {
    _tagsController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _applyTierParams(int tier) {
    final params = _tierParams[tier] ?? _tierParams[3]!;
    _solvesCount = params.solvesCount;
    _strategyLevel = params.strategyLevel;
    _branchConditions = params.branchConditions;
  }

  List<String> _parseTags() {
    return _tagsController.text
        .split(RegExp(r'[,\n]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'hash_tags': _parseTags(),
      'solves_count': _solvesCount,
      'strategy_level': _strategyLevel,
      'branch_conditions': _branchConditions,
      'reference_quest_id': _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      'strict_tags': _strictTags,
    };
  }

  Future<void> _generateQuest() async {
    if (_loading) {
      return;
    }
    final tags = _parseTags();
    if (tags.isEmpty) {
      _showMessage('태그를 입력해 주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _quest = null;
    });
    try {
      final quest = await ApiClient.instance.generateQuest(
        hashTags: tags,
        solvesCount: _solvesCount,
        strategyLevel: _strategyLevel,
        branchConditions: _branchConditions,
        referenceQuestId: _referenceController.text.trim(),
        strictTags: _strictTags,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _quest = quest;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '문제 생성 실패';
        _loading = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = _buildPayload();
    final payloadText = const JsonEncoder.withIndent('  ').convert(payload);
    final questId = _extractQuestId(_quest);
    final questTitleBlocks = _extractQuestTitleBlocks(_quest);

    return Scaffold(
      appBar: AppBar(
        title: const Text('빠른 생성 (1문제 디버깅)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTierSection(),
          const SizedBox(height: 12),
          _buildParamSection(),
          const SizedBox(height: 12),
          _buildPayloadSection(payloadText),
          const SizedBox(height: 12),
          _buildActionSection(questId, questTitleBlocks),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(child: Text(_error!)),
            ),
        ],
      ),
    );
  }

  Widget _buildTierSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '난이도 티어 (상중하 패닝)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text('현재 티어: ${_difficultyTier.round()}'),
            Slider(
              value: _difficultyTier,
              min: 1,
              max: 5,
              divisions: 4,
              label: _difficultyTier.round().toString(),
              onChanged: (value) {
                setState(() {
                  _difficultyTier = value;
                  _applyTierParams(value.round());
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('하', style: TextStyle(fontSize: 12)),
                Text('중하', style: TextStyle(fontSize: 12)),
                Text('중', style: TextStyle(fontSize: 12)),
                Text('중상', style: TextStyle(fontSize: 12)),
                Text('상', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParamSection() {
    final tags = _parseTags();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '문제 생성 파라미터',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _buildSlider(
              label: 'solves_count',
              value: _solvesCount,
              min: 1,
              max: 8,
              divisions: 7,
              onChanged: (value) => setState(() => _solvesCount = value),
            ),
            _buildSlider(
              label: 'strategy_level',
              value: _strategyLevel,
              min: 1,
              max: 3,
              divisions: 2,
              onChanged: (value) => setState(() => _strategyLevel = value),
            ),
            _buildSlider(
              label: 'branch_conditions',
              value: _branchConditions,
              min: 0,
              max: 4,
              divisions: 4,
              onChanged: (value) => setState(() => _branchConditions = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'hash_tags (콤마/줄바꿈 구분)',
                hintText: '#다항식, #이차방정식',
              ),
              minLines: 1,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((tag) => Chip(label: Text(tag))).toList(),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: 'reference_quest_id (선택)',
                hintText: '002/260120/22125366',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('strict_tags'),
              value: _strictTags,
              onChanged: (value) => setState(() => _strictTags = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayloadSection(String payloadText) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '파이썬 전달 변수 (payload)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SelectableText(
              payloadText,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection(
    String questId,
    List<ContentBlock> questTitleBlocks,
  ) {
    final hasQuest = questId.isNotEmpty;
    final displayTitleBlocks = questTitleBlocks.isEmpty
        ? [const ContentBlock(type: 'text', content: '-')]
        : questTitleBlocks;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '생성 결과',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('quest_id: ${questId.isEmpty ? '-' : questId}'),
            const SizedBox(height: 4),
            const Text('quest_title:'),
            const SizedBox(height: 4),
            ContentBlocksView(
              blocks: displayTitleBlocks,
              textStyle: const TextStyle(fontSize: 13, height: 1.3),
              latexStyle: const TextStyle(fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _loading ? null : _generateQuest,
                  child: const Text('1문제 생성'),
                ),
                OutlinedButton(
                  onPressed: hasQuest
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FlowViewPage(quest: _quest!),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Flow Editor 열기'),
                ),
                OutlinedButton(
                  onPressed: hasQuest
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SolutionViewPage(
                                initialQuestId: questId,
                                autoSearch: true,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text('솔루션뷰/DB 조회'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required int value,
    required int min,
    required int max,
    required int divisions,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value.toString()),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: divisions,
          label: value.toString(),
          onChanged: (newValue) => onChanged(newValue.round()),
        ),
      ],
    );
  }

  String _extractQuestId(Map<String, dynamic>? quest) {
    if (quest == null) {
      return '';
    }
    final header = quest['header'] as Map<String, dynamic>? ?? {};
    return header['quest_id']?.toString().trim() ?? '';
  }

  List<ContentBlock> _extractQuestTitleBlocks(
    Map<String, dynamic>? quest,
  ) {
    if (quest == null) {
      return [];
    }
    final data = quest['data'] as Map<String, dynamic>? ?? {};
    return parseContentBlocks(data['quest_title']);
  }
}

class _TierParams {
  final int solvesCount;
  final int strategyLevel;
  final int branchConditions;

  const _TierParams({
    required this.solvesCount,
    required this.strategyLevel,
    required this.branchConditions,
  });
}
