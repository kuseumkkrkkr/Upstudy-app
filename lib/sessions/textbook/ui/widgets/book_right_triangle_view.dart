import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'book_activity_view.dart';

/// Bounded Pythagoras exploration. Local state only; no grading or server writes.
class BookRightTriangleView extends StatefulWidget {
  const BookRightTriangleView({super.key, required this.activity});
  final BookActivity activity;
  @override
  State<BookRightTriangleView> createState() => _TriangleState();
}

class _TriangleState extends State<BookRightTriangleView> {
  late int _a, _b;
  int _hints = 0;
  bool _restored = false;
  void _reset() {
    _a = widget.activity.legA;
    _b = widget.activity.legB;
    _hints = 0;
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant BookRightTriangleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.activity.toJson()) !=
        jsonEncode(widget.activity.toJson())) {
      _reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    final saved = BookActivityKeyScope.read(context, widget.activity);
    if (saved != null) {
      _a = saved['a'] as int;
      _b = saved['b'] as int;
      _hints = saved['hints'] as int;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final c = math.sqrt(_a * _a + _b * _b);
    BookActivityKeyScope.save(context, activity, {
      'a': _a,
      'b': _b,
      'hints': _hints,
    });
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffd4d4d8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            activity.prompt,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          Text('첫 직각변 a: $_a'),
          Slider(
            value: _a.toDouble(),
            min: 1,
            max: 12,
            divisions: 11,
            label: '$_a',
            semanticFormatterCallback: (v) => '첫 직각변 ${v.round()}',
            onChanged: (v) => setState(() => _a = v.round()),
          ),
          Text('둘째 직각변 b: $_b'),
          Slider(
            value: _b.toDouble(),
            min: 1,
            max: 12,
            divisions: 11,
            label: '$_b',
            semanticFormatterCallback: (v) => '둘째 직각변 ${v.round()}',
            onChanged: (v) => setState(() => _b = v.round()),
          ),
          Semantics(
            label: '직각삼각형: 두 직각변 $_a, $_b. 빗변 ${c.toStringAsFixed(2)}',
            image: true,
            child: SizedBox(
              height: 160,
              child: CustomPaint(painter: _TrianglePainter(_a, _b)),
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text('빗변 c: ${c.toStringAsFixed(2)}'),
          ),
          Text('a² + b² = c² · ${_a * _a} + ${_b * _b} = ${_a * _a + _b * _b}'),
          const Text('길이는 소수 셋째 자리에서 반올림해 둘째 자리까지 표시합니다.'),
          for (var i = 0; i < _hints; i++) Text(activity.hints[i]),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_hints < activity.hints.length)
                TextButton(
                  onPressed: () => setState(() => _hints++),
                  child: const Text('힌트 한 단계'),
                ),
              OutlinedButton(
                onPressed: () => setState(_reset),
                child: const Text('초기화'),
              ),
            ],
          ),
          const Text('교재 체험 · 시험 점수·등급에 반영되지 않아요.'),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.a, this.b);
  final int a, b;
  @override
  void paint(Canvas canvas, Size size) {
    // Both legs use one scale: the drawing preserves the right angle and ratio.
    final scale = math.min((size.width - 24) / a, (size.height - 24) / b);
    final origin = Offset((size.width - a * scale) / 2, size.height - 12);
    final right = origin + Offset(a * scale, 0);
    final top = origin - Offset(0, b * scale);
    final pen = Paint()
      ..color = const Color(0xff18181b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(
      Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(top.dx, top.dy)
        ..close(),
      pen,
    );
    final mark = math.min(12.0, math.min(a, b) * scale / 3);
    canvas.drawPath(
      Path()
        ..moveTo(origin.dx, origin.dy - mark)
        ..lineTo(origin.dx + mark, origin.dy - mark)
        ..lineTo(origin.dx + mark, origin.dy),
      pen..color = const Color(0xff71717a),
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) =>
      a != oldDelegate.a || b != oldDelegate.b;
}
