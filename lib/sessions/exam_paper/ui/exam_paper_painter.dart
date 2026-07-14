part of 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

class _StrokePainter extends CustomPainter {
  static const double _pressureMinFactor = 0.35;

  _StrokePainter({
    required this.strokes,
    required this.currentStroke,
    required this.eraserPosition,
    required this.eraserRadius,
    required this.logicalSize,
    required this.backgroundColor,
    super.repaint,
  });

  final List<_Stroke> strokes;
  final _Stroke? currentStroke;
  final Offset? eraserPosition;
  final double eraserRadius;
  final Size logicalSize;
  final Color backgroundColor;

  static void drawStrokes(
    Canvas canvas,
    List<_Stroke> strokes, {
    _Stroke? currentStroke,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    void drawOne(_Stroke stroke) {
      if (stroke.points.isEmpty) return;
      paint.color = stroke.color;
      if (stroke.points.length == 1) {
        final point = stroke.points.first;
        final width = _pressureWidth(stroke.baseWidth, point.pressure);
        canvas.drawCircle(
          point.position,
          width / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        return;
      }
      for (var i = 0; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];
        final width = _pressureWidth(
          stroke.baseWidth,
          (p1.pressure + p2.pressure) * 0.5,
        );
        paint.strokeWidth = width;
        canvas.drawLine(p1.position, p2.position, paint);
      }
    }

    for (final stroke in strokes) {
      drawOne(stroke);
    }
    if (currentStroke != null) {
      drawOne(currentStroke);
    }
  }

  static double _pressureWidth(double baseWidth, double pressure) {
    final factor =
        _pressureMinFactor +
        (1 - _pressureMinFactor) * pressure.clamp(0.0, 1.0);
    return baseWidth * factor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & logicalSize);
    if (backgroundColor.a > 0) {
      canvas.drawRect(
        Offset.zero & logicalSize,
        Paint()..color = backgroundColor,
      );
    }
    drawStrokes(canvas, strokes, currentStroke: currentStroke);

    if (eraserPosition != null) {
      final fillPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(eraserPosition!, eraserRadius, fillPaint);
      canvas.drawCircle(eraserPosition!, eraserRadius, borderPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) {
    return oldDelegate.logicalSize != logicalSize ||
        oldDelegate.eraserPosition != eraserPosition ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _GradingGridPainter extends CustomPainter {
  _GradingGridPainter({required this.regions, required this.activeItemIndex});

  final List<_QuestionRegion> regions;
  final int? activeItemIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (regions.isEmpty) return;
    final normalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.grey.withValues(alpha: 0.6);
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.grey.withValues(alpha: 0.9);

    for (final region in regions) {
      final isActive =
          activeItemIndex != null && region.item.itemIndex == activeItemIndex;
      canvas.drawRect(region.rect, isActive ? activePaint : normalPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradingGridPainter oldDelegate) {
    return oldDelegate.activeItemIndex != activeItemIndex ||
        oldDelegate.regions.length != regions.length;
  }
}
