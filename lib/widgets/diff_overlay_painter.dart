import 'package:flutter/material.dart';

/// 수정 제안 오버레이를 그리는 CustomPainter
class DiffOverlayPainter extends CustomPainter {
  final bool isOriginal;
  final Color color;

  DiffOverlayPainter({required this.isOriginal, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // 배경 그리기
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 테두리 그리기
    paint
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant DiffOverlayPainter oldDelegate) =>
      color != oldDelegate.color || isOriginal != oldDelegate.isOriginal;
}
