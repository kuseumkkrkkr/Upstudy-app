import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'book_discrete_experiment_view.dart';
import 'book_statistics_estimator_view.dart';
import 'book_right_triangle_view.dart';
import 'book_coordinate_point_view.dart';

/// Reader-owned keys reparent practice state across responsive shells. No storage.
class BookActivityKeyScope extends InheritedWidget {
  const BookActivityKeyScope({
    super.key,
    required this.keys,
    required this.states,
    required this.bookId,
    required super.child,
  });
  final Map<String, GlobalKey> keys;
  final Map<String, Map<String, Object?>> states;
  final String bookId;
  static Map<String, Object?>? read(
    BuildContext context,
    BookActivity activity,
  ) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BookActivityKeyScope>();
    if (scope == null) return null;
    final saved = scope.states['${scope.bookId}\u0000${activity.id}'];
    return saved?['definition'] == jsonEncode(activity.toJson()) ? saved : null;
  }

  static void save(
    BuildContext context,
    BookActivity activity,
    Map<String, Object?> value,
  ) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BookActivityKeyScope>();
    if (scope == null) return;
    scope.states['${scope.bookId}\u0000${activity.id}'] = {
      'definition': jsonEncode(activity.toJson()),
      ...value,
    };
  }

  static Key keyFor(BuildContext context, String id) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BookActivityKeyScope>();
    return scope?.keys.putIfAbsent(id, () => GlobalKey()) ?? ValueKey(id);
  }

  @override
  bool updateShouldNotify(BookActivityKeyScope oldWidget) =>
      !identical(keys, oldWidget.keys);
}

/// Disposable practice state; no student/OVR writes, author scripts, or autoplay.
class BookActivityView extends StatefulWidget {
  const BookActivityView({super.key, required this.activity});
  final BookActivity activity;
  @override
  State<BookActivityView> createState() => _BookActivityViewState();
}

class _BookActivityViewState extends State<BookActivityView>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin<BookActivityView> {
  final _answer = TextEditingController();
  Timer? _timer;
  late double _p, _x;
  int _step = 0, _hints = 0;
  int? _choice;
  String _feedback = '';
  bool _restored = false;
  BookActivity get a => widget.activity;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _p = a.p;
    _x = a.x;
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _reset() {
    _stop();
    _answer.clear();
    _p = a.p;
    _x = a.x;
    _step = 0;
    _hints = 0;
    _choice = null;
    _feedback = '';
  }

