import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/book_coordinate_point.dart';
import 'book_activity_view.dart';

/// Integer point dragging/keyboard exploration; no executable math or network.
class BookCoordinatePointView extends StatefulWidget {
  const BookCoordinatePointView({super.key, required this.activity});
  final BookActivity activity;
  @override
  State<BookCoordinatePointView> createState() => _PointState();
}

class _PointState extends State<BookCoordinatePointView> {
  final _plot = GlobalKey();
  final _focus = FocusNode();
  late BookCoordinatePoint _point;
  int _step = 0, _hints = 0;
  bool _restored = false;
  Offset _dragOffset = Offset.zero;
  void _reset() {
    _point = widget.activity.point!;
    _step = 0;
    _hints = 0;
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BookCoordinatePointView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.activity.toJson()) !=
        jsonEncode(widget.activity.toJson())) {
      _reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    final saved = BookActivityKeyScope.read(context, widget.activity);
    if (saved != null) {
      _point = BookCoordinatePoint.fromJson({'x': saved['x'], 'y': saved['y']});
      _step = saved['step'] as int;
      _hints = saved['hints'] as int;
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => const Offset(-1, 0),
      LogicalKeyboardKey.arrowRight => const Offset(1, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, 1),
      LogicalKeyboardKey.arrowDown => const Offset(0, -1),
      _ => null,
    };
    if (delta == null) return KeyEventResult.ignored;
    setState(() => _point = _point.move(delta.dx.toInt(), delta.dy.toInt()));
    return KeyEventResult.handled;
  }

  void _drag(Offset globalPosition) {
    final box = _plot.currentContext!.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(globalPosition) - _dragOffset;
    final unit = (box.size.width - 48) / 10;
    setState(
      () => _point = BookCoordinatePoint.snapped(
        (local.dx - box.size.width / 2) / unit,
        (box.size.height / 2 - local.dy) / unit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    BookActivityKeyScope.save(context, activity, {
      ..._point.toJson(),
      'step': _step,
      'hints': _hints,
    });
    final stage = switch (_step) {
      0 => '1단계: 먼저 가로로 움직입니다. x=${_point.x}',
      1 => '2단계: 가로 위치를 유지하고 세로로 움직입니다. y=${_point.y}',
      _ => '3단계: 도착점은 (${_point.x},${_point.y})입니다. 좌표 순서는 가로, 세로입니다.',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffd4d4d8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            activity.prompt,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const Text('점 A를 끌거나 선택한 뒤 방향키로 움직이세요. 한 칸씩 -5~5 범위에서 이동합니다.'),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final unit = (constraints.maxWidth - 48) / 10;
                    final center = constraints.maxWidth / 2;
                    return Stack(
                      key: _plot,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _PlanePainter(_point)),
                        ),
                        Positioned(
                          left: center + _point.x * unit - 24,
                          top: center - _point.y * unit - 24,
                          width: 48,
                          height: 48,
                          child: Focus(
                            focusNode: _focus,
                            includeSemantics: false,
                            onKeyEvent: _key,
                            onFocusChange: (_) => setState(() {}),
                            child: Semantics(
                              button: true,
                              focusable: true,
                              focused: _focus.hasFocus,
                              label: '점 A 이동',
                              value:
                                  'x ${_point.x}, y ${_point.y}, ${_point.quadrant}',
                              onTap: _focus.requestFocus,
                              child: GestureDetector(
                                key: const ValueKey('coordinate-point-handle'),
                                excludeFromSemantics: true,
                                behavior: HitTestBehavior.opaque,
                                onTap: _focus.requestFocus,
                                onPanDown: (d) {
                                  _dragOffset =
                                      d.localPosition - const Offset(24, 24);
                                },
                                onPanStart: (d) {
                                  _focus.requestFocus();
                                  _drag(d.globalPosition);
                                },
                                onPanUpdate: (d) => _drag(d.globalPosition),
                                onPanEnd: (_) => _dragOffset = Offset.zero,
                                onPanCancel: () => _dragOffset = Offset.zero,
                                child: Center(
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xffc2410c),
                                      border: Border.all(
                                        color: _focus.hasFocus
                                            ? Colors.black
                                            : Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text('A(${_point.x}, ${_point.y}) · ${_point.quadrant}'),
          ),
          Text('${_point.horizontal}, ${_point.vertical} 이동한 점입니다.'),
          Text('x: ${_point.x}'),
          Slider(
            value: _point.x.toDouble(),
            min: -5,
            max: 5,
            divisions: 10,
            semanticFormatterCallback: (v) => 'x좌표 ${v.round()}',
            onChanged: (v) => setState(
              () => _point = BookCoordinatePoint.bounded(v.round(), _point.y),
            ),
          ),
          Text('y: ${_point.y}'),
          Slider(
            value: _point.y.toDouble(),
            min: -5,
            max: 5,
            divisions: 10,
            semanticFormatterCallback: (v) => 'y좌표 ${v.round()}',
            onChanged: (v) => setState(
              () => _point = BookCoordinatePoint.bounded(_point.x, v.round()),
            ),
          ),
          Semantics(liveRegion: true, child: Text(stage)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _step = (_step + 1) % 3),
                child: const Text('이동 순서 보기'),
              ),
              OutlinedButton(
                onPressed: () => setState(_reset),
                child: const Text('처음 위치로'),
              ),
              if (_hints < activity.hints.length)
                TextButton(
                  onPressed: () => setState(() => _hints++),
                  child: const Text('힌트 한 단계'),
                ),
            ],
          ),
          for (var i = 0; i < _hints; i++) Text(activity.hints[i]),
          const Text('교재 체험 · 시험 점수·등급에 반영되지 않아요.'),
        ],
      ),
    );
  }
}

class _PlanePainter extends CustomPainter {
  _PlanePainter(this.point);
  final BookCoordinatePoint point;
  @override
  void paint(Canvas canvas, Size size) {
    final unit = (size.width - 48) / 10, center = size.width / 2;
    final pen = Paint()
      ..strokeWidth = 1
      ..color = const Color(0xffe4e4e7);
    void label(String value, Offset offset) {
      final text = TextPainter(
        text: TextSpan(
          text: value,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xff52525b),
            fontFamily: 'NotoSansKR',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          offset.dx.clamp(0, math.max(0, size.width - text.width)),
          offset.dy.clamp(0, math.max(0, size.height - text.height)),
        ),
      );
    }

    for (var n = -5; n <= 5; n++) {
      canvas.drawLine(
        Offset(center + n * unit, 24),
        Offset(center + n * unit, size.height - 24),
        pen,
      );
      canvas.drawLine(
        Offset(24, center - n * unit),
        Offset(size.width - 24, center - n * unit),
        pen,
      );
      if (n != 0) {
        label('$n', Offset(center + n * unit - 4, center + 3));
        label('$n', Offset(center + 4, center - n * unit - 6));
      }
    }
    pen
      ..color = const Color(0xff71717a)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(24, center), Offset(size.width - 24, center), pen);
    canvas.drawLine(Offset(center, 24), Offset(center, size.height - 24), pen);
    label('x', Offset(size.width - 14, center - 16));
    label('y', Offset(center + 4, 4));
    label(
      'A(${point.x}, ${point.y})',
      Offset(
        center + point.x * unit + 12,
        center - point.y * unit + (point.y < 0 ? 10 : -22),
      ),
    );
  }

  @override
  bool shouldRepaint(_PlanePainter oldDelegate) =>
      point.x != oldDelegate.point.x || point.y != oldDelegate.point.y;
}
