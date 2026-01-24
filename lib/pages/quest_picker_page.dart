import 'package:flutter/material.dart';

import '../models/content_block.dart';
import '../services/api_client.dart';

class QuestPickerPage extends StatefulWidget {
  const QuestPickerPage({super.key});

  @override
  State<QuestPickerPage> createState() => _QuestPickerPageState();
}

class _QuestPickerPageState extends State<QuestPickerPage> {
  final TextEditingController _hashTagController = TextEditingController();
  final TextEditingController _questIdController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

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
      _showMessage('검색어를 입력하세요.');
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
        _error = '검색 실패';
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
        title: const Text('문제 찾아보기'),
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
                    hintText: '#해시태그',
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
                        final header =
                            quest['header'] as Map<String, dynamic>? ?? {};
                        final info =
                            quest['info'] as Map<String, dynamic>? ?? {};
                        final data =
                            quest['data'] as Map<String, dynamic>? ?? {};
                        final questId =
                            header['quest_id']?.toString() ?? 'unknown';
                        final titleBlocks =
                            parseContentBlocks(data['quest_title']);
                        final titleText =
                            contentBlocksToPlainText(titleBlocks);
                        final tags = (info['hash_tag'] as List<dynamic>? ?? [])
                            .map((tag) => tag.toString())
                            .toList();

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  questId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(titleText.isEmpty ? 'untitled' : titleText),
                                const SizedBox(height: 8),
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
                                      Navigator.of(context).pop(quest);
                                    },
                                    child: const Text('선택'),
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
    );
  }
}
