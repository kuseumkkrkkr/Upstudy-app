import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:s11/shared/utils/download_bytes.dart';

class SolveDebugSnapshot {
  final Map<String, dynamic> ocrPayload;
  final Map<String, dynamic>? ocrDebug;
  final Map<String, dynamic> ocrResult;

  final Map<String, dynamic> gradingPayload;
  final Map<String, dynamic>? gradingDebug;
  final Map<String, dynamic> gradingResult;

  final Uint8List studentImage;
  final Uint8List heatmapImage;
  final Uint8List? problemImage;

  final Future<Map<String, dynamic>> Function(String promptOverride)?
  onRerunGrading;

  const SolveDebugSnapshot({
    required this.ocrPayload,
    required this.ocrDebug,
    required this.ocrResult,
    required this.gradingPayload,
    required this.gradingDebug,
    required this.gradingResult,
    required this.studentImage,
    required this.heatmapImage,
    this.problemImage,
    this.onRerunGrading,
  });
}

class SolveDebugPage extends StatefulWidget {
  const SolveDebugPage({super.key, required this.snapshot});

  final SolveDebugSnapshot snapshot;

  @override
  State<SolveDebugPage> createState() => _SolveDebugPageState();
}

class _SolveDebugPageState extends State<SolveDebugPage> {
  late Map<String, dynamic>? _gradingDebug;
  late Map<String, dynamic> _gradingResult;
  late TextEditingController _promptController;
  bool _rerunBusy = false;

  @override
  void initState() {
    super.initState();
    _gradingDebug = widget.snapshot.gradingDebug;
    _gradingResult = Map<String, dynamic>.from(widget.snapshot.gradingResult);
    _promptController = TextEditingController(
      text: widget.snapshot.gradingDebug?['prompt']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  String _pretty(Object? value) {
    if (value == null) return '-';
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  Widget _section(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _jsonBlock(Object? value) {
    return SelectableText(
      _pretty(value),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        height: 1.4,
      ),
    );
  }

  Future<void> _downloadImage(String baseName, Uint8List bytes) async {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final filename = '${baseName}_$stamp.png';
    final savedPath = await saveBytesForUser(bytes, filename);
    if (!mounted) return;

    final message = savedPath == null
        ? '저장 실패: $filename'
        : '파일 저장됨: $savedPath';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _imageBlock(
    String label,
    Uint8List bytes, {
    required String baseName,
  }) {
    return _section(
      label,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('이미지 크기: ${bytes.lengthInBytes} bytes'),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _downloadImage(baseName, bytes),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('다운로드'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section('AI 프롬프트 (채점 입력)', _buildPromptEditor()),
        if (widget.snapshot.studentImage.isNotEmpty)
          _imageBlock(
            '학생 답안 이미지',
            widget.snapshot.studentImage,
            baseName: 'student_answer',
          ),
        if (widget.snapshot.heatmapImage.isNotEmpty)
          _imageBlock(
            '히트맵 이미지',
            widget.snapshot.heatmapImage,
            baseName: 'heatmap',
          ),
        if (widget.snapshot.problemImage != null &&
            widget.snapshot.problemImage!.isNotEmpty)
          _imageBlock(
            '문제 이미지',
            widget.snapshot.problemImage!,
            baseName: 'problem',
          ),
      ],
    );
  }

  Widget _buildPromptEditor() {
    final canRerun = widget.snapshot.onRerunGrading != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _promptController,
          minLines: 6,
          maxLines: 16,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '프롬프트를 수정할 수 있습니다.',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: canRerun && !_rerunBusy ? _handleRerun : null,
              child: _rerunBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('다시 실행'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                final prompt =
                    widget.snapshot.gradingDebug?['prompt']?.toString() ?? '';
                _promptController.text = prompt;
              },
              child: const Text('원래 프롬프트로 복원'),
            ),
          ],
        ),
        if (!canRerun)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '다시 실행 기능을 사용할 수 없습니다.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _handleRerun() async {
    if (widget.snapshot.onRerunGrading == null) return;
    setState(() => _rerunBusy = true);
    try {
      final prompt = _promptController.text;
      final result = await widget.snapshot.onRerunGrading!(prompt);
      setState(() {
        _gradingDebug = result['debug'] as Map<String, dynamic>?;
        final resultJson = result['result'];
        if (resultJson is Map<String, dynamic>) {
          _gradingResult = Map<String, dynamic>.from(resultJson);
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('다시 실행 완료')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('실행 실패: $error')));
    } finally {
      if (mounted) {
        setState(() => _rerunBusy = false);
      }
    }
  }

  Widget _buildOutputTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section('OCR 결과', _jsonBlock(widget.snapshot.ocrResult)),
        _section(
          'AI 결과',
          _jsonBlock(_gradingDebug?['result_json'] ?? _gradingResult),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('AI 디버그'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: '입력'),
              Tab(text: '출력'),
            ],
          ),
        ),
        body: TabBarView(children: [_buildInputTab(), _buildOutputTab()]),
      ),
    );
  }
}
