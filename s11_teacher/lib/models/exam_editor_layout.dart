import '../models/exam_editor_models.dart';

/// 2×2 grid layout engine for the exam paper editor.
///
/// Rules:
/// - Normal items: single slot (1×1)
/// - Large items (flowCount > threshold or manually set): full column (rowSpan=2)
/// - Geometry items: max 1 per row, max 2 per page
/// - When only 2 items on a page: they can expand (rowSpan=2 each, one per column)
class ExamEditorLayoutEngine {
  static const int _largeFlowThreshold = 10;

  /// Computes page layouts from a flat list of editor items.
  static List<EditorPageLayout> computeLayout(List<ExamEditorItem> items) {
    final pages = <EditorPageLayout>[];
    var currentEntries = <EditorLayoutEntry>[];
    var occupied = <String, bool>{};
    var columnSpans = [false, false];

    void flushPage() {
      if (currentEntries.isNotEmpty) {
        pages.add(EditorPageLayout(
          entries: List.unmodifiable(currentEntries),
          columnSpans: List.unmodifiable(columnSpans),
        ));
      }
      currentEntries = [];
      occupied = {};
      columnSpans = [false, false];
    }

    int? findFreeColumn() {
      for (var col = 0; col < 2; col++) {
        if (!columnSpans[col] &&
            occupied['$col,0'] != true &&
            occupied['$col,1'] != true) {
          return col;
        }
      }
      return null;
    }

    List<int>? findFreeSlot() {
      for (var col = 0; col < 2; col++) {
        for (var row = 0; row < 2; row++) {
          if (occupied['$col,$row'] != true && !columnSpans[col]) {
            return [col, row];
          }
        }
      }
      return null;
    }

    bool canPlaceGeometry(List<int> slot, bool isLarge) {
      final row = slot[1];
      // Check row constraint: max 1 geometry per row
      if (currentEntries.any((e) => e.row == row && e.editorItem.isGeometry)) {
        return false;
      }
      // Check page constraint: max 2 geometry per page
      final pageGeometryCount =
          currentEntries.where((e) => e.editorItem.isGeometry).length;
      if (pageGeometryCount >= 2) {
        return false;
      }
      // If large, check both rows
      if (isLarge) {
        if (currentEntries.any((e) => e.row == 1 && e.editorItem.isGeometry)) {
          return false;
        }
      }
      return true;
    }

    for (final editorItem in items) {
      final item = editorItem.item;
      final flowCount = item.flowCount ?? item.solvesCount;
      final isLarge = flowCount > _largeFlowThreshold;
      final isGeometry = editorItem.isGeometry;

      if (isLarge) {
        // Large item needs a full column
        var col = findFreeColumn();
        if (col == null) {
          flushPage();
          col = findFreeColumn() ?? 0;
        }
        // Geometry large items: must check both rows
        if (isGeometry) {
          if (!canPlaceGeometry([col, 0], true)) {
            flushPage();
            col = findFreeColumn() ?? 0;
          }
        }
        currentEntries.add(EditorLayoutEntry(
          editorItem: editorItem,
          column: col,
          row: 0,
          rowSpan: 2,
        ));
        columnSpans[col] = true;
        occupied['$col,0'] = true;
        occupied['$col,1'] = true;
      } else {
        // Normal item needs a single slot
        var slot = findFreeSlot();
        if (slot == null) {
          flushPage();
          slot = findFreeSlot() ?? [0, 0];
        }
        // Geometry constraint check
        if (isGeometry && !canPlaceGeometry(slot, false)) {
          flushPage();
          slot = findFreeSlot() ?? [0, 0];
        }
        currentEntries.add(EditorLayoutEntry(
          editorItem: editorItem,
          column: slot[0],
          row: slot[1],
          rowSpan: 1,
        ));
        occupied['${slot[0]},${slot[1]}'] = true;
      }
    }

    // Flush remaining items
    if (currentEntries.isNotEmpty) {
      flushPage();
    }

    return pages;
  }

  /// Computes layout with "2 problems per page, expanded" mode.
  /// Each page has exactly 2 items, each taking a full column (rowSpan=2).
  static List<EditorPageLayout> computeTwoPerPageLayout(
      List<ExamEditorItem> items) {
    final pages = <EditorPageLayout>[];
    for (var i = 0; i < items.length; i += 2) {
      final entries = <EditorLayoutEntry>[];
      // First item: column 0, full height
      entries.add(EditorLayoutEntry(
        editorItem: items[i],
        column: 0,
        row: 0,
        rowSpan: 2,
      ));
      // Second item: column 1, full height (if exists)
      if (i + 1 < items.length) {
        entries.add(EditorLayoutEntry(
          editorItem: items[i + 1],
          column: 1,
          row: 0,
          rowSpan: 2,
        ));
      }
      pages.add(EditorPageLayout(
        entries: List.unmodifiable(entries),
        columnSpans: List.unmodifiable([true, entries.length > 1]),
      ));
    }
    return pages;
  }

  /// Reorders items by moving an item from one index to another.
  static List<ExamEditorItem> reorder(
    List<ExamEditorItem> items,
    int oldIndex,
    int newIndex,
  ) {
    final result = List<ExamEditorItem>.from(items);
    if (oldIndex < 0 || oldIndex >= result.length) return result;
    if (newIndex < 0 || newIndex > result.length) return result;

    final item = result.removeAt(oldIndex);
    // Adjust index if moving forward
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    result.insert(adjustedNewIndex, item);

    // Update display indices
    for (var i = 0; i < result.length; i++) {
      result[i] = result[i].copyWith(displayIndex: i);
    }

    return result;
  }

  /// Removes an item at the given index and updates display indices.
  static List<ExamEditorItem> removeAt(List<ExamEditorItem> items, int index) {
    final result = List<ExamEditorItem>.from(items);
    if (index < 0 || index >= result.length) return result;
    result.removeAt(index);
    for (var i = 0; i < result.length; i++) {
      result[i] = result[i].copyWith(displayIndex: i);
    }
    return result;
  }

  /// Inserts an item at the given index and updates display indices.
  static List<ExamEditorItem> insertAt(
    List<ExamEditorItem> items,
    int index,
    ExamEditorItem item,
  ) {
    final result = List<ExamEditorItem>.from(items);
    final clampedIndex = index.clamp(0, result.length);
    result.insert(clampedIndex, item.copyWith(displayIndex: clampedIndex));
    for (var i = 0; i < result.length; i++) {
      result[i] = result[i].copyWith(displayIndex: i);
    }
    return result;
  }
}
