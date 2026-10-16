import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_logarithm_power_explorer.dart';

/// Native reader control for the source HTML's base/exponent exploration.
/// It uses bounded numeric data and manual steps; it runs no author script.
class BookLogarithmPowerExplorerView extends StatefulWidget {
  const BookLogarithmPowerExplorerView({super.key, required this.explorer});

  final BookLogarithmPowerExplorer explorer;

  @override
  State<BookLogarithmPowerExplorerView> createState() =>
      _BookLogarithmPowerExplorerViewState();
}

class _BookLogarithmPowerExplorerViewState
    extends State<BookLogarithmPowerExplorerView> {
  late double _base;
  late double _exponent;
  int _stage = 0;
  bool _showHint = false;

  BookLogarithmPowerExplorer get explorer => widget.explorer;

  @override
  void initState() {
    super.initState();
    _resetValues();
  }

  void _resetValues() {
    _base = explorer.initialBase;
    _exponent = explorer.initialExponent;
    _stage = 0;
    _showHint = false;
  }

  String _format(double value) {
    if ((value - value.roundToDouble()).abs() < 1e-9) {
      return value.round().toString();
    }
    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final result = math.pow(_base, _exponent).toDouble();
    final baseLabel = _base.toStringAsFixed(1);
    final exponentLabel = _format(_exponent);
    final resultLabel = _format(result);
    final colors = Theme.of(context).colorScheme;
    final divisions =
        ((explorer.maxExponent - explorer.minExponent) / explorer.step).round();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.functions, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '거듭제곱과 로그를 함께 조작',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('현재 관계  $baseLabel^$exponentLabel = $resultLabel'),
            const SizedBox(height: 6),
            Semantics(
              liveRegion: true,
              child: Text('log_$baseLabel($resultLabel) = $exponentLabel'),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 220,
              child: CustomPaint(
                key: const ValueKey('log-power-explorer-plot'),
                painter: _PowerCurvePainter(
                  base: _base,
                  exponent: _exponent,
                  result: result,
                  guideStage: _stage,
                  gridColor: colors.outlineVariant,
                  axisColor: colors.onSurfaceVariant,
                  curveColor: colors.primary,
                  pointColor: colors.error,
                ),
              ),
            ),
            DropdownButtonFormField<double>(
              key: const ValueKey('log-power-explorer-base'),
              initialValue: _base,
              decoration: const InputDecoration(labelText: '밑 a'),
              items: [
                for (final base in explorer.bases)
                  DropdownMenuItem(
                    value: base,
                    child: Text(base.toStringAsFixed(1)),
                  ),
              ],
              onChanged: (base) {
                if (base == null) return;
                setState(() {
                  _base = base;
                  _stage = 0;
                });
              },
            ),
            const SizedBox(height: 4),
            Text('지수 x = $exponentLabel'),
            Slider(
              key: const ValueKey('log-power-explorer-exponent'),
              min: explorer.minExponent,
              max: explorer.maxExponent,
              divisions: divisions,
              value: _exponent,
              label: exponentLabel,
              onChanged: (value) => setState(() {
                _exponent = value;
                _stage = 0;
              }),
            ),
            Text(
              _stage == 0
                  ? '시작: 밑과 지수를 정하고 결과를 먼저 예측하세요.'
                  : _stage == 1
                  ? '1단계 · 지수 x=$exponentLabel를 가로축에서 찾습니다.'
                  : _stage == 2
                  ? '2단계 · 곡선 위 점의 높이에서 결과 a^x=$resultLabel를 읽습니다.'
                  : '3단계 · 거꾸로 읽으면 log_$baseLabel($resultLabel)=$exponentLabel입니다.',
              key: const ValueKey('log-power-explorer-stage'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const ValueKey('log-power-explorer-next'),
                  onPressed: _stage >= 3
                      ? null
                      : () => setState(() => _stage++),
                  child: const Text('다음 단계 보기'),
                ),
                OutlinedButton(
                  key: const ValueKey('log-power-explorer-reset'),
                  onPressed: () => setState(_resetValues),
                  child: const Text('처음 값으로'),
                ),
                TextButton.icon(
                  key: const ValueKey('log-power-explorer-hint-toggle'),
                  onPressed: () => setState(() => _showHint = !_showHint),
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(_showHint ? '힌트 숨기기' : '힌트 보기'),
                ),
              ],
            ),
            if (_showHint)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '밑 a=1이면 1^x는 x가 무엇이든 1입니다. 결과만으로 지수 x를 하나로 정할 수 없습니다.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PowerCurvePainter extends CustomPainter {
  const _PowerCurvePainter({
    required this.base,
    required this.exponent,
    required this.result,
    required this.guideStage,
    required this.gridColor,
    required this.axisColor,
    required this.curveColor,
    required this.pointColor,
  });

  final double base, exponent, result;
  final int guideStage;
  final Color gridColor, axisColor, curveColor, pointColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0, right = 12.0, top = 12.0, bottom = 22.0;
    final plotWidth = math.max(1.0, size.width - left - right);
    final plotHeight = math.max(1.0, size.height - top - bottom);
    double px(double x) => left + (x + 2) / 4 * plotWidth;
    double py(double y) => top + (10 - y.clamp(0, 10)) / 10 * plotHeight;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.6;
    for (var tick = -2; tick <= 2; tick++) {
      canvas.drawLine(
        Offset(px(tick.toDouble()), top),
        Offset(px(tick.toDouble()), top + plotHeight),
        gridPaint,
      );
    }
    for (var tick = 0; tick <= 10; tick += 2) {
      canvas.drawLine(
        Offset(left, py(tick.toDouble())),
        Offset(left + plotWidth, py(tick.toDouble())),
        gridPaint,
      );
    }
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(left, py(0)),
      Offset(left + plotWidth, py(0)),
      axisPaint,
    );
    canvas.drawLine(
      Offset(px(0), top),
      Offset(px(0), top + plotHeight),
      axisPaint,
    );

    final curve = Path();
    for (var index = 0; index <= 120; index++) {
      final x = -2 + 4 * index / 120;
      final y = math.pow(base, x).toDouble().clamp(0, 10).toDouble();
      final point = Offset(px(x), py(y));
      if (index == 0) {
        curve.moveTo(point.dx, point.dy);
      } else {
        curve.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = curveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final point = Offset(px(exponent), py(result));
    if (guideStage >= 1) {
      canvas.drawLine(
        Offset(point.dx, py(0)),
        point,
        Paint()
          ..color = pointColor
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke,
      );
    }
    if (guideStage >= 2) {
      canvas.drawLine(
        Offset(px(0), point.dy),
        point,
        Paint()
          ..color = Colors.green.shade700
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.drawCircle(point, 5, Paint()..color = pointColor);
  }

  @override
  bool shouldRepaint(covariant _PowerCurvePainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.exponent != exponent ||
      oldDelegate.result != result ||
      oldDelegate.guideStage != guideStage ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.axisColor != axisColor ||
      oldDelegate.curveColor != curveColor ||
      oldDelegate.pointColor != pointColor;
}
