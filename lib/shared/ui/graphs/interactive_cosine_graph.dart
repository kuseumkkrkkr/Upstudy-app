import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dependency-free cosine graph. Dragging pans the viewport and pinch zooms.
class InteractiveCosineGraph extends StatefulWidget {
  const InteractiveCosineGraph({super.key});

  @override
  State<InteractiveCosineGraph> createState() => _InteractiveCosineGraphState();
}

class _InteractiveCosineGraphState extends State<InteractiveCosineGraph> {
  double _scale = 1;
  Offset _offset = Offset.zero;

  void _updateViewport(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_scale * details.scale).clamp(.55, 3.2);
      _offset += details.focalPointDelta;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '코사인 함수 그래프',
      hint: '드래그하거나 두 손가락으로 확대·축소할 수 있습니다',
      child: GestureDetector(
        onScaleUpdate: _updateViewport,
        child: CustomPaint(
          painter: _CosineGraphPainter(scale: _scale, offset: _offset),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CosineGraphPainter extends CustomPainter {
  const _CosineGraphPainter({required this.scale, required this.offset});

  final double scale;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + offset;
    final unitX = 42 * scale;
    final unitY = math.min(42 * scale, size.height / 3);
    final grid = Paint()..color = const Color(0x1A09090B);
    final axis = Paint()
      ..color = const Color(0xFF71717A)
      ..strokeWidth = 1;
    for (var x = center.dx % unitX; x < size.width; x += unitX) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = center.dy % unitY; y < size.height; y += unitY) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), axis);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), axis);
    final curve = Path();
    for (var px = 0.0; px <= size.width; px += 2) {
      final py = center.dy - math.cos((px - center.dx) / unitX) * unitY;
      if (px == 0) {
        curve.moveTo(px, py);
      } else {
        curve.lineTo(px, py);
      }
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = const Color(0xFF09090B)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _CosineGraphPainter oldDelegate) =>
      oldDelegate.scale != scale || oldDelegate.offset != offset;
}
