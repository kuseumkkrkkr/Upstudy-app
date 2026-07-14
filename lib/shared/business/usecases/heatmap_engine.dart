import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

enum HeatmapEventType { penStroke, eraserStroke, undo }

class HeatmapConfig {
  const HeatmapConfig({
    this.gridSize = 10,
    this.penLevel1 = 1,
    this.penLevel2 = 3,
    this.penLevel3 = 5,
    this.eraseLevel1 = 4,
    this.eraseLevel2 = 6,
    this.eraseLevel3 = 8,
    this.undoHighlightThreshold = 5,
    this.jumpThresholdCells = 20,
  });

  final int gridSize;
  final int penLevel1;
  final int penLevel2;
  final int penLevel3;
  final int eraseLevel1;
  final int eraseLevel2;
  final int eraseLevel3;
  final int undoHighlightThreshold;
  final int jumpThresholdCells;
}

class HeatmapStroke {
  const HeatmapStroke({
    required this.key,
    required this.points,
    required this.order,
  });

  final String key;
  final List<Offset> points;
  final double order;

  Offset? get centroid {
    if (points.isEmpty) return null;
    var sumX = 0.0;
    var sumY = 0.0;
    for (final point in points) {
      sumX += point.dx;
      sumY += point.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }
}

class HeatmapEraserStroke {
  const HeatmapEraserStroke({required this.points, required this.order});

  final List<Offset> points;
  final double order;
}

class HeatmapEvent {
  HeatmapEvent.pen(HeatmapStroke stroke)
    : type = HeatmapEventType.penStroke,
      order = stroke.order,
      stroke = stroke,
      eraser = null;

  HeatmapEvent.eraser(HeatmapEraserStroke eraser)
    : type = HeatmapEventType.eraserStroke,
      order = eraser.order,
      stroke = null,
      eraser = eraser;

  HeatmapEvent.undo(double order)
    : type = HeatmapEventType.undo,
      order = order,
      stroke = null,
      eraser = null;

  final HeatmapEventType type;
  final double order;
  final HeatmapStroke? stroke;
  final HeatmapEraserStroke? eraser;
}

class HeatmapCell {
  const HeatmapCell(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) {
    return other is HeatmapCell && other.row == row && other.col == col;
  }

  @override
  int get hashCode => Object.hash(row, col);
}

class HeatmapResult {
  HeatmapResult({
    required this.size,
    required this.config,
    required this.penCounts,
    required this.eraseCounts,
    required this.overDarkCells,
    required this.highlightReasons,
  });

  final Size size;
  final HeatmapConfig config;
  final List<List<int>> penCounts;
  final List<List<int>> eraseCounts;
  final Set<HeatmapCell> overDarkCells;
  final Map<String, Set<String>> highlightReasons;

  int get rows => penCounts.length;
  int get cols => rows == 0 ? 0 : penCounts[0].length;

  Future<Uint8List> renderImage({
    Color penBaseColor = const Color(0xFF1450DC),
    Color eraseBaseColor = const Color(0xFFE63C3C),
  }) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final width = math.max(1, size.width.round());
    final height = math.max(1, size.height.round());
    final rect = Offset.zero & Size(width.toDouble(), height.toDouble());
    canvas.drawRect(rect, Paint()..color = const Color(0x00000000));

    _drawHeatmap(
      canvas,
      penCounts,
      penBaseColor,
      config.penLevel1,
      config.penLevel2,
      config.penLevel3,
      width,
      height,
      config.gridSize,
    );
    _drawHeatmap(
      canvas,
      eraseCounts,
      eraseBaseColor,
      config.eraseLevel1,
      config.eraseLevel2,
      config.eraseLevel3,
      width,
      height,
      config.gridSize,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    return bytes?.buffer.asUint8List() ?? Uint8List(0);
  }

