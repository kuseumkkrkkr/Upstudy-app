part of 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

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

class _ProblemSnapshot {
  const _ProblemSnapshot({
    required this.strokes,
    required this.strokeHistory,
    required this.eraserHistory,
    required this.undoStack,
    required this.pendingEraseRemoved,
    required this.inputEvents,
    required this.nextStrokeOrder,
    required this.nextStrokeId,
    required this.elapsedSeconds,
  });

  final List<_Stroke> strokes;
  final List<_Stroke> strokeHistory;
  final List<_EraserStroke> eraserHistory;
  final List<_UndoAction> undoStack;
  final List<_Stroke> pendingEraseRemoved;
  final List<_InputEvent> inputEvents;
  final int nextStrokeOrder;
  final int nextStrokeId;
  final double elapsedSeconds;
}

class _EraserStroke {
  _EraserStroke({required this.startTime}) : endTime = startTime;

  final double startTime;
  double endTime;
  final List<Offset> points = <Offset>[];

  // 필요 변수: 지우개 위치와 입력 시각. 작동 원리: 이동 경로를 추가하고 종료 시각을 최신 입력으로 갱신한다.
  void addPoint(Offset position, double timestamp) {
    points.add(position);
    endTime = timestamp;
  }
}

enum _InputEventType { undo, erase }

class _InputEvent {
  const _InputEvent._({
    required this.type,
    required this.timestamp,
    this.region,
    this.strokeId,
  });

  // 필요 변수: 실행 취소 시각. 작동 원리: 히트맵 재생용 undo 이벤트를 만든다.
  factory _InputEvent.undo(double timestamp) {
    return _InputEvent._(type: _InputEventType.undo, timestamp: timestamp);
  }

  // 필요 변수: 지우개 시각·영역·획 ID. 작동 원리: 지워진 범위를 재현할 erase 이벤트를 만든다.
  factory _InputEvent.erase({
    required double timestamp,
    required Rect region,
    required String strokeId,
  }) {
    return _InputEvent._(
      type: _InputEventType.erase,
      timestamp: timestamp,
      region: region,
      strokeId: strokeId,
    );
  }

  final _InputEventType type;
  final double timestamp;
  final Rect? region;
  final String? strokeId;
}
