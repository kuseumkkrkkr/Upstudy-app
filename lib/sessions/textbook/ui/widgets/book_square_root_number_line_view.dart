import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';

/// Registered integer n=1..25 practice, never a grading or OVR authority.
class BookSquareRootNumberLineView extends StatefulWidget {
  const BookSquareRootNumberLineView({super.key, required this.activity});
  final BookActivity activity;

  @override
  State<BookSquareRootNumberLineView> createState() => _SquareRootState();
}

class _SquareRootState extends State<BookSquareRootNumberLineView> {
  int _n = 1;

  @override
  Widget build(BuildContext context) {
    final root = math.sqrt(_n);
    final exact = root == root.roundToDouble();
    final label = '√$_n ${exact ? '=' : '≈'} ${exact ? root.toInt() : root.toStringAsFixed(3)}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD4D4D8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.activity.prompt, style: const TextStyle(fontSize: 14, height: 1.5)),
        const SizedBox(height: 12),
        Text('n = $_n · $label', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        Slider(
          min: 1, max: 25, divisions: 24, value: _n.toDouble(),
          label: 'n = $_n',
          semanticFormatterCallback: (value) => 'n은 ${value.round()}',
          onChanged: (value) => setState(() => _n = value.round()),
        ),
        Semantics(label: '$label, 0부터 5까지 수직선 위의 위치', child: LayoutBuilder(
          builder: (context, constraints) {
            final position = 8 + (constraints.maxWidth - 16) * root / 5;
            return SizedBox(height: 68, child: Stack(children: [
              const Positioned(left: 8, right: 8, top: 20, child: Divider(height: 1, color: Colors.black)),
              Positioned(left: 4, right: 4, top: 14, child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => Column(children: [
                  const SizedBox(height: 12, child: VerticalDivider(width: 8, color: Colors.black)),
                  Text('$i', style: const TextStyle(fontSize: 12)),
                ])),
              )),
              Positioned(left: position - 5, top: 15, child: Container(
                key: const ValueKey('square-root-position'),
                width: 10, height: 10,
                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
              )),
            ]));
          },
        )),
        for (final hint in widget.activity.hints)
          Text(hint, style: const TextStyle(fontSize: 13, height: 1.5)),
      ]),
    );
  }
}
