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

  factory _InputEvent.undo(double timestamp) {
    return _InputEvent._(type: _InputEventType.undo, timestamp: timestamp);
  }

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

class _PauseEvent {
  const _PauseEvent({required this.strokeIndex, required this.duration});

  final int strokeIndex;
  final double duration;

  Map<String, dynamic> toJson() {
    return {'stroke_index': strokeIndex, 'duration': duration};
  }
}

class _TimelineBucket {
  const _TimelineBucket({
    required this.t,
    required this.strokeCount,
    required this.avgSpeed,
  });

  final double t;
  final int strokeCount;
  final double avgSpeed;

  Map<String, dynamic> toJson() {
    return {'t': t, 'stroke_count': strokeCount, 'avg_speed': avgSpeed};
  }
}

class _StrokeAnalytics {
  const _StrokeAnalytics({
    required this.totalStrokes,
    required this.totalTime,
    required this.avgLength,
    required this.avgSpeed,
    required this.pauseEvents,
    required this.eraseCount,
    required this.undoCount,
    required this.rewriteCount,
    required this.timeline,
  });

  final int totalStrokes;
  final double totalTime;
  final double avgLength;
  final double avgSpeed;
  final List<_PauseEvent> pauseEvents;
  final int eraseCount;
  final int undoCount;
  final int rewriteCount;
  final List<_TimelineBucket> timeline;

  Map<String, dynamic> toJson() {
    return {
      'total_strokes': totalStrokes,
      'total_time': totalTime,
      'avg_stroke_length': avgLength,
      'avg_stroke_speed': avgSpeed,
      'pause_events': pauseEvents.map((event) => event.toJson()).toList(),
      'erase_count': eraseCount,
      'undo_count': undoCount,
      'rewrite_count': rewriteCount,
      'timeline': timeline.map((bucket) => bucket.toJson()).toList(),
    };
  }
}

enum _WritingEventType {
  longPause,
  slowWriting,
  rewrite,
  undoBurst,
  eraseCluster,
}

extension _WritingEventTypeLabel on _WritingEventType {
  String get label {
    switch (this) {
      case _WritingEventType.longPause:
        return 'long_pause';
      case _WritingEventType.slowWriting:
        return 'slow_writing';
      case _WritingEventType.rewrite:
        return 'rewrite';
      case _WritingEventType.undoBurst:
        return 'undo_burst';
      case _WritingEventType.eraseCluster:
        return 'erase_cluster';
    }
  }
}

class _WritingEvent {
  const _WritingEvent({required this.type, required this.data});

  final _WritingEventType type;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() {
    return {'type': type.label, ...data};
  }
}

class _RegionCluster {
  _RegionCluster(this.region) : count = 1;

  Rect region;
  int count;

  void absorb(Rect other) {
    region = region.expandToInclude(other);
    count += 1;
  }
}

class _StrokeAnalyticsEngine {
  static const double pauseThresholdSeconds = 1.5;
  static const double slowWritingFactor = 0.5;
  static const double undoBurstWindowSeconds = 3.0;
  static const int undoBurstMinCount = 2;
  static const int maxEventsPerType = 5;
  static const int maxTotalEvents = 20;
  static const double sampleWindowSeconds = 1.0;

