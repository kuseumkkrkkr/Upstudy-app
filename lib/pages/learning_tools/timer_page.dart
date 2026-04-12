import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  static const int _maxTimerSeconds = 99 * 3600 + 59 * 60 + 59; // 99:59:59

  Timer? _ticker;
  bool _isTimerMode = false;
  bool _running = false;

  int _elapsedSeconds = 0; // stopwatch
  int _remainingSeconds = 0; // timer countdown
  int _timerTotalSeconds = 0; // for progress bar

  final TextEditingController _hourController = TextEditingController(text: '0');
  final TextEditingController _minuteController = TextEditingController(text: '5');
  final TextEditingController _secondController = TextEditingController(text: '0');

  final List<int> _laps = [];

  @override
  void initState() {
    super.initState();
    _setTimerFromInputs();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  int _clampSeconds(int value) {
    if (value < 0) return 0;
    if (value > _maxTimerSeconds) return _maxTimerSeconds;
    return value;
  }

  int _parseTimerInputSeconds() {
    final hours = int.tryParse(_hourController.text.trim()) ?? 0;
    final minutes = int.tryParse(_minuteController.text.trim()) ?? 0;
    final seconds = int.tryParse(_secondController.text.trim()) ?? 0;

    final int h = hours.clamp(0, 99).toInt();
    final int m = minutes.clamp(0, 59).toInt();
    final int s = seconds.clamp(0, 59).toInt();

    return _clampSeconds(h * 3600 + m * 60 + s);
  }

  void _syncInputsFromSeconds(int seconds) {
    final safe = _clampSeconds(seconds);
    final h = safe ~/ 3600;
    final m = (safe % 3600) ~/ 60;
    final s = safe % 60;
    _hourController.text = h.toString().padLeft(2, '0');
    _minuteController.text = m.toString().padLeft(2, '0');
    _secondController.text = s.toString().padLeft(2, '0');
  }

  void _setTimerFromInputs() {
    final total = _parseTimerInputSeconds();
    _timerTotalSeconds = total;
    _remainingSeconds = total;
  }

  void _toggleMode(bool timerMode) {
    if (_running) return;
    setState(() {
      _isTimerMode = timerMode;
      _ticker?.cancel();
      _running = false;
      if (_isTimerMode) {
        _setTimerFromInputs();
      } else {
        _elapsedSeconds = 0;
        _laps.clear();
      }
    });
  }

  void _start() {
    if (_running) return;
    if (_isTimerMode) {
      if (_remainingSeconds <= 0) {
        _setTimerFromInputs();
      } else if (_timerTotalSeconds <= 0) {
        _timerTotalSeconds = _remainingSeconds;
      }
      if (_remainingSeconds <= 0) return;
    }

    setState(() => _running = true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_isTimerMode) {
          if (_remainingSeconds > 0) {
            _remainingSeconds -= 1;
          }
          if (_remainingSeconds <= 0) {
            _running = false;
            _ticker?.cancel();
          }
        } else {
          _elapsedSeconds += 1;
        }
      });
    });
  }

  void _pause() {
    if (!_running) return;
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      if (_isTimerMode) {
        _setTimerFromInputs();
      } else {
        _elapsedSeconds = 0;
        _laps.clear();
      }
    });
  }

  void _recordLap() {
    if (_isTimerMode || !_running) return;
    setState(() {
      _laps.insert(0, _elapsedSeconds);
    });
  }

  void _addDuration(int seconds) {
    if (!_isTimerMode) return;
    final newRemaining = _clampSeconds(_remainingSeconds + seconds);
    final newTotal = _clampSeconds(_timerTotalSeconds + seconds);
    setState(() {
      _remainingSeconds = newRemaining;
      _timerTotalSeconds = newTotal > 0 ? newTotal : newRemaining;
    });
    _syncInputsFromSeconds(_remainingSeconds);
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Widget _buildModeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Stopwatch'),
          selected: !_isTimerMode,
          onSelected: _running ? null : (_) => _toggleMode(false),
        ),
        const SizedBox(width: 12),
        ChoiceChip(
          label: const Text('Timer'),
          selected: _isTimerMode,
          onSelected: _running ? null : (_) => _toggleMode(true),
        ),
      ],
    );
  }

  Widget _buildStopwatchControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _running ? _pause : _start,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(110, 44),
              ),
              child: Text(_running ? '정지' : '시작'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _recordLap,
              style: OutlinedButton.styleFrom(minimumSize: const Size(110, 44)),
              child: const Text('기록'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _reset,
              style: TextButton.styleFrom(minimumSize: const Size(90, 44)),
              child: const Text('초기화'),
            ),
          ],
        ),
        if (_laps.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: ListView.separated(
              itemCount: _laps.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final lapSeconds = _laps[index];
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lap ${_laps.length - index}'),
                    Text(
                      _formatTime(lapSeconds),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimerInputs() {
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );

    Widget _buildField(
      String label,
      TextEditingController controller,
    ) {
      return SizedBox(
        width: 90,
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              enabled: !_running,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: inputDecoration,
              onChanged: (_) {
                if (_running) return;
                setState(_setTimerFromInputs);
              },
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildField('시', _hourController),
            const SizedBox(width: 10),
            _buildField('분', _minuteController),
            const SizedBox(width: 10),
            _buildField('초', _secondController),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _addDuration(30 * 60),
              child: const Text('+30분'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _addDuration(60 * 60),
              child: const Text('+1시간'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _addDuration(2 * 60 * 60),
              child: const Text('+2시간'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _running ? _pause : _start,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(130, 44),
          ),
          child: Text(_running ? '일시정지' : '시작'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: _reset,
          style: OutlinedButton.styleFrom(minimumSize: const Size(110, 44)),
          child: const Text('초기화'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTimer = _isTimerMode;
    final displaySeconds = isTimer ? _remainingSeconds : _elapsedSeconds;
    final double? progress = isTimer && _timerTotalSeconds > 0
        ? (1 - (_remainingSeconds / _timerTotalSeconds)).clamp(0.0, 1.0).toDouble()
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('스톱워치 / 타이머'),
        backgroundColor: const Color(0xFF1B402B),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeToggle(),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    _formatTime(displaySeconds),
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (progress != null)
                  Center(
                    child: SizedBox(
                      width: 280,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE0E6E2),
                          color: const Color(0xFF1B402B),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (!isTimer) ...[
                  _buildStopwatchControls(),
                ] else ...[
                  _buildTimerInputs(),
                  const SizedBox(height: 20),
                  _buildTimerControls(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
