import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'flow_view_page.dart';
import '../models/content_block.dart';
import '../widgets/content_blocks_view.dart';

class SolutionViewPage extends StatefulWidget {
  final String? initialHashTag;
  final String? initialQuestId;
  final String? initialTextQuery;
  final bool autoSearch;

  const SolutionViewPage({
    super.key,
    this.initialHashTag,
    this.initialQuestId,
    this.initialTextQuery,
    this.autoSearch = false,
  });

  @override
  State<SolutionViewPage> createState() => _SolutionViewPageState();
}

class _SolutionViewPageState extends State<SolutionViewPage> {
  final TextEditingController _hashTagController = TextEditingController();
  final TextEditingController _questIdController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _hashTagController.text = widget.initialHashTag ?? '';
    _questIdController.text = widget.initialQuestId ?? '';
    _textController.text = widget.initialTextQuery ?? '';
    if (widget.autoSearch &&
        (_hashTagController.text.isNotEmpty ||
            _questIdController.text.isNotEmpty ||
            _textController.text.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _hashTagController.dispose();
    _questIdController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final hashTag = _hashTagController.text.trim();
    final questId = _questIdController.text.trim();
    final text = _textController.text.trim();
    if (hashTag.isEmpty && questId.isEmpty && text.isEmpty) {
      _showMessage('Enter a hash tag, quest id, or text.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await ApiClient.instance.searchQuests(
        hashTag: hashTag,
        questId: questId,
        textQuery: text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Search failed.';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('풀이보기'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _hashTagController,
                  decoration: const InputDecoration(
                    labelText: 'Hash tag',
                    hintText: '#다항식',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _questIdController,
                  decoration: const InputDecoration(
                    labelText: 'Quest ID',
                    hintText: '002/260120/22125366',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: 'Problem text',
                    hintText: '문제 내용 검색',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _search,
                    child: const Text('Search'),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(child: Text(_error!)),
            )
          else
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('No results.'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final quest = _results[index];
                        final header = quest['header'] as Map<String, dynamic>? ?? {};
                        final info = quest['info'] as Map<String, dynamic>? ?? {};
                        final data = quest['data'] as Map<String, dynamic>? ?? {};
                        final questId = header['quest_id']?.toString() ?? 'unknown';
                        final titleBlocks =
                            parseContentBlocks(data['quest_title']);
                        final displayTitleBlocks = titleBlocks.isEmpty
                            ? [const ContentBlock(type: 'text', content: 'untitled')]
                            : titleBlocks;
                        final tags = (info['hash_tag'] as List<dynamic>? ?? [])
                            .map((tag) => tag.toString())
                            .toList();
                        final flows = _flattenFlows(
                          (quest['solves'] as List<dynamic>? ?? []),
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ExpansionTile(
                            title: Text(questId),
                            subtitle: ContentBlocksView(
                              blocks: displayTitleBlocks,
                              textStyle: const TextStyle(fontSize: 12),
                              latexStyle: const TextStyle(fontSize: 12),
                            ),
                            childrenPadding: const EdgeInsets.all(12),
                            children: [
                              if (tags.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: tags
                                      .map((tag) => Chip(label: Text(tag)))
                                      .toList(),
                                ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FlowViewPage(
                                          quest: quest,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Flow 보기'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (flows.isEmpty)
                                const Text('No flow data.')
                              else
                                ...flows.map(
                                  (blocks) => ContentBlocksView(
                                    blocks: blocks,
                                    textStyle: const TextStyle(fontSize: 12),
                                    latexStyle: const TextStyle(fontSize: 12),
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
    );
  }
}

List<List<ContentBlock>> _flattenFlows(List<dynamic> solves, {int depth = 0}) {
  final results = <List<ContentBlock>>[];
  for (final entry in solves) {
    final map = entry as Map<String, dynamic>? ?? {};
    final prefix = '  ' * depth;
    final flowBlocks = normalizeFlowBlocks(parseContentBlocks(map['flow']));
    results.add(prependTextBlock(flowBlocks, '$prefix- '));
    final branches = map['branches'] as List<dynamic>? ?? [];
    if (branches.isNotEmpty) {
      results.addAll(_flattenFlows(branches, depth: depth + 1));
    }
  }
  return results;
}