  static _StrokeAnalytics analyze({
    required List<_Stroke> strokes,
    required List<_InputEvent> inputEvents,
    required double sampleWindowSeconds,
  }) {
    if (strokes.isEmpty) {
      return const _StrokeAnalytics(
        totalStrokes: 0,
        totalTime: 0,
        avgLength: 0,
        avgSpeed: 0,
        pauseEvents: <_PauseEvent>[],
        eraseCount: 0,
        undoCount: 0,
        rewriteCount: 0,
        timeline: <_TimelineBucket>[],
      );
    }

    final ordered = List<_Stroke>.from(strokes)
      ..sort((a, b) => a.order.compareTo(b.order));
    final totalStrokes = ordered.length;
    final totalTime = math.max(
      0.0,
      ordered.last.endTime - ordered.first.startTime,
    );

    final totalLength = ordered.fold<double>(
      0.0,
      (sum, stroke) => sum + stroke.length,
    );
    final avgLength = totalStrokes == 0 ? 0.0 : totalLength / totalStrokes;

    final speeds = ordered
        .map((stroke) {
          final duration = stroke.duration;
          if (duration <= 0) return 0.0;
          return stroke.length / duration;
        })
        .where((speed) => speed > 0)
        .toList();
    final avgSpeed = speeds.isEmpty
        ? 0.0
        : speeds.reduce((a, b) => a + b) / speeds.length;

    final pauseEvents = <_PauseEvent>[];
    for (var i = 0; i < ordered.length - 1; i++) {
      final pause = ordered[i + 1].startTime - ordered[i].endTime;
      if (pause > 0) {
        pauseEvents.add(_PauseEvent(strokeIndex: i, duration: pause));
      }
    }

    final eraseCount = inputEvents
        .where((event) => event.type == _InputEventType.erase)
        .length;
    final undoCount = inputEvents
        .where((event) => event.type == _InputEventType.undo)
        .length;
    final rewriteClusters = _buildRewriteClusters(ordered, inputEvents);
    final rewriteCount = rewriteClusters.fold<int>(
      0,
      (sum, cluster) => sum + cluster.count,
    );

    final timeline = _buildTimeline(
      strokes: ordered,
      totalTime: totalTime,
      sampleWindowSeconds: sampleWindowSeconds,
    );

    return _StrokeAnalytics(
      totalStrokes: totalStrokes,
      totalTime: totalTime,
      avgLength: avgLength,
      avgSpeed: avgSpeed,
      pauseEvents: pauseEvents,
      eraseCount: eraseCount,
      undoCount: undoCount,
      rewriteCount: rewriteCount,
      timeline: timeline,
    );
  }

  static List<_WritingEvent> extractEvents({
    required _StrokeAnalytics analytics,
    required List<_Stroke> strokes,
    required List<_InputEvent> inputEvents,
  }) {
    final events = <_WritingEvent>[];

    final longPauses =
        analytics.pauseEvents
            .where((event) => event.duration >= pauseThresholdSeconds)
            .toList()
          ..sort((a, b) => b.duration.compareTo(a.duration));
    for (final pause in longPauses.take(maxEventsPerType)) {
      events.add(
        _WritingEvent(type: _WritingEventType.longPause, data: pause.toJson()),
      );
    }

    final avgSpeed = analytics.avgSpeed;
    final slowCandidates = <Map<String, dynamic>>[];
    for (var i = 0; i < strokes.length; i++) {
      final stroke = strokes[i];
      if (stroke.duration <= 0) continue;
      final speed = stroke.length / stroke.duration;
      if (avgSpeed > 0 && speed < avgSpeed * slowWritingFactor) {
        slowCandidates.add({'stroke_index': i, 'speed': speed});
      }
    }
    slowCandidates.sort(
      (a, b) => (a['speed'] as double).compareTo(b['speed'] as double),
    );
    for (final slow in slowCandidates.take(maxEventsPerType)) {
      events.add(
        _WritingEvent(
          type: _WritingEventType.slowWriting,
          data: {'stroke_index': slow['stroke_index']},
        ),
      );
    }

    final rewriteClusters = _buildRewriteClusters(strokes, inputEvents)
      ..sort((a, b) => b.count.compareTo(a.count));
    for (final cluster in rewriteClusters.take(maxEventsPerType)) {
      events.add(
        _WritingEvent(
          type: _WritingEventType.rewrite,
          data: {'region': _rectToList(cluster.region), 'count': cluster.count},
        ),
      );
    }

    final undoBurst = _buildUndoBurst(inputEvents);
    if (undoBurst != null) {
      events.add(undoBurst);
    }

    final eraseClusters = _buildEraseClusters(inputEvents)
      ..sort((a, b) => b.count.compareTo(a.count));
    for (final cluster in eraseClusters.take(maxEventsPerType)) {
      events.add(
        _WritingEvent(
          type: _WritingEventType.eraseCluster,
          data: {'region': _rectToList(cluster.region), 'count': cluster.count},
        ),
      );
    }

    if (events.length <= maxTotalEvents) {
      return events;
    }
    return events.take(maxTotalEvents).toList();
  }

