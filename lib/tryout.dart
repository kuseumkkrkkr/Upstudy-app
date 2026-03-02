import 'dart:math' as math;
import 'package:flutter/material.dart';

class BuildpageWidget extends StatefulWidget {
  const BuildpageWidget({super.key});

  static const String routeName = 'buildpage';
  static const String routePath = '/buildpage';

  @override
  State<BuildpageWidget> createState() => _BuildpageWidgetState();
}

enum _ToolMode { pen, eraser }

class _BuildpageWidgetState extends State<BuildpageWidget> {
  static const double _baseWidth = 1920;
  static const double _baseHeight = 1080;
  static const double _expandedHeight = 2500;
  static const double _scrollbarThickness = 12;
  static const double _eraserRadius = 26;
  static const double _minPointDistance = 0.6;
  static const Color _kGreen = Color(0xFF1B402B);

  static const Color _penRed = Color(0xFFE53935);
  static const Color _penBlue = Color(0xFF1E88E5);
  static const List<Color> _penColors = [_penRed, _penBlue, Colors.black];
  static const List<double> _penWidths = [5, 3, 1];

  static const String _problemText =
      '''1. 카페에서 아메리카노는 4,000원, 치즈케이크는 6,000원이다. 두 메뉴를 합쳐 8개를 샀더니 38,000원을 지불했다. 아메리카노와 치즈케이크의 개수를 구하시오.''';

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _paintVersion = ValueNotifier<int>(0);

  final List<_Stroke> _strokes = <_Stroke>[];
  final List<_UndoAction> _undoStack = <_UndoAction>[];
  final List<_Stroke> _pendingEraseRemoved = <_Stroke>[];

  _Stroke? _currentStroke;
  int _nextStrokeOrder = 0;
  int? _activePointer;
  Offset? _lastFilteredPoint;

  _ToolMode _toolMode = _ToolMode.pen;
  Color _penColor = Colors.black;
  double _penWidth = 3;

  bool _scrollEnabled = false;

