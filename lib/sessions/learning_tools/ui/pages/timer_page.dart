import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================
// Vertical Layout Timer / Stopwatch
// Clean centered layout: mode toggle → time display → inputs/laps → controls
// Dark-mode support, Theme integration, haptic feedback
// ============================================================

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> with TickerProviderStateMixin {
  // ── state ──
  bool _isTimerMode = false;
  bool _running = false;
  int _elapsedSeconds = 0;
  int _remainingSeconds = 0;
  int _timerTotalSeconds = 0;
  final List<int> _laps = <int>[];

  Timer? _tickTimer;

  // input controllers
  final _hCtrl = TextEditingController();
  final _mCtrl = TextEditingController();
  final _sCtrl = TextEditingController();

  // animation controllers
  late final AnimationController _pulseController;
  late final AnimationController _modeSwitchController;
  late final AnimationController _digitAnimController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _modeSwitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _digitAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _hCtrl.dispose();
    _mCtrl.dispose();
    _sCtrl.dispose();
    _pulseController.dispose();
    _modeSwitchController.dispose();
    _digitAnimController.dispose();
    super.dispose();
  }

  // ============================================================
  // logic
  // ============================================================

  void _toggleMode(bool timerMode) {
    if (_running) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isTimerMode = timerMode;
      _elapsedSeconds = 0;
      _remainingSeconds = 0;
      _timerTotalSeconds = 0;
      _laps.clear();
      _hCtrl.clear();
      _mCtrl.clear();
      _sCtrl.clear();
    });
    _modeSwitchController.forward(from: 0);
  }

  void _start() {
    if (_running) return;
    HapticFeedback.mediumImpact();
    if (_isTimerMode) {
      final h = int.tryParse(_hCtrl.text) ?? 0;
      final m = int.tryParse(_mCtrl.text) ?? 0;
      final s = int.tryParse(_sCtrl.text) ?? 0;
      final total = h * 3600 + m * 60 + s;
      if (total <= 0) return;
      setState(() {
        _remainingSeconds = total;
        _timerTotalSeconds = total;
      });
    }
    setState(() => _running = true);
    _pulseController.repeat(reverse: true);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      if (_isTimerMode) {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _stop();
          _showTimerComplete();
        }
      } else {
        _elapsedSeconds++;
      }
    });
    _digitAnimController.forward(from: 0);
  }

  void _pause() {
    HapticFeedback.mediumImpact();
    _tickTimer?.cancel();
    _pulseController.stop();
    setState(() => _running = false);
  }

  void _stop() {
    _tickTimer?.cancel();
    _pulseController.stop();
    _pulseController.value = 0;
    setState(() => _running = false);
  }

  void _reset() {
    HapticFeedback.lightImpact();
    _stop();
    setState(() {
      _elapsedSeconds = 0;
      _remainingSeconds = 0;
      _timerTotalSeconds = 0;
      _laps.clear();
      _hCtrl.clear();
      _mCtrl.clear();
      _sCtrl.clear();
    });
  }

  void _recordLap() {
    if (!_running || _isTimerMode) return;
    HapticFeedback.lightImpact();
    setState(() => _laps.insert(0, _elapsedSeconds));
  }

  void _addDuration(int seconds) {
    if (_running) return;
    HapticFeedback.selectionClick();
    if (_isTimerMode) {
      final current = _remainingSeconds + seconds;
      setState(() {
        _remainingSeconds = current;
        _timerTotalSeconds = current;
      });
      _hCtrl.text = (current ~/ 3600).toString();
      _mCtrl.text = ((current % 3600) ~/ 60).toString().padLeft(2, '0');
      _sCtrl.text = (current % 60).toString().padLeft(2, '0');
    }
  }

  void _showTimerComplete() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '타이머 완료',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '설정한 시간이 경과했습니다',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '확인',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar (80px white) ──
            Container(
              height: 80,
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF3B3B3B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    '타이머',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 48), // balance back-button width
                ],
              ),
            ),

            // ── Main vertical body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Mode toggle
                    _buildModeToggle(cs, isDark),
                    const SizedBox(height: 28),

                    // 2. Big time display (focal point)
                    _buildTimeDisplay(cs, isDark),
                    const SizedBox(height: 28),

                    // 3. Timer inputs (only in timer mode)
                    if (_isTimerMode) ...[
                      _buildTimerInputs(cs, isDark),
                      const SizedBox(height: 24),
                    ],

                    // 4. Laps list (only in stopwatch mode with laps)
                    if (!_isTimerMode && _laps.isNotEmpty) ...[
                      _buildLapsList(cs, isDark),
                      const SizedBox(height: 24),
                    ],

                    // 5. Control buttons
                    _buildControls(cs),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── mode toggle (segmented, centered, compact) ──
  Widget _buildModeToggle(ColorScheme cs, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: '스톱워치',
              icon: Icons.timer_outlined,
              selected: !_isTimerMode,
              onTap: () => _toggleMode(false),
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: '타이머',
              icon: Icons.hourglass_empty_rounded,
              selected: _isTimerMode,
              onTap: () => _toggleMode(true),
            ),
          ),
        ],
      ),
    );
  }

  // ── big centered time display (THE focal point) ──
  Widget _buildTimeDisplay(ColorScheme cs, bool isDark) {
    final displaySeconds = _isTimerMode ? _remainingSeconds : _elapsedSeconds;
    final progress = _isTimerMode && _timerTotalSeconds > 0
        ? _remainingSeconds / _timerTotalSeconds
        : null;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final bgColor = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF2F2F7);
    final textPrimary = cs.onSurface;
    final textSecondary = cs.onSurfaceVariant;
    final textTertiary = isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // status dot
          if (_running)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 8 + _pulseController.value * 4,
                  height: 8 + _pulseController.value * 4,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.4 * _pulseController.value),
                        blurRadius: 12,
                        spreadRadius: 4 * _pulseController.value,
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: textTertiary,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(height: 20),

          // big time text
          AnimatedBuilder(
            animation: _digitAnimController,
            builder: (context, child) {
              final scale = 1.0 - _digitAnimController.value * 0.02;
              return Transform.scale(
                scale: scale,
                child: Text(
                  _formatTime(displaySeconds),
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w300,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: textPrimary,
                    letterSpacing: -2,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            _isTimerMode ? '남은 시간' : '경과 시간',
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),

          // 6. Progress ring (only in timer mode, below time display)
          if (progress != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              height: 160,
              child: _ProgressRing(
                progress: progress,
                strokeWidth: 8,
                backgroundColor: bgColor,
                foregroundColor: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── timer inputs (full width) ──
  Widget _buildTimerInputs(ColorScheme cs, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final inputBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '시간 설정',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _TimeInputField(
                controller: _hCtrl,
                label: '시',
                enabled: !_running,
                inputBg: inputBg,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 24,
                    color: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
                  ),
                ),
              ),
              _TimeInputField(
                controller: _mCtrl,
                label: '분',
                enabled: !_running,
                inputBg: inputBg,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 24,
                    color: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
                  ),
                ),
              ),
              _TimeInputField(
                controller: _sCtrl,
                label: '초',
                enabled: !_running,
                inputBg: inputBg,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickAddButton(
                label: '+30분',
                onTap: () => _addDuration(30 * 60),
                enabled: !_running,
              ),
              _QuickAddButton(
                label: '+1시간',
                onTap: () => _addDuration(60 * 60),
                enabled: !_running,
              ),
              _QuickAddButton(
                label: '+2시간',
                onTap: () => _addDuration(2 * 60 * 60),
                enabled: !_running,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── laps list ──
  Widget _buildLapsList(ColorScheme cs, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '랩 기록',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              Text(
                '${_laps.length}개',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._laps.asMap().entries.map((entry) {
            final index = entry.key;
            final lapTime = entry.value;
            final prevTime = index < _laps.length - 1 ? _laps[index + 1] : 0;
            final split = lapTime - prevTime;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: index == 0
                    ? cs.primary.withValues(alpha: isDark ? 0.15 : 0.06)
                    : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '랩 ${_laps.length - index}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: index == 0 ? FontWeight.w600 : FontWeight.w400,
                      color: cs.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _formatTime(lapTime),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '+${_formatTime(split)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── controls (centered row) ──
  Widget _buildControls(ColorScheme cs) {
    final destructive = cs.error;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Reset (secondary)
        _ControlButton(
          icon: Icons.refresh_rounded,
          label: '리셋',
          color: cs.onSurfaceVariant,
          onTap: _reset,
          size: 56,
        ),
        const SizedBox(width: 24),

        // Start/Pause (big primary)
        GestureDetector(
          onTap: _running ? _pause : _start,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _running ? destructive : cs.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_running ? destructive : cs.primary).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: cs.onPrimary,
              size: 36,
            ),
          ),
        ),
        const SizedBox(width: 24),

        // Lap (tertiary, stopwatch) or +5min (tertiary, timer)
        if (!_isTimerMode)
          _ControlButton(
            icon: Icons.flag_rounded,
            label: '랩',
            color: cs.primary,
            onTap: _recordLap,
            size: 56,
            enabled: _running,
          )
        else
          _ControlButton(
            icon: Icons.add_rounded,
            label: '+5분',
            color: cs.primary,
            onTap: () => _addDuration(5 * 60),
            size: 56,
            enabled: _running && _remainingSeconds > 0,
          ),
      ],
    );
  }
}

// ============================================================
// sub-widgets
// ============================================================

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeInputField extends StatelessWidget {
  const _TimeInputField({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.inputBg,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final Color inputBg;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            hintText: '00',
            hintStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            suffix: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
        ),
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? cs.primaryContainer.withValues(alpha: isDark ? 0.3 : 1.0)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? cs.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.size,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: enabled
                  ? color.withValues(alpha: 0.1)
                  : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: enabled ? color : cs.onSurfaceVariant,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: enabled ? color : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// circular progress ring
// ============================================================

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(
        progress: progress.clamp(0.0, 1.0),
        strokeWidth: strokeWidth,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      -sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
