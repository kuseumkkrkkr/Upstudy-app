import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'diff_overlay_painter.dart';

/// 수정 제안 스팬 - 텍스트의 특정 부분에 대한 수정 제안을 나타냄
class DiffSpan {
  /// 수정 시작 위치
  final int start;

  /// 수정 끝 위치
  final int end;

  /// 원본 텍스트
  final String originalText;

  /// 제안된 텍스트
  final String suggestedText;

  /// 수정 이유
  final String? reason;

  /// 수락 여부
  bool isAccepted;

  /// 화면상의 위치 (오버레이 표시용)
  Rect? blockRect;
  DiffSpan({
    required this.start,
    required this.end,
    required this.originalText,
    required this.suggestedText,
    this.reason,
    this.isAccepted = false,
  });
}

class InlineDiffEditor extends StatefulWidget {
  final String text;
  final List<DiffSpan> diffs;
  final Function(DiffSpan) onAccept;
  final Function(DiffSpan) onReject;
  final TextEditingController controller;

  const InlineDiffEditor({
    super.key,
    required this.text,
    required this.diffs,
    required this.onAccept,
    required this.onReject,
    required this.controller,
  });

  @override
  State<InlineDiffEditor> createState() => _InlineDiffEditorState();
}

class _InlineDiffEditorState extends State<InlineDiffEditor> {
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }

  void _showTooltip(BuildContext context, DiffSpan diff, Offset position) {
    _hideTooltip();

    // 화면 경계를 벗어나지 않도록 위치 조정
    final screenWidth = MediaQuery.of(context).size.width;
    double left = position.dx;
    if (left + 300 > screenWidth) {
      left = screenWidth - 320;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: position.dy - 10, // 블록 위에 표시
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (diff.reason != null) ...[
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
                          diff.reason!,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        widget.onReject(diff);
                        _hideTooltip();
                      },
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('거절'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        widget.onAccept(diff);
                        _hideTooltip();
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('수락'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(children: _buildTextSpans()),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        // 각 diff의 위치와 크기 계산
        for (var diff in widget.diffs) {
          final startOffset = textPainter.getOffsetForCaret(
            TextPosition(offset: diff.start),
            Rect.zero,
          );
          final endOffset = textPainter.getOffsetForCaret(
            TextPosition(offset: diff.end),
            Rect.zero,
          );

          // 높이 계산을 위해 줄 수 확인
          final lineCount =
              (endOffset.dy - startOffset.dy) / textPainter.height;

          diff.blockRect = Rect.fromLTWH(
            startOffset.dx,
            startOffset.dy,
            lineCount <= 1
                ? endOffset.dx - startOffset.dx
                : constraints.maxWidth - startOffset.dx,
            (lineCount + 1) * textPainter.height,
          );
        }

        return Stack(
          children: [
            // 기본 텍스트
            SelectableText.rich(
              TextSpan(children: _buildTextSpans()),
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
            // 수정 제안 오버레이
            if (_overlayEntry == null) // 툴팁이 표시되지 않은 경우만 오버레이 표시
              for (var diff in widget.diffs)
                if (!diff.isAccepted && diff.blockRect != null)
                  GestureDetector(
                    onTapUp: (details) {
                      final RenderBox box =
                          context.findRenderObject() as RenderBox;
                      _showTooltip(
                        context,
                        diff,
                        box.localToGlobal(
                          Offset(diff.blockRect!.left, diff.blockRect!.top),
                        ),
                      );
                    },
                    child: Positioned(
                      left: diff.blockRect!.left,
                      top: diff.blockRect!.top,
                      width: diff.blockRect!.width,
                      height: diff.blockRect!.height,
                      child: CustomPaint(
                        painter: DiffOverlayPainter(
                          isOriginal: true,
                          color: Colors.red.shade300,
                        ),
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }

  List<TextSpan> _buildTextSpans() {
    final List<TextSpan> spans = [];
    int currentIndex = 0;

    // diffs를 시작 위치 기준으로 정렬
    final sortedDiffs = List<DiffSpan>.from(widget.diffs)
      ..sort((a, b) => a.start.compareTo(b.start));

    for (var diff in sortedDiffs) {
      // diff 이전의 일반 텍스트
      if (currentIndex < diff.start) {
        spans.add(
          TextSpan(text: widget.text.substring(currentIndex, diff.start)),
        );
      }

      if (!diff.isAccepted) {
        // 원본 텍스트 (빨간색 오버레이 블록)
        spans.add(
          TextSpan(
            text: diff.originalText,
            style: TextStyle(
              backgroundColor: Colors.transparent,
              decoration: TextDecoration.none,
              color: Colors.black87,
            ),
          ),
        );

        // 제안 텍스트 (초록색 오버레이 블록)
        spans.add(
          TextSpan(
            text: diff.suggestedText,
            style: TextStyle(
              backgroundColor: Colors.transparent,
              color: Colors.black87,
            ),
          ),
        );
      } else {
        // 수락된 경우 제안된 텍스트만 표시
        spans.add(TextSpan(text: diff.suggestedText));
      }

      currentIndex = diff.end;
    }

    // 마지막 diff 이후의 일반 텍스트
    if (currentIndex < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(currentIndex)));
    }

    return spans;
  }
}
