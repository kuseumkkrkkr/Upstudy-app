import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/book_vector_operation.dart';

import 'book_activity_view.dart';

/// Native, bounded plane-vector addition/subtraction/scalar multiplication.
/// Local interaction only; the authored JavaScript is never loaded or run.
class BookVectorOperationsView extends StatefulWidget {
  const BookVectorOperationsView({super.key, required this.activity});

  final BookActivity activity;

  @override
  State<BookVectorOperationsView> createState() => _VectorOperationsState();
}

class _VectorOperationsState extends State<BookVectorOperationsView>
    with WidgetsBindingObserver {
  late BookVectorOperation _vector;
  int _step = 0;
  int _hints = 0;
  Timer? _timer;
  bool _restored = false;

  BookActivity get _activity => widget.activity;

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _reset() {
    _stop();
    _vector = _activity.vectorOperation!;
    _step = 0;
    _hints = 0;
  }

  @override
  void initState() {
    super.initState();
    _reset();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant BookVectorOperationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.activity.toJson()) !=
        jsonEncode(_activity.toJson())) {
      _reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restored) {
      _restored = true;
      final saved = BookActivityKeyScope.read(context, _activity);
      if (saved != null) {
        _vector = BookVectorOperation.fromJson({
          'operation': saved['operation'],
          'ux': saved['ux'],
          'uy': saved['uy'],
          'vx': saved['vx'],
          'vy': saved['vy'],
          'alpha': saved['alpha'],
        });
        _step = saved['step'] as int;
        _hints = saved['hints'] as int? ?? 0;
      }
    }
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled ||
        ModalRoute.of(context)?.isCurrent == false) {
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
    super.dispose();
  }

  void _setVector(BookVectorOperation vector) {
    _stop();
    _vector = vector;
    _step = 3;
  }

  void _setOperation(String value) {
    if (value == _vector.operation) return;
    _stop();
    setState(() {
      _vector = BookVectorOperation(
        operation: value,
        ux: _vector.ux,
        uy: _vector.uy,
        vx: _vector.vx,
        vy: _vector.vy,
        alpha: _vector.alpha,
      );
      _step = 0;
    });
  }

  void _change({int? ux, int? uy, int? vx, int? vy, double? alpha}) {
    setState(() {
      _setVector(
        BookVectorOperation(
          operation: _vector.operation,
          ux: ux ?? _vector.ux,
          uy: uy ?? _vector.uy,
          vx: vx ?? _vector.vx,
          vy: vy ?? _vector.vy,
          alpha: alpha ?? _vector.alpha,
        ),
      );
    });
  }

  void _play() {
    if (_timer != null) {
      setState(_stop);
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _step = 3);
      return;
    }
    setState(() {
      _step = 0;
      _timer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
        if (!mounted ||
            MediaQuery.disableAnimationsOf(context) ||
            !TickerMode.valuesOf(context).enabled ||
            ModalRoute.of(context)?.isCurrent == false) {
          timer.cancel();
          _timer = null;
          return;
        }
        setState(() {
          if (_step >= 3) {
            timer.cancel();
            _timer = null;
          } else {
            _step++;
          }
        });
      });
    });
  }

  List<_VectorSegment> _segments() {
    final u = Offset(_vector.ux.toDouble(), _vector.uy.toDouble());
    final v = Offset(_vector.vx.toDouble(), _vector.vy.toDouble());
    final result = switch (_vector.operation) {
      'add' => u + v,
      'subtract' => u - v,
      _ => u * _vector.alpha,
    };
    final operationLines = switch (_vector.operation) {
      'add' => <_VectorSegment>[
        _VectorSegment(Offset.zero, u, const Color(0xff315da8), 'u'),
        _VectorSegment(u, result, const Color(0xffc45a36), 'v'),
        _VectorSegment(
          Offset.zero,
          result,
          const Color(0xff168b83),
          'u+v',
          dashed: true,
        ),
      ],
      'subtract' => <_VectorSegment>[
        _VectorSegment(Offset.zero, u, const Color(0xff315da8), 'u'),
        _VectorSegment(u, result, const Color(0xffc45a36), '−v', dashed: true),
        _VectorSegment(
          Offset.zero,
          result,
          const Color(0xff168b83),
          'u−v',
          dashed: true,
        ),
      ],
      _ => <_VectorSegment>[
        _VectorSegment(Offset.zero, u, const Color(0xff315da8), 'u'),
        _VectorSegment(
          Offset.zero,
          result,
          const Color(0xff168b83),
          '${_vector.alpha}u',
          dashed: true,
        ),
      ],
    };
    return switch (_step) {
      0 => operationLines.sublist(operationLines.length - 1),
      1 => operationLines.sublist(0, 1),
      2 => operationLines.sublist(
        0,
        operationLines.length < 2 ? operationLines.length : 2,
      ),
      _ => operationLines,
    };
  }

  (double, double) get _result => switch (_vector.operation) {
    'add' => (
      (_vector.ux + _vector.vx).toDouble(),
      (_vector.uy + _vector.vy).toDouble(),
    ),
    'subtract' => (
      (_vector.ux - _vector.vx).toDouble(),
      (_vector.uy - _vector.vy).toDouble(),
    ),
    _ => (_vector.alpha * _vector.ux, _vector.alpha * _vector.uy),
  };

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  String get _resultText => '(${_number(_result.$1)}, ${_number(_result.$2)})';

  String get _formula => switch (_vector.operation) {
    'add' =>
      'u=(${_vector.ux}, ${_vector.uy}), v=(${_vector.vx}, ${_vector.vy})  →  u+v=$_resultText',
    'subtract' =>
      'u=(${_vector.ux}, ${_vector.uy}), v=(${_vector.vx}, ${_vector.vy})  →  u−v=$_resultText',
    _ =>
      'u=(${_vector.ux}, ${_vector.uy}), α=${_number(_vector.alpha)}  →  αu=$_resultText',
  };

  String get _explanation => switch (_vector.operation) {
    'add' => '파란 u의 끝에 주황 v를 이어 그립니다. 처음 점과 마지막 점을 잇는 초록 화살표가 합입니다.',
    'subtract' => 'u−v=u+(−v)입니다. 주황 점선 −v를 u의 끝에서 시작하고, 초록 화살표가 차입니다.',
    _ when _vector.alpha == 0 => '계수가 0이면 결과는 영벡터입니다.',
    _ when _vector.alpha < 0 => '계수가 음수이므로 결과는 u와 반대 방향이며 길이는 |α|배입니다.',
    _ => '계수가 양수이므로 결과는 u와 같은 방향이며 길이는 α배입니다.',
  };

  static const _stages = [
    '결과 벡터를 먼저 예상하세요.',
    '첫 번째 이동 u를 놓았습니다.',
    '연산에 필요한 화살표를 이어 붙였습니다.',
    '처음과 끝을 잇는 결과 성분을 확인하세요.',
  ];

  Widget _componentSlider(String label, int value, ValueChanged<int> change) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $value'),
          Slider(
            value: value.toDouble(),
            min: -4,
            max: 4,
            divisions: 8,
            label: '$value',
            semanticFormatterCallback: (v) => '$label ${v.round()}',
            onChanged: (v) => change(v.round()),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final vector = _vector;
    BookActivityKeyScope.save(context, _activity, {
      ...vector.toJson(),
      'step': _step,
      'hints': _hints,
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
            _activity.prompt,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: vector.operation,
            decoration: const InputDecoration(labelText: '연산'),
            items: const [
              DropdownMenuItem(value: 'add', child: Text('덧셈 u + v')),
              DropdownMenuItem(value: 'subtract', child: Text('뺄셈 u − v')),
              DropdownMenuItem(value: 'scalar', child: Text('실수배 αu')),
            ],
            onChanged: (value) {
              if (value != null) _setOperation(value);
            },
          ),
          if (vector.operation == 'scalar') ...[
            Text('실수배 계수 α: ${vector.alpha}'),
            Slider(
              value: vector.alpha,
              min: -2,
              max: 2,
              divisions: 8,
              label: '${vector.alpha}',
              semanticFormatterCallback: (v) =>
                  '실수배 계수 ${v.toStringAsFixed(1)}',
              onChanged: (v) => _change(alpha: (v * 2).round() / 2),
            ),
          ],
          _componentSlider('u의 x성분', vector.ux, (v) => _change(ux: v)),
          _componentSlider('u의 y성분', vector.uy, (v) => _change(uy: v)),
          if (vector.operation != 'scalar') ...[
            _componentSlider('v의 x성분', vector.vx, (v) => _change(vx: v)),
            _componentSlider('v의 y성분', vector.vy, (v) => _change(vy: v)),
          ],
          Semantics(
            label: '좌표평면의 평면 벡터 ${_formula.replaceAll('→', '결과')}',
            image: true,
            child: AspectRatio(
              aspectRatio: 760 / 440,
              child: CustomPaint(painter: _VectorPlanePainter(_segments())),
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              _formula,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(_explanation),
          Text(
            '단계 ${_step + 1}/4 · ${_stages[_step]}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _step > 0
                    ? () => setState(() {
                        _stop();
                        _step--;
                      })
                    : null,
                child: const Text('이전 단계'),
              ),
              OutlinedButton(
                onPressed: _step < 3
                    ? () => setState(() {
                        _stop();
                        _step++;
                      })
                    : null,
                child: const Text('다음 단계'),
              ),
              OutlinedButton(
                onPressed: _play,
                child: Text(_timer == null ? '단계 보기' : '일시정지'),
              ),
              OutlinedButton(
                onPressed: () => setState(_reset),
                child: const Text('기본 벡터'),
              ),
            ],
          ),
          if (_activity.hints.isNotEmpty) ...[
            for (var i = 0; i < _hints; i++) Text(_activity.hints[i]),
            if (_hints < _activity.hints.length)
              TextButton(
                onPressed: () => setState(() => _hints++),
                child: const Text('힌트 한 단계'),
              ),
          ],
          Text(
            '결과 벡터 $_resultText · 교재 체험 · 시험 점수·등급에 반영되지 않아요.',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _VectorSegment {
  const _VectorSegment(
    this.from,
    this.to,
    this.color,
    this.label, {
    this.dashed = false,
  });
  final Offset from, to;
  final Color color;
  final String label;
  final bool dashed;
}

class _VectorPlanePainter extends CustomPainter {
  const _VectorPlanePainter(this.segments);
  final List<_VectorSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    const designWidth = 760.0, unit = 23.0;
    final scale = size.width / designWidth;
    final center = Offset(size.width / 2, size.height / 2);
    Offset screen(Offset p) => Offset(
      center.dx + p.dx * unit * scale,
      center.dy - p.dy * unit * scale,
    );
    final gridPaint = Paint()..strokeWidth = scale;
    for (var n = -8; n <= 8; n++) {
      gridPaint.color = n == 0
          ? const Color(0xff64748b)
          : const Color(0xffe5ebf3);
      canvas.drawLine(
        screen(Offset(n.toDouble(), -8)),
        screen(Offset(n.toDouble(), 8)),
        gridPaint,
      );
      canvas.drawLine(
        screen(Offset(-8, n.toDouble())),
        screen(Offset(8, n.toDouble())),
        gridPaint,
      );
      if (n != 0 && n.isEven) {
        _text(
          canvas,
          '$n',
          screen(Offset(n.toDouble(), -.45)),
          scale,
          const Color(0xff607086),
        );
        _text(
          canvas,
          '$n',
          screen(Offset(.25, n.toDouble())),
          scale,
          const Color(0xff607086),
        );
      }
    }
    _text(
      canvas,
      'x',
      screen(const Offset(8.25, -.45)),
      scale,
      const Color(0xff18253b),
    );
    _text(
      canvas,
      'y',
      screen(const Offset(.2, 8.25)),
      scale,
      const Color(0xff18253b),
    );
    for (final segment in segments) {
      final from = screen(segment.from), to = screen(segment.to);
      final paint = Paint()
        ..color = segment.color
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round;
      final delta = to - from;
      final distance = delta.distance;
      if (distance > 0) {
        final unitVector = delta / distance;
        if (segment.dashed) {
          for (
            double start = 0;
            start < distance - 8 * scale;
            start += 12 * scale
          ) {
            canvas.drawLine(
              from + unitVector * start,
              from +
                  unitVector *
                      math.min(start + 7 * scale, distance - 5 * scale),
              paint,
            );
          }
        } else {
          canvas.drawLine(from, to - unitVector * 6 * scale, paint);
        }
        final normal = Offset(-unitVector.dy, unitVector.dx);
        final arrow = Path()
          ..moveTo(to.dx, to.dy)
          ..lineTo(
            to.dx - unitVector.dx * 11 * scale + normal.dx * 5 * scale,
            to.dy - unitVector.dy * 11 * scale + normal.dy * 5 * scale,
          )
          ..lineTo(
            to.dx - unitVector.dx * 11 * scale - normal.dx * 5 * scale,
            to.dy - unitVector.dy * 11 * scale - normal.dy * 5 * scale,
          )
          ..close();
        canvas.drawPath(arrow, Paint()..color = segment.color);
        _text(
          canvas,
          segment.label,
          to + Offset(5 * scale, -8 * scale),
          scale,
          segment.color,
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset point,
    double scale,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11 * scale,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, point);
  }

  @override
  bool shouldRepaint(_VectorPlanePainter oldDelegate) =>
      segments.length != oldDelegate.segments.length ||
      List.generate(segments.length, (i) {
        final a = segments[i], b = oldDelegate.segments[i];
        return a.from != b.from ||
            a.to != b.to ||
            a.color != b.color ||
            a.label != b.label ||
            a.dashed != b.dashed;
      }).any((changed) => changed);
}
