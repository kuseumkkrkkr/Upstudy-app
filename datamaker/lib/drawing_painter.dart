import 'package:flutter/material.dart';
import 'data_manager.dart';

class DrawingPainter extends CustomPainter {
  final List<List<StrokePoint>> strokes;
  final List<StrokePoint> currentStroke;

  DrawingPainter(this.strokes, this.currentStroke);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    _drawStroke(canvas, currentStroke, paint);
  }

  void _drawStroke(Canvas canvas, List<StrokePoint> points, Paint paint) {
    if (points.length < 2) return;

    final path = Path()
      ..moveTo(points.first.position.dx, points.first.position.dy);

    for (final p in points.skip(1)) {
      path.lineTo(p.position.dx, p.position.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(DrawingPainter old) =>
      old.strokes != strokes || old.currentStroke != currentStroke;
}