  static List<_TimelineBucket> _buildTimeline({
    required List<_Stroke> strokes,
    required double totalTime,
    required double sampleWindowSeconds,
  }) {
    if (totalTime <= 0 || sampleWindowSeconds <= 0) {
      return <_TimelineBucket>[];
    }
    final bucketCount = (totalTime / sampleWindowSeconds).ceil();
    final buckets = List<_TimelineBucket>.generate(
      bucketCount,
      (index) => _TimelineBucket(
        t: index * sampleWindowSeconds,
        strokeCount: 0,
        avgSpeed: 0,
      ),
    );

    for (var i = 0; i < bucketCount; i++) {
      final start = i * sampleWindowSeconds;
      final end = start + sampleWindowSeconds;
      final strokesInBucket = strokes
          .where(
            (stroke) => stroke.startTime >= start && stroke.startTime < end,
          )
          .toList();
      if (strokesInBucket.isEmpty) continue;
      final speeds = strokesInBucket
          .map(
            (stroke) =>
                stroke.duration > 0 ? stroke.length / stroke.duration : 0.0,
          )
          .where((speed) => speed > 0)
          .toList();
      final avgSpeed = speeds.isEmpty
          ? 0.0
          : speeds.reduce((a, b) => a + b) / speeds.length;
      buckets[i] = _TimelineBucket(
        t: start,
        strokeCount: strokesInBucket.length,
        avgSpeed: avgSpeed,
      );
    }
    return buckets;
  }

  static List<_RegionCluster> _buildRewriteClusters(
    List<_Stroke> strokes,
    List<_InputEvent> inputEvents,
  ) {
    if (strokes.isEmpty || inputEvents.isEmpty) return <_RegionCluster>[];
    final erases = inputEvents
        .where((event) => event.type == _InputEventType.erase)
        .where((event) => event.region != null)
        .toList();
    if (erases.isEmpty) return <_RegionCluster>[];

    final clusters = <_RegionCluster>[];
    for (final stroke in strokes) {
      final strokeBounds = stroke.resolvedBounds;
      if (strokeBounds == null) continue;
      Rect? overlapRegion;
      for (final erase in erases) {
        if (erase.timestamp > stroke.startTime) continue;
        final region = erase.region!;
        if (!region.overlaps(strokeBounds)) continue;
        overlapRegion = overlapRegion == null
            ? strokeBounds.expandToInclude(region)
            : overlapRegion.expandToInclude(region);
      }
      if (overlapRegion == null) continue;
      _addToClusters(clusters, overlapRegion);
    }
    return clusters;
  }

  static List<_RegionCluster> _buildEraseClusters(
    List<_InputEvent> inputEvents,
  ) {
    final erases = inputEvents
        .where((event) => event.type == _InputEventType.erase)
        .where((event) => event.region != null)
        .toList();
    if (erases.isEmpty) return <_RegionCluster>[];
    final clusters = <_RegionCluster>[];
    for (final erase in erases) {
      _addToClusters(clusters, erase.region!);
    }
    return clusters.where((cluster) => cluster.count >= 2).toList();
  }

  static _WritingEvent? _buildUndoBurst(List<_InputEvent> inputEvents) {
    final undoTimes =
        inputEvents
            .where((event) => event.type == _InputEventType.undo)
            .map((event) => event.timestamp)
            .toList()
          ..sort();
    if (undoTimes.length < undoBurstMinCount) return null;
    var maxCount = 0;
    var start = 0;
    for (var end = 0; end < undoTimes.length; end++) {
      while (undoTimes[end] - undoTimes[start] > undoBurstWindowSeconds) {
        start += 1;
      }
      final count = end - start + 1;
      if (count > maxCount) maxCount = count;
    }
    if (maxCount < undoBurstMinCount) return null;
    return _WritingEvent(
      type: _WritingEventType.undoBurst,
      data: {'count': maxCount},
    );
  }

  static void _addToClusters(List<_RegionCluster> clusters, Rect region) {
    for (final cluster in clusters) {
      if (cluster.region.overlaps(region)) {
        cluster.absorb(region);
        return;
      }
    }
    clusters.add(_RegionCluster(region));
  }
}