  Offset? _eraserPosition;
  bool _eraserActive = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _paintVersion.dispose();
    super.dispose();
  }

  double get _logicalHeight => _scrollEnabled ? _expandedHeight : _baseHeight;

  void _bumpPaint() {
    _paintVersion.value = _paintVersion.value + 1;
  }

  void _setToolMode(_ToolMode mode) {
    if (_toolMode == mode) return;
    setState(() {
      _toolMode = mode;
    });
  }

  void _toggleScroll() {
    setState(() {
      _scrollEnabled = !_scrollEnabled;
      if (!_scrollEnabled) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _openPenSettings() async {
    final result = await showModalBottomSheet<_PenSettings>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        var tempColor = _penColor;
        var tempWidth = _penWidth;
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '펜 설정',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  const Text('색상', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final color in _penColors)
                        _ColorChip(
                          color: color,
                          selected: tempColor == color,
                          onTap: () => setState(() => tempColor = color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('굵기', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final width in _penWidths)
                        _WidthChip(
                          width: width,
                          selected: tempWidth == width,
                          onTap: () => setState(() => tempWidth = width),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            _PenSettings(color: tempColor, width: tempWidth),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B402B),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('적용'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _penColor = result.color;
      _penWidth = result.width;
      _toolMode = _ToolMode.pen;
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();
    if (action is _AddAction) {
      _strokes.remove(action.stroke);
    } else if (action is _RemoveAction) {
      _strokes.addAll(action.strokes);
      _strokes.sort((a, b) => a.order.compareTo(b.order));
    }
    _bumpPaint();
  }

  void _clearAll() {
    if (_strokes.isEmpty && _currentStroke == null) return;
    final removed = <_Stroke>[
      ..._strokes,
      if (_currentStroke != null) _currentStroke!,
    ];
    _strokes.clear();
    _currentStroke = null;
    if (removed.isNotEmpty) {
      _undoStack.add(_RemoveAction(removed));
    }
    _bumpPaint();
  }

  double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 1100;
    if (scale < min) return min;
    if (scale > max) return max;
    return scale;
  }

  void _handlePointerDown(PointerDownEvent event, double scale) {
    if (_activePointer != null) return;
    final position = _toLogicalPosition(event.localPosition, scale);
    if (!_withinCanvas(position)) return;
    _activePointer = event.pointer;
    if (_toolMode == _ToolMode.pen) {
      _startStroke(position, _normalizePressure(event));
    } else {
      _startEraser(position);
    }
  }

  void _handlePointerMove(PointerMoveEvent event, double scale) {
    if (_activePointer != event.pointer) return;
    final position = _toLogicalPosition(event.localPosition, scale);
    if (!_withinCanvas(position)) return;
    if (_toolMode == _ToolMode.pen) {
      _appendStroke(position, _normalizePressure(event));
    } else {
      _updateEraser(position);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    if (_toolMode == _ToolMode.pen) {
      _finishStroke();
    } else {
      _finishEraser();
    }
    _activePointer = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    if (_toolMode == _ToolMode.pen) {
      _finishStroke();
    } else {
      _finishEraser();
    }
    _activePointer = null;
  }

  void _startStroke(Offset position, double pressure) {
    _lastFilteredPoint = null;
    final stroke = _Stroke(
      color: _penColor,
      baseWidth: _penWidth,
      order: _nextStrokeOrder++,
    );
    _currentStroke = stroke;
    _appendStroke(position, pressure);
  }

  void _appendStroke(Offset position, double pressure) {
    final stroke = _currentStroke;
    if (stroke == null) return;
    final filtered = _filterPoint(position);
    if (stroke.points.isNotEmpty) {
      final lastPoint = stroke.points.last.position;
      if ((filtered - lastPoint).distance < _minPointDistance) return;
    }
    stroke.addPoint(filtered, pressure);
    _bumpPaint();
  }

  void _finishStroke() {
    final stroke = _currentStroke;
    if (stroke != null && stroke.points.isNotEmpty) {
      _strokes.add(stroke);
      _undoStack.add(_AddAction(stroke));
    }
    _currentStroke = null;
    _lastFilteredPoint = null;
    _bumpPaint();
  }

  void _startEraser(Offset position) {
    _pendingEraseRemoved.clear();
    _eraserActive = true;
    _eraserPosition = position;
    _eraseAt(position);
    _bumpPaint();
  }

  void _updateEraser(Offset position) {
    _eraserActive = true;
    _eraserPosition = position;
    _eraseAt(position);
    _bumpPaint();
  }

  void _finishEraser() {
    if (_pendingEraseRemoved.isNotEmpty) {
      _undoStack.add(_RemoveAction(List<_Stroke>.from(_pendingEraseRemoved)));
      _pendingEraseRemoved.clear();
    }
    _eraserActive = false;
    _eraserPosition = null;
    _bumpPaint();
  }

  void _eraseAt(Offset position) {
    if (_strokes.isEmpty) return;
    final toRemove = <_Stroke>[];
    for (final stroke in _strokes) {
      if (!stroke.hitTestCircle(position, _eraserRadius)) continue;
      toRemove.add(stroke);
    }
    if (toRemove.isEmpty) return;
    _strokes.removeWhere(toRemove.contains);
    _pendingEraseRemoved.addAll(toRemove);
  }

  bool _withinCanvas(Offset position) {
    return position.dx >= 0 &&
        position.dy >= 0 &&
        position.dx <= _baseWidth &&
        position.dy <= _logicalHeight;
  }

  Offset _toLogicalPosition(Offset localPosition, double scale) {
    if (scale <= 0) return localPosition;
    return Offset(localPosition.dx / scale, localPosition.dy / scale);
  }

  Offset _filterPoint(Offset next) {
    const smoothing = 0.55;
    final last = _lastFilteredPoint;
    if (last == null) {
      _lastFilteredPoint = next;
      return next;
    }
    final filtered = Offset(
      last.dx + (next.dx - last.dx) * smoothing,
      last.dy + (next.dy - last.dy) * smoothing,
    );
    _lastFilteredPoint = filtered;
    return filtered;
  }

  double _normalizePressure(PointerEvent event) {
    final min = event.pressureMin;
    final max = event.pressureMax;
    final value = event.pressure;
    if (max <= min) return 1.0;
    final normalized = (value - min) / (max - min);
    return normalized.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader(),
              Expanded(child: _buildCanvasArea()),
              _buildToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final scale = _uiScale(context);
    return SizedBox(
      height: 72 * scale,
      child: Row(
        children: [
          SizedBox(width: 16 * scale),
          IconButton(
            iconSize: 28 * scale,
            icon: const Icon(Icons.arrow_back, color: _kGreen),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'AIFlow',
                style: TextStyle(
                  fontSize: 36 * scale,
                  fontWeight: FontWeight.bold,
                  color: _kGreen,
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                iconSize: 28 * scale,
                icon: const Icon(Icons.info_outline, color: _kGreen),
                onPressed: () {},
              ),
              SizedBox(width: 8 * scale),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rightPadding = _scrollEnabled ? _scrollbarThickness + 6 : 0.0;
        final drawableWidth = math.max(
          0.0,
          constraints.maxWidth - rightPadding,
        );
        final double scale = drawableWidth <= 0
            ? 1.0
            : drawableWidth / _baseWidth;
        final double scaledHeight = _logicalHeight * scale;
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: _scrollEnabled,
          interactive: _scrollEnabled,
          thickness: _scrollbarThickness,
          radius: const Radius.circular(6),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: _scrollEnabled
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: constraints.maxWidth,
              height: scaledHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(right: rightPadding),
                      child: Transform.scale(
                        alignment: Alignment.topLeft,
                        scale: scale,
                        child: SizedBox(
                          width: _baseWidth,
                          height: _logicalHeight,
                          child: _buildProblemContent(),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(right: rightPadding),
                      child: RepaintBoundary(
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) =>
                              _handlePointerDown(event, scale),
                          onPointerMove: (event) =>
                              _handlePointerMove(event, scale),
                          onPointerUp: _handlePointerUp,
                          onPointerCancel: _handlePointerCancel,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _paintVersion,
                            builder: (context, _, __) {
                              return CustomPaint(
                                painter: _StrokePainter(
                                  strokes: _strokes,
                                  currentStroke: _currentStroke,
                                  eraserPosition: _eraserActive
                                      ? _eraserPosition
                                      : null,
                                  eraserRadius: _eraserRadius,
                                  scale: scale,
                                  logicalSize: Size(_baseWidth, _logicalHeight),
                                  backgroundColor: Colors.transparent,
                                  repaint: _paintVersion,
                                ),
                                size: Size(drawableWidth, scaledHeight),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProblemContent() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(80, 20, 80, 0),
      child: const SizedBox(
        width: double.infinity,
        child: Text(
          _problemText,
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 22, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final activeColor = const Color(0xFF1B402B);
    final inactiveColor = const Color(0xFF6B6B6B);
    return Container(
      width: 800,
      height: 70,
      decoration: const BoxDecoration(
        color: Color(0xFFE9E9E9),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ToolbarIcon(
              icon: Icons.edit_outlined,
              size: 48,
              color: _toolMode == _ToolMode.pen ? activeColor : inactiveColor,
              onTap: () => _setToolMode(_ToolMode.pen),
            ),
            const SizedBox(width: 20),
            _ToolbarIcon(
              icon: Icons.cleaning_services_outlined,
              size: 40,
              color: _toolMode == _ToolMode.eraser
                  ? activeColor
                  : inactiveColor,
              onTap: () => _setToolMode(_ToolMode.eraser),
            ),
            const SizedBox(width: 20),
            _ToolbarIcon(
              icon: Icons.color_lens_outlined,
              size: 48,
              color: _penColor,
              onTap: _openPenSettings,
            ),
            const SizedBox(width: 20),
            const SizedBox(
              height: 100,
              child: VerticalDivider(thickness: 2, color: Color(0xFFE0E3E7)),
            ),
            const SizedBox(width: 20),
            _ToolbarIcon(
              icon: Icons.undo_outlined,
              size: 40,
              color: _undoStack.isEmpty ? inactiveColor : activeColor,
              onTap: _undoStack.isEmpty ? null : _undo,
            ),
            const SizedBox(width: 20),
            _ToolbarIcon(
              icon: Icons.delete_outline,
              size: 48,
              color: (_strokes.isEmpty && _currentStroke == null)
                  ? inactiveColor
                  : activeColor,
              onTap: (_strokes.isEmpty && _currentStroke == null)
                  ? null
                  : _clearAll,
            ),
            const SizedBox(width: 20),
            const SizedBox(
              height: 100,
              child: VerticalDivider(thickness: 2, color: Color(0xFFE0E3E7)),
            ),
            const SizedBox(width: 20),
            _ToolbarIcon(
              icon: Icons.auto_fix_high,
              size: 40,
              color: _scrollEnabled ? activeColor : inactiveColor,
              onTap: _toggleScroll,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: size * 0.8,
      child: Icon(icon, size: size, color: color),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _WidthChip extends StatelessWidget {
  const _WidthChip({
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 54,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B402B) : const Color(0xFFE9E9E9),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Container(
          width: width * 6,
          height: width * 6,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
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

class _StrokePainter extends CustomPainter {
  static const double _pressureMinFactor = 0.35;

  _StrokePainter({
    required this.strokes,
    required this.currentStroke,
    required this.eraserPosition,
    required this.eraserRadius,
    required this.scale,
    required this.logicalSize,
    required this.backgroundColor,
    Listenable? repaint,
  }) : super(repaint: repaint);

  final List<_Stroke> strokes;
  final _Stroke? currentStroke;
  final Offset? eraserPosition;
  final double eraserRadius;
  final double scale;
  final Size logicalSize;
  final Color backgroundColor;

  static void drawStrokes(
    Canvas canvas,
    List<_Stroke> strokes, {
    _Stroke? currentStroke,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    void drawOne(_Stroke stroke) {
      if (stroke.points.isEmpty) return;
      paint.color = stroke.color;
      if (stroke.points.length == 1) {
        final point = stroke.points.first;
        final width = _pressureWidth(stroke.baseWidth, point.pressure);
        canvas.drawCircle(
          point.position,
          width / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        return;
      }
      for (var i = 0; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];
        final width = _pressureWidth(
          stroke.baseWidth,
          (p1.pressure + p2.pressure) * 0.5,
        );
        paint.strokeWidth = width;
        canvas.drawLine(p1.position, p2.position, paint);
      }
    }

    for (final stroke in strokes) {
      drawOne(stroke);
    }
    if (currentStroke != null) {
      drawOne(currentStroke);
    }
  }

  static double _pressureWidth(double baseWidth, double pressure) {
    final factor =
        _pressureMinFactor +
        (1 - _pressureMinFactor) * pressure.clamp(0.0, 1.0);
    return baseWidth * factor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    canvas.clipRect(Offset.zero & logicalSize);
    if (backgroundColor.opacity > 0) {
      canvas.drawRect(
        Offset.zero & logicalSize,
        Paint()..color = backgroundColor,
      );
    }
    drawStrokes(canvas, strokes, currentStroke: currentStroke);

    if (eraserPosition != null) {
      final fillPaint = Paint()
        ..color = Colors.black.withOpacity(0.08)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(eraserPosition!, eraserRadius, fillPaint);
      canvas.drawCircle(eraserPosition!, eraserRadius, borderPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.logicalSize != logicalSize ||
        oldDelegate.eraserPosition != eraserPosition ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
