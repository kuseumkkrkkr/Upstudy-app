import 'package:flutter/material.dart';
import 'base_graph_painter.dart';
import 'graph_card_shell.dart';

/// Interactive graph for quadratic function y = ax² + bx + c
class InteractiveQuadraticGraph extends StatefulWidget {
  const InteractiveQuadraticGraph({super.key});

  @override
  State<InteractiveQuadraticGraph> createState() => _InteractiveQuadraticGraphState();
}

class _InteractiveQuadraticGraphState extends State<InteractiveQuadraticGraph> {
  double _a = 1.0;
  double _b = 0.0;
  double _c = 0.0;

  static const double _xMin = -5;
  static const double _xMax = 5;

  double get _vertexX => -_b / (2 * _a);
  double get _vertexY => _a * _vertexX * _vertexX + _b * _vertexX + _c;

  double get _yMin {
    if (_a == 0) return -5;
    return _a > 0 ? _vertexY - 5 : _vertexY - 10;
  }

  double get _yMax {
    if (_a == 0) return 5;
    return _a > 0 ? _vertexY + 10 : _vertexY + 5;
  }

  @override
  Widget build(BuildContext context) {
    return GraphCard(
      title: r'y = ax^2 + bx + c',
      formula: 'y = ${_fmt(_a)}x^2 + ${_fmt(_b)}x + ${_fmt(_c)}',
      painter: _QuadraticGraphPainter(
        a: _a,
        b: _b,
        c: _c,
        xMin: _xMin,
        xMax: _xMax,
        yMin: _yMin,
        yMax: _yMax,
      ),
      sliders: [
        SliderDef(
          label: 'a (이차 계수)',
          value: _a,
          min: -3,
          max: 3,
          divisions: 60,
          onChanged: (v) => setState(() => _a = v),
        ),
        SliderDef(
          label: 'b (일차 계수)',
          value: _b,
          min: -5,
          max: 5,
          divisions: 100,
          onChanged: (v) => setState(() => _b = v),
        ),
        SliderDef(
          label: 'c (상수항)',
          value: _c,
          min: -5,
          max: 5,
          divisions: 100,
          onChanged: (v) => setState(() => _c = v),
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

class _QuadraticGraphPainter extends BaseGraphPainter {
  final double a;
  final double b;
  final double c;

  _QuadraticGraphPainter({
    required this.a,
    required this.b,
    required this.c,
    required super.xMin,
    required super.xMax,
    required super.yMin,
    required super.yMax,
  });

  @override
  void paintCurve(Canvas canvas, Size size, double Function(double x) worldToPixelX, double Function(double y) worldToPixelY) {
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
      final y = a * x * x + b * x + c;
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
  }
}
