import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';

class VariantProblemStudioPage extends StatefulWidget {
  const VariantProblemStudioPage({super.key});

  @override
  State<VariantProblemStudioPage> createState() =>
      _VariantProblemStudioPageState();
}

class _VariantProblemStudioPageState extends State<VariantProblemStudioPage> {
  final _promptCtrl = TextEditingController();
  final _baseQuestCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController(text: '#함수');
  String _mode = 'prompt_note';
  bool _loading = false;
  String _result = '';

  Future<void> _generate() async {
    final tags = _tagsCtrl.text
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    setState(() {
      _loading = true;
      _result = '';
    });
    try {
      final baseRef = {
        if (_baseQuestCtrl.text.trim().isNotEmpty)
          'quest_id': _baseQuestCtrl.text.trim(),
      };
      Map<String, dynamic> res;
      if (_mode == 'flow_draft') {
        res = await ApiClient.instance.generateVariantFromFlowDraft(
          payload: {
            'variant_input_mode': 'flow_draft',
            'base_quest_ref': baseRef,
            'flow_draft': [
              {
                'node_id': 'n1',
                'text': _promptCtrl.text.trim(),
                'hash_tags': tags,
                'branches': [],
              },
            ],
            'tags': tags,
            'prompt': _promptCtrl.text.trim(),
          },
        );
      } else {
        res = await ApiClient.instance.generateVariantFromPromptNote(
          payload: {
            'variant_input_mode': 'prompt_note',
            'base_quest_ref': baseRef,
            'prompt': _promptCtrl.text.trim(),
            'note_blocks': [
              {'type': 'memo', 'text': _promptCtrl.text.trim()},
            ],
            'tags': tags,
          },
        );
      }
      if (!mounted) return;
      setState(() => _result = res.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _convertMcq() async {
    final questId = _baseQuestCtrl.text.trim();
    if (questId.isEmpty) {
      setState(() => _result = 'base quest id is required');
      return;
    }
    setState(() {
      _loading = true;
      _result = '';
    });
    try {
      final res = await ApiClient.instance.convertQuestToMcq(
        payload: {
          'base_quest_ref': {'quest_id': questId},
          'mcq_policy': {'offset_pattern': 'pm2', 'random_choices': true},
          'visibility_scope': 'private_mcq',
        },
      );
      if (!mounted) return;
      setState(() => _result = res.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  // 필요 변수: 변형 모드와 기준 문제 ID. 작동 원리: 현재 모드를 초기 선택값으로 표시하고 생성 요청 폼을 구성한다.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Variant Studio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _mode,
            items: const [
              DropdownMenuItem(
                value: 'prompt_note',
                child: Text('Prompt + Note (2-2)'),
              ),
              DropdownMenuItem(
                value: 'flow_draft',
                child: Text('Flow Draft (2-1)'),
              ),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'prompt_note'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _baseQuestCtrl,
            decoration: const InputDecoration(
              labelText: 'Base quest id',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tagsCtrl,
            decoration: const InputDecoration(
              labelText: 'tags',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'prompt / note',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: _loading ? null : _generate,
                child: const Text('Generate Variant'),
              ),
              OutlinedButton(
                onPressed: _loading ? null : _convertMcq,
                child: const Text('Convert MCQ'),
              ),
            ],
          ),
          if (_loading) ...const [
            SizedBox(height: 12),
            Center(child: CircularProgressIndicator()),
          ],
          if (_result.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(_result),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _baseQuestCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }
}
