import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/local_db.dart';

class NotepadPage extends StatefulWidget {
  const NotepadPage({super.key});

  @override
  State<NotepadPage> createState() => _NotepadPageState();
}

class _NotepadPageState extends State<NotepadPage> {
  static const _storageKey = 'notepad_strokes_v1';
  static const _baseHeight = 1400.0;
  static const _extendHeight = 900.0;
  static const _minPointDistance = 0.8;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _paintVersion = ValueNotifier<int>(0);
  final List<_Stroke> _strokes = <_Stroke>[];

  double _canvasHeight = _baseHeight;
  _Stroke? _currentStroke;
  Offset? _lastPoint;
  Timer? _saveTimer;

  bool _showLines = true;
  Color _penColor = Colors.black;
  double _penWidth = 3;

  bool get _canPersist => !kIsWeb;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    unawaited(_loadStrokes());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _paintVersion.dispose();
    _saveTimer?.cancel();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 240) {
      setState(() => _canvasHeight += _extendHeight);
    }
  }

  Future<void> _loadStrokes() async {
    if (!_canPersist) return;
    final raw = await LocalDb.instance.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = <_Stroke>[];
      for (final item in decoded) {
        if (item is Map) {
          loaded.add(_Stroke.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      if (!mounted) return;
      setState(() {
        _strokes
          ..clear()
          ..addAll(loaded);
        _canvasHeight = _estimateHeight(loaded);
      });
      _paintVersion.value += 1;
    } catch (_) {
      // ignore
    }
  }

  double _estimateHeight(List<_Stroke> strokes) {
    var maxY = _baseHeight;
    for (final stroke in strokes) {
      for (final point in stroke.points) {
        if (point.dy + 200 > maxY) {
          maxY = point.dy + 200;
        }
      }
    }
    return maxY;
  }

  void _scheduleSave() {
    if (!_canPersist) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _persistStrokes);
  }

  Future<void> _persistStrokes() async {
    if (!_canPersist) return;
    final payload = jsonEncode(_strokes.map((e) => e.toJson()).toList());
    await LocalDb.instance.setString(_storageKey, payload);
  }

  void _startStroke(Offset position) {
    final stroke = _Stroke(color: _penColor, width: _penWidth);
    stroke.points.add(position);
    _currentStroke = stroke;
    _lastPoint = position;
    _paintVersion.value += 1;
  }

  void _updateStroke(Offset position) {
    final last = _lastPoint;
    if (last != null && (position - last).distance < _minPointDistance) {
      return;
    }
    _currentStroke?.points.add(position);
    _lastPoint = position;
    _paintVersion.value += 1;
  }

  void _endStroke() {
    final stroke = _currentStroke;
    if (stroke != null && stroke.points.isNotEmpty) {
      _strokes.add(stroke);
      _scheduleSave();
    }
    _currentStroke = null;
    _lastPoint = null;
    _paintVersion.value += 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('노트패드'),
        backgroundColor: const Color(0xFF1B402B),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _NotepadToolbar(
            showLines: _showLines,
            penColor: _penColor,
            penWidth: _penWidth,
            onLinesChanged: (value) => setState(() => _showLines = value),
            onColorChanged: (color) => setState(() => _penColor = color),
            onWidthChanged: (width) => setState(() => _penWidth = width),
            canPersist: _canPersist,
          ),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) => _startStroke(event.localPosition),
                  onPointerMove: (event) => _updateStroke(event.localPosition),
                  onPointerUp: (_) => _endStroke(),
                  onPointerCancel: (_) => _endStroke(),
                  child: SizedBox(
                    height: _canvasHeight,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _NotepadPainter(
                        strokes: _strokes,
                        current: _currentStroke,
                        showLines: _showLines,
                        repaint: _paintVersion,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotepadToolbar extends StatelessWidget {
  const _NotepadToolbar({
    required this.showLines,
    required this.penColor,
    required this.penWidth,
    required this.onLinesChanged,
    required this.onColorChanged,
    required this.onWidthChanged,
    required this.canPersist,
  });

  final bool showLines;
  final Color penColor;
  final double penWidth;
  final ValueChanged<bool> onLinesChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;
  final bool canPersist;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              const Text('줄 표시'),
              const SizedBox(width: 8),
              Switch(value: showLines, onChanged: onLinesChanged),
              const Spacer(),
              if (!canPersist)
                const Text(
                  '웹에서는 저장되지 않습니다.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('펜 색상'),
              const SizedBox(width: 8),
              _ColorChip(
                color: Colors.black,
                selected: penColor == Colors.black,
                onTap: () => onColorChanged(Colors.black),
              ),
              const SizedBox(width: 6),
              _ColorChip(
                color: Colors.blue,
                selected: penColor == Colors.blue,
                onTap: () => onColorChanged(Colors.blue),
              ),
              const SizedBox(width: 6),
              _ColorChip(
                color: Colors.red,
                selected: penColor == Colors.red,
                onTap: () => onColorChanged(Colors.red),
              ),
              const SizedBox(width: 12),
              const Text('굵기'),
              const SizedBox(width: 6),
              Expanded(
                child: Slider(
                  value: penWidth,
                  min: 1,
                  max: 6,
                  divisions: 5,
                  onChanged: onWidthChanged,
                ),
              ),
            ],
          ),
        ],
      ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
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

class _Stroke {
  _Stroke({required this.color, required this.width});

  final Color color;
  final double width;
  final List<Offset> points = <Offset>[];

  Map<String, dynamic> toJson() {
    return {
      'color': color.value,
      'width': width,
      'points': points.map((e) => {'x': e.dx, 'y': e.dy}).toList(),
    };
  }

  factory _Stroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    final points = <Offset>[];
    if (rawPoints is List) {
      for (final item in rawPoints) {
        if (item is Map) {
          final dx = (item['x'] as num?)?.toDouble() ?? 0.0;
          final dy = (item['y'] as num?)?.toDouble() ?? 0.0;
          points.add(Offset(dx, dy));
        }
      }
    }
    final stroke = _Stroke(
      color: Color((json['color'] as num?)?.toInt() ?? Colors.black.value),
      width: (json['width'] as num?)?.toDouble() ?? 3.0,
    );
    stroke.points.addAll(points);
    return stroke;
  }
}

class _NotepadPainter extends CustomPainter {
  _NotepadPainter({
    required this.strokes,
    required this.current,
    required this.showLines,
    Listenable? repaint,
  }) : super(repaint: repaint);

  final List<_Stroke> strokes;
  final _Stroke? current;
  final bool showLines;

  @override
  void paint(Canvas canvas, Size size) {
    if (showLines) {
      final linePaint = Paint()
        ..color = const Color(0xFFE2E2E2)
        ..strokeWidth = 1;
      const gap = 28.0;
      for (var y = gap; y < size.height; y += gap) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    }

    void drawStroke(_Stroke stroke) {
      if (stroke.points.length < 2) return;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      drawStroke(stroke);
    }
    if (current != null) {
      drawStroke(current!);
    }
  }

  @override
  bool shouldRepaint(covariant _NotepadPainter oldDelegate) {
    return oldDelegate.strokes.length != strokes.length ||
        oldDelegate.current != current ||
        oldDelegate.showLines != showLines;
  }
}
