import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/shared/data/models/book_vector_inner_product.dart';

import 'book_activity_view.dart';

/// Native, bounded 2D vector projection and inner-product exploration.
class BookVectorInnerProductView extends StatefulWidget {
  const BookVectorInnerProductView({super.key, required this.activity});
  final BookActivity activity;

  @override
  State<BookVectorInnerProductView> createState() =>
      _BookVectorInnerProductViewState();
}

class _BookVectorInnerProductViewState
    extends State<BookVectorInnerProductView> {
  late BookVectorInnerProduct _values;
  int _step = 0, _hints = 0;
  String? _guess;
  String _feedback = '먼저 내적의 부호를 예상한 뒤 각도를 바꿔 보세요.';
  bool _restored = false;

  BookActivity get _activity => widget.activity;

  @override
  void initState() {
    super.initState();
    _values = _activity.vectorInnerProduct!;
  }

  @override
  void didUpdateWidget(covariant BookVectorInnerProductView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.activity.toJson()) !=
        jsonEncode(_activity.toJson())) {
      _values = _activity.vectorInnerProduct!;
      _step = 0;
      _hints = 0;
      _guess = null;
      _feedback = '먼저 내적의 부호를 예상한 뒤 각도를 바꿔 보세요.';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    final saved = BookActivityKeyScope.read(context, _activity);
    if (saved != null) {
      _values = BookVectorInnerProduct.fromJson(saved);
      _step = saved['step'] as int? ?? 0;
      _hints = saved['hints'] as int? ?? 0;
      _guess = saved['guess'] as String?;
      _feedback = saved['feedback'] as String? ?? _feedback;
    }
  }

  double get _radians => _values.angleDeg * math.pi / 180;
  double get _projection => _values.vLength * math.cos(_radians);
  double get _product => _values.uLength * _projection;
  String get _sign => _values.angleDeg < 90
      ? 'positive'
      : _values.angleDeg == 90
      ? 'zero'
      : 'negative';
  String _fmt(double value) =>
      value.abs() < .005 ? '0.00' : value.toStringAsFixed(2);

  void _change({int? u, int? v, int? angle}) => setState(() {
    _values = BookVectorInnerProduct(
      uLength: u ?? _values.uLength,
      vLength: v ?? _values.vLength,
      angleDeg: angle ?? _values.angleDeg,
    );
    _step = 0;
    _guess = null;
    _feedback = '값을 바꿨습니다. 먼저 내적의 부호를 예상해 보세요.';
  });

  void _reset() => setState(() {
    _values = _activity.vectorInnerProduct!;
    _step = 0;
    _hints = 0;
    _guess = null;
    _feedback = '처음 조건으로 돌아왔습니다. 먼저 내적의 부호를 예상하세요.';
  });

  void _answer(String value) => setState(() {
    _guess = value;
    _feedback = value == _sign
        ? '맞아요. θ=${_values.angleDeg}°에서 cosθ의 부호가 내적의 부호를 결정합니다.'
        : '다시 확인해 보세요. θ=${_values.angleDeg}°일 때 점선 투영이 u와 같은 쪽인지 살펴보세요.';
  });

  String get _stageText => switch (_step) {
    0 => '1단계: 결과를 먼저 예상하세요. θ가 90°보다 작은지, 같은지, 큰지 확인합니다.',
    1 => '2단계: v를 u 방향으로 투영한 부호 있는 길이는 |v|cosθ = ${_fmt(_projection)}입니다.',
    _ =>
      '3단계: 투영에 |u|=${_values.uLength}을 곱하면 u·v=|u||v|cosθ = ${_fmt(_product)}입니다.',
  };

  Widget _slider(
    String label,
    int value,
    int min,
    int max,
    int divisions,
    ValueChanged<int> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: $value'),
      Slider(
        value: value.toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: divisions,
        label: '$value',
        onChanged: (v) => onChanged(v.round()),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    BookActivityKeyScope.save(context, _activity, {
      ..._values.toJson(),
      'step': _step,
      'hints': _hints,
      'guess': _guess,
      'feedback': _feedback,
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _slider(
            '벡터 u의 크기 |u|',
            _values.uLength,
            1,
            5,
            4,
            (v) => _change(u: v),
          ),
          _slider(
            '벡터 v의 크기 |v|',
            _values.vLength,
            1,
            5,
            4,
            (v) => _change(v: v),
          ),
          _slider(
            '끼인각 θ (도)',
            _values.angleDeg,
            0,
            180,
            12,
            (v) => _change(angle: v),
          ),
          Semantics(
            label:
                '크기 ${_values.uLength}인 u, 크기 ${_values.vLength}인 v, 끼인각 ${_values.angleDeg}도. v의 u 방향 투영 ${_fmt(_projection)}, 내적 ${_fmt(_product)}.',
            image: true,
            child: AspectRatio(
              aspectRatio: 800 / 360,
              child: CustomPaint(
                painter: _InnerProductPainter(
                  uLength: _values.uLength.toDouble(),
                  vLength: _values.vLength.toDouble(),
                  angle: _radians,
                ),
              ),
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              '투영 |v|cosθ = ${_fmt(_projection)} · 내적 u·v = ${_fmt(_product)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Text('현재 θ=${_values.angleDeg}°에서 u·v의 부호는?'),
          Wrap(
            spacing: 8,
            children: [
              _choice('positive', '양수'),
              _choice('zero', '0'),
              _choice('negative', '음수'),
            ],
          ),
          Semantics(liveRegion: true, child: Text(_feedback)),
          const SizedBox(height: 8),
          Text(_stageText, key: const ValueKey('inner-product-stage')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _step > 0 ? () => setState(() => _step--) : null,
                child: const Text('이전 단계'),
              ),
              OutlinedButton(
                onPressed: _step < 2 ? () => setState(() => _step++) : null,
                child: const Text('다음 단계'),
              ),
              OutlinedButton(onPressed: _reset, child: const Text('처음 조건')),
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
            '교재 체험 · 시험 점수·등급에 반영되지 않아요.',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _choice(String key, String label) => OutlinedButton(
    onPressed: () => _answer(key),
    style: OutlinedButton.styleFrom(
      backgroundColor: _guess == key ? const Color(0xffe4e4e7) : null,
    ),
    child: Text(label),
  );
}

class _InnerProductPainter extends CustomPainter {
  const _InnerProductPainter({
    required this.uLength,
    required this.vLength,
    required this.angle,
  });
  final double uLength, vLength, angle;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 800, size.height / 360) * 45;
    final origin = Offset(size.width * .34, size.height * .78);
    Offset screen(double x, double y) => origin + Offset(x * scale, -y * scale);
    final axis = Paint()
      ..color = const Color(0xff94a3b8)
      ..strokeWidth = 1.5;
    canvas.drawLine(screen(-5.4, 0), screen(5.4, 0), axis);
    canvas.drawLine(screen(0, -1.2), screen(0, 5.4), axis);
    final uEnd = screen(uLength, 0);
    final vX = vLength * math.cos(angle), vY = vLength * math.sin(angle);
    final vEnd = screen(vX, vY);
    final projectionEnd = screen(vX, 0);
    _arrow(canvas, screen(0, 0), uEnd, const Color(0xff2358c5), 'u', scale);
    _arrow(canvas, screen(0, 0), vEnd, const Color(0xff087e75), 'v', scale);
    final projection = Paint()
      ..color = const Color(0xff9a5b00)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(vEnd.dx, vEnd.dy)
      ..lineTo(projectionEnd.dx, projectionEnd.dy);
    canvas.drawPath(path, projection);
    final dotPaint = Paint()..color = const Color(0xff9a5b00);
    canvas.drawCircle(projectionEnd, 3, dotPaint);
    _label(
      canvas,
      '투영 ${_signed(vLength * math.cos(angle))}',
      projectionEnd + const Offset(-8, 14),
    );
    _label(canvas, 'θ=${(angle * 180 / math.pi).round()}°', screen(.8, .4));
  }

  String _signed(double value) =>
      value.abs() < .005 ? '0.00' : value.toStringAsFixed(2);

  void _arrow(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color,
    String label,
    double scale,
  ) {
    final delta = to - from;
    if (delta.distance < .1) return;
    final direction = delta / delta.distance;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to - direction * 6, paint);
    final side = Offset(-direction.dy, direction.dx);
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - direction.dx * 10 + side.dx * 5,
        to.dy - direction.dy * 10 + side.dy * 5,
      )
      ..lineTo(
        to.dx - direction.dx * 10 - side.dx * 5,
        to.dy - direction.dy * 10 - side.dy * 5,
      )
      ..close();
    canvas.drawPath(head, Paint()..color = color);
    _label(canvas, label, to + Offset(5, -10));
  }

  void _label(Canvas canvas, String value, Offset point) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          color: Color(0xff1f2937),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 150);
    text.paint(canvas, point);
  }

  @override
  bool shouldRepaint(_InnerProductPainter old) =>
      uLength != old.uLength || vLength != old.vLength || angle != old.angle;
}
