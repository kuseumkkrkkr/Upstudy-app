import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'book_activity_view.dart' show BookActivityKeyScope;

/// Local finite-outcome experiment. RNG/counts are never sent to student APIs.
class BookDiscreteExperimentView extends StatefulWidget {
  const BookDiscreteExperimentView({
    super.key,
    required this.activity,
    this.random,
  });
  final BookActivity activity;
  final math.Random? random;
  @override
  State<BookDiscreteExperimentView> createState() => _ExperimentState();
}

class _ExperimentState extends State<BookDiscreteExperimentView> {
  late final math.Random _random;
  late List<int> _counts;
  int _trials = 0, _successes = 0, _last = -1, _hints = 0;
  bool _restored = false;
  BookActivity get a => widget.activity;
  @override
  void initState() {
    super.initState();
    _random = widget.random ?? math.Random();
    _reset();
  }

  void _reset() {
    _counts = List.filled(a.experiment!.outcomes.length, 0);
    _trials = 0;
    _successes = 0;
    _last = -1;
    _hints = 0;
  }

  @override
  void didUpdateWidget(covariant BookDiscreteExperimentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.activity.toJson()) != jsonEncode(a.toJson())) {
      _reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    final saved = BookActivityKeyScope.read(context, a);
    if (saved != null) {
      _counts = List<int>.from(saved['counts'] as List<int>);
      _trials = saved['trials'] as int;
      _successes = saved['successes'] as int;
      _last = saved['last'] as int;
      _hints = saved['hints'] as int;
    }
  }

  void _draw(int batch) {
    final experiment = a.experiment!;
    final amount = math.min(batch, experiment.maxTrials - _trials);
    if (amount <= 0) return;
    setState(() {
      for (var i = 0; i < amount; i++) {
        _last = experiment.sample(_random);
        _counts[_last]++;
        _trials++;
        if (experiment.outcomes[_last].success) _successes++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final experiment = a.experiment!;
    BookActivityKeyScope.save(context, a, {
      'counts': List<int>.of(_counts),
      'trials': _trials,
      'successes': _successes,
      'last': _last,
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
            a.prompt,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('시행 횟수: $_trials'),
                Text(
                  _trials == 0
                      ? '상대도수: 시행 전'
                      : '상대도수: $_successes/$_trials = ${(_successes / _trials).toStringAsFixed(3)}',
                ),
                if (_last >= 0)
                  Text('이번 결과: ${experiment.outcomes[_last].label}'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final batch in experiment.batchSizes)
                FilledButton(
                  onPressed: _trials >= experiment.maxTrials
                      ? null
                      : () => _draw(batch),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  child: Text('$batch회 시행'),
                ),
              OutlinedButton(
                onPressed: () => setState(_reset),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 48),
                ),
                child: const Text('실험 초기화'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Text alternatives preserve exact observed counts without color/graphics.
          for (var i = 0; i < experiment.outcomes.length; i++)
            Text('${experiment.outcomes[i].label}: ${_counts[i]}회'),
          if (_trials >= experiment.maxTrials)
            Text('최대 ${experiment.maxTrials}회에 도달했어요. 초기화하여 다시 실험하세요.'),
          for (var i = 0; i < _hints; i++) Text(a.hints[i]),
          if (_hints < a.hints.length)
            TextButton(
              onPressed: () => setState(() => _hints++),
              child: const Text('힌트 한 단계'),
            ),
          const Text(
            '확률 체험이며 시험 점수·등급에 반영되지 않아요.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
