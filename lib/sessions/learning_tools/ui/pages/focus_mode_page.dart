import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// /////////////////////////////////////////////////////
// 집중모드 - 그라데이션 배경 + 3초 카운트다운 해제
// /////////////////////////////////////////////////////

class FocusModePage extends StatefulWidget {
  const FocusModePage({super.key});

  @override
  State<FocusModePage> createState() => _FocusModePageState();
}

class _FocusModePageState extends State<FocusModePage>
    with TickerProviderStateMixin {
  static const int _maxMinutes = 720; // 12 hours

  int _selectedMinutes = 60;
  bool _running = false;
  int _remainingSeconds = 0;
  Timer? _timer;

  // 해제 카운트다운
  bool _unlocking = false;
  int _unlockCountdown = 0;
  Timer? _unlockTimer;

  late final AnimationController _gradientAnimController;

  @override
  void initState() {
    super.initState();
    _gradientAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _unlockTimer?.cancel();
    _gradientAnimController.dispose();
    super.dispose();
  }

  void _startFocus() {
    setState(() {
      _running = true;
      _remainingSeconds = _selectedMinutes * 60;
      _unlocking = false;
      _unlockCountdown = 0;
    });
    HapticFeedback.mediumImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _stopFocus();
        }
      });
    });
  }

  void _stopFocus() {
    _timer?.cancel();
    _unlockTimer?.cancel();
    setState(() {
      _running = false;
      _remainingSeconds = 0;
      _unlocking = false;
      _unlockCountdown = 0;
    });
  }

  void _startUnlock() {
    HapticFeedback.lightImpact();
    setState(() {
      _unlocking = true;
      _unlockCountdown = 3;
    });
    _unlockTimer?.cancel();
    _unlockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_unlockCountdown > 1) {
          _unlockCountdown--;
        } else {
          _unlockTimer?.cancel();
          _stopFocus();
        }
      });
    });
  }

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
    if (h > 0 && m > 0) {
      return '$h시간 $m분';
    } else if (h > 0) {
      return '$h시간';
    }
    return '$m분';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F8F4),
      body: _running ? _buildFocusRunning() : _buildSetup(isDark),
    );
  }

  Widget _buildSetup(bool isDark) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
    final textTertiary = isDark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6);
    const accentGreen = Color(0xFF45BF63);

    return SafeArea(
      child: Column(
        children: [
          // App Bar
          Container(
            height: 80,
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 36,
                    color: Color(0xFF3B3B3B),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      '집중 모드',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B3B3B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF12151A) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x1A000000)),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 14,
                      color: Color(0x14000000),
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  // Subtitle
                  Text(
                    '설정한 시간 동안 방해를 차단합니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Time display - focal point
                  Text(
                    _formatSelectedTime(_selectedMinutes),
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w300,
                      color: textPrimary,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Slider - full width, minimal
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      activeTrackColor: accentGreen,
                      inactiveTrackColor: textTertiary,
                      thumbColor: accentGreen,
                      overlayColor: accentGreen.withValues(alpha: 0.15),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                        elevation: 0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                    ),
                    child: Slider(
                      value: _selectedMinutes.toDouble(),
                      min: 30,
                      max: _maxMinutes.toDouble(),
                      divisions: (_maxMinutes - 30) ~/ 30,
                      onChanged: (value) {
                        setState(() => _selectedMinutes = value.round());
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Quick preset chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _QuickTimeButton(
                        label: '30분',
                        onTap: () => setState(() => _selectedMinutes = 30),
                        selected: _selectedMinutes == 30,
                      ),
                      const SizedBox(width: 10),
                      _QuickTimeButton(
                        label: '1시간',
                        onTap: () => setState(() => _selectedMinutes = 60),
                        selected: _selectedMinutes == 60,
                      ),
                      const SizedBox(width: 10),
                      _QuickTimeButton(
                        label: '2시간',
                        onTap: () => setState(() => _selectedMinutes = 120),
                        selected: _selectedMinutes == 120,
                      ),
                      const SizedBox(width: 10),
                      _QuickTimeButton(
                        label: '4시간',
                        onTap: () => setState(() => _selectedMinutes = 240),
                        selected: _selectedMinutes == 240,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // Start button - simple, primary green
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _startFocus,
                      style: FilledButton.styleFrom(
                        backgroundColor: accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 24),
                          SizedBox(width: 6),
                          Text('집중 시작'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusRunning() {
    final progress = _selectedMinutes > 0
        ? 1 - (_remainingSeconds / (_selectedMinutes * 60))
        : 0.0;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.white;
    final textSecondary = isDark ? const Color(0xFF8E8E93) : const Color(0xFFB0B0B0);
    final textTertiary = isDark ? const Color(0xFF48484A) : const Color(0xFF666666);
    const accentGreen = Color(0xFF45BF63);

    return Stack(
      children: [
        // 그라데이션 배경 애니메이션 (화면 보호기 스타일)
        AnimatedBuilder(
          animation: _gradientAnimController,
          builder: (context, child) {
            return CustomPaint(
              painter: _GradientBackgroundPainter(
                progress: _gradientAnimController.value,
                isDark: isDark,
              ),
              size: Size.infinite,
            );
          },
        ),
        // 메인 콘텐츠
        SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 진행 링 + 시간
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 배경 원
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: textTertiary,
                            width: 8,
                          ),
                        ),
                      ),
                      // 진행 링
                      CustomPaint(
                        size: const Size(220, 220),
                        painter: _FocusRingPainter(
                          progress: progress.clamp(0.0, 1.0),
                          color: accentGreen,
                          strokeWidth: 8,
                        ),
                      ),
                      // 시간 표시
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(_remainingSeconds),
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w300,
                              color: textPrimary,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '남은 시간',
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  '집중 중...',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _unlocking
                      ? '잠금 해제 중... $_unlockCountdown초'
                      : '잠금해제 버튼을 눌러 해제하세요',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 40),
                // 해제 버튼
                if (!_unlocking)
                  GestureDetector(
                    onTap: _startUnlock,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: textTertiary,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_open_outlined,
                            color: textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '잠금해제',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      // 카운트다운 표시
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentGreen.withValues(alpha: 0.15),
                          border: Border.all(
                            color: accentGreen,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$_unlockCountdown',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: accentGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 취소 버튼
                      TextButton(
                        onPressed: _cancelUnlock,
                        child: Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickTimeButton extends StatelessWidget {
  const _QuickTimeButton({
    required this.label,
    required this.onTap,
    required this.selected,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF45BF63) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF45BF63)
                : isDark
                    ? const Color(0xFF48484A)
                    : const Color(0xFFD1D1D6),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }
}

// /////////////////////////////////////////////////////
// 그라데이션 배경 Painter (화면 보호기 스타일)
// /////////////////////////////////////////////////////

class _GradientBackgroundPainter extends CustomPainter {
  _GradientBackgroundPainter({
    required this.progress,
    required this.isDark,
  });

  final double progress;
  final bool isDark;

  // 다크 모드 색상 팔레트
  static const List<Color> _darkColors = [
    Color(0xFF0F2027),
    Color(0xFF203A43),
    Color(0xFF2C5364),
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
    Color(0xFF0F3460),
  ];

  // 라이트 모드 색상 팔레트
  static const List<Color> _lightColors = [
    Color(0xFF45BF63),
    Color(0xFF2E8B57),
    Color(0xFF3CB371),
    Color(0xFF20B2AA),
    Color(0xFF48D1CC),
    Color(0xFF5F9EA0),
  ];

  List<Color> get _colors => isDark ? _darkColors : _lightColors;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _colors;
    final count = colors.length;

    // 1. 기본 배경 먼저 그리기
    final basePaint = Paint()
      ..color = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFE8F5E9);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      basePaint,
    );

    // 2. 첫 번째 그라데이트 오브 (srcOver로 합성 - Web 호환)
    for (int i = 0; i < count; i++) {
      final t = (progress + i / count) % 1.0;
      final nextT = (t + 0.5) % 1.0;

      final centerX = size.width * (0.3 + 0.4 * math.sin(t * 2 * math.pi));
      final centerY = size.height * (0.3 + 0.4 * math.cos(t * 2 * math.pi));
      final radius = size.width * (0.5 + 0.3 * math.sin(nextT * math.pi));

      final gradient = RadialGradient(
        colors: [
          colors[i].withValues(alpha: 0.4),
          colors[i].withValues(alpha: 0.0),
        ],
        radius: 1.0,
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(
            center: Offset(centerX, centerY),
            radius: radius,
          ),
        )
        ..blendMode = BlendMode.srcOver;

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        paint,
      );
    }

    // 3. 두 번째 그라데이트 오브
    for (int i = 0; i < count; i++) {
      final t = (progress + i / count) % 1.0;
      final centerX = size.width * (0.3 + 0.4 * math.sin(t * 2 * math.pi + i));
      final centerY = size.height * (0.3 + 0.4 * math.cos(t * 2 * math.pi + i * 0.7));
      final radius = size.width * (0.6 + 0.2 * math.sin(t * math.pi));

      final gradient = RadialGradient(
        colors: [
          colors[(i + 2) % count].withValues(alpha: isDark ? 0.35 : 0.25),
          colors[(i + 2) % count].withValues(alpha: 0.0),
        ],
        radius: 1.0,
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(
            center: Offset(centerX, centerY),
            radius: radius,
          ),
        )
        ..blendMode = BlendMode.srcOver;

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GradientBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

// /////////////////////////////////////////////////////
// 집중 진행 링
// /////////////////////////////////////////////////////

class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      -sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
