import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/design_tokens.dart';
import '../widgets/teacher_app_drawer.dart';

class ProblemEditorPage extends StatefulWidget {
  const ProblemEditorPage({super.key});

  @override
  State<ProblemEditorPage> createState() => _ProblemEditorPageState();
}

class _ProblemEditorPageState extends State<ProblemEditorPage> {
  final _promptCtrl = TextEditingController();
  final _baseQuestCtrl = TextEditingController();
  final _seedCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final List<String> _tags = [];
  final List<_FlowNodeDraft> _nodes = [_FlowNodeDraft()];

  String _mode = 'prompt_note';
  bool _loading = false;
  String? _resultText;
  List<String> _availableTags = [];
  List<Map<String, dynamic>> _tray = [];

  @override
  void initState() {
    super.initState();
    _loadTagSuggestions();
    _loadTray();
  }

  Future<void> _loadTagSuggestions() async {
    try {
      final tags = await ApiClient.instance.getCourseHashTags();
      if (!mounted) return;
      setState(() => _availableTags = tags);
    } catch (_) {}
  }

  Future<void> _loadTray() async {
    try {
      final items = await ApiClient.instance.listQuestTray(limit: 50);
      if (!mounted) return;
      setState(() => _tray = items);
    } catch (_) {}
  }

  int? _seedOverride() {
    final text = _seedCtrl.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Map<String, dynamic> _baseQuestRef() {
    final questId = _baseQuestCtrl.text.trim();
    return {if (questId.isNotEmpty) 'quest_id': questId};
  }

  List<Map<String, dynamic>> _flowDraft() {
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      final text = node.textCtrl.text.trim();
      final tags = node.tags.where((e) => e.trim().isNotEmpty).toList();
      if (text.isEmpty && tags.isEmpty) continue;
      items.add({
        'node_id': 'n${i + 1}',
        if (text.isNotEmpty) 'text': text,
        'hash_tags': tags,
        'branches': <String>[],
      });
    }
    return items;
  }

  Future<void> _generateVariant() async {
    setState(() {
      _loading = true;
      _resultText = null;
    });
    try {
      final common = <String, dynamic>{
        'base_quest_ref': _baseQuestRef(),
        'prompt': _promptCtrl.text.trim().isEmpty
            ? null
            : _promptCtrl.text.trim(),
        'seed_override': _seedOverride(),
        'tags': _tags,
      };
      Map<String, dynamic> result;
      if (_mode == 'flow_draft') {
        result = await ApiClient.instance.generateVariantFromFlowDraft(
          payload: {
            ...common,
            'variant_input_mode': 'flow_draft',
            'flow_draft': _flowDraft(),
          },
        );
      } else {
        result = await ApiClient.instance.generateVariantFromPromptNote(
          payload: {
            ...common,
            'variant_input_mode': 'prompt_note',
            'note_blocks': _flowDraft(),
          },
        );
      }
      if (!mounted) return;
      setState(() {
        _resultText = result.toString();
      });
      final quest = result['quest'] as Map<String, dynamic>?;
      final header = quest?['header'] as Map<String, dynamic>?;
      final questId = header?['quest_id']?.toString();
      if (questId != null && questId.isNotEmpty) {
        await ApiClient.instance.createQuestTrayItem(
          payload: {
            'quest_id': questId,
            'source_variant_mode': _mode,
            'visibility_scope': 'shared',
            'is_mcq_branch': false,
            'payload': {'tags': _tags, 'mode': _mode},
          },
        );
      }
      await _loadTray();
    } catch (e) {
      if (!mounted) return;
      setState(() => _resultText = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _convertToMcq() async {
    final questId = _baseQuestCtrl.text.trim();
    if (questId.isEmpty) {
      setState(() => _resultText = 'base quest id is required');
      return;
    }
    setState(() {
      _loading = true;
      _resultText = null;
    });
    try {
      final result = await ApiClient.instance.convertQuestToMcq(
        questId: questId,
      );
      setState(() => _resultText = result.toString());
      await _loadTray();
    } catch (e) {
      setState(() => _resultText = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addTag() {
    final value = _tagCtrl.text.trim();
    if (value.isEmpty) return;
    if (!_tags.contains(value)) {
      setState(() => _tags.add(value));
    }
    _tagCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    return Scaffold(
      endDrawer: const TeacherAppDrawer(currentRoute: '/problem-editor'),
      backgroundColor: kCourseBgGrey,
      appBar: AppBar(
        backgroundColor: kCourseGreen,
        foregroundColor: Colors.white,
        title: const Text('문항 변형 스튜디오'),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: '메뉴',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16 * scale),
        children: [
          _card(
            scale,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('생성 방식'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _mode,
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
                const SizedBox(height: 12),
                TextField(
                  controller: _baseQuestCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Base Quest ID (optional for 2-1/2-2)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _seedCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Seed override',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _promptCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Prompt',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          _card(
            scale,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tags with Autocomplete'),
                const SizedBox(height: 8),
                Autocomplete<String>(
                  optionsBuilder: (value) {
                    if (value.text.trim().isEmpty)
                      return const Iterable<String>.empty();
                    final q = value.text.trim().toLowerCase();
                    return _availableTags
                        .where((t) => t.toLowerCase().contains(q))
                        .take(12);
                  },
                  onSelected: (value) {
                    _tagCtrl.text = value;
                    _addTag();
                  },
                  fieldViewBuilder: (_, ctrl, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: ctrl,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Add hashtag',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        _tagCtrl.text = ctrl.text;
                        _addTag();
                        ctrl.clear();
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          _card(
            scale,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Flow Draft Nodes'),
                const SizedBox(height: 8),
                ..._nodes.map(
                  (node) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: node.textCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Node text',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: node.tagCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Node tags',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) {
                              final tag = node.tagCtrl.text.trim();
                              if (tag.isNotEmpty && !node.tags.contains(tag)) {
                                setState(() => node.tags.add(tag));
                              }
                              node.tagCtrl.clear();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _nodes.add(_FlowNodeDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add node'),
                ),
              ],
            ),
          ),
          _card(
            scale,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _loading ? null : _generateVariant,
                  child: const Text('문항 생성'),
                ),
                OutlinedButton(
                  onPressed: _loading ? null : _convertToMcq,
                  child: const Text('MCQ 변환 (2-4)'),
                ),
                OutlinedButton(
                  onPressed: _loading ? null : _loadTray,
                  child: const Text('Tray 새로고침'),
                ),
              ],
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_resultText != null) _card(scale, SelectableText(_resultText!)),
          _card(
            scale,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('내 Tray'),
                const SizedBox(height: 8),
                if (_tray.isEmpty)
                  const Text('No items')
                else
                  ..._tray.map((e) => Text(e.toString())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(double scale, Widget child) {
    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * scale),
        boxShadow: const [kCourseShadow],
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _baseQuestCtrl.dispose();
    _seedCtrl.dispose();
    _tagCtrl.dispose();
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }
}

class _FlowNodeDraft {
  _FlowNodeDraft();

  TextEditingController get textCtrl => _textCtrl ??= TextEditingController();
  TextEditingController get tagCtrl => _tagCtrl ??= TextEditingController();

  final List<String> tags = [];
  TextEditingController? _textCtrl;
  TextEditingController? _tagCtrl;

  void dispose() {
    _textCtrl?.dispose();
    _tagCtrl?.dispose();
  }
}
