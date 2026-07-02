import 'package:flutter/material.dart';
import 'base_graph_painter.dart';
import 'graph_card_shell.dart';

/// Interactive graph showing a function and its tangent line to visualize derivatives.
/// Uses f(x) = x² as the base function.
class InteractiveDerivativeGraph extends StatefulWidget {
  const InteractiveDerivativeGraph({super.key});

  @override
  State<InteractiveDerivativeGraph> createState() => _InteractiveDerivativeGraphState();
}

class _InteractiveDerivativeGraphState extends State<InteractiveDerivativeGraph> {
  double _x0 = 1.0;   // point of tangency

  static const double _xMin = -4;
  static const double _xMax = 4;
  static const double _yMin = -2;
  static const double _yMax = 10;

  double _f(double x) => x * x;
  double _df(double x) => 2 * x; // derivative of x²

  @override
  Widget build(BuildContext context) {
    final y0 = _f(_x0);
    final slope = _df(_x0);
    return GraphCard(
      title: r'f(x) = x^2',
      formula: 'x_0 = ${_fmt(_x0)},\\; f(x_0) = ${_fmt(y0)},\\; f\'(x_0) = ${_fmt(slope)}',
      painter: _DerivativeGraphPainter(
        x0: _x0,
        xMin: _xMin,
        xMax: _xMax,
        yMin: _yMin,
        yMax: _yMax,
      ),
      sliders: [
        SliderDef(
          label: r'$x_0$ (접점 위치)',
          value: _x0,
          min: -3,
          max: 3,
          divisions: 60,
          onChanged: (v) => setState(() => _x0 = v),
        ),
      ],
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    if (s.endsWith('.00')) return s.substring(0, s.length - 3);
    if (s.endsWith('0')) return s.substring(0, s.length - 1);
    return s;
  }
}

class _DerivativeGraphPainter extends BaseGraphPainter {
  final double x0;

  _DerivativeGraphPainter({
    required this.x0,
    required super.xMin,
    required super.xMax,
    required super.yMin,
    required super.yMax,
  });

  double _f(double x) => x * x;
  double _df(double x) => 2 * x;

  @override
  void paintCurve(Canvas canvas, Size size, double Function(double x) worldToPixelX, double Function(double y) worldToPixelY) {
    // Parabola
    final curvePaint = Paint()
      ..color = const Color(0xFF1B402B)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    bool first = true;
    final dx = (xMax - xMin) / sampleCount;

    for (int i = 0; i <= sampleCount; i++) {
      final x = xMin + i * dx;
      final y = _f(x);
      if (y.isNaN || y.isInfinite) continue;
      final px = worldToPixelX(x);
      final py = worldToPixelY(y);
      if (first) {
        path.moveTo(px, py);
        first = false;
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, curvePaint);

    // Tangent line: y = f'(x0)(x - x0) + f(x0)
    final tangentPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.85)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final slope = _df(x0);
    final y0 = _f(x0);

    final xLeft = xMin;
    final yLeft = slope * (xLeft - x0) + y0;
    final xRight = xMax;
    final yRight = slope * (xRight - x0) + y0;

    canvas.drawLine(
      Offset(worldToPixelX(xLeft), worldToPixelY(yLeft)),
      Offset(worldToPixelX(xRight), worldToPixelY(yRight)),
      tangentPaint,
    );
  }

  @override
  void paintAnnotations(Canvas canvas, Size size, double Function(double x) worldToPixelX, double Function(double y) worldToPixelY) {
    // Point of tangency
    final dotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final px = worldToPixelX(x0);
    final py = worldToPixelY(_f(x0));
    canvas.drawCircle(Offset(px, py), 6, dotPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(px, py), 6, borderPaint);
  }
}
