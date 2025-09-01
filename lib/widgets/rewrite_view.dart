import 'package:flutter/material.dart';
import '../models/text_diff.dart';

class RewriteView extends StatefulWidget {
  final String originalText;
  final List<TextDiff> diffs;
  final VoidCallback? onAcceptAll;
  final VoidCallback? onRejectAll;
  final Function(TextDiff)? onDiffAccepted;
  final Function(TextDiff)? onDiffRejected;
  final String? selectedModel; // 선택된 AI 모델

  const RewriteView({
    super.key,
    required this.originalText,
    required this.diffs,
    this.onAcceptAll,
    this.onRejectAll,
    this.onDiffAccepted,
    this.onDiffRejected,
    this.selectedModel = 'gemini', // 기본값은 Gemini
  });

  @override
  State<RewriteView> createState() => _RewriteViewState();
}

class _RewriteViewState extends State<RewriteView> {
  OverlayEntry? _overlayEntry;

  void _showDiffTooltip(
    BuildContext context,
    TextDiff addition,
    TextDiff deletion,
    Offset position,
  ) {
    _hideTooltip();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy + 20, // 버튼 아래에 표시
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 수정 이유
                if (addition.reason != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '수정 이유',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          addition.reason!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // 수락/거절 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onDiffRejected != null
                          ? () {
                              widget.onDiffRejected!(addition);
                              _hideTooltip();
                            }
                          : null,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('거절'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: widget.onDiffAccepted != null
                          ? () {
                              widget.onDiffAccepted!(addition);
                              _hideTooltip();
                            }
                          : null,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('수락'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100, // 피드백 모드임을 나타내는 배경색
      child: Column(
        children: [
          // 전체 수락/거절 버튼
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onRejectAll != null)
                  OutlinedButton.icon(
                    onPressed: widget.onRejectAll,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('전체 거절'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                if (widget.onAcceptAll != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: widget.onAcceptAll,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('전체 수락'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Diff 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.diffs.length,
              itemBuilder: (context, index) {
                final diff = widget.diffs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildDiffCard(context, diff),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _findDeletedText(TextDiff currentDiff) {
    final currentIndex = widget.diffs.indexOf(currentDiff);
    if (currentIndex > 0) {
      final previousDiff = widget.diffs[currentIndex - 1];
      if (previousDiff.type == DiffType.deletion) {
        return previousDiff.text;
      }
    }
    return '원본 텍스트 없음';
  }

  Widget _buildDiffCard(BuildContext context, TextDiff diff) {
    final isDeletion = diff.type == DiffType.deletion;

    // 삭제된 텍스트는 건너뛰고 개선된 텍스트만 표시
    if (isDeletion) {
      return const SizedBox.shrink();
    }

    // deletion 텍스트 찾기
    final deletedText = _findDeletedText(diff);

    return InkWell(
      onTapDown: (details) {
        _showDiffTooltip(
          context,
          diff,
          TextDiff(text: deletedText, type: DiffType.deletion, reason: null),
          details.globalPosition,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                text: deletedText,
                style: const TextStyle(
                  color: Colors.red,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const TextSpan(text: ' → '),
              TextSpan(
                text: diff.text,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
