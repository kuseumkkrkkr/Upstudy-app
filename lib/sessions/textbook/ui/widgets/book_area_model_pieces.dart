import 'package:flutter/material.dart';

/// Four author-labelled pieces, in reading order. This is a schematic, not a
/// measurement: the source format supplies labels but no side lengths.
class BookAreaModelPieces extends StatelessWidget {
  const BookAreaModelPieces({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.length != 4) {
      return const Text('넓이 모형에는 네 조각의 설명이 필요합니다.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('넓이 분할 개념도 · 실제 길이 비례 아님',
            style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: const Color(0xFF71717A)),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (var row = 0; row < 2; row++)
              TableRow(children: [
                for (var column = 0; column < 2; column++)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(labels[row * 2 + column],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, height: 1.5)),
                  ),
              ]),
          ],
        ),
      ],
    );
  }
}
