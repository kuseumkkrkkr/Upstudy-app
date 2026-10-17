import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/book_function_explorer.dart';
import 'book_activity_view.dart';

/// Manual fixed-formula exploration; local reader session only, no AI/OVR writes.
class BookFunctionExplorerView extends StatefulWidget {
  const BookFunctionExplorerView({super.key, required this.activity});
  final BookActivity activity;
  @override
  State<BookFunctionExplorerView> createState() => _ExplorerState();
}

class _ExplorerState extends State<BookFunctionExplorerView> {
  BookFunctionExplorer get config => widget.activity.functionExplorer!;
  late double coefficient, u, v;
  int stage = 0;
  bool hint = false, restored = false;
  void reset() {
    coefficient = config.initialCoefficient;
    u = config.initialU;
    v = config.initialV;
    stage = 0;
    hint = false;
  }

  @override
  void initState() {
    super.initState();
    reset();
  }

  @override
  void didUpdateWidget(covariant BookFunctionExplorerView old) {
    super.didUpdateWidget(old);
    if (jsonEncode(old.activity.toJson()) !=
        jsonEncode(widget.activity.toJson())) {
      reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (restored) return;
    restored = true;
    final saved = BookActivityKeyScope.read(context, widget.activity);
    if (saved != null) {
      coefficient = saved['coefficient'] as double;
      u = saved['u'] as double;
      v = saved['v'] as double;
      stage = saved['stage'] as int;
      hint = saved['hint'] as bool;
    }
  }

  String fmt(double n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    final text = n.toStringAsPrecision(6);
    return text.contains('e')
        ? text
        : text
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
  }

  String signed(double n) => n < 0 ? '−${fmt(-n)}' : '+${fmt(n)}';
  @override
  Widget build(BuildContext context) {
    BookActivityKeyScope.save(context, widget.activity, {
      'coefficient': coefficient,
      'u': u,
      'v': v,
      'stage': stage,
      'hint': hint,
    });
    final power = config.isPower;
    final radical = config.kind == BookFunctionKind.radical;
    final start = -u / coefficient;
    final result = power ? config.valueAt(u, coefficient, u, v)! : 0.0;
    final equation = power
        ? '${fmt(coefficient)}^${fmt(u)} ≈ ${fmt(result)}'
        : radical
        ? 'y=√(${fmt(coefficient)}x${signed(u)})${signed(v)}'
        : 'y=${fmt(coefficient)}/(x${signed(-u)})${signed(v)}';
    final detail = power
        ? 'log_${fmt(coefficient)}(${fmt(result)}) ≈ ${fmt(u)}'
        : radical
        ? '정의역: ${fmt(coefficient)}x${signed(u)} ≥ 0 · 치역: y ≥ ${fmt(v)} · 시작점 x=−b/a ≈ ${fmt(start)}'
        : '정의역: x ≠ ${fmt(u)} · 수직점근선 x=${fmt(u)} · 수평점근선 y=${fmt(v)}';
    final guides = power
        ? [
            '밑과 지수를 정하고 결과를 먼저 예측하세요.',
            '1단계 · 지수 x=${fmt(u)}를 가로축에서 찾습니다.',
            '2단계 · 곡선 위 점의 높이에서 a^x ≈ ${fmt(result)}를 읽습니다.',
            '3단계 · 거꾸로 읽으면 log_${fmt(coefficient)}(${fmt(result)}) ≈ ${fmt(u)}입니다.',
          ]
        : radical
        ? [
            '먼저 제곱근 안이 0이 되는 x를 찾아보세요.',
            '1단계 · ${fmt(coefficient)}x${signed(u)} ≥ 0을 풀어 정의역을 정합니다.',
            '2단계 · 그래프는 (−b/a, c)에서 시작합니다.',
            '3단계 · 제곱근 값은 0 이상이므로 치역은 y ≥ ${fmt(v)}입니다.',
          ]
        : [
            '먼저 분모가 0이 되는 x를 찾아보세요.',
            '1단계 · 분모가 0인 x=${fmt(u)}는 정의역에서 제외됩니다.',
            '2단계 · 점근선은 x=${fmt(u)}, y=${fmt(v)}입니다.',
            '3단계 · a=${fmt(coefficient)}의 부호가 두 가지의 방향을 정합니다.',
          ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffd4d4d8)),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 16, height: 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.activity.prompt,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Semantics(
              liveRegion: true,
              child: Text(equation, key: const ValueKey('explorer-equation')),
            ),
            Text(detail, key: const ValueKey('explorer-detail')),
            Semantics(
              label: '함수 그래프. $equation. $detail',
              image: true,
              child: SizedBox(
                height: 230,
                child: CustomPaint(
                  key: const ValueKey('function-explorer-plot'),
                  painter: _FunctionPainter(
                    config,
                    coefficient,
                    u,
                    v,
                    stage,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            DropdownButtonFormField<double>(
              key: ValueKey(
                '${jsonEncode(widget.activity.toJson())}:$coefficient',
              ),
              initialValue: coefficient,
              decoration: InputDecoration(
                labelText: power ? '밑 a' : '계수 a (0 제외)',
              ),
              items: [
                for (final value in config.values)
                  DropdownMenuItem(value: value, child: Text(fmt(value))),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    coefficient = value;
                    stage = 0;
                  });
                }
              },
            ),
            Text(
              '${power
                  ? '지수 x'
                  : radical
                  ? '제곱근 안의 상수 b'
                  : '수평 이동 h'} = ${fmt(u)}',
            ),
            Slider(
              key: const ValueKey('explorer-u'),
              label: fmt(u),
              semanticFormatterCallback: (value) =>
                  '${config.uName} ${fmt(value)}',
              value: u,
              min: config.minU,
              max: config.maxU,
              divisions: ((config.maxU - config.minU) / config.stepU).round(),
              onChanged: (value) => setState(() {
                u = value;
                stage = 0;
              }),
            ),
            if (!power) ...[
              Text('${radical ? '수직 이동 c' : '수평 점근선 k'} = ${fmt(v)}'),
              Slider(
                key: const ValueKey('explorer-v'),
                label: fmt(v),
                semanticFormatterCallback: (value) =>
                    '${config.vName} ${fmt(value)}',
                value: v,
                min: config.minV,
                max: config.maxV,
                divisions: ((config.maxV - config.minV) / config.stepV).round(),
                onChanged: (value) => setState(() {
                  v = value;
                  stage = 0;
                }),
              ),
            ],
            Text(guides[stage], key: const ValueKey('explorer-stage')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: stage == 3 ? null : () => setState(() => stage++),
                  child: const Text('다음 단계 보기'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => setState(reset),
                  child: const Text('처음 값으로'),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => setState(() => hint = !hint),
                  child: Text(hint ? '힌트 숨기기' : '힌트 보기'),
                ),
              ],
            ),
            if (hint) ...[
              if (widget.activity.hints.isNotEmpty)
                for (final text in widget.activity.hints) Text(text)
              else
                Text(
                  power
                      ? '밑이 1이면 결과만으로 지수를 하나로 정할 수 없습니다.'
                      : radical
                      ? '제곱근 안은 0 이상이고, 제곱근 값의 최솟값은 0입니다.'
                      : '분모가 0인 x=h와 그래프가 가까워지는 y=k를 확인하세요.',
                ),
            ],
            const Text(
              '교재 체험 · 시험 점수·등급에 반영되지 않아요.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _FunctionPainter extends CustomPainter {
  const _FunctionPainter(
    this.config,
    this.a,
    this.u,
    this.v,
    this.stage,
    this.color,
  );
  final BookFunctionExplorer config;
  final double a, u, v;
  final int stage;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final power = config.isPower,
        radical = config.kind == BookFunctionKind.radical;
    final origin = radical ? -u / a : u;
    final xmin = power ? config.minU : origin - 5;
    final xmax = power ? config.maxU : origin + 5;
    final ymin = power
        ? 0.0
        : radical
        ? v - 1
        : v - 8;
    final ymax = power
        ? math.max(
            10.0,
            math.max(
                  config.valueAt(xmin, a, u, v)!,
                  config.valueAt(xmax, a, u, v)!,
                ) *
                1.1,
          )
        : v + 8;
    const left = 40.0, top = 10.0, bottom = 28.0;
    final width = math.max(1.0, size.width - left - 12),
        height = size.height - top - bottom;
    Offset point(double x, double y) => Offset(
      left + (x - xmin) / (xmax - xmin) * width,
      top + (ymax - y) / (ymax - ymin) * height,
    );
    void label(String text, Offset p) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 11, color: Color(0xff71717a)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p);
    }

    final grid = Paint()
      ..color = const Color(0xffd4d4d8)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final x = xmin + (xmax - xmin) * i / 4, y = ymin + (ymax - ymin) * i / 4;
      canvas.drawLine(point(x, ymin), point(x, ymax), grid);
      canvas.drawLine(point(xmin, y), point(xmax, y), grid);
      label(
        x.toStringAsPrecision(3),
        Offset(point(x, ymin).dx - 10, top + height + 3),
      );
      label(y.toStringAsPrecision(3), Offset(0, point(xmin, y).dy - 6));
    }
    final axis = Paint()
      ..color = const Color(0xff71717a)
      ..strokeWidth = 1.4;
    if (xmin <= 0 && xmax >= 0) {
      canvas.drawLine(point(0, ymin), point(0, ymax), axis);
    }
    if (ymin <= 0 && ymax >= 0) {
      canvas.drawLine(point(xmin, 0), point(xmax, 0), axis);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(left, top, width, height));
    final path = Path();
    var drawing = false;
    double? lastX;
    for (var i = 0; i <= 400; i++) {
      final x = xmin + (xmax - xmin) * i / 400;
      final y = config.valueAt(x, a, u, v);
      if (y == null ||
          y < ymin ||
          y > ymax ||
          (!power && !radical && lastX != null && lastX < u && x >= u)) {
        drawing = false;
        lastX = x;
        continue;
      }
      final p = point(x, y);
      if (drawing) {
        path.lineTo(p.dx, p.dy);
      } else {
        path.moveTo(p.dx, p.dy);
        drawing = true;
      }
      lastX = x;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    // Clip the curve, but keep boundary markers whole in the chart's margin.
    canvas.restore();
    final guide = Paint()
      ..color = const Color(0xffc2410c)
      ..strokeWidth = 1.3;
    if (power) {
      final p = point(u, config.valueAt(u, a, u, v)!);
      if (stage >= 1) canvas.drawLine(point(u, ymin), p, guide);
      if (stage >= 2) {
        canvas.drawLine(point(xmin, config.valueAt(u, a, u, v)!), p, guide);
      }
      canvas.drawCircle(p, 4, guide);
    } else if (radical && stage >= 2) {
      canvas.drawCircle(point(origin, v), 4, guide);
    } else if (!radical && stage >= 1) {
      canvas.drawLine(point(u, ymin), point(u, ymax), guide);
      canvas.drawLine(point(xmin, v), point(xmax, v), guide);
    }
  }

  @override
  bool shouldRepaint(covariant _FunctionPainter old) =>
      old.config != config ||
      old.a != a ||
      old.u != u ||
      old.v != v ||
      old.stage != stage ||
      old.color != color;
}
