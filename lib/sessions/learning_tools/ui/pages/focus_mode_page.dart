import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

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
  int _selectedMinutes = 25;
  int _selectedTab = 0;
  bool _settingsOpen = false;
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
    final minutes =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return h == 0 ? minutes : '${h.toString().padLeft(2, '0')}:$minutes';
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
    return StudentHtmlShell(
      key: const ValueKey('focus-tool-page'),
      title: '집중 모드',
      activeRoute: '/tools',
      railWidth: MediaQuery.sizeOf(context).width > 1040 ? 84 : 72,
      mobileBackButton: true,
      showContextAside: MediaQuery.sizeOf(context).width > 1040,
      onMenu: () => Navigator.maybePop(context),
      onSearch: () => showStudentQuickSearch(context),
      onNotifications: () => showStudentNotifications(context),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(
            mobile
                ? 10
                : MediaQuery.sizeOf(context).width > 1040
                ? 38
                : 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _referenceTabs(mobile),
              const SizedBox(height: 20),
              if (mobile) ...[
                _referenceSettings(),
                const SizedBox(height: 30),
                _referenceMetrics(true),
                const SizedBox(height: 30),
                _referenceClock(true),
              ] else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final rightWidth =
                        ((constraints.maxWidth - 18) * .42 / 1.42).clamp(
                          240.0,
                          double.infinity,
                        );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 440,
                            child: _referenceSettings(),
                          ),
                        ),
                        const SizedBox(width: 18),
                        SizedBox(
                          width: rightWidth,
                          child: Column(
                            children: [
                              _referenceMetrics(false),
                              const SizedBox(height: 18),
                              _referenceClock(false),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              SizedBox(height: mobile ? 30 : 18),
              _surface(
                Padding(
                  padding: EdgeInsets.all(mobile ? 7 : 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (mobile)
                        Expanded(
                          flex: 115,
                          child: _action(
                            _running
                                ? (_unlocking ? '해제 취소' : '집중 해제')
                                : '집중 모드 시작',
                            _running
                                ? (_unlocking ? _cancelUnlock : _startUnlock)
                                : _startFocus,
                            dark: true,
                            arrow: true,
                          ),
                        )
                      else
                        SizedBox(
                          width: 180,
                          child: _action(
                            _running
                                ? (_unlocking ? '해제 취소' : '집중 해제')
                                : '집중 모드 시작',
                            _running
                                ? (_unlocking ? _cancelUnlock : _startUnlock)
                                : _startFocus,
                            dark: true,
                            arrow: true,
                          ),
                        ),
                      const SizedBox(width: 9),
                      if (mobile)
                        Expanded(
                          flex: 85,
                          child: _action(
                            '세부 설정',
                            () =>
                                setState(() => _settingsOpen = !_settingsOpen),
                          ),
                        )
                      else
                        SizedBox(
                          width: 78.15625,
                          child: _action(
                            '세부 설정',
                            () =>
                                setState(() => _settingsOpen = !_settingsOpen),
                          ),
                        ),
                    ],
                  ),
                ),
                key: const ValueKey('focus-reference-actions'),
              ),
              if (_settingsOpen && !_running) ...[
                const SizedBox(height: 18),
                _buildSetup(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// HTML utility의 직각 표면. 테마 카드의 모서리/그림자를 적용하지 않는다.
  Widget _surface(Widget child, {Key? key}) => Container(
    key: key,
    decoration: BoxDecoration(
      color: const Color(0xFFFDFDFE),
      border: Border.all(color: const Color(0x1A09090B)),
    ),
    child: child,
  );

  /// The reference toolbar uses a full-width mobile strip and 194px desktop strip.
  Widget _referenceTabs(bool mobile) => _surface(
    SizedBox(
      height: mobile ? 50 : 54,
      child: Padding(
        padding: EdgeInsets.all(mobile ? 5 : 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: mobile ? double.infinity : 194,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: StudentDensityTokens.line),
              ),
              child: Row(
                children: List.generate(
                  3,
                  (index) => Expanded(
                    child: Semantics(
                      selected: _selectedTab == index,
                      child: _action(
                        ['집중', '화면', '알림'][index],
                        () => setState(() => _selectedTab = index),
                        dark: _selectedTab == index,
                        tab: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    key: const ValueKey('focus-reference-toolbar'),
  );

  Widget _action(
    String label,
    VoidCallback onTap, {
    bool dark = false,
    bool tab = false,
    bool arrow = false,
  }) => SizedBox(
    height: tab ? (isStudentDensityMobile(context) ? 38 : 40) : 44,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.standard,
        padding: EdgeInsets.symmetric(horizontal: tab ? 9 : 16),
        backgroundColor: dark
            ? const Color(0xFF09090B)
            : const Color(0xFFFDFDFE),
        foregroundColor: dark
            ? Colors.white
            : tab
            ? StudentDensityTokens.muted
            : StudentDensityTokens.ink,
        side: tab ? null : const BorderSide(color: StudentDensityTokens.ink),
        shape: const RoundedRectangleBorder(),
        textStyle: TextStyle(
          fontSize: tab ? 10 : 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      child: arrow
          ? Row(
              children: [
                Expanded(child: Text(label, maxLines: 1, softWrap: false)),
                const SizedBox(width: 8),
                const StudentHtmlGlyph(
                  icon: StudentHtmlIcon.arrow,
                  color: Colors.white,
                  size: 17,
                ),
              ],
            )
          : Text(label, maxLines: 1, softWrap: false),
    ),
  );

  Widget _referenceSettings() => _surface(
    Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isStudentDensityMobile(context) ? 10 : 16,
        vertical: isStudentDensityMobile(context) ? 6 : 10,
      ),
      child: Column(
        children: List.generate(
          2,
          (index) => SizedBox(
            height: isStudentDensityMobile(context) ? 66 : 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: isStudentDensityMobile(context) ? 50 : 62,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        color: StudentDensityTokens.surfaceMuted,
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            index == 0 ? '화면' : '소리',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: StudentDensityTokens.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isStudentDensityMobile(context) ? 9 : 14),
                  Expanded(
                    child: Text(
                      index == 0 ? '현재 문제만 표시' : '완료 알림만',
                      style: TextStyle(
                        fontSize: isStudentDensityMobile(context) ? 13 : 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: isStudentDensityMobile(context) ? 9 : 14),
                  Container(
                    width: 44,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: StudentDensityTokens.line),
                    ),
                    child: const Text(
                      'ON',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    key: const ValueKey('focus-reference-settings'),
  );

  Widget _referenceMetrics(bool mobile) {
    final values = ['$_selectedMinutes분', '숨김', '—'];
    final valueSize = mobile
        ? 18.0
        : (MediaQuery.sizeOf(context).width * .02).clamp(19.0, 28.0);
    final cells = List.generate(
      3,
      (index) => Container(
        key: ValueKey('focus-reference-metric-$index'),
        height: mobile ? 74 : 90,
        padding: EdgeInsets.all(
          mobile ? 12 : 14,
        ).copyWith(left: mobile ? 10 : 14, right: mobile ? 10 : 14),
        decoration: BoxDecoration(
          border: index < 2
              ? (mobile
                    ? const Border(
                        right: BorderSide(color: StudentDensityTokens.line),
                      )
                    : const Border(
                        bottom: BorderSide(color: StudentDensityTokens.line),
                      ))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              values[index],
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.w900,
                height: 1.5,
                letterSpacing: -valueSize * .06,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              ['시간', '알림', '목표'][index],
              style: const TextStyle(
                fontSize: 10,
                height: 1.5,
                color: Color(0xFF71717A),
              ),
            ),
          ],
        ),
      ),
    );
    return _surface(
      mobile
          ? Row(children: cells.map((cell) => Expanded(child: cell)).toList())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cells,
            ),
      key: const ValueKey('focus-reference-metrics'),
    );
  }

  Widget _referenceClock(bool mobile) => _surface(
    SizedBox(
      width: double.infinity,
      height: mobile ? 124 : 148,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _running ? (_unlocking ? '해제까지 $_unlockCountdown초' : '집중 중') : '준비',
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF71717A),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              _formatTime(_running ? _remainingSeconds : _selectedMinutes * 60),
              maxLines: 1,
              style: TextStyle(
                fontSize: mobile ? 38 : 62,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.9,
              ),
            ),
          ),
        ],
      ),
    ),
    key: const ValueKey('focus-reference-clock'),
  );

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
              min: 5,
              max: _maxMinutes.toDouble(),
              divisions: (_maxMinutes - 5) ~/ 5,
              onChanged: (value) =>
                  setState(() => _selectedMinutes = value.round()),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '5분',
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
            children: [25, 30, 60, 120]
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
