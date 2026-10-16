import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'book_activity_view.dart';

/// Source-bounded (x+a)(x+b) exploration. Diagram is schematic, not measured.
class BookPolynomialAreaView extends StatefulWidget {
  const BookPolynomialAreaView({super.key, required this.activity});
  final BookActivity activity;
  @override
  State<BookPolynomialAreaView> createState() => _AreaState();
}

class _AreaState extends State<BookPolynomialAreaView> {
  late int _a, _b;
  bool _restored = false;
  void _reset() {
    _a = widget.activity.legA;
    _b = widget.activity.legB;
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant BookPolynomialAreaView oldWidget) {
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
    }
  }

  Widget _control(String name, int value, ValueChanged<int> change) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('상수 $name $value', style: const TextStyle(fontSize: 16)),
      Row(
        children: [
          IconButton(
            tooltip: '$name 줄이기',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: value > 1 ? () => change(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: ExcludeFocus(
              child: ExcludeSemantics(
                child: Slider(
                  key: ValueKey('polynomial-area-$name'),
                  min: 1,
                  max: 8,
                  divisions: 7,
                  value: value.toDouble(),
                  onChanged: (v) => change(v.round()),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '$name 늘리기',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: value < 8 ? () => change(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    BookActivityKeyScope.save(context, widget.activity, {'a': _a, 'b': _b});
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffd4d4d8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.activity.prompt,
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 12),
          _control('a', _a, (v) => setState(() => _a = v)),
          _control('b', _b, (v) => setState(() => _b = v)),
          Semantics(
            liveRegion: true,
            child: Text(
              '(x+$_a)(x+$_b) = x² + ${_a + _b}x + ${_a * _b}',
              key: const ValueKey('polynomial-area-result'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
          ),
          Semantics(
            image: true,
            label: 'x와 상수로 나눈 직사각형 넓이 모형',
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 416),
                child: const AspectRatio(
                  aspectRatio: 240 / 150,
                  child: CustomPaint(painter: _AreaPainter()),
                ),
              ),
            ),
          ),
          const Text(
            '그림은 개념 모형이며 실제 길이 비례가 아닙니다.',
            style: TextStyle(fontSize: 12),
          ),
          for (final hint in widget.activity.hints) Text(hint),
          TextButton(
            onPressed: () => setState(_reset),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
}

class _AreaPainter extends CustomPainter {
  const _AreaPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 150);
    final border = Paint()
      ..color = const Color(0xff172033)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(const Rect.fromLTWH(25, 25, 110, 90), border);
    final partition = Paint()
      ..color = const Color(0xffb45309)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(80, 25), const Offset(80, 115), partition);
    canvas.drawLine(const Offset(25, 70), const Offset(135, 70), partition);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AreaPainter oldDelegate) => false;
}
