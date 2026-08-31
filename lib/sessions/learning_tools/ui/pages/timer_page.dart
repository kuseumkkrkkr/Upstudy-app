import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  bool _isTimerMode = false;
  bool _running = false;
  int _elapsedSeconds = 0;
  int _remainingSeconds = 0;
  int _timerTotalSeconds = 0;
  final List<int> _laps = <int>[];

  Timer? _tickTimer;

  final _hCtrl = TextEditingController();
  final _mCtrl = TextEditingController();
  final _sCtrl = TextEditingController();

  @override
  void dispose() {
    _tickTimer?.cancel();
    _hCtrl.dispose();
    _mCtrl.dispose();
    _sCtrl.dispose();
    super.dispose();
  }

  void _toggleMode(bool timerMode) {
    if (_running || _isTimerMode == timerMode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isTimerMode = timerMode;
      _resetState();
    });
  }

  void _start() {
    if (_running) return;
    HapticFeedback.mediumImpact();

    if (_isTimerMode && _remainingSeconds <= 0) {
      final total = _parseInputSeconds();
      if (total <= 0) return;
      _setTimerSeconds(total);
    }

    if (_isTimerMode && _timerTotalSeconds <= 0) {
      _timerTotalSeconds = _remainingSeconds;
    }

    _tickTimer?.cancel();
    setState(() => _running = true);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;

    if (_isTimerMode) {
      if (_remainingSeconds <= 1) {
        _tickTimer?.cancel();
        setState(() {
          _running = false;
          _remainingSeconds = 0;
        });
        _showTimerComplete();
        return;
      }

      setState(() => _remainingSeconds -= 1);
      return;
    }

    setState(() => _elapsedSeconds += 1);
  }

  void _pause() {
    if (!_running) return;
    HapticFeedback.lightImpact();
    _tickTimer?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    HapticFeedback.selectionClick();
    _tickTimer?.cancel();
    setState(_resetState);
  }

  void _resetState() {
    _running = false;
    _elapsedSeconds = 0;
    _remainingSeconds = 0;
    _timerTotalSeconds = 0;
    _laps.clear();
    _hCtrl.clear();
    _mCtrl.clear();
    _sCtrl.clear();
  }

  void _recordLap() {
    if (!_running || _isTimerMode) return;
    HapticFeedback.selectionClick();
    setState(() => _laps.insert(0, _elapsedSeconds));
  }

  void _addTimerSeconds(int seconds) {
    if (!_isTimerMode || seconds <= 0) return;
    HapticFeedback.selectionClick();

    final next = _remainingSeconds + seconds;
    setState(() {
      _remainingSeconds = next;
      _timerTotalSeconds = (_running ? _timerTotalSeconds : 0) + seconds;
      if (_timerTotalSeconds < _remainingSeconds) {
        _timerTotalSeconds = _remainingSeconds;
      }
    });
    _syncInputsFromSeconds(_remainingSeconds);
  }

  int _parseInputSeconds() {
    final h = int.tryParse(_hCtrl.text) ?? 0;
    final m = int.tryParse(_mCtrl.text) ?? 0;
    final s = int.tryParse(_sCtrl.text) ?? 0;
    return h * 3600 + m * 60 + s;
  }

  void _setTimerSeconds(int seconds) {
    if (seconds < 0) return;
    setState(() {
      _remainingSeconds = seconds;
      _timerTotalSeconds = seconds;
    });
    _syncInputsFromSeconds(seconds);
  }

  void _syncInputsFromSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    _hCtrl.text = h == 0 ? '' : h.toString();
    _mCtrl.text = m == 0 ? '' : m.toString().padLeft(2, '0');
    _sCtrl.text = s == 0 ? '' : s.toString().padLeft(2, '0');
  }

  void _showTimerComplete() {
    HapticFeedback.mediumImpact();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('타이머 종료'),
          content: const Text('설정한 시간이 모두 지났습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
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

  String _formatLapDelta(int index) {
    final current = _laps[index];
    final previous = index + 1 < _laps.length ? _laps[index + 1] : 0;
    return _formatTime(current - previous);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mobile = isStudentDensityMobile(context);
    final progress = _isTimerMode && _timerTotalSeconds > 0
        ? (_remainingSeconds / _timerTotalSeconds).clamp(0.0, 1.0)
        : null;

    return Scaffold(
      key: const ValueKey('timer-tool-page'),
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (headerContext) => Ios26TopBar(
                brandColor: StudentDensityTokens.dark,
                onBack: () => Navigator.maybePop(context),
                onMenu: () => toggleAppDrawer(headerContext),
                onTitleTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/student/dashboard',
                  (route) => false,
                ),
                showMenuWithBack: true,
                showLevelIndicator: false,
                items: studentTopNavItems(
                  context,
                  active: StudentTopDestination.learning,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: StudentDensityPage(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StudentDensityPageHeader(
                            eyebrow: 'LEARNING TOOL',
                            title: '집중 타이머',
                            description: '스톱워치와 타이머를 한 화면에서 기록합니다.',
                            showMobileDescription: true,
                            action: StudentDensityButton(
                              label: '도구 닫기',
                              icon: Icons.close_rounded,
                              onPressed: () => Navigator.maybePop(context),
                            ),
                          ),
                          SizedBox(height: mobile ? 16 : 22),
                          _buildModeToggle(cs),
                          const SizedBox(height: 14),
                          _buildDisplayCard(cs, progress),
                          const SizedBox(height: 14),
                          if (_isTimerMode) ...[
                            _buildTimerSetup(cs),
                            const SizedBox(height: 14),
                          ],
                          if (!_isTimerMode && _laps.isNotEmpty) ...[
                            _buildLapsCard(cs),
                            const SizedBox(height: 14),
                          ],
                          _buildControls(cs),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle(ColorScheme cs) {
    return StudentDensitySurface(
      key: const ValueKey('timer-mode-toggle'),
      padding: const EdgeInsets.all(4),
      radius: StudentDensityTokens.radiusMedium,
      child: Row(
        children: [
          Expanded(
            child: _ModeToggleButton(
              label: '스톱워치',
              icon: Icons.timer_outlined,
              selected: !_isTimerMode,
              onTap: () => _toggleMode(false),
            ),
          ),
          Expanded(
            child: _ModeToggleButton(
              label: '타이머',
              icon: Icons.hourglass_bottom_rounded,
              selected: _isTimerMode,
              onTap: () => _toggleMode(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayCard(ColorScheme cs, double? progress) {
    final seconds = _isTimerMode ? _remainingSeconds : _elapsedSeconds;
    const accentSoft = Color(0xFFF4F4F5);

    return StudentDensitySurface(
      key: const ValueKey('timer-display-card'),
      padding: EdgeInsets.fromLTRB(
        isStudentDensityMobile(context) ? 18 : 24,
        22,
        isStudentDensityMobile(context) ? 18 : 24,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _running
                      ? const Color(0xFF09090B)
                      : const Color(0xFFD4D4D8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _running ? '진행 중' : '대기 중',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _running
                      ? const Color(0xFF09090B)
                      : cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isTimerMode ? '남은 시간' : '경과 시간',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF09090B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatTime(seconds),
              style: TextStyle(
                fontSize: 68,
                fontWeight: FontWeight.w300,
                color: cs.onSurface,
                letterSpacing: -2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isTimerMode
                ? '입력값이나 프리셋으로 시간을 빠르게 맞출 수 있습니다.'
                : '필요할 때 랩을 찍어 구간 시간을 확인합니다.',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: const Color(0xFFE9EDF0),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF09090B),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${(progress * 100).round()}% 남음',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF09090B),
                  ),
                ),
                const Spacer(),
                Text(
                  '총 ${_formatTime(_timerTotalSeconds)}',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimerSetup(ColorScheme cs) {
    return StudentDensitySurface(
      key: const ValueKey('timer-setup-card'),
      padding: EdgeInsets.all(isStudentDensityMobile(context) ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '시간 설정',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '직접 입력하거나 자주 쓰는 시간으로 바로 맞춥니다.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimeInputField(
                  controller: _hCtrl,
                  label: '시',
                  enabled: !_running,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeInputField(
                  controller: _mCtrl,
                  label: '분',
                  enabled: !_running,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeInputField(
                  controller: _sCtrl,
                  label: '초',
                  enabled: !_running,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PresetChip(
                label: '+10분',
                onTap: () => _addTimerSeconds(10 * 60),
              ),
              _PresetChip(
                label: '+30분',
                onTap: () => _addTimerSeconds(30 * 60),
              ),
              _PresetChip(
                label: '+1시간',
                onTap: () => _addTimerSeconds(60 * 60),
              ),
              _PresetChip(
                label: '+2시간',
                onTap: () => _addTimerSeconds(2 * 60 * 60),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLapsCard(ColorScheme cs) {
    return StudentDensitySurface(
      padding: EdgeInsets.all(isStudentDensityMobile(context) ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '랩 기록',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${_laps.length}개',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _laps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final isLatest = index == 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isLatest
                        ? StudentDensityTokens.dark.withValues(alpha: 0.08)
                        : StudentDensityTokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '랩 ${_laps.length - index}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isLatest
                              ? StudentDensityTokens.dark
                              : cs.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(_laps[index]),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '+${_formatLapDelta(index)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ColorScheme cs) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _ActionButton(
          label: '리셋',
          icon: Icons.refresh_rounded,
          onTap: _reset,
          filled: false,
        ),
        _ActionButton(
          label: _running ? '일시정지' : '시작',
          icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onTap: _running ? _pause : _start,
          filled: true,
        ),
        _ActionButton(
          label: _isTimerMode ? '+5분' : '랩 추가',
          icon: _isTimerMode ? Icons.add_rounded : Icons.flag_rounded,
          onTap: _isTimerMode ? () => _addTimerSeconds(5 * 60) : _recordLap,
          filled: false,
          enabled: _isTimerMode || _running,
        ),
      ],
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  const _ModeToggleButton({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF09090B) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : const Color(0xFF52525B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF52525B),
                ),
              ),
            ],
          ),
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
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF7F8F9) : const Color(0xFFF0F2F3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: '00',
              hintStyle: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE4E4E7)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF27272A),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? (filled ? Colors.white : const Color(0xFF27272A))
        : const Color(0xFF98A1A8);
    final background = enabled
        ? (filled ? const Color(0xFF09090B) : Colors.white)
        : const Color(0xFFF0F2F3);

    return SizedBox(
      width: 152,
      height: 54,
      child: FilledButton.tonal(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: const Color(0xFFF0F2F3),
          disabledForegroundColor: const Color(0xFF98A1A8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: filled ? const Color(0xFF09090B) : const Color(0xFFE4E4E7),
            ),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
