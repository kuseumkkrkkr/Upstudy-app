import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PromptEditorPage extends StatefulWidget {
  const PromptEditorPage({super.key});

  @override
  State<PromptEditorPage> createState() => _PromptEditorPageState();
}

class _PromptEditorPageState extends State<PromptEditorPage> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _vocabController = TextEditingController();
  final TextEditingController _outlineController = TextEditingController();
  static const String _apiBaseUrl = 'http://localhost:8000';
  bool _isLoading = true;
  String _selectedModel = 'gemini'; // 기본값으로 Gemini 선택

  @override
  void initState() {
    super.initState();
    _loadSavedPrompt();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _vocabController.dispose();
    _outlineController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPrompt() async {
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/prompt'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _promptController.text = data['prompt'] ?? '';
          _selectedModel = data['model'] ?? 'gemini'; // 저장된 모델 설정 로드
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading prompt: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _sendApiRequest(String endpoint) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': _promptController.text,
          'model': _selectedModel, // 선택된 모델 정보 포함
        }),
      );

      if (response.statusCode == 200) {
        // 응답 처리
        final data = jsonDecode(response.body);
        // TODO: 응답 처리 로직 구현
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending request: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프롬프트 수정 / 생성')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              '필수 프롬프트 작성',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _promptController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '프롬프트 내용을 입력하세요...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'AI 모델 선택',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Radio<String>(
                  value: 'gemini',
                  groupValue: _selectedModel,
                  onChanged: (String? value) {
                    setState(() => _selectedModel = value!);
                  },
                ),
                const Text('Gemini'),
                const SizedBox(width: 16),
                Radio<String>(
                  value: 'gpt',
                  groupValue: _selectedModel,
                  onChanged: (String? value) {
                    setState(() => _selectedModel = value!);
                  },
                ),
                const Text('GPT'),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '단어집합 생성',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _vocabController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '단어들을 쉼표로 구분하여 입력하세요...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '글 개요 만들기',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _outlineController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '글 개요를 작성하세요...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: () async {
                  setState(() => _isLoading = true);
                  try {
                    // 프롬프트 저장
                    final promptRes = await http.post(
                      Uri.parse(
                        '$_apiBaseUrl/prompt?prompt=${Uri.encodeComponent(_promptController.text.trim())}&model=$_selectedModel',
                      ),
                    );
                    if (promptRes.statusCode != 200) {
                      throw Exception('프롬프트 저장 실패');
                    }

                    // 단어 추가
                    final vocabText = _vocabController.text.trim();
                    final words = vocabText
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();

                    bool anyFailed = false;
                    for (final word in words) {
                      try {
                        final res = await http.post(
                          Uri.parse(
                            '$_apiBaseUrl/words?word=${Uri.encodeComponent(word)}',
                          ),
                        );
                        if (res.statusCode != 200) {
                          anyFailed = true;
                        }
                      } catch (e) {
                        anyFailed = true;
                      }
                    }

                    if (mounted) {
                      String message = '프롬프트가 저장되었습니다.';
                      if (words.isNotEmpty) {
                        message += anyFailed
                            ? ' (일부 단어 저장 실패)'
                            : ' (단어집합 저장 완료)';
                      }
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message)));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('저장 중 오류가 발생했습니다.')),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isLoading = false);
                    }
                  }
                },
                child: const Text('저장'),
              ),
          ],
        ),
      ),
    );
  }
}