  Map<String, dynamic> toMetaJson() {
    return {
      'grid_size': config.gridSize,
      'pen_levels': [config.penLevel1, config.penLevel2, config.penLevel3],
      'erase_levels': [
        config.eraseLevel1,
        config.eraseLevel2,
        config.eraseLevel3,
      ],
      'jump_threshold_cells': config.jumpThresholdCells,
      'undo_highlight_threshold': config.undoHighlightThreshold,
      'pen_total': _sumCounts(penCounts),
      'erase_total': _sumCounts(eraseCounts),
      'rewrite_total': _sumOverlap(penCounts, eraseCounts),
      'over_dark_count': overDarkCells.length,
      'highlights': highlightReasons.entries
          .map(
            (entry) => {
              'stroke_key': entry.key,
              'reasons': entry.value.toList(),
            },
          )
          .toList(),
      'size': {'width': size.width, 'height': size.height},
    };
  }

  static void _drawHeatmap(
    Canvas canvas,
    List<List<int>> counts,
    Color baseColor,
    int level1,
    int level2,
    int level3,
    int width,
    int height,
    int gridSize,
  ) {
    final rows = counts.length;
    final cols = rows == 0 ? 0 : counts[0].length;
    if (rows == 0 || cols == 0) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final count = counts[r][c];
        final alpha = _alphaForCount(count, level1, level2, level3);
        if (alpha <= 0) continue;
        paint.color = baseColor.withAlpha(alpha);
        final left = c * gridSize.toDouble();
        final top = r * gridSize.toDouble();
        final cellWidth = math.min(gridSize.toDouble(), width - left);
        final cellHeight = math.min(gridSize.toDouble(), height - top);
        if (cellWidth <= 0 || cellHeight <= 0) continue;
        canvas.drawRect(Rect.fromLTWH(left, top, cellWidth, cellHeight), paint);
      }
    }
  }

  static int _alphaForCount(int count, int level1, int level2, int level3) {
    if (count >= level3) return 160;
    if (count >= level2) return 110;
    if (count >= level1) return 70;
    return 0;
  }

  static int _sumCounts(List<List<int>> counts) {
    var total = 0;
    for (final row in counts) {
      for (final value in row) {
        total += value;
      }
    }
    return total;
  }

  static int _sumOverlap(List<List<int>> countsA, List<List<int>> countsB) {
    var total = 0;
    final rows = math.min(countsA.length, countsB.length);
    final cols = rows == 0 ? 0 : math.min(countsA[0].length, countsB[0].length);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        total += math.min(countsA[r][c], countsB[r][c]);
      }
    }
    return total;
  }
}

