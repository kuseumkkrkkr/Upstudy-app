import 'dart:math';
import 'package:flutter/material.dart';
import 'base_graph_painter.dart';
import 'graph_card_shell.dart';

/// Interactive graph for logarithmic function y = a · log_b(x - h) + k
class InteractiveLogarithmicGraph extends StatefulWidget {
  const InteractiveLogarithmicGraph({super.key});

  @override
  State<InteractiveLogarithmicGraph> createState() => _InteractiveLogarithmicGraphState();
}

class _InteractiveLogarithmicGraphState extends State<InteractiveLogarithmicGraph> {
  double _a = 1.0;
  double _b = 2.0;
  double _h = 0.0;
  double _k = 0.0;

  static const double _xMin = -2;
  static const double _xMax = 8;

  double get _yMin => _k - 5;
  double get _yMax => _k + 5;

  @override
  Widget build(BuildContext context) {
    return GraphCard(
      title: r'y = a \cdot \log_b(x-h) + k',
      formula: 'y = ${_fmt(_a)} \\cdot \\log_{${_fmt(_b)}}(x${_op(_h)}) ${_op2(_k)}',
      painter: _LogarithmicGraphPainter(
        a: _a,
        b: _b,
        h: _h,
        k: _k,
        xMin: _xMin,
        xMax: _xMax,
        yMin: _yMin,
        yMax: _yMax,
      ),
      sliders: [
        SliderDef(
          label: 'a (계수)',
          value: _a,
          min: -3,
          max: 3,
          divisions: 60,
          onChanged: (v) => setState(() => _a = v),
        ),
        SliderDef(
          label: 'b (밑, b > 0)',
          value: _b,
          min: 0.5,
          max: 5,
          divisions: 45,
          onChanged: (v) => setState(() => _b = v == 1 ? 1.1 : v),
        ),
        SliderDef(
          label: 'h (좌우 이동, 수직 점근선)',
          value: _h,
          min: -2,
          max: 4,
          divisions: 60,
          onChanged: (v) => setState(() => _h = v),
        ),
        SliderDef(
          label: 'k (상하 이동)',
          value: _k,
          min: -3,
          max: 3,
          divisions: 60,
          onChanged: (v) => setState(() => _k = v),
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

  String _op(double v) {
    if (v == 0) return '';
    if (v > 0) return '-${_fmt(v)}';
    return '+${_fmt(-v)}';
  }

  String _op2(double v) {
    if (v == 0) return '';
    if (v > 0) return '+ ${_fmt(v)}';
    return '- ${_fmt(-v)}';
  }
}

class _LogarithmicGraphPainter extends BaseGraphPainter {
  final double a;
  final double b;
  final double h;
  final double k;

  _LogarithmicGraphPainter({
    required this.a,
    required this.b,
    required this.h,
    required this.k,
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
      if (x <= h || b <= 0 || b == 1) continue;
      final y = a * (log(x - h) / log(b)) + k;
      if (y.isNaN || y.isInfinite) continue;
      if (y < yMin - 20 || y > yMax + 20) {
        first = true;
        continue;
      }
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

  @override
  void paintAnnotations(Canvas canvas, Size size, double Function(double x) worldToPixelX, double Function(double y) worldToPixelY) {
    // Vertical asymptote x = h
    final asymptotePaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final px = worldToPixelX(h);
    canvas.drawLine(
      Offset(px, worldToPixelY(yMin)),
      Offset(px, worldToPixelY(yMax)),
      asymptotePaint,
    );
  }
}
