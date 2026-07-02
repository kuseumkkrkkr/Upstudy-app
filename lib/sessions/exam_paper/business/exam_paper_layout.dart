part of 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

const int _largeFlowThreshold = 10;

List<_PageLayout> _layoutItems(List<ExamItem> items) {
  final pages = <_PageLayout>[];
  var entries = <_LayoutEntry>[];
  var columnSpans = [false, false];
  var occupied = [
    [false, false],
    [false, false],
  ];

  void flush() {
    if (entries.isNotEmpty) {
      pages.add(_PageLayout(entries: entries, columnSpans: columnSpans));
    }
    entries = <_LayoutEntry>[];
    columnSpans = [false, false];
    occupied = [
      [false, false],
      [false, false],
    ];
  }

  int? findFreeColumn() {
    for (var col = 0; col < 2; col++) {
      if (!occupied[col][0] && !occupied[col][1]) {
        return col;
      }
    }
    return null;
  }

  List<int>? findFreeSlot() {
    for (var col = 0; col < 2; col++) {
      for (var row = 0; row < 2; row++) {
        if (!occupied[col][row]) {
          return [col, row];
        }
      }
    }
    return null;
  }

  for (final item in items) {
    final flowCount = item.flowCount ?? item.solvesCount ?? 0;
    final isLarge = flowCount > _largeFlowThreshold;

    if (isLarge) {
      var column = findFreeColumn();
      if (column == null) {
        flush();
        column = findFreeColumn() ?? 0;
      }
      entries.add(
        _LayoutEntry(
          item,
          column: column,
          row: 0,
          rowSpan: 2,
        ),
      );
      columnSpans[column] = true;
      occupied[column][0] = true;
      occupied[column][1] = true;
      continue;
    }

    var slot = findFreeSlot();
    if (slot == null) {
      flush();
      slot = findFreeSlot() ?? [0, 0];
    }
    entries.add(
      _LayoutEntry(
        item,
        column: slot[0],
        row: slot[1],
        rowSpan: 1,
      ),
    );
    occupied[slot[0]][slot[1]] = true;
  }

  if (entries.isNotEmpty) {
    pages.add(_PageLayout(entries: entries, columnSpans: columnSpans));
  }

  return pages;
}


