import 'package:flutter/material.dart';
import 'base_graph_painter.dart';
import 'graph_card_shell.dart';

/// Interactive graph for simple rational function y = a/(x - h) + k
class InteractiveRationalGraph extends StatefulWidget {
  const InteractiveRationalGraph({super.key});

  @override
  State<InteractiveRationalGraph> createState() => _InteractiveRationalGraphState();
}

class _InteractiveRationalGraphState extends State<InteractiveRationalGraph> {
  double _a = 1.0;
  double _h = 0.0;
  double _k = 0.0;

  static const double _xMin = -6;
  static const double _xMax = 6;

  double get _yMin => _k - 6;
  double get _yMax => _k + 6;

  @override
  Widget build(BuildContext context) {
    return GraphCard(
      title: r'y = \dfrac{a}{x-h} + k',
      formula: 'y = \\dfrac{${_fmt(_a)}}{x${_op(_h)}} ${_op2(_k)}',
      painter: _RationalGraphPainter(
        a: _a,
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
          min: -5,
          max: 5,
          divisions: 100,
          onChanged: (v) => setState(() => _a = v),
        ),
        SliderDef(
          label: 'h (수직 점근선)',
          value: _h,
          min: -3,
          max: 3,
          divisions: 60,
          onChanged: (v) => setState(() => _h = v),
        ),
        SliderDef(
          label: 'k (수평 점근선)',
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

class _RationalGraphPainter extends BaseGraphPainter {
  final double a;
  final double h;
  final double k;

  _RationalGraphPainter({
    required this.a,
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

    final dx = (xMax - xMin) / sampleCount;
    const gap = 0.08;

    // Left branch (x < h)
    {
      final path = Path();
      bool first = true;
      for (int i = 0; i <= sampleCount; i++) {
        final x = xMin + i * dx;
        if (x >= h - gap) continue;
        final y = a / (x - h) + k;
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

    // Right branch (x > h)
    {
      final path = Path();
      bool first = true;
      for (int i = 0; i <= sampleCount; i++) {
        final x = xMin + i * dx;
        if (x <= h + gap) continue;
        final y = a / (x - h) + k;
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
  }

  @override
  void paintAnnotations(Canvas canvas, Size size, double Function(double x) worldToPixelX, double Function(double y) worldToPixelY) {
    final asymptotePaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Vertical asymptote x = h
    final px = worldToPixelX(h);
    canvas.drawLine(
      Offset(px, worldToPixelY(yMin)),
      Offset(px, worldToPixelY(yMax)),
      asymptotePaint,
    );

    // Horizontal asymptote y = k
    final py = worldToPixelY(k);
    canvas.drawLine(
      Offset(worldToPixelX(xMin), py),
      Offset(worldToPixelX(xMax), py),
      asymptotePaint,
    );
  }
}
