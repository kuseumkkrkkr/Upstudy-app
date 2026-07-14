import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:s11/shared/services/storage/local_db.dart';

enum _AnnotationTool { move, pen, eraser }

class CourseTextbookAnnotationCanvas extends StatefulWidget {
  const CourseTextbookAnnotationCanvas({
    super.key,
    required this.storageKey,
    required this.child,
  });

  final String storageKey;
  final Widget child;

  // 필요 변수: storageKey와 child. 작동 원리: 페이지별 필기 상태를 관리하는 State를 만든다.
  @override
  State<CourseTextbookAnnotationCanvas> createState() =>
      _CourseTextbookAnnotationCanvasState();
}

class _CourseTextbookAnnotationCanvasState
    extends State<CourseTextbookAnnotationCanvas> {
  static const _palette = <Color>[
    Colors.black,
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF2E7D32),
  ];

  final List<_NormalizedStroke> _strokes = <_NormalizedStroke>[];
  _NormalizedStroke? _activeStroke;
  _AnnotationTool _tool = _AnnotationTool.move;
  Color _color = Colors.black;
  Timer? _saveTimer;
  Size _canvasSize = Size.zero;
  int _revision = 0;
  int _persistedRevision = 0;

  // 필요 변수: 현재 storageKey. 작동 원리: 첫 화면이 준비되면 저장된 페이지 필기를 한 번 읽는다.
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  // 필요 변수: 대기 중인 저장 타이머와 현재 필기. 작동 원리: 종료 전에 지연 저장을 취소하고 최신 상태를 즉시 기록한다.
  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_persist(widget.storageKey));
    super.dispose();
  }

  // 필요 변수: storageKey. 작동 원리: UTF-8 JSON 문자열을 복원하고 손상된 로컬 데이터는 빈 필기로 안전하게 무시한다.
  Future<void> _load() async {
    try {
      final raw = await LocalDb.instance.getString(widget.storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = decoded
          .whereType<Map>()
          .map(
            (item) =>
                _NormalizedStroke.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _strokes
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {
      // 손상된 로컬 필기는 학습 화면 진입을 막지 않는다.
    }
  }

  // 필요 변수: 현재 필기 목록. 작동 원리: 연속 포인터 입력을 합쳐 600ms 뒤 한 번만 로컬 DB에 기록한다.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_persist(widget.storageKey)),
    );
  }

  // 필요 변수: 저장 키와 필기 목록. 작동 원리: 빈 목록은 키를 삭제하고 나머지는 정규화 좌표 JSON으로 저장한다.
  Future<void> _persist(String storageKey) async {
    if (_revision == _persistedRevision) return;
    final revision = _revision;
    try {
      if (_strokes.isEmpty) {
        await LocalDb.instance.delete(storageKey);
        _persistedRevision = revision;
        return;
      }
      await LocalDb.instance.setString(
        storageKey,
        jsonEncode(_strokes.map((stroke) => stroke.toJson()).toList()),
      );
      _persistedRevision = revision;
    } catch (_) {
      // 저장소가 없는 테스트 환경에서도 교재 읽기 자체는 계속 제공한다.
    }
  }

  // 필요 변수: 화면 좌표와 현재 캔버스 크기. 작동 원리: 기기 크기와 무관한 0~1 좌표로 변환한다.
  Offset _normalize(Offset point) {
    if (_canvasSize.isEmpty) return Offset.zero;
    return Offset(
      (point.dx / _canvasSize.width).clamp(0, 1),
      (point.dy / _canvasSize.height).clamp(0, 1),
    );
  }

  // 필요 변수: 시작 위치와 선택 도구. 작동 원리: 펜은 새 획을 만들고 지우개는 닿은 획을 제거한다.
  void _onPanStart(DragStartDetails details) {
    final point = _normalize(details.localPosition);
    if (_tool == _AnnotationTool.eraser) {
      _eraseAt(point);
      return;
    }
    setState(() {
      _activeStroke = _NormalizedStroke(color: _color, width: 3)
        ..points.add(point);
    });
  }

  // 필요 변수: 이동 위치와 진행 중 획. 작동 원리: 너무 가까운 점은 생략해 메모리와 저장 크기를 제한한다.
  void _onPanUpdate(DragUpdateDetails details) {
    final point = _normalize(details.localPosition);
    if (_tool == _AnnotationTool.eraser) {
      _eraseAt(point);
      return;
    }
    final stroke = _activeStroke;
    if (stroke == null) return;
    final threshold = _canvasSize.isEmpty
        ? 0.004
        : 3 / _canvasSize.shortestSide;
    if (stroke.points.isNotEmpty &&
        (stroke.points.last - point).distance < threshold) {
      return;
    }
    setState(() => stroke.points.add(point));
  }

  // 필요 변수: 진행 중 획. 작동 원리: 완성 획을 목록에 넣고 한 번의 지연 저장을 예약한다.
  void _onPanEnd(DragEndDetails details) {
    final stroke = _activeStroke;
    if (stroke != null && stroke.points.isNotEmpty) {
      setState(() {
        _strokes.add(stroke);
        _activeStroke = null;
        _revision++;
      });
    }
    _scheduleSave();
  }

  // 필요 변수: 취소된 획. 작동 원리: 화면 전환 등으로 제스처가 끊기면 불완전 획을 버린다.
  void _onPanCancel() {
    if (_activeStroke == null) return;
    setState(() => _activeStroke = null);
  }

  // 필요 변수: 정규화된 지우개 위치. 작동 원리: 화면상 약 18px 반경에 닿는 획 전체를 한 번에 제거한다.
  void _eraseAt(Offset point) {
    final radius = _canvasSize.isEmpty ? 0.03 : 18 / _canvasSize.shortestSide;
    if (!_strokes.any((stroke) => stroke.hitTest(point, radius))) return;
    setState(() {
      _strokes.removeWhere((stroke) => stroke.hitTest(point, radius));
      _revision++;
    });
    _scheduleSave();
  }

  // 필요 변수: 마지막 필기 획. 작동 원리: 가장 최근 획 하나를 제거하고 지연 저장한다.
  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() {
      _strokes.removeLast();
      _revision++;
    });
    _scheduleSave();
  }

  // 필요 변수: 선택 도구, 색상, 필기 목록. 작동 원리: 이동 모드에서는 본문 제스처를 통과시키고 그리기 모드만 캔버스가 입력을 받는다.
  @override
  Widget build(BuildContext context) {
    final drawing = _tool != _AnnotationTool.move;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _canvasSize = constraints.biggest;
              return IgnorePointer(
                ignoring: !drawing,
                child: GestureDetector(
                  key: const ValueKey('course-textbook-annotation-canvas'),
                  behavior: HitTestBehavior.translucent,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  onPanCancel: _onPanCancel,
                  child: CustomPaint(
                    painter: _AnnotationPainter(
                      strokes: _strokes,
                      activeStroke: _activeStroke,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(top: 10, right: 10, child: _buildToolbar()),
      ],
    );
  }

  // 필요 변수: 현재 도구, 색상, undo 가능 여부. 작동 원리: 페이지 안의 소형 툴바가 이동·펜·지우개·팔레트·undo를 즉시 전환한다.
  Widget _buildToolbar() {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolButton(
            tooltip: '이동',
            icon: Icons.pan_tool_outlined,
            selected: _tool == _AnnotationTool.move,
            onPressed: () => setState(() => _tool = _AnnotationTool.move),
          ),
          _ToolButton(
            tooltip: '펜',
            icon: Icons.edit_outlined,
            selected: _tool == _AnnotationTool.pen,
            onPressed: () => setState(() => _tool = _AnnotationTool.pen),
          ),
          _ToolButton(
            tooltip: '지우개',
            icon: Icons.auto_fix_normal_outlined,
            selected: _tool == _AnnotationTool.eraser,
            onPressed: () => setState(() => _tool = _AnnotationTool.eraser),
          ),
          PopupMenuButton<Color>(
            tooltip: '팔레트',
            icon: Icon(Icons.palette_outlined, color: _color),
            onSelected: (color) => setState(() {
              _color = color;
              _tool = _AnnotationTool.pen;
            }),
            itemBuilder: (_) => [
              for (final color in _palette)
                PopupMenuItem(
                  value: color,
                  child: Icon(Icons.circle, color: color),
                ),
            ],
          ),
          IconButton(
            tooltip: '실행 취소',
            onPressed: _strokes.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  // 필요 변수: 아이콘, 선택 상태, 콜백. 작동 원리: 활성 도구만 흑백 배경 대비로 표시한다.
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: selected ? Colors.black : Colors.transparent,
        foregroundColor: selected ? Colors.white : Colors.black87,
      ),
      icon: Icon(icon),
    );
  }
}

