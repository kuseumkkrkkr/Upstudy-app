import 'dart:math';
import 'package:flutter/material.dart';
import 'base_graph_painter.dart';
import 'graph_card_shell.dart';
import '../../theme/app_colors.dart';

/// Interactive graph for trigonometric function y = A쨌cos(Bx + C) + D
class InteractiveTrigonometricGraph extends StatefulWidget {
  const InteractiveTrigonometricGraph({super.key});

  @override
  State<InteractiveTrigonometricGraph> createState() => _InteractiveTrigonometricGraphState();
}

class _InteractiveTrigonometricGraphState extends State<InteractiveTrigonometricGraph> {
  double _a = 1.0;   // amplitude
  double _b = 1.0;   // frequency
  double _c = 0.0;   // phase shift
  double _d = 0.0;   // vertical shift

  static const double _xMin = -2 * pi;
  static const double _xMax = 2 * pi;

  double get _yMin => -_a.abs() - 1 + _d;
  double get _yMax => _a.abs() + 1 + _d;

  @override
  Widget build(BuildContext context) {
    return GraphCard(
      title: r'y = A \cos(Bx + C) + D',
      formula: 'y = ${_fmt(_a)} \\cos(${_fmt(_b)}x + ${_fmt(_c)}) ${_op2(_d)}',
      painter: _TrigonometricGraphPainter(
        a: _a,
        b: _b,
        c: _c,
        d: _d,
        xMin: _xMin,
        xMax: _xMax,
        yMin: _yMin,
        yMax: _yMax,
      ),
      sliders: [
        SliderDef(
          label: 'A (吏꾪룺)',
          value: _a,
          min: -3,
          max: 3,
          divisions: 60,
          onChanged: (v) => setState(() => _a = v),
        ),
        SliderDef(
          label: 'B (二쇨린 怨꾩닔)',
          value: _b,
          min: 0.1,
          max: 3,
          divisions: 29,
          onChanged: (v) => setState(() => _b = v),
        ),
        SliderDef(
          label: 'C (?꾩긽 ?대룞)',
          value: _c,
          min: -pi,
          max: pi,
          divisions: 60,
          onChanged: (v) => setState(() => _c = v),
        ),
        SliderDef(
          label: 'D (?섏쭅 ?대룞)',
          value: _d,
          min: -3,
          max: 3,
          divisions: 60,
          onChanged: (v) => setState(() => _d = v),
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

  String _op2(double v) {
    if (v == 0) return '';
    if (v > 0) return '+ ${_fmt(v)}';
    return '- ${_fmt(-v)}';
  }
}

class _TrigonometricGraphPainter extends BaseGraphPainter {
  final double a;
  final double b;
  final double c;
  final double d;

  _TrigonometricGraphPainter({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required super.xMin,
    required super.xMax,
    required super.yMin,
    required super.yMax,
  });

  @override
  void paintCurve(Canvas canvas, Size size, double Function(double x) worldToPixelX, double Function(double y) worldToPixelY) {
    final curvePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    bool first = true;
    final dx = (xMax - xMin) / sampleCount;

    for (int i = 0; i <= sampleCount; i++) {
      final x = xMin + i * dx;
      final y = a * cos(b * x + c) + d;
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

