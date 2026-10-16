import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'book_activity_view.dart' show BookActivityKeyScope;

/// Local sample editing/estimation only; no grading, population claim or HTTP.
class BookStatisticsEstimatorView extends StatefulWidget {
  const BookStatisticsEstimatorView({super.key, required this.activity});
  final BookActivity activity;
  @override
  State<BookStatisticsEstimatorView> createState() => _EstimatorState();
}

class _EstimatorState extends State<BookStatisticsEstimatorView> {
  final _values = TextEditingController(), _trials = TextEditingController();
  double? _estimate;
  int _sampleCount = 0, _hints = 0;
  String _feedback = '';
  bool _restored = false;
  BookActivity get a => widget.activity;
  bool get _mean => a.statistics!.mode == 'mean';
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final data = a.statistics!;
    _values.text = _mean ? data.samples.join(', ') : '${data.successes}';
    _trials.text = '${data.trials}';
    _estimate = null;
    _sampleCount = 0;
    _hints = 0;
    _feedback = '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    final saved = BookActivityKeyScope.read(context, a);
    if (saved == null) return;
    _values.text = saved['values'] as String;
    _trials.text = saved['trialsInput'] as String;
    _estimate = saved['estimate'] as double?;
    _sampleCount = saved['sampleCount'] as int;
    _hints = saved['hints'] as int;
    _feedback = saved['feedback'] as String;
  }

  @override
  void didUpdateWidget(covariant BookStatisticsEstimatorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.activity.toJson()) != jsonEncode(a.toJson())) {
      _reset();
    }
  }

  @override
  void dispose() {
    _values.dispose();
    _trials.dispose();
    super.dispose();
  }

  void _changed(String _) => setState(() {
    _estimate = null;
    _sampleCount = 0;
    _feedback = '';
  });
  void _calculate() {
    setState(() {
      _estimate = null;
      _sampleCount = 0;
      _feedback = '';
      if (_mean) {
        final parts = _values.text.trim().split(RegExp(r'[,\s]+'));
        final numbers = parts.map(double.tryParse).toList();
        if (parts.isEmpty ||
            parts.length > 200 ||
            numbers.any((v) => v == null || !v.isFinite || v.abs() > 1e6)) {
          _feedback = '유한한 숫자 1~200개를 쉼표나 공백으로 구분해 주세요. 각 값은 ±1,000,000 이내입니다.';
          return;
        }
        _sampleCount = numbers.length;
        _estimate =
            numbers.fold<double>(0, (sum, v) => sum + v!) / _sampleCount;
      } else {
        final successes = int.tryParse(_values.text.trim()),
            n = int.tryParse(_trials.text.trim());
        if (n == null ||
            n < 1 ||
            n > 100000 ||
            successes == null ||
            successes < 0 ||
            successes > n) {
          _feedback = '표본 크기는 1~100,000의 정수, 조건에 맞는 수는 0~표본 크기의 정수여야 합니다.';
          return;
        }
        _sampleCount = n;
        _estimate = successes / n;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    BookActivityKeyScope.save(context, a, {
      'values': _values.text,
      'trialsInput': _trials.text,
      'estimate': _estimate,
      'sampleCount': _sampleCount,
      'hints': _hints,
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
            a.prompt,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(_mean ? '표본 값으로 모평균을 추정합니다.' : '표본에서 조건에 맞는 비율로 모비율을 추정합니다.'),
          TextField(
            controller: _values,
            maxLength: _mean ? 8000 : 6,
            minLines: 1,
            maxLines: _mean ? 4 : 1,
            keyboardType: _mean
                ? TextInputType.multiline
                : TextInputType.number,
            decoration: InputDecoration(
              labelText: _mean ? '표본 값' : '조건에 맞는 수',
              helperText: _mean ? '쉼표 또는 공백으로 구분' : '0부터 표본 크기까지',
            ),
            onChanged: _changed,
          ),
          if (!_mean)
            TextField(
              controller: _trials,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '표본 크기'),
              onChanged: _changed,
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _calculate,
                style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                child: const Text('추정하기'),
              ),
              OutlinedButton(
                onPressed: () => setState(_reset),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 48),
                ),
                child: const Text('표본 초기화'),
              ),
            ],
          ),
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_feedback.isNotEmpty) Text(_feedback),
                if (_estimate != null) ...[
                  Text('표본 크기: $_sampleCount'),
                  Text(
                    _mean
                        ? '모평균의 추정값: ${_estimate!.toStringAsFixed(4)}'
                        : '모비율의 추정값: ${(_estimate! * 100).toStringAsFixed(2)}%',
                  ),
                  Text(
                    _mean
                        ? '표본평균 = 표본 값의 합 ÷ 표본 크기 (소수 4자리 반올림)'
                        : '표본비율 = 조건에 맞는 수 ÷ 표본 크기 (백분율 소수 2자리 반올림)',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '표본이 달라지면 추정값도 달라질 수 있어요. 표본 추정값이 모집단의 실제 값과 같다고 단정하지 마세요. 무작위·대표성 있는 표본인지도 확인하세요.',
          ),
          for (var i = 0; i < _hints; i++) Text(a.hints[i]),
          if (_hints < a.hints.length)
            TextButton(
              onPressed: () => setState(() => _hints++),
              child: const Text('힌트 한 단계'),
            ),
          const Text('교재 체험 · 시험 점수·등급에 반영되지 않아요. 신뢰구간·유의검정은 제공하지 않습니다.'),
        ],
      ),
    );
  }
}