  @override
  void didUpdateWidget(covariant BookActivityView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.activity.toJson()) != jsonEncode(a.toJson())) {
      _reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restored &&
        !{
          'discreteExperiment',
          'statisticsEstimator',
          'rightTriangle',
          'coordinatePoint',
          'coordinateWalk',
        }.contains(a.kind)) {
      _restored = true;
      final saved = BookActivityKeyScope.read(context, a);
      if (saved != null) {
        _answer.text = saved['answer'] as String;
        _choice = saved['choice'] as int?;
        _feedback = saved['feedback'] as String;
        _step = saved['step'] as int;
        _hints = saved['hints'] as int;
        _p = saved['p'] as double;
        _x = saved['x'] as double;
      }
    }
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) setState(_stop);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _answer.dispose();
    super.dispose();
  }

  void _play() {
    if (_timer != null) {
      setState(_stop);
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _feedback = '동작 줄이기 설정: 슬라이더로 직접 확인하세요.');
      return;
    }
    final watch = Stopwatch()..start();
    setState(() {
      _x = -4;
      _feedback = '';
    });
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) {
        _stop();
        return;
      }
      if (ModalRoute.of(context)?.isCurrent == false ||
          !TickerMode.valuesOf(context).enabled ||
          MediaQuery.disableAnimationsOf(context)) {
        setState(_stop);
        return;
      }
      setState(() {
        _x = -4 + 8 * (watch.elapsedMilliseconds / 5000).clamp(0, 1);
        if (watch.elapsedMilliseconds >= 5000) _stop();
      });
    });
  }

  void _grade() {
    final numeric = BookActivity.numericInput(_answer.text);
    if (a.options.isNotEmpty && _choice == null) {
      setState(() => _feedback = '답을 선택해 주세요.');
      return;
    }
    if (a.options.isEmpty && numeric == null) {
      setState(() => _feedback = '유한한 숫자 또는 분수로 입력해 주세요.');
      return;
    }
    final correct = a.options.isNotEmpty
        ? _choice == a.correctIndex
        : (numeric! - a.answer!).abs() <= a.tolerance;
    setState(
      () => _feedback = correct ? a.correctFeedback : a.incorrectFeedback,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (a.kind == 'discreteExperiment') {
      return BookDiscreteExperimentView(activity: a);
    }
    if (a.kind == 'statisticsEstimator') {
      return BookStatisticsEstimatorView(activity: a);
    }
    if (a.kind == 'rightTriangle') {
      return BookRightTriangleView(activity: a);
    }
    if (a.kind == 'coordinatePoint' || a.kind == 'coordinateWalk') {
      return BookCoordinatePointView(activity: a);
    }
    BookActivityKeyScope.save(context, a, {
      'answer': _answer.text,
      'choice': _choice,
      'feedback': _feedback,
      'step': _step,
      'hints': _hints,
      'p': _p,
      'x': _x,
    });
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffd4d4d8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            a.prompt,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (a.kind == 'parabolaDistance') ..._geometry(),
          if (a.kind == 'quiz') ...[
            if (a.options.isNotEmpty)
              for (var i = 0; i < a.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _choice = i;
                      _feedback = '';
                    }),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: _choice == i
                          ? const Color(0xffe4e4e7)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _choice == i
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(a.options[i])),
                      ],
                    ),
                  ),
                )
            else
              TextField(
                controller: _answer,
                maxLength: 80,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: '답 입력',
                  hintText: '숫자 또는 분수 (예: 1/2)',
                ),
                onChanged: (_) => setState(() => _feedback = ''),
                onSubmitted: (_) => _grade(),
              ),
            FilledButton(onPressed: _grade, child: const Text('답 확인')),
            const Text(
              '교재 연습: 시험 점수·등급에 반영되지 않아요.',
              style: TextStyle(fontSize: 12),
            ),
          ],
          if (a.kind == 'steps') ...[
            Text('${_step + 1} / ${a.steps.length}'),
            Text(a.steps[_step], style: const TextStyle(fontSize: 16)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _step == 0
                        ? null
                        : () => setState(() => _step--),
                    child: const Text('이전 단계'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _step == a.steps.length - 1
                        ? null
                        : () => setState(() => _step++),
                    child: const Text('다음 단계'),
                  ),
                ),
              ],
            ),
          ],
          if (_feedback.isNotEmpty)
            Semantics(liveRegion: true, child: Text(_feedback)),
          for (var i = 0; i < _hints; i++) Text(a.hints[i]),
          Wrap(
            spacing: 8,
            children: [
              if (_hints < a.hints.length)
                TextButton(
                  onPressed: () => setState(() => _hints++),
                  child: const Text('힌트 한 단계'),
                ),
              TextButton(
                onPressed: () => setState(_reset),
                child: const Text('초기화'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _geometry() {
    final y = _x * _x / (4 * _p);
    final distance = math.sqrt(_x * _x + math.pow(y - _p, 2));
    return [
      const Text('파란 점을 좌우로 끌거나 슬라이더를 조작하세요.'),
      LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, 240);
          final point = _ParabolaPainter.position(size, _x, y);
          return SizedBox(
            height: 240,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _ParabolaPainter(_p, _x)),
                ),
                Positioned(
                  left: point.dx - 24,
                  top: point.dy - 24,
                  child: Semantics(
                    label:
                        '점 P, x ${_x.toStringAsFixed(2)}, y ${y.toStringAsFixed(2)}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (event) => setState(() {
                        _stop();
                        _x =
                            (_x +
                                    event.delta.dx /
                                        _ParabolaPainter.unitScale(size))
                                .clamp(-4, 4);
                      }),
                      child: const SizedBox(width: 48, height: 48),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      Text(
        'P (${_x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}) · F (0, ${_p.toStringAsFixed(2)})',
      ),
      Text(
        'PF ${distance.toStringAsFixed(2)} · 준선까지 ${(y + _p).abs().toStringAsFixed(2)}',
      ),
      Text(
        (distance - (y + _p).abs()).abs() < 1e-8
            ? '두 거리가 같습니다.'
            : '거리 조건을 다시 확인하세요.',
      ),
      Text('p = ${_p.toStringAsFixed(2)}'),
      Slider(
        semanticFormatterCallback: (v) => 'p ${v.toStringAsFixed(2)}',
        value: _p,
        min: .5,
        max: 3,
        divisions: 5,
        onChanged: (v) => setState(() {
          _stop();
          _p = v;
        }),
      ),
      Text('x = ${_x.toStringAsFixed(2)}'),
      Slider(
        semanticFormatterCallback: (v) => 'x ${v.toStringAsFixed(2)}',
        value: _x,
        min: -4,
        max: 4,
        divisions: 32,
        onChanged: (v) => setState(() {
          _stop();
          _x = v;
        }),
      ),
      OutlinedButton(
        onPressed: _play,
        child: Text(_timer == null ? '재생' : '정지'),
      ),
    ];
  }
}

class _ParabolaPainter extends CustomPainter {
  _ParabolaPainter(this.p, this.x);
  final double p, x;
  // One graph unit has the same pixel length on both axes: equal distances
  // must also look equal. Independent x/y stretching would falsify the lesson.
  static double unitScale(Size s) =>
      math.min((s.width - 48) / 10, (s.height - 48) / 14);
  static Offset position(Size s, double x, double y) =>
      Offset(s.width / 2 + x * unitScale(s), 24 + (10 - y) * unitScale(s));
  @override
  void paint(Canvas canvas, Size size) {
    Offset at(double x, double y) => position(size, x, y);
    final paint = Paint()
      ..strokeWidth = 1
      ..color = const Color(0xffa1a1aa);
    canvas.drawLine(at(-5, 0), at(5, 0), paint);
    canvas.drawLine(at(0, -4), at(0, 10), paint);
    paint
      ..color = const Color(0xff7c3aed)
      ..strokeWidth = 2;
    final left = at(-5, -p), right = at(5, -p);
    for (var dx = left.dx; dx < right.dx; dx += 10) {
      canvas.drawLine(
        Offset(dx, left.dy),
        Offset(math.min(dx + 5, right.dx), left.dy),
        paint,
      );
    }
    final path = Path();
    for (var i = 0; i <= 80; i++) {
      final u = -4 + i / 10;
      final q = at(u, u * u / (4 * p));
      if (i == 0) {
        path.moveTo(q.dx, q.dy);
      } else {
        path.lineTo(q.dx, q.dy);
      }
    }
    paint
      ..color = const Color(0xff2563eb)
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);
    final point = at(x, x * x / (4 * p)), focus = at(0, p);
    paint.color = const Color(0xff15803d);
    canvas.drawLine(point, focus, paint);
    paint.color = const Color(0xff7c3aed);
    canvas.drawLine(point, at(x, -p), paint);
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xffea580c);
    canvas.drawCircle(focus, 5, paint);
    paint.color = const Color(0xff2563eb);
    canvas.drawCircle(point, 7, paint);
    for (final label in [(point, 'P'), (focus, 'F'), (at(-4.8, -p), '준선')]) {
      final text = TextPainter(
        text: TextSpan(
          text: label.$2,
          style: const TextStyle(color: Colors.black, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, label.$1 + const Offset(7, -16));
    }
  }

  @override
  bool shouldRepaint(covariant _ParabolaPainter oldDelegate) =>
      p != oldDelegate.p || x != oldDelegate.x;
}