class _NormalizedStroke {
  _NormalizedStroke({required this.color, required this.width});

  final Color color;
  final double width;
  final List<Offset> points = <Offset>[];

  // 필요 변수: JSON 색상·굵기·좌표. 작동 원리: 유효한 숫자 좌표만 정규화 획으로 복원한다.
  factory _NormalizedStroke.fromJson(Map<String, dynamic> json) {
    final stroke = _NormalizedStroke(
      color: Color((json['color'] as num?)?.toInt() ?? Colors.black.toARGB32()),
      width: (json['width'] as num?)?.toDouble() ?? 3,
    );
    final rawPoints = json['points'];
    if (rawPoints is List) {
      for (final rawPoint in rawPoints) {
        if (rawPoint is! List || rawPoint.length < 2) continue;
        final dx = (rawPoint[0] as num?)?.toDouble();
        final dy = (rawPoint[1] as num?)?.toDouble();
        if (dx != null && dy != null) stroke.points.add(Offset(dx, dy));
      }
    }
    return stroke;
  }

  // 필요 변수: 색상·굵기·정규화 좌표. 작동 원리: 로컬 DB에 넣을 JSON 호환 맵으로 변환한다.
  Map<String, dynamic> toJson() => {
    'color': color.toARGB32(),
    'width': width,
    'points': points.map((point) => [point.dx, point.dy]).toList(),
  };

