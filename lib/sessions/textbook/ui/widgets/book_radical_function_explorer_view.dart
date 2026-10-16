import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../shared/data/models/book_radical_function_explorer.dart';

class BookRadicalFunctionExplorerView extends StatefulWidget {
  const BookRadicalFunctionExplorerView({super.key, required this.explorer});
  final BookRadicalFunctionExplorer explorer;
  @override
  State<BookRadicalFunctionExplorerView> createState() =>
      _BookRadicalFunctionExplorerViewState();
}

class _BookRadicalFunctionExplorerViewState
    extends State<BookRadicalFunctionExplorerView> {
  BookRadicalFunctionExplorer get config => widget.explorer;
  late double a = config.initialA, b = config.initialB, c = config.initialC;
  int stage = 0;
  bool showHint = false;
  String fmt(double x) =>
      x == x.roundToDouble() ? x.toInt().toString() : x.toStringAsFixed(1);
  void reset() => setState(() {
    a = config.initialA;
    b = config.initialB;
    c = config.initialC;
    stage = 0;
    showHint = false;
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final startX = -b / a;
    final bDivisions = ((config.maxB - config.minB) / config.bStep).round();
    final cDivisions = ((config.maxC - config.minC) / config.cStep).round();
    final bTerm = b < 0 ? '−${fmt(b.abs())}' : '+${fmt(b)}';
    final aTerm = a < 0 ? '−${fmt(a.abs())}' : fmt(a);
    final equation =
        'y=√(${aTerm}x$bTerm)${c < 0 ? '−${fmt(c.abs())}' : '+${fmt(c)}'}';
    final domain = a > 0
        ? '정의역: x ≥ ${fmt(startX)}'
        : '정의역: x ≤ ${fmt(startX)}';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('무리함수 그래프 탐구', style: Theme.of(context).textTheme.titleSmall),
            Text(equation, key: const ValueKey('radical-explorer-equation')),
            Text(
              '$domain · 시작점 (${fmt(startX)}, ${fmt(c)}) · 치역: y ≥ ${fmt(c)}',
              key: const ValueKey('radical-explorer-domain'),
            ),
            SizedBox(
              height: 230,
              child: CustomPaint(
                key: const ValueKey('radical-explorer-plot'),
                painter: _RadicalFunctionPainter(
                  a: a,
                  b: b,
                  c: c,
                  stage: stage,
                  grid: colors.outlineVariant,
                  axis: colors.onSurfaceVariant,
                  curve: colors.primary,
                  point: colors.error,
                ),
              ),
            ),
            DropdownButtonFormField<double>(
              key: const ValueKey('radical-explorer-a'),
              initialValue: a,
              decoration: const InputDecoration(labelText: '계수 a (0 제외)'),
              items: [
                for (final v in config.aValues)
                  DropdownMenuItem(value: v, child: Text(fmt(v))),
              ],
              onChanged: (v) => setState(() {
                if (v != null) {
                  a = v;
                  stage = 0;
                }
              }),
            ),
            Text('제곱근 안의 상수 b = ${fmt(b)}'),
            Slider(
              key: const ValueKey('radical-explorer-b'),
              min: config.minB,
              max: config.maxB,
              divisions: bDivisions,
              value: b,
              label: fmt(b),
              onChanged: (v) => setState(() {
                b = v;
                stage = 0;
              }),
            ),
            Text('수직 이동 c = ${fmt(c)}'),
            Slider(
              key: const ValueKey('radical-explorer-c'),
              min: config.minC,
              max: config.maxC,
              divisions: cDivisions,
              value: c,
              label: fmt(c),
              onChanged: (v) => setState(() {
                c = v;
                stage = 0;
              }),
            ),
            Text(switch (stage) {
              0 => '먼저 제곱근 안이 0이 되는 x를 찾아보세요.',
              1 =>
                '1단계 · ax+b≥0을 풀어 정의역을 정합니다: ${a > 0 ? 'x≥' : 'x≤'}${fmt(startX)}.',
              2 => '2단계 · 그래프는 (${fmt(startX)}, ${fmt(c)})에서 시작합니다.',
              _ => '3단계 · √값은 0 이상이므로 치역은 y≥${fmt(c)}입니다.',
            }, key: const ValueKey('radical-explorer-stage')),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  key: const ValueKey('radical-explorer-next'),
                  onPressed: stage == 3 ? null : () => setState(() => stage++),
                  child: const Text('다음 단계 보기'),
                ),
                OutlinedButton(
                  key: const ValueKey('radical-explorer-reset'),
                  onPressed: reset,
                  child: const Text('처음 값으로'),
                ),
                TextButton(
                  key: const ValueKey('radical-explorer-hint'),
                  onPressed: () => setState(() => showHint = !showHint),
                  child: Text(showHint ? '힌트 숨기기' : '힌트 보기'),
                ),
              ],
            ),
            if (showHint)
              const Text(
                '제곱근 안을 0 이상으로 놓아 정의역을 찾고, √값의 최솟값 0을 이용해 시작점과 치역을 읽습니다.',
              ),
          ],
        ),
      ),
    );
  }
}

class _RadicalFunctionPainter extends CustomPainter {
  const _RadicalFunctionPainter({
    required this.a,
    required this.b,
    required this.c,
    required this.stage,
    required this.grid,
    required this.axis,
    required this.curve,
    required this.point,
  });
  final double a, b, c;
  final int stage;
  final Color grid, axis, curve, point;
  @override
  void paint(Canvas canvas, Size size) {
    const xmin = -5.0, xmax = 5.0, ymin = -8.0, ymax = 8.0;
    double px(double x) => (x - xmin) / (xmax - xmin) * size.width;
    double py(double y) =>
        size.height - (y - ymin) / (ymax - ymin) * size.height;
    final gp = Paint()
      ..color = grid.withValues(alpha: .45)
      ..strokeWidth = 1;
    for (var x = -4; x <= 4; x++)
      canvas.drawLine(
        Offset(px(x.toDouble()), 0),
        Offset(px(x.toDouble()), size.height),
        gp,
      );
    for (var y = -7; y <= 7; y++)
      canvas.drawLine(
        Offset(0, py(y.toDouble())),
        Offset(size.width, py(y.toDouble())),
        gp,
      );
    final ap = Paint()
      ..color = axis
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(px(0), 0), Offset(px(0), size.height), ap);
    canvas.drawLine(Offset(0, py(0)), Offset(size.width, py(0)), ap);
    final path = Path();
    var drawing = false;
    for (var i = 0; i <= 300; i++) {
      final x = xmin + (xmax - xmin) * i / 300, radicand = a * x + b;
      if (radicand < 0) {
        drawing = false;
        continue;
      }
      final y = math.sqrt(radicand) + c;
      if (y < ymin || y > ymax) {
        drawing = false;
        continue;
      }
      final p = Offset(px(x), py(y));
      if (!drawing) {
        path.moveTo(p.dx, p.dy);
        drawing = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = curve
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke,
    );
    if (stage >= 2) {
      final sx = -b / a;
      if (sx >= xmin && sx <= xmax && c >= ymin && c <= ymax) {
        canvas.drawCircle(Offset(px(sx), py(c)), 5, Paint()..color = point);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadicalFunctionPainter old) =>
      old.a != a ||
      old.b != b ||
      old.c != c ||
      old.stage != stage ||
      old.grid != grid ||
      old.axis != axis ||
      old.curve != curve ||
      old.point != point;
}
