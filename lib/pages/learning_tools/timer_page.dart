import 'dart:async';

import 'package:flutter/material.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  Timer? _ticker;
  bool _isTimerMode = false;
  bool _running = false;
  int _elapsedSeconds = 0;
  int _remainingSeconds = 0;

  final TextEditingController _timerInputController =
      TextEditingController(text: '300');

  @override
  void dispose() {
    _ticker?.cancel();
    _timerInputController.dispose();
    super.dispose();
  }

  void _toggleMode(bool timerMode) {
    if (_running) return;
    setState(() {
      _isTimerMode = timerMode;
      _elapsedSeconds = 0;
      _remainingSeconds = _parseInputSeconds();
    });
  }

  int _parseInputSeconds() {
    final parsed = int.tryParse(_timerInputController.text.trim());
    if (parsed == null || parsed <= 0) return 0;
    return parsed;
  }

  void _start() {
    if (_running) return;
    if (_isTimerMode) {
      final input = _parseInputSeconds();
      if (input <= 0) return;
      _remainingSeconds = input;
    }
    setState(() => _running = true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_isTimerMode) {
          if (_remainingSeconds > 0) {
            _remainingSeconds -= 1;
          } else {
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
      _elapsedSeconds = 0;
      _remainingSeconds = _parseInputSeconds();
    });
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final displaySeconds = _isTimerMode ? _remainingSeconds : _elapsedSeconds;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('타이머'),
        backgroundColor: const Color(0xFF1B402B),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: const Text('스톱워치'),
                  selected: !_isTimerMode,
                  onSelected: _running ? null : (_) => _toggleMode(false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('타이머'),
                  selected: _isTimerMode,
                  onSelected: _running ? null : (_) => _toggleMode(true),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isTimerMode)
              Row(
                children: [
                  const Text('초 단위 설정'),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _timerInputController,
                      enabled: !_running,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) {
                        if (!_running) {
                          setState(() {
                            _remainingSeconds = _parseInputSeconds();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 30),
            Center(
              child: Text(
                _formatTime(displaySeconds),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _running ? _pause : _start,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B402B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 44),
                  ),
                  child: Text(_running ? '일시정지' : '시작'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(120, 44),
                  ),
                  child: const Text('초기화'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
