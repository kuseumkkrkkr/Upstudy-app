import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// 수정 제안의 정보를 담는 클래스
class SuggestionOverlay extends StatelessWidget {
  final Rect blockRect;
  final String originalText;
  final String suggestedText;
  final String reason;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isOriginal; // 원본 텍스트 여부

  const SuggestionOverlay({
    super.key,
    required this.blockRect,
    required this.originalText,
    required this.suggestedText,
    required this.reason,
    required this.onAccept,
    required this.onReject,
    required this.isOriginal,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: blockRect.left,
      top: blockRect.top,
      width: blockRect.width,
      height: blockRect.height,
      child: GestureDetector(
        onTap: () {
          _showTooltip(context);
        },
        child: CustomPaint(
          painter: BlockOverlayPainter(
            color: isOriginal ? Colors.red : Colors.green,
          ),
        ),
      ),
    );
  }

  void _showTooltip(BuildContext context) {
    final tooltipWidth = 300.0;
    final tooltipHeight = 200.0;

    // 화면 크기 구하기
    final screenSize = MediaQuery.of(context).size;

    // 툴팁 위치 계산
    double left = blockRect.left;
    if (left + tooltipWidth > screenSize.width) {
      left = screenSize.width - tooltipWidth - 16;
    }

    // 블록 상단에 표시
    double top = blockRect.top - tooltipHeight - 8;
    if (top < 0) {
      // 상단 공간이 부족하면 하단에 표시
      top = blockRect.bottom + 8;
    }

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: Material(
              borderRadius: BorderRadius.circular(8),
              elevation: 8,
              child: Container(
                width: tooltipWidth,
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade200),
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
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            reason,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 버튼
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onReject();
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text('거절'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onAccept();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text('수락'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 블록 오버레이 페인터
class BlockOverlayPainter extends CustomPainter {
  final Color color;

  BlockOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // 블록 배경
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 테두리
    paint
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