  // 필요 변수: 지우개 중심과 반경. 작동 원리: 획의 점 또는 선분과의 최단거리가 반경 이내인지 검사한다.
  bool hitTest(Offset center, double radius) {
    if (points.isEmpty) return false;
    if (points.length == 1) return (points.first - center).distance <= radius;
    for (var index = 0; index < points.length - 1; index++) {
      if (_distanceToSegment(center, points[index], points[index + 1]) <=
          radius) {
        return true;
      }
    }
    return false;
  }

  // 필요 변수: 점 p와 선분 a-b. 작동 원리: 선분 투영값을 0~1로 제한해 최단거리를 계산한다.
  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final ap = p - a;
    final ratio = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(
      0.0,
      1.0,
    );
    return (p - Offset(a.dx + ab.dx * ratio, a.dy + ab.dy * ratio)).distance;
  }
}

class _AnnotationPainter extends CustomPainter {
  const _AnnotationPainter({required this.strokes, required this.activeStroke});

  final List<_NormalizedStroke> strokes;
  final _NormalizedStroke? activeStroke;

  // 필요 변수: 캔버스 크기와 정규화 획. 작동 원리: 저장 좌표를 실제 크기로 환산해 부드러운 선을 그린다.
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    void drawStroke(_NormalizedStroke stroke) {
      if (stroke.points.isEmpty) return;
      paint
        ..color = stroke.color
        ..strokeWidth = stroke.width;
      final points = stroke.points
          .map((point) => Offset(point.dx * size.width, point.dy * size.height))
          .toList(growable: false);
      if (points.length == 1) {
        canvas.drawCircle(points.first, stroke.width / 2, paint);
        return;
      }
      for (var index = 0; index < points.length - 1; index++) {
        canvas.drawLine(points[index], points[index + 1], paint);
      }
    }

    for (final stroke in strokes) {
      drawStroke(stroke);
    }
    if (activeStroke != null) drawStroke(activeStroke!);
  }

  // 필요 변수: 이전/현재 획 참조. 작동 원리: 입력 중이거나 획 목록이 달라진 경우에만 다시 그린다.
  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return activeStroke != null ||
        oldDelegate.activeStroke != activeStroke ||
        oldDelegate.strokes.length != strokes.length ||
        !identical(oldDelegate.strokes, strokes);
  }
}
