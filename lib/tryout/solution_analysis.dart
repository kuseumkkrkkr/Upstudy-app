part of s11.tryout;

class _OcrBlock {
  const _OcrBlock({required this.text, required this.bbox});

  final String text;
  final Rect bbox;

  Map<String, dynamic> toJson() {
    return {'text': text, 'bbox': _rectToList(bbox)};
  }
}

class _SolutionStepTimeRange {
  const _SolutionStepTimeRange(this.startTime, this.endTime);

  final double startTime;
  final double endTime;

  static _SolutionStepTimeRange fromStrokes(List<_Stroke> strokes) {
    if (strokes.isEmpty) {
      return const _SolutionStepTimeRange(0, 0);
    }
    final start = strokes
        .map((stroke) => stroke.startTime)
        .reduce((a, b) => a < b ? a : b);
    final end = strokes
        .map((stroke) => stroke.endTime)
        .reduce((a, b) => a > b ? a : b);
    return _SolutionStepTimeRange(start, end);
  }
}

class _SolutionStep {
  const _SolutionStep({
    required this.stepId,
    required this.recognizedText,
    required this.bbox,
    required this.connectedStrokes,
    required this.startTime,
    required this.endTime,
  });

  final int stepId;
  final String recognizedText;
  final Rect bbox;
  final List<String> connectedStrokes;
  final double startTime;
  final double endTime;

  double get duration => math.max(0.0, endTime - startTime);

  Map<String, dynamic> toJson() {
    return {
      'step_id': stepId,
      'recognized_text': recognizedText,
      'bbox': _rectToList(bbox),
      'connected_strokes': connectedStrokes,
      'start_time': startTime,
      'end_time': endTime,
      'duration': duration,
    };
  }
}

class _ReferenceSolveStep {
  const _ReferenceSolveStep({
    required this.flowText,
    required this.hashTags,
    required this.hintText,
    required this.answerText,
    required this.enterHuddle,
    this.branches = const [],
  });

  final String flowText;
  final List<String> hashTags;
  final String hintText;
  final String answerText;
  final int enterHuddle;
  final List<_ReferenceSolveStep> branches;

  static List<_ReferenceSolveStep> fromServer(dynamic solves) {
    if (solves is! List) return <_ReferenceSolveStep>[];
    return solves
        .whereType<Map<String, dynamic>>()
        .map(_fromServerMap)
        .toList();
  }

  static _ReferenceSolveStep _fromServerMap(Map<String, dynamic> step) {
    final flowText = _contentBlocksToText(step['flow']);
    final hintText = _contentBlocksToText(step['hint_riddle']);
    final answerText = _contentBlocksToText(step['answer_riddle']);
    final hashTags = (step['hash_tag'] as List<dynamic>? ?? const [])
        .map((tag) => tag.toString())
        .toList();
    final enterHuddle = (step['enter_huddle'] as int?) ?? 0;
    final branches = fromServer(step['branches']);
    return _ReferenceSolveStep(
      flowText: flowText,
      hashTags: hashTags,
      hintText: hintText,
      answerText: answerText,
      enterHuddle: enterHuddle,
      branches: branches,
    );
  }
}

class _StepCorrectness {
  const _StepCorrectness({
    required this.stepId,
    required this.correct,
    required this.similarity,
    this.feedback,
  });

  const _StepCorrectness.unknown({required this.stepId})
    : correct = null,
      similarity = 0.0,
      feedback = null;

  final int stepId;
  final bool? correct;
  final double similarity;
  final String? feedback;

  factory _StepCorrectness.fromJson(Map<String, dynamic> json) {
    return _StepCorrectness(
      stepId: (json['step_id'] as num?)?.toInt() ?? 0,
      correct: json['correct'] as bool?,
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
      feedback: json['feedback'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step_id': stepId,
      'correct': correct,
      'similarity': similarity,
      if (feedback != null) 'feedback': feedback,
    };
  }
}

class _StepWeakness {
  const _StepWeakness({required this.stepId, required this.weaknessType});

  final int stepId;
  final String weaknessType;

  Map<String, dynamic> toJson() {
    return {'step_id': stepId, 'weakness_type': weaknessType};
  }
}

List<double> _rectToList(Rect rect) {
  return <double>[rect.left, rect.top, rect.right, rect.bottom];
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
