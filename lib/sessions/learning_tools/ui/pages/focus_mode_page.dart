import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

/// 집중 시간을 설정하고, 진행 중에는 남은 시간과 해제 상태만 보여주는 화면이다.
/// 필요한 변수: 선택 시간, 남은 초, 집중·해제 타이머.
/// 작동 원리: 설정 화면과 실행 화면을 흑백의 동일한 세션 카드 구조로 전환한다.
class FocusModePage extends StatefulWidget {
  const FocusModePage({super.key});

  @override
  State<FocusModePage> createState() => _FocusModePageState();
}

class _FocusModePageState extends State<FocusModePage> {
  static const int _maxMinutes = 720;
  int _selectedMinutes = 60;
  int _remainingSeconds = 0;
  bool _running = false;
  bool _unlocking = false;
  int _unlockCountdown = 0;
  Timer? _timer;
  Timer? _unlockTimer;

  @override
  void dispose() {
    _timer?.cancel();
    _unlockTimer?.cancel();
    super.dispose();
  }

  /// 선택한 시간을 초로 바꾸고 1초 간격으로 줄여 집중 세션을 시작한다.
  /// 필요한 변수: [_selectedMinutes], [_remainingSeconds], [_timer].
  void _startFocus() {
    _timer?.cancel();
    setState(() {
      _running = true;
      _remainingSeconds = _selectedMinutes * 60;
      _unlocking = false;
      _unlockCountdown = 0;
    });
    HapticFeedback.mediumImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _stopFocus();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  /// 진행·해제 타이머를 모두 정리하고 설정 화면으로 되돌린다.
  /// 필요한 변수: 실행 중인 타이머와 세션 상태 값.
  void _stopFocus() {
    _timer?.cancel();
    _unlockTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _running = false;
      _remainingSeconds = 0;
      _unlocking = false;
      _unlockCountdown = 0;
    });
  }

  /// 실수로 집중을 끝내지 않도록 3초 확인 카운트다운을 시작한다.
  /// 필요한 변수: [_unlockCountdown], [_unlockTimer].
  void _startUnlock() {
    HapticFeedback.lightImpact();
    _unlockTimer?.cancel();
    setState(() {
      _unlocking = true;
      _unlockCountdown = 3;
    });
    _unlockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_unlockCountdown <= 1) {
        _stopFocus();
        return;
      }
      setState(() => _unlockCountdown--);
    });
  }

  /// 해제 확인을 취소하고 집중 세션을 유지한다.
  /// 필요한 변수: [_unlockTimer], [_unlocking].
  void _cancelUnlock() {
    _unlockTimer?.cancel();
    setState(() {
      _unlocking = false;
      _unlockCountdown = 0;
    });
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatSelectedTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h == 0
        ? '$m분'
        : m == 0
        ? '$h시간'
        : '$h시간 $m분';
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Scaffold(
      key: const ValueKey('focus-tool-page'),
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
                            title: '집중 모드',
                            description: '정한 시간 동안 학습에만 집중할 수 있도록 합니다.',
                            showMobileDescription: true,
                            action: StudentDensityButton(
                              label: '도구 닫기',
                              icon: Icons.close_rounded,
                              onPressed: () => Navigator.maybePop(context),
                            ),
                          ),
                          SizedBox(height: mobile ? 16 : 22),
                          _running ? _buildRunning() : _buildSetup(),
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

  /// 시간 선택 컨트롤을 레퍼런스의 흰색 카드 안에 구성한다.
  /// 필요한 변수: [_selectedMinutes]와 프리셋 목록.
  Widget _buildSetup() {
    return _ToolSurface(
      key: const ValueKey('focus-setup-surface'),
      child: Column(
        children: [
          const Text(
            '설정한 시간 동안 방해를 차단합니다',
            style: TextStyle(color: Color(0xFF73737C)),
          ),
          const SizedBox(height: 42),
          Text(
            _formatSelectedTime(_selectedMinutes),
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w300,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 34),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 5,
              activeTrackColor: const Color(0xFF09090B),
              inactiveTrackColor: const Color(0xFFE4E4E7),
              thumbColor: const Color(0xFF09090B),
              overlayColor: Colors.black.withValues(alpha: .08),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _selectedMinutes.toDouble(),
              min: 30,
              max: _maxMinutes.toDouble(),
              divisions: (_maxMinutes - 30) ~/ 30,
              onChanged: (value) =>
                  setState(() => _selectedMinutes = value.round()),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '30분',
                style: TextStyle(fontSize: 11, color: Color(0xFF71717A)),
              ),
              Text(
                '12시간',
                style: TextStyle(fontSize: 11, color: Color(0xFF71717A)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [30, 60, 120, 240]
                .map(
                  (minutes) => _TimePreset(
                    label: _formatSelectedTime(minutes),
                    selected: _selectedMinutes == minutes,
                    onTap: () => setState(() => _selectedMinutes = minutes),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 30),
          _BlackButton(
            label: '집중 시작',
            icon: Icons.play_arrow_rounded,
            onTap: _startFocus,
          ),
        ],
      ),
    );
  }

  /// 남은 시간과 해제 확인만 노출해 집중 중 시각적 방해를 줄인다.
  /// 필요한 변수: 전체 시간 대비 남은 시간, 해제 확인 상태.
  Widget _buildRunning() {
    final progress = 1 - (_remainingSeconds / (_selectedMinutes * 60));
    return _ToolSurface(
      key: const ValueKey('focus-running-surface'),
      child: Column(
        children: [
          SizedBox(
            width: 224,
            height: 224,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 224,
                  height: 224,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE4E4E7),
                      width: 8,
                    ),
                  ),
                ),
                CustomPaint(
                  size: const Size(224, 224),
                  painter: _FocusRingPainter(
                    progress: progress.clamp(0.0, 1.0),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '남은 시간',
                      style: TextStyle(color: Color(0xFF71717A)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            '집중 중',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _unlocking
                ? '집중을 끝내려면 $_unlockCountdown초 기다려주세요.'
                : '필요할 때만 집중을 해제할 수 있어요.',
            style: const TextStyle(color: Color(0xFF71717A)),
          ),
          const SizedBox(height: 28),
          if (_unlocking)
            OutlinedButton(onPressed: _cancelUnlock, child: const Text('취소'))
          else
            OutlinedButton.icon(
              onPressed: _startUnlock,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('집중 해제'),
            ),
        ],
      ),
    );
  }
}

class _ToolSurface extends StatelessWidget {
  const _ToolSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => StudentDensitySurface(
    padding: EdgeInsets.all(isStudentDensityMobile(context) ? 18 : 28),
    child: child,
  );
}

class _TimePreset extends StatelessWidget {
  const _TimePreset({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      backgroundColor: selected ? const Color(0xFF09090B) : Colors.white,
      foregroundColor: selected ? Colors.white : const Color(0xFF52525B),
      side: BorderSide(
        color: selected ? const Color(0xFF09090B) : const Color(0xFFE4E4E7),
      ),
      shape: const StadiumBorder(),
    ),
    child: Text(label),
  );
}

class _BlackButton extends StatelessWidget {
  const _BlackButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => StudentDensityButton(
    label: label,
    icon: icon,
    primary: true,
    onPressed: onTap,
  );
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF09090B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
