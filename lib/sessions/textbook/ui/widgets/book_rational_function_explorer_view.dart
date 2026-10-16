import 'package:flutter/material.dart';

import '../../../../shared/data/models/book_rational_function_explorer.dart';

class BookRationalFunctionExplorerView extends StatefulWidget {
  const BookRationalFunctionExplorerView({super.key, required this.explorer});
  final BookRationalFunctionExplorer explorer;

  @override
  State<BookRationalFunctionExplorerView> createState() =>
      _BookRationalFunctionExplorerViewState();
}

class _BookRationalFunctionExplorerViewState
    extends State<BookRationalFunctionExplorerView> {
  BookRationalFunctionExplorer get config => widget.explorer;
  late double a = config.initialA, h = config.initialH, k = config.initialK;
  int stage = 0;
  bool showHint = false;

  void reset() => setState(() {
    a = config.initialA;
    h = config.initialH;
    k = config.initialK;
    stage = 0;
    showHint = false;
  });

  String fmt(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hDivisions = ((config.maxH - config.minH) / config.hStep).round();
    final kDivisions = ((config.maxK - config.minK) / config.kStep).round();
    final equation =
        'y=${fmt(a)}/(x${h < 0 ? '+' : '−'}${fmt(h.abs())})${k < 0 ? '−${fmt(k.abs())}' : '+${fmt(k)}'}';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('유리함수 그래프 탐구', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(equation, key: const ValueKey('rational-explorer-equation')),
            Text(
              '정의역: x ≠ ${fmt(h)} · 수직점근선 x=${fmt(h)} · 수평점근선 y=${fmt(k)}',
              key: const ValueKey('rational-explorer-domain'),
            ),
            SizedBox(
              height: 230,
              child: CustomPaint(
                key: const ValueKey('rational-explorer-plot'),
                painter: _RationalFunctionPainter(
                  a: a,
                  h: h,
                  k: k,
                  stage: stage,
                  grid: colors.outlineVariant,
                  axis: colors.onSurfaceVariant,
                  curve: colors.primary,
                  asymptote: colors.error,
                ),
              ),
            ),
            DropdownButtonFormField<double>(
              key: const ValueKey('rational-explorer-a'),
              initialValue: a,
              decoration: const InputDecoration(labelText: '계수 a (0 제외)'),
              items: [
                for (final value in config.aValues)
                  DropdownMenuItem(value: value, child: Text(fmt(value))),
              ],
              onChanged: (value) => setState(() {
                if (value != null) {
                  a = value;
                  stage = 0;
                }
              }),
            ),
            Text('수직 이동 h = ${fmt(h)}'),
            Slider(
              key: const ValueKey('rational-explorer-h'),
              min: config.minH,
              max: config.maxH,
              divisions: hDivisions,
              value: h,
              label: fmt(h),
              onChanged: (value) => setState(() {
                h = value;
                stage = 0;
              }),
            ),
            Text('수평 점근선 k = ${fmt(k)}'),
            Slider(
              key: const ValueKey('rational-explorer-k'),
              min: config.minK,
              max: config.maxK,
              divisions: kDivisions,
              value: k,
              label: fmt(k),
              onChanged: (value) => setState(() {
                k = value;
                stage = 0;
              }),
            ),
            Text(switch (stage) {
              0 => '먼저 분모가 0이 되는 x를 찾아보세요.',
              1 => '1단계 · 분모가 0인 x=${fmt(h)}는 정의역에서 제외됩니다.',
              2 => '2단계 · 점근선은 x=${fmt(h)}, y=${fmt(k)}입니다.',
              _ => '3단계 · a=${fmt(a)}의 부호가 점근선 주변 두 가지 가지의 방향을 정합니다.',
            }, key: const ValueKey('rational-explorer-stage')),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  key: const ValueKey('rational-explorer-next'),
                  onPressed: stage == 3 ? null : () => setState(() => stage++),
                  child: const Text('이동 단계 보기'),
                ),
                OutlinedButton(
                  key: const ValueKey('rational-explorer-reset'),
                  onPressed: reset,
                  child: const Text('처음 값으로'),
                ),
                TextButton(
                  key: const ValueKey('rational-explorer-hint'),
                  onPressed: () => setState(() => showHint = !showHint),
                  child: Text(showHint ? '힌트 숨기기' : '힌트 보기'),
                ),
              ],
            ),
            if (showHint)
              const Text('y=a/(x−h)+k에서 분모가 0인 x=h와 그래프가 가까워지는 y=k를 각각 확인합니다.'),
          ],
        ),
      ),
    );
  }
}

class _RationalFunctionPainter extends CustomPainter {
  const _RationalFunctionPainter({
    required this.a,
    required this.h,
    required this.k,
    required this.stage,
    required this.grid,
    required this.axis,
    required this.curve,
    required this.asymptote,
  });
  final double a, h, k;
  final int stage;
  final Color grid, axis, curve, asymptote;

  @override
  void paint(Canvas canvas, Size size) {
    const xMin = -5.0, xMax = 5.0, yMin = -8.0, yMax = 8.0;
    final px = (double x) => (x - xMin) / (xMax - xMin) * size.width;
    final py = (double y) =>
        size.height - (y - yMin) / (yMax - yMin) * size.height;
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: .45)
      ..strokeWidth = 1;
    for (var x = -4; x <= 4; x++) {
      canvas.drawLine(
        Offset(px(x.toDouble()), 0),
        Offset(px(x.toDouble()), size.height),
        gridPaint,
      );
    }
    for (var y = -7; y <= 7; y++) {
      canvas.drawLine(
        Offset(0, py(y.toDouble())),
        Offset(size.width, py(y.toDouble())),
        gridPaint,
      );
    }
    final axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(px(0), 0), Offset(px(0), size.height), axisPaint);
    canvas.drawLine(Offset(0, py(0)), Offset(size.width, py(0)), axisPaint);
    final curvePaint = Paint()
      ..color = curve
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;
    for (final interval in <(double, double)>[
      (xMin, h - .04),
      (h + .04, xMax),
    ]) {
      final path = Path();
      var drawing = false;
      for (var i = 0; i <= 240; i++) {
        final x = interval.$1 + (interval.$2 - interval.$1) * i / 240;
        final y = a / (x - h) + k;
        if (!y.isFinite || y < yMin || y > yMax) {
          drawing = false;
          continue;
        }
        final point = Offset(px(x), py(y));
        if (!drawing) {
          path.moveTo(point.dx, point.dy);
          drawing = true;
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, curvePaint);
    }
    if (stage >= 1) {
      final asymptotePaint = Paint()
        ..color = asymptote
        ..strokeWidth = 1.5;
      if (h >= xMin && h <= xMax)
        canvas.drawLine(
          Offset(px(h), 0),
          Offset(px(h), size.height),
          asymptotePaint,
        );
      if (k >= yMin && k <= yMax)
        canvas.drawLine(
          Offset(0, py(k)),
          Offset(size.width, py(k)),
          asymptotePaint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _RationalFunctionPainter old) =>
      old.a != a ||
      old.h != h ||
      old.k != k ||
      old.stage != stage ||
      old.grid != grid ||
      old.axis != axis ||
      old.curve != curve ||
      old.asymptote != asymptote;
}