class HeatmapEngine {
  static HeatmapResult build({
    required Size size,
    required List<HeatmapEvent> events,
    HeatmapConfig config = const HeatmapConfig(),
    Offset origin = Offset.zero,
  }) {
    final gridSize = math.max(1, config.gridSize);
    final cols = math.max(1, (size.width / gridSize).ceil());
    final rows = math.max(1, (size.height / gridSize).ceil());
    final penCounts = List<List<int>>.generate(
      rows,
      (_) => List<int>.filled(cols, 0),
    );
    final eraseCounts = List<List<int>>.generate(
      rows,
      (_) => List<int>.filled(cols, 0),
    );

    final sortedEvents = List<HeatmapEvent>.from(events)
      ..sort((a, b) => a.order.compareTo(b.order));

    var undoCounter = 0;
    Offset? lastCentroid;
    String? lastStrokeKey;
    Offset? jumpOrigin;
    var jumpActive = false;
    final highlightReasons = <String, Set<String>>{};

    for (final event in sortedEvents) {
      switch (event.type) {
        case HeatmapEventType.undo:
          undoCounter += 1;
          break;
        case HeatmapEventType.penStroke:
          final stroke = event.stroke;
          if (stroke == null || stroke.points.isEmpty) {
            undoCounter = math.min(undoCounter, config.undoHighlightThreshold);
            break;
          }
          if (undoCounter >= config.undoHighlightThreshold) {
            _addHighlight(
              highlightReasons,
              stroke.key,
              'undo>=${config.undoHighlightThreshold}',
            );
            undoCounter = 0;
          }
          final centroid = stroke.centroid;
          if (centroid != null && lastCentroid != null) {
            final distCells = (centroid - lastCentroid).distance / gridSize;
            if (distCells > config.jumpThresholdCells) {
              if (lastStrokeKey != null) {
                _addHighlight(highlightReasons, lastStrokeKey, 'jump_out');
              }
              _addHighlight(highlightReasons, stroke.key, 'jump_out');
              jumpOrigin = lastCentroid;
              jumpActive = true;
            } else if (jumpActive && jumpOrigin != null) {
              final backDist = (centroid - jumpOrigin).distance / gridSize;
              if (backDist <= config.jumpThresholdCells) {
                _addHighlight(highlightReasons, stroke.key, 'jump_back');
                jumpActive = false;
                jumpOrigin = null;
              }
            }
          }
          if (centroid != null) {
            lastCentroid = centroid;
            lastStrokeKey = stroke.key;
          }
          _recordPenCounts(penCounts, stroke.points, origin, gridSize);
          break;
        case HeatmapEventType.eraserStroke:
          final eraser = event.eraser;
          if (eraser == null || eraser.points.isEmpty) break;
          _recordEraseCounts(
            eraseCounts,
            penCounts,
            eraser.points,
            origin,
            gridSize,
            config.penLevel1,
          );
          break;
      }
    }

    final overDarkCells = <HeatmapCell>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (penCounts[r][c] >= config.penLevel2 &&
            eraseCounts[r][c] >= config.eraseLevel2) {
          overDarkCells.add(HeatmapCell(r, c));
        }
      }
    }

    return HeatmapResult(
      size: size,
      config: config,
      penCounts: penCounts,
      eraseCounts: eraseCounts,
      overDarkCells: overDarkCells,
      highlightReasons: highlightReasons,
    );
  }

  static void _recordPenCounts(
    List<List<int>> penCounts,
    List<Offset> points,
    Offset origin,
    int gridSize,
  ) {
    final rows = penCounts.length;
    final cols = rows == 0 ? 0 : penCounts[0].length;
    if (rows == 0 || cols == 0) return;
    final touched = <HeatmapCell>{};
    for (final point in points) {
      final x = point.dx - origin.dx;
      final y = point.dy - origin.dy;
      final col = (x / gridSize).floor();
      final row = (y / gridSize).floor();
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          final r = row + dr;
          final c = col + dc;
          if (r < 0 || c < 0 || r >= rows || c >= cols) continue;
          touched.add(HeatmapCell(r, c));
        }
      }
    }
    for (final cell in touched) {
      penCounts[cell.row][cell.col] += 1;
    }
  }

  static void _recordEraseCounts(
    List<List<int>> eraseCounts,
    List<List<int>> penCounts,
    List<Offset> points,
    Offset origin,
    int gridSize,
    int penLevel1,
  ) {
    final rows = eraseCounts.length;
    final cols = rows == 0 ? 0 : eraseCounts[0].length;
    if (rows == 0 || cols == 0) return;
    final touched = <HeatmapCell>{};
    for (final point in points) {
      final x = point.dx - origin.dx;
      final y = point.dy - origin.dy;
      final col = (x / gridSize).floor();
      final row = (y / gridSize).floor();
      for (var dr = -4; dr <= 4; dr++) {
        for (var dc = -4; dc <= 4; dc++) {
          final r = row + dr;
          final c = col + dc;
          if (r < 0 || c < 0 || r >= rows || c >= cols) continue;
          touched.add(HeatmapCell(r, c));
        }
      }
    }
    for (final cell in touched) {
      if (penCounts[cell.row][cell.col] >= penLevel1) {
        eraseCounts[cell.row][cell.col] += 1;
      }
    }
  }

  static void _addHighlight(
    Map<String, Set<String>> highlights,
    String key,
    String reason,
  ) {
    highlights.putIfAbsent(key, () => <String>{}).add(reason);
  }
}
