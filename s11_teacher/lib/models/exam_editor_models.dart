import '../services/api_client.dart';

/// Exam editor item that wraps an [ExamItem] with editor-specific metadata.
class ExamEditorItem {
  /// The underlying exam item from the API.
  final ExamItem item;

  /// Unique identifier for this editor item (may differ from questId).
  final String editorId;

  /// Whether this item contains JSX/graph geometry content.
  final bool isGeometry;

  /// Whether this item is a multiple-choice question.
  final bool isMultipleChoice;

  /// Display order index within the exam.
  int displayIndex;

  /// Whether this item is currently selected in the editor.
  bool isSelected;

  ExamEditorItem({
    required this.item,
    required this.editorId,
    this.isGeometry = false,
    this.isMultipleChoice = false,
    this.displayIndex = 0,
    this.isSelected = false,
  });

  /// Detects geometry content from hashtags or quest title text.
  static bool detectGeometry(ExamItem item) {
    final tags = item.hashTags.map((t) => t.toLowerCase()).toList();
    if (tags.any((t) =>
        t.contains('graph') ||
        t.contains('jsx') ||
        t.contains('geometry') ||
        t.contains('geo') ||
        t.contains('figure'))) {
      return true;
    }
    final title = item.questTitle?.toString().toLowerCase() ?? '';
    if (title.contains('jsxgraph') ||
        title.contains('jsx') ||
        title.contains('geometry') ||
        title.contains('그래프')) {
      return true;
    }
    return false;
  }

  /// Detects multiple choice from quest options.
  static bool detectMultipleChoice(ExamItem item) {
    final opts = item.questOptions;
    if (opts != null && opts.isNotEmpty) {
      return true;
    }
    final title = item.questTitle?.toString().toLowerCase() ?? '';
    if (title.contains('①') ||
        title.contains('②') ||
        title.contains('③') ||
        title.contains('④') ||
        title.contains('⑤') ||
        title.contains('(1)') ||
        title.contains('(2)') ||
        title.contains('(3)') ||
        title.contains('(4)') ||
        title.contains('(5)')) {
      return true;
    }
    return false;
  }

  /// Creates an [ExamEditorItem] from an [ExamItem] with auto-detection.
  factory ExamEditorItem.fromExamItem(ExamItem item, int displayIndex) {
    return ExamEditorItem(
      item: item,
      editorId: '${item.questId ?? item.itemIndex}_${DateTime.now().millisecondsSinceEpoch}',
      isGeometry: detectGeometry(item),
      isMultipleChoice: detectMultipleChoice(item),
      displayIndex: displayIndex,
    );
  }

  String get titleText {
    final qt = item.questTitle;
    if (qt == null) return '문제 ${displayIndex + 1}';
    if (qt is String) return qt;
    if (qt is List) {
      return qt.map((e) => e.toString()).join(' ');
    }
    return qt.toString();
  }

  List<String> get options {
    final opts = item.questOptions;
    if (opts == null) return [];
    return opts.map((o) {
      if (o is String) return o;
      if (o is Map) return o['text']?.toString() ?? o.toString();
      return o.toString();
    }).toList().cast<String>();
  }

  ExamEditorItem copyWith({
    ExamItem? item,
    String? editorId,
    bool? isGeometry,
    bool? isMultipleChoice,
    int? displayIndex,
    bool? isSelected,
  }) {
    return ExamEditorItem(
      item: item ?? this.item,
      editorId: editorId ?? this.editorId,
      isGeometry: isGeometry ?? this.isGeometry,
      isMultipleChoice: isMultipleChoice ?? this.isMultipleChoice,
      displayIndex: displayIndex ?? this.displayIndex,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Layout entry for a single item on a page.
class EditorLayoutEntry {
  final ExamEditorItem editorItem;
  final int column;
  final int row;
  final int rowSpan;

  const EditorLayoutEntry({
    required this.editorItem,
    required this.column,
    required this.row,
    required this.rowSpan,
  });

  bool get isLarge => rowSpan > 1;
}

/// Layout for a single page (2 columns × 2 rows).
class EditorPageLayout {
  final List<EditorLayoutEntry> entries;
  final List<bool> columnSpans;

  const EditorPageLayout({
    required this.entries,
    required this.columnSpans,
  });

  /// Number of geometry items on this page.
  int get geometryCount =>
      entries.where((e) => e.editorItem.isGeometry).length;

  /// Whether the page has a geometry item in the given row.
  bool hasGeometryInRow(int row) => entries
      .where((e) => e.row == row && e.editorItem.isGeometry)
      .isNotEmpty;

  /// Whether a new geometry item can be placed in the given row.
  bool canPlaceGeometryInRow(int row) =>
      !hasGeometryInRow(row) && geometryCount < 2;

  /// Total items on this page.
  int get itemCount => entries.length;

  /// Whether the page is full (all 4 slots occupied).
  bool get isFull {
    final occupied = <String, bool>{};
    for (final e in entries) {
      occupied['${e.column},${e.row}'] = true;
      if (e.rowSpan > 1) {
        occupied['${e.column},1'] = true;
      }
    }
    return occupied.length >= 4;
  }
}

/// The full exam editor state containing all items and page layouts.
class ExamEditorState {
  final List<ExamEditorItem> items;
  final List<EditorPageLayout> pages;
  final double fontScale;
  final String? examId;
  final String title;

  const ExamEditorState({
    required this.items,
    required this.pages,
    this.fontScale = 1.0,
    this.examId,
    this.title = '새 시험지',
  });

  static const int maxProblems = 100;

  bool get canAddMore => items.length < maxProblems;

  ExamEditorState copyWith({
    List<ExamEditorItem>? items,
    List<EditorPageLayout>? pages,
    double? fontScale,
    String? examId,
    String? title,
  }) {
    return ExamEditorState(
      items: items ?? this.items,
      pages: pages ?? this.pages,
      fontScale: fontScale ?? this.fontScale,
      examId: examId ?? this.examId,
      title: title ?? this.title,
    );
  }
}
