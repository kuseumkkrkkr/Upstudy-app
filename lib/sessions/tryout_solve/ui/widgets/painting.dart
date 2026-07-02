part of 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

class _Stroke {
  _Stroke({
    required this.id,
    required this.color,
    required this.baseWidth,
    required this.order,
    required this.startTime,
  }) : endTime = startTime;

  final String id;
  final Color color;
  final double baseWidth;
  final int order;
  final double startTime;
  double endTime;
  final List<_StrokePoint> points = <_StrokePoint>[];
  Rect? bounds;

  void addPoint(Offset position, double pressure, double timestamp) {
    points.add(_StrokePoint(position, pressure, timestamp));
    endTime = timestamp;
    final radius = baseWidth / 2;
    final pointRect = Rect.fromCircle(center: position, radius: radius);
    bounds = bounds == null ? pointRect : bounds!.expandToInclude(pointRect);
  }

  double get duration => math.max(0.0, endTime - startTime);

  double get length {
    if (points.length < 2) return 0.0;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += (points[i + 1].position - points[i].position).distance;
    }
    return total;
  }

  Offset? get centroid {
    if (points.isEmpty) return null;
    var sumX = 0.0;
    var sumY = 0.0;
    for (final point in points) {
      sumX += point.position.dx;
      sumY += point.position.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  Rect? get resolvedBounds {
    if (bounds != null) return bounds;
    if (points.isEmpty) return null;
    var rect = Rect.fromCircle(
      center: points.first.position,
      radius: baseWidth / 2,
    );
    for (final point in points.skip(1)) {
      final pointRect = Rect.fromCircle(
        center: point.position,
        radius: baseWidth / 2,
      );
      rect = rect.expandToInclude(pointRect);
    }
    return rect;
  }

  Map<String, dynamic> toJson() {
    return {
      'stroke_id': id,
      'order': order,
      'start_time': startTime,
      'end_time': endTime,
      'points': points.map((point) => point.toJson()).toList(),
    };
  }

  bool hitTestCircle(Offset center, double radius) {
    final currentBounds = bounds;
    if (currentBounds == null) return false;
    if (!currentBounds.inflate(radius).contains(center)) return false;
    if (points.length == 1) {
      return (points.first.position - center).distance <= radius;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i].position;
      final b = points[i + 1].position;
      if (_distanceToSegment(center, a, b) <= radius) {
        return true;
      }
    }
    return false;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLen2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLen2 == 0) return (p - a).distance;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLen2;
    final clamped = t.clamp(0.0, 1.0);
    final closest = Offset(a.dx + ab.dx * clamped, a.dy + ab.dy * clamped);
    return (p - closest).distance;
  }
}

class _StrokePoint {
  const _StrokePoint(this.position, this.pressure, this.timestamp);

  final Offset position;
  final double pressure;
  final double timestamp;

  Map<String, dynamic> toJson() {
    return {
      'x': position.dx,
      'y': position.dy,
      'pressure': pressure,
      'timestamp': timestamp,
    };
  }
}

class _StrokePainter extends CustomPainter {
  static const double _pressureMinFactor = 0.35;

  _StrokePainter({
    required this.strokes,
    required this.currentStroke,
    required this.eraserPosition,
    required this.eraserRadius,
    required this.scale,
    required this.logicalSize,
    required this.backgroundColor,
    Listenable? repaint,
  }) : super(repaint: repaint);

  final List<_Stroke> strokes;
  final _Stroke? currentStroke;
  final Offset? eraserPosition;
  final double eraserRadius;
  final double scale;
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
    canvas.scale(scale);
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
    return oldDelegate.scale != scale ||
        oldDelegate.logicalSize != logicalSize ||
        oldDelegate.eraserPosition != eraserPosition ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
