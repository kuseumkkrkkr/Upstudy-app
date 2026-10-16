import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/book_set_operations.dart';
import 'book_activity_view.dart';

/// Source-bounded membership controls and Venn regions. Reader-session state only.
class BookSetOperationsView extends StatefulWidget {
  const BookSetOperationsView({super.key, required this.activity});
  final BookActivity activity;
  @override
  State<BookSetOperationsView> createState() => _SetState();
}

class _SetState extends State<BookSetOperationsView> {
  late Set<int> _a, _b;
  late String _operation;
  bool _restored = false;
  void _reset() {
    final definition = widget.activity.setOperations!;
    _a = definition.a.toSet();
    _b = definition.b.toSet();
    _operation = definition.operation;
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant BookSetOperationsView oldWidget) {
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
      _a = (saved['a'] as List<int>).toSet();
      _b = (saved['b'] as List<int>).toSet();
      _operation = saved['operation'] as String;
    }
  }

  String _list(Iterable<int> members) =>
      '{${(members.toList()..sort()).join(', ')}}';
  Widget _membership(int n, String name, Set<int> members) => Expanded(
    child: Row(
      children: [
        Semantics(
          label: '원소 $n을 $name 집합에 포함',
          child: SizedBox(
            width: 48,
            height: 48,
            child: Checkbox(
              value: members.contains(n),
              onChanged: (value) => setState(() {
                value! ? members.add(n) : members.remove(n);
              }),
            ),
          ),
        ),
        Flexible(
          child: Text('$name에 포함', style: const TextStyle(fontSize: 14)),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    BookActivityKeyScope.save(context, widget.activity, {
      'a': _a.toList(),
      'b': _b.toList(),
      'operation': _operation,
    });
    final result = BookSetOperations.result(_a, _b, _operation);
    final label = BookSetOperations
        .labels[BookSetOperations.operations.indexOf(_operation)];
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
          for (final n in BookSetOperations.universe)
            Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '$n',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _membership(n, 'A', _a),
                _membership(n, 'B', _b),
              ],
            ),
          Semantics(
            image: true,
            label:
                '전체집합 U 안의 두 집합. A=${_list(_a)}, B=${_list(_b)}. $label=${_list(result)}',
            child: ExcludeSemantics(
              child: AspectRatio(
                aspectRatio: 640 / 330,
                child: CustomPaint(
                  painter: _VennPainter(Set.of(_a), Set.of(_b), _operation),
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < BookSetOperations.operations.length; i++)
                ChoiceChip(
                  label: Text(BookSetOperations.labels[i]),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  selected: _operation == BookSetOperations.operations[i],
                  onSelected: (_) => setState(
                    () => _operation = BookSetOperations.operations[i],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              '$label = ${_list(result)} · U = {1, 2, 3, 4, 5, 6}',
              key: const ValueKey('set-operation-result'),
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _operation == 'complement'
                ? 'U를 기준으로 A에 없는 원소를 골랐습니다.'
                : '${result.length}개의 원소가 선택한 연산 결과에 들어갑니다.',
            style: const TextStyle(fontSize: 14, height: 1.6),
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

class _VennPainter extends CustomPainter {
  const _VennPainter(this.a, this.b, this.operation);
  final Set<int> a, b;
  final String operation;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 640, size.height / 330);
    final u = Path()..addRect(const Rect.fromLTWH(48, 34, 544, 258));
    final left = Path()
      ..addOval(Rect.fromCircle(center: const Offset(260, 175), radius: 112));
    final right = Path()
      ..addOval(Rect.fromCircle(center: const Offset(380, 175), radius: 112));
    final selected = switch (operation) {
      'union' => Path.combine(PathOperation.union, left, right),
      'difference' => Path.combine(PathOperation.difference, left, right),
      'complement' => Path.combine(PathOperation.difference, u, left),
      _ => Path.combine(PathOperation.intersect, left, right),
    };
    canvas.drawPath(u, Paint()..color = Colors.white);
    canvas.drawPath(selected, Paint()..color = const Color(0x66f59e0b));
    canvas.drawPath(
      u,
      Paint()
        ..color = const Color(0xffcbd5e1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      left,
      Paint()
        ..color = const Color(0xff2358c5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawPath(
      right,
      Paint()
        ..color = const Color(0xff23835b)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    void text(String value, double x, double y) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: const TextStyle(
            color: Color(0xff17233b),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(x - painter.width / 2, y - painter.height / 2),
      );
    }

    text('U', 555, 52);
    text('A', 180, 85);
    text('B', 455, 85);
    final counts = [0, 0, 0, 0];
    for (final n in BookSetOperations.universe) {
      final region = a.contains(n)
          ? (b.contains(n) ? 2 : 0)
          : (b.contains(n) ? 1 : 3);
      // Six positions remain inside the chosen region, including all-in-one-set.
      text(
        '$n',
        [205.0, 435.0, 320.0, 555.0][region],
        120 + 22.0 * counts[region]++,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VennPainter oldDelegate) =>
      operation != oldDelegate.operation ||
      !setEquals(a, oldDelegate.a) ||
      !setEquals(b, oldDelegate.b);
}
