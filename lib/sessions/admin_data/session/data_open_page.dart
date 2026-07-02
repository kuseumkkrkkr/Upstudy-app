import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:s11/shared/services/api/api_client.dart';

class DataOpenPage extends StatefulWidget {
  const DataOpenPage({super.key});

  @override
  State<DataOpenPage> createState() => _DataOpenPageState();
}

class _DataOpenPageState extends State<DataOpenPage> {
  final TextEditingController _pageController = TextEditingController(text: '1');
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];
  int _page = 1;
  int _total = 0;
  final int _pageSize = 20;

  int get _totalPages {
    if (_total <= 0) {
      return 1;
    }
    return (_total / _pageSize).ceil();
  }

  @override
  void initState() {
    super.initState();
    _loadPage(1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPage(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiClient.instance.fetchQuestPage(
        page: page,
        pageSize: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = result.quests;
        _total = result.total;
        _page = result.page;
        _pageController.text = result.page.toString();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Load failed.';
        _loading = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _goToPage(int page) {
    final target = page.clamp(1, _totalPages);
    if (target == _page || _loading) {
      return;
    }
    _loadPage(target);
  }

  void _applyPageInput() {
    final parsed = int.tryParse(_pageController.text.trim());
    if (parsed == null) {
      _showMessage('Enter a valid page number.');
      _pageController.text = _page.toString();
      return;
    }
    _goToPage(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Open'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  onPressed:
                      _loading || _page <= 1 ? null : () => _goToPage(_page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _pageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _applyPageInput(),
                    decoration: const InputDecoration(
                      labelText: 'Page',
                      isDense: true,
                    ),
                  ),
                ),
                Text('/ $_totalPages'),
                IconButton(
                  onPressed: _loading || _page >= _totalPages
                      ? null
                      : () => _goToPage(_page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  onPressed: _loading ? null : _applyPageInput,
                  icon: const Icon(Icons.check),
                ),
                Text('Total: $_total'),
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
                  ? const Center(child: Text('No data.'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final quest = _results[index];
                        final header =
                            quest['header'] as Map<String, dynamic>? ?? {};
                        final info = quest['info'] as Map<String, dynamic>? ?? {};
                        final data = quest['data'] as Map<String, dynamic>? ?? {};
                        final questId =
                            header['quest_id']?.toString() ?? 'unknown';
                        final title =
                            data['quest_title']?.toString() ?? 'untitled';
                        final tags = (info['hash_tag'] as List<dynamic>? ?? [])
                            .map((tag) => tag.toString())
                            .toList();
                        final pretty =
                            const JsonEncoder.withIndent('  ').convert(quest);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ExpansionTile(
                            title: Text(questId),
                            subtitle: Text(title),
                            childrenPadding: const EdgeInsets.all(12),
                            children: [
                              if (tags.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: tags
                                      .map(
                                        (tag) => Chip(
                                          label: Text(tag),
                                        ),
                                      )
                                      .toList(),
                                ),
                              const SizedBox(height: 8),
                              SelectableText(pretty),
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
