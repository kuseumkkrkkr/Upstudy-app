import 'dart:math';
import 'package:flutter/material.dart';

/// Base graph painter with axes, grid, labels, and border.
/// Subclasses only need to implement [paintCurve].
abstract class BaseGraphPainter extends CustomPainter {
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final int sampleCount;

  const BaseGraphPainter({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    this.sampleCount = 600,
  });

  /// Override to paint the specific curve.
  void paintCurve(Canvas canvas, Size size, double Function(double x) worldToPixelX, double Function(double y) worldToPixelY);

  /// Override to paint annotations (asymptotes, vertex dots, etc.).
  void paintAnnotations(Canvas canvas, Size size, double Function(double x) worldToPixelX, double Function(double y) worldToPixelY) {}

  @override
  bool shouldRepaint(covariant BaseGraphPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    const padding = EdgeInsets.only(left: 44, right: 12, top: 16, bottom: 28);
    final plotWidth = width - padding.left - padding.right;
    final plotHeight = height - padding.top - padding.bottom;

    double worldToPixelX(double x) => padding.left + (x - xMin) / (xMax - xMin) * plotWidth;
    double worldToPixelY(double y) => padding.top + (1 - (y - yMin) / (yMax - yMin)) * plotHeight;

    // Background
    final bgPaint = Paint()..color = const Color(0xFFF9F9F9);
    canvas.drawRect(
      Rect.fromLTWH(padding.left, padding.top, plotWidth, plotHeight),
      bgPaint,
    );

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.8;

    // Vertical grid
    final xStep = _niceStep(xMax - xMin);
    for (double x = (xMin / xStep).floor() * xStep; x <= xMax; x += xStep) {
      final px = worldToPixelX(x);
      if (px < padding.left || px > padding.left + plotWidth) continue;
      canvas.drawLine(Offset(px, padding.top), Offset(px, padding.top + plotHeight), gridPaint);
    }

    // Horizontal grid
    final yStep = _niceStep(yMax - yMin);
    for (double y = (yMin / yStep).ceil() * yStep; y <= yMax; y += yStep) {
      final py = worldToPixelY(y);
      if (py < padding.top || py > padding.top + plotHeight) continue;
      canvas.drawLine(Offset(padding.left, py), Offset(padding.left + plotWidth, py), gridPaint);
    }

    // Axes
    final axisPaint = Paint()
      ..color = const Color(0xFF444444)
      ..strokeWidth = 1.4;

    final py0 = worldToPixelY(0).clamp(padding.top, padding.top + plotHeight);
    canvas.drawLine(Offset(padding.left, py0), Offset(padding.left + plotWidth, py0), axisPaint);

    final px0 = worldToPixelX(0).clamp(padding.left, padding.left + plotWidth);
    canvas.drawLine(Offset(px0, padding.top), Offset(px0, padding.top + plotHeight), axisPaint);

    // Curve
    paintCurve(canvas, size, worldToPixelX, worldToPixelY);

    // Annotations
    paintAnnotations(canvas, size, worldToPixelX, worldToPixelY);

    // Labels
    final labelStyle = const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.w500);
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);

    // X labels
    for (double x = (xMin / xStep).floor() * xStep; x <= xMax; x += xStep) {
      final px = worldToPixelX(x);
      if (px < padding.left - 4 || px > padding.left + plotWidth + 4) continue;
      final text = _formatLabel(x);
      labelPainter.text = TextSpan(text: text, style: labelStyle);
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(px - labelPainter.width / 2, padding.top + plotHeight + 4));
    }

    // Y labels
    for (double y = (yMin / yStep).ceil() * yStep; y <= yMax; y += yStep) {
      final py = worldToPixelY(y);
      if (py < padding.top - 8 || py > padding.top + plotHeight + 8) continue;
      final text = y.toStringAsFixed(y.abs() == y.abs().roundToDouble() ? 0 : 1);
      labelPainter.text = TextSpan(text: text, style: labelStyle);
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(padding.left - labelPainter.width - 4, py - labelPainter.height / 2));
    }

    // Border
    final borderPaint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(padding.left, padding.top, plotWidth, plotHeight), borderPaint);
  }

  String _formatLabel(double x) {
    final piMult = x / pi;
    if (piMult == 0) return '0';
    if (piMult == 1) return 'π';
    if (piMult == -1) return '-π';
    if (piMult == 2) return '2π';
    if (piMult == -2) return '-2π';
    if (piMult == 0.5) return 'π/2';
    if (piMult == -0.5) return '-π/2';
    if (piMult == 1.5) return '3π/2';
    if (piMult == -1.5) return '-3π/2';
    if (x == x.roundToDouble()) return x.toInt().toString();
    return x.toStringAsFixed(1);
  }

  double _niceStep(double range) {
    if (range <= 0) return 1;
    final rough = range / 5;
    final pow10 = pow(10, (log(rough) / ln10).floor()).toDouble();
    final norm = rough / pow10;
    if (norm <= 1) return pow10;
    if (norm <= 2) return 2 * pow10;
    if (norm <= 5) return 5 * pow10;
    return 10 * pow10;
  }
}
