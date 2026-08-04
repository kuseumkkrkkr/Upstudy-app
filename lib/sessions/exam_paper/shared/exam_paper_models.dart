part of 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

class _LayoutEntry {
  final ExamItem item;
  final int column;
  final int row;
  final int rowSpan;

  _LayoutEntry(
    this.item, {
    required this.column,
    required this.row,
    required this.rowSpan,
  });
}

class _PageLayout {
  final List<_LayoutEntry> entries;
  final List<bool> columnSpans;

  _PageLayout({required this.entries, required this.columnSpans});
}

class _QuestionRegion {
  final ExamItem item;
  final Rect rect;

  const _QuestionRegion({required this.item, required this.rect});
}

class ExamGradeResult {
  final int itemIndex;
  final String? analysis;
  final String? error;
  final List<String> warnings;
  final bool empty;
  final bool? isCorrect;
  final List<Map<String, dynamic>> stepCorrectness;
  final Map<String, dynamic>? quest;

  const ExamGradeResult._({
    required this.itemIndex,
    this.analysis,
    this.error,
    this.warnings = const [],
    this.empty = false,
    this.isCorrect,
    this.stepCorrectness = const [],
    this.quest,
  });

  factory ExamGradeResult.empty(int itemIndex, {Map<String, dynamic>? quest}) {
    return ExamGradeResult._(itemIndex: itemIndex, empty: true, quest: quest);
  }

  factory ExamGradeResult.success(
    int itemIndex, {
    required String analysis,
    required List<String> warnings,
    bool? isCorrect,
    List<Map<String, dynamic>> stepCorrectness = const [],
    Map<String, dynamic>? quest,
  }) {
    return ExamGradeResult._(
      itemIndex: itemIndex,
      analysis: analysis,
      warnings: warnings,
      isCorrect: isCorrect,
      stepCorrectness: stepCorrectness,
      quest: quest,
    );
  }

  factory ExamGradeResult.failure(
    int itemIndex,
    String error, {
    Map<String, dynamic>? quest,
  }) {
    return ExamGradeResult._(itemIndex: itemIndex, error: error, quest: quest);
  }
}

class _ReferenceSolveStep {
  final String flowText;
  final List<String> hashTags;
  final String hintText;
  final String answerText;
  final int enterHuddle;
  final List<_ReferenceSolveStep> branches;

  const _ReferenceSolveStep({
    required this.flowText,
    this.hashTags = const [],
    this.hintText = '',
    this.answerText = '',
    this.enterHuddle = 0,
    this.branches = const [],
  });

  static List<_ReferenceSolveStep> fromQuest(dynamic solves) {
    if (solves is! List) return <_ReferenceSolveStep>[];
    return solves
        .whereType<Map<String, dynamic>>()
        .map(_fromServerMap)
        .toList();
  }

  static _ReferenceSolveStep _fromServerMap(Map<String, dynamic> step) {
    final flowText = _contentBlocksToText(step['flow']);
    final branches = fromQuest(step['branches']);
    final hintText = _contentBlocksToText(step['hint_riddle']);
    final answerText = _contentBlocksToText(step['answer_riddle']);
    final hashTags = (step['hash_tag'] as List<dynamic>? ?? const [])
        .map((tag) => tag.toString())
        .toList();
    final enterHuddle = (step['enter_huddle'] as int?) ?? 0;
    return _ReferenceSolveStep(
      flowText: flowText,
      hintText: hintText,
      answerText: answerText,
      hashTags: hashTags,
      enterHuddle: enterHuddle,
      branches: branches,
    );
  }
}

String _contentBlocksToText(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is Map<String, dynamic>) {
    if (value.containsKey('blocks')) {
      final blocks = value['blocks'];
      if (blocks is List) {
        return blocks
            .whereType<Map<String, dynamic>>()
            .map((block) => (block['content'] ?? '').toString().trim())
            .where((content) => content.isNotEmpty)
            .join(' ')
            .trim();
      }
    }
    if (value.containsKey('content')) {
      return (value['content'] ?? '').toString().trim();
    }
  }
  if (value is List) {
    return value
        .map((item) {
          if (item is Map<String, dynamic>) {
            return (item['content'] ?? '').toString().trim();
          }
          return item.toString().trim();
        })
        .where((content) => content.isNotEmpty)
        .join(' ')
        .trim();
  }
  return value.toString().trim();
}

class _PenSettings {
  const _PenSettings({required this.color, required this.width});

  final Color color;
  final double width;
}

abstract class _UndoAction {
  const _UndoAction();
}

class _AddAction extends _UndoAction {
  const _AddAction(this.stroke);

  final _Stroke stroke;
}

class _RemoveAction extends _UndoAction {
  const _RemoveAction(this.strokes);

  final List<_Stroke> strokes;
}

class _Stroke {
  _Stroke({required this.color, required this.baseWidth, required this.order});

  final Color color;
  final double baseWidth;
  final int order;
  final List<_StrokePoint> points = <_StrokePoint>[];
  Rect? bounds;

  void addPoint(Offset position, double pressure) {
    points.add(_StrokePoint(position, pressure));
    final radius = baseWidth / 2;
    final pointRect = Rect.fromCircle(center: position, radius: radius);
    bounds = bounds == null ? pointRect : bounds!.expandToInclude(pointRect);
  }

  bool hitTestCircle(Offset center, double radius) {
    final currentBounds = bounds;
    if (currentBounds == null) return false;
    if (!currentBounds.inflate(radius).contains(center)) return false;
    if (points.length == 1) {
      return (points.first.position - center).distance <= radius;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i].position;
      final b = points[i + 1].position;
      if (_distanceToSegment(center, a, b) <= radius) {
        return true;
      }
    }
    return false;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLen2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLen2 == 0) return (p - a).distance;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLen2;
    final clamped = t.clamp(0.0, 1.0);
    final closest = Offset(a.dx + ab.dx * clamped, a.dy + ab.dy * clamped);
    return (p - closest).distance;
  }
}

class _StrokePoint {
  const _StrokePoint(this.position, this.pressure);

  final Offset position;
  final double pressure;
}
