import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:s11/sessions/auth/ui/pages/login_page.dart';

class LandingAboutPage extends StatefulWidget {
  static const routeName = '/landing/about';

  const LandingAboutPage({super.key});

  @override
  State<LandingAboutPage> createState() => _LandingAboutPageState();
}

class _LandingAboutPageState extends State<LandingAboutPage>
    with WidgetsBindingObserver {
  static const _contactEmail = 'aiflow683@gmail.com';

  final _scrollController = ScrollController();
  final _heroKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _processKey = GlobalKey();
  bool _isAppActive = true;
  bool _isHeroVisible = true;
  bool _isAboutVisible = true;
  bool _isProcessVisible = true;

  /// 스크롤·앱 생명주기 감지를 등록하고, 첫 프레임 뒤의 실제 노출 영역을 계산합니다.
  ///
  /// [_scrollController]는 섹션의 화면 노출 여부를 갱신하는 데 사용합니다.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_updateAnimationVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateAnimationVisibility();
    });
  }

  /// 등록한 리스너를 해제해 화면 종료 후 애니메이션이 남지 않게 합니다.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_updateAnimationVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  /// 앱이 백그라운드에 있으면 모든 ticker를 멈추고 복귀 시 다시 허용합니다.
  ///
  /// [state]는 Flutter가 전달하는 앱 생명주기 상태입니다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    if (_isAppActive == isActive) return;
    setState(() => _isAppActive = isActive);
  }

  /// 화면 좌표를 기준으로 [key]가 현재 뷰포트와 겹치는지 확인합니다.
  ///
  /// [key]는 각 애니메이션 섹션의 RenderBox를 찾는 데 사용하며, 찾지 못한
  /// 첫 레이아웃 순간에는 콘텐츠가 멈춘 채 노출되지 않도록 true를 반환합니다.
  bool _isSectionVisible(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return true;
    final top = renderBox.localToGlobal(Offset.zero).dy;
    final bottom = top + renderBox.size.height;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    return bottom > 0 && top < viewportHeight;
  }

  /// 스크롤 뒤 노출된 섹션만 ticker를 실행하도록 상태를 최소 횟수로 갱신합니다.
  void _updateAnimationVisibility() {
    if (!mounted) return;
    final heroVisible = _isSectionVisible(_heroKey);
    final aboutVisible = _isSectionVisible(_aboutKey);
    final processVisible = _isSectionVisible(_processKey);
    if (_isHeroVisible == heroVisible &&
        _isAboutVisible == aboutVisible &&
        _isProcessVisible == processVisible) {
      return;
    }
    setState(() {
      _isHeroVisible = heroVisible;
      _isAboutVisible = aboutVisible;
      _isProcessVisible = processVisible;
    });
  }

  void _openLogin() {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const LoginPage(asDialog: true),
      ),
    );
  }

  void _scrollToAbout() {
    final current = _aboutKey.currentContext;
    if (current != null) {
      unawaited(
        Scrollable.ensureVisible(
          current,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }
    unawaited(
      _scrollController.animateTo(
        620,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _contact() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: const {
        'subject': 'AIFlow 문의',
        'body': '안녕하세요. AIFlow 도입 문의드립니다.',
      },
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('메일 앱을 열 수 없습니다. aiflow683@gmail.com 으로 문의해주세요.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                KeyedSubtree(
                  key: _heroKey,
                  child: TickerMode(
                    enabled: _isAppActive && _isHeroVisible,
                    child: _LoopingAnimation(
                      builder: (animation) => _HeroSection(
                        animation: animation,
                        onLogin: _openLogin,
                        onLearnMore: _scrollToAbout,
                        onContact: _contact,
                      ),
                    ),
                  ),
                ),
                KeyedSubtree(
                  key: _aboutKey,
                  child: TickerMode(
                    enabled: _isAppActive && _isAboutVisible,
                    child: RepaintBoundary(
                      child: _LoopingAnimation(
                        builder: (animation) =>
                            _AboutSection(animation: animation),
                      ),
                    ),
                  ),
                ),
                KeyedSubtree(
                  key: _processKey,
                  child: TickerMode(
                    enabled: _isAppActive && _isProcessVisible,
                    child: RepaintBoundary(
                      child: _LoopingAnimation(
                        builder: (animation) =>
                            _ProcessSection(animation: animation),
                      ),
                    ),
                  ),
                ),
                RepaintBoundary(child: _ContactSection(onContact: _contact)),
              ],
            ),
          ),
          _Header(
            onLogin: _openLogin,
            onLearnMore: _scrollToAbout,
            onContact: _contact,
          ),
        ],
      ),
    );
  }
}

/// 화면에 표시되는 각 데모에 독립적인 반복 애니메이션을 제공합니다.
///
/// [builder]는 controller 값을 구독하는 데모 위젯을 만들며, 상위 [TickerMode]가
/// 비활성화되면 controller의 프레임 콜백도 함께 멈춥니다.
class _LoopingAnimation extends StatefulWidget {
  const _LoopingAnimation({required this.builder});

  final Widget Function(Animation<double> animation) builder;

  @override
  State<_LoopingAnimation> createState() => _LoopingAnimationState();
}

class _LoopingAnimationState extends State<_LoopingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 18초 단위의 데모 애니메이션을 생성해 반복 재생합니다.
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  /// controller를 해제해 ticker와 프레임 콜백을 정리합니다.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 하위 데모가 controller만 구독하게 하여 상위 레이아웃 재빌드를 막습니다.
  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onLogin,
    required this.onLearnMore,
    required this.onContact,
  });

  final VoidCallback onLogin;
  final VoidCallback onLearnMore;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: ClipRect(
          child: RepaintBoundary(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  return Container(
                    height: compact ? 62 : 72,
                    color: const Color(0xFF07110A).withValues(alpha: 0.9),
                    child: Row(
                      children: [
                        SizedBox(
                          width: compact ? 54 : 72,
                          height: compact ? 54 : 72,
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            semanticLabel: 'AIFlow 로고',
                          ),
                        ),
                        SizedBox(width: compact ? 8 : 14),
                        if (!compact)
                          Text(
                            'AIFlow',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        const Spacer(),
                        _HeaderButton(label: '로그인', onTap: onLogin),
                        if (!compact)
                          _HeaderButton(label: '알아보기', onTap: onLearnMore),
                        Padding(
                          padding: EdgeInsets.only(right: compact ? 8 : 20),
                          child: _HeaderButton(
                            label: '문의하기',
                            onTap: onContact,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: filled
            ? const Color(0xFF45BF63)
            : Colors.white.withValues(alpha: 0),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 15,
          vertical: compact ? 8 : 11,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: compact ? 12 : 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.animation,
    required this.onLogin,
    required this.onLearnMore,
    required this.onContact,
  });

  final Animation<double> animation;
  final VoidCallback onLogin;
  final VoidCallback onLearnMore;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final height = compact
            ? math.max(760.0, screen.height * 0.9)
            : math.max(640.0, screen.height * 0.88);
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1600',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFF07110A)),
                  ),
                ),
              ),
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.58)),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 20 : 56,
                    compact ? 92 : 118,
                    compact ? 20 : 56,
                    compact ? 24 : 48,
                  ),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeroCopy(
                              compact: true,
                              onLogin: onLogin,
                              onLearnMore: onLearnMore,
                              onContact: onContact,
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 300,
                              child: _ShowreelDevice(animation: animation),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 9,
                              child: _HeroCopy(
                                compact: false,
                                onLogin: onLogin,
                                onLearnMore: onLearnMore,
                                onContact: onContact,
                              ),
                            ),
                            const SizedBox(width: 42),
                            Expanded(
                              flex: 8,
                              child: _ShowreelDevice(animation: animation),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.compact,
    required this.onLogin,
    required this.onLearnMore,
    required this.onContact,
  });

  final bool compact;
  final VoidCallback onLogin;
  final VoidCallback onLearnMore;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AIFlow',
            style: GoogleFonts.interTight(
              color: Colors.white,
              fontSize: compact ? 42 : 76,
              height: 0.96,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '필기부터 채점까지,\n수학 풀이가 흐름이 됩니다',
            style: GoogleFonts.interTight(
              color: Colors.white,
              fontSize: compact ? 28 : 48,
              height: 1.06,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '학생이 직접 쓴 풀이와 그래프 해석을 한 화면에서 읽고, AI가 채점 근거와 다음 학습 방향까지 이어줍니다.',
            style: GoogleFonts.inter(
              color: const Color(0xFFE5EEE6),
              fontSize: compact ? 14 : 18,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: const [
              _MetricChip(label: '필기 풀이 분석', value: 'OCR + 흐름'),
              _MetricChip(label: '그래프 예제', value: '자동 재생'),
              _MetricChip(label: '피드백', value: '즉시 리포트'),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                label: '로그인',
                icon: Icons.login_rounded,
                onTap: onLogin,
                primary: true,
              ),
              _ActionButton(
                label: '알아보기',
                icon: Icons.play_circle_outline_rounded,
                onTap: onLearnMore,
              ),
              _ActionButton(
                label: '문의하기',
                icon: Icons.mail_outline_rounded,
                onTap: onContact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFFC8D8CB),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: primary
            ? const Color(0xFF45BF63)
            : Colors.white.withValues(alpha: 0.13),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ShowreelDevice extends StatelessWidget {
  const _ShowreelDevice({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final showGraph = animation.value >= 0.52;
          return Transform.translate(
            offset: Offset(0, math.sin(animation.value * math.pi * 2) * 5),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1510).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 34,
                    offset: Offset(0, 22),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _ProblemDemo(animation: animation, compact: true),
                    ),
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: showGraph ? 1 : 0,
                        duration: const Duration(milliseconds: 360),
                        child: _GraphDemo(animation: animation, compact: true),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _LivePill(
                        label: showGraph ? '그래프 예제 재생' : '필기 채점 재생',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        return Container(
          width: double.infinity,
          color: const Color(0xFFF5F7F2),
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 56,
            compact ? 52 : 76,
            compact ? 20 : 56,
            compact ? 44 : 70,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '알아보기',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1B402B),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '문제 풀이, 그래프, 채점 리포트가 끊기지 않고 이어집니다',
                    style: GoogleFonts.interTight(
                      color: const Color(0xFF102116),
                      fontSize: compact ? 31 : 46,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '아래 화면은 직접 조작하는 체험판이 아니라 실제 사용 흐름을 보여주는 자동 재생 데모입니다.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF5D6C61),
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (compact)
                    Column(
                      children: [
                        SizedBox(
                          height: 410,
                          child: _ProblemDemo(animation: animation),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 410,
                          child: _GraphDemo(animation: animation),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      height: 470,
                      child: Row(
                        children: [
                          Expanded(child: _ProblemDemo(animation: animation)),
                          const SizedBox(width: 18),
                          Expanded(child: _GraphDemo(animation: animation)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProblemDemo extends StatelessWidget {
  const _ProblemDemo({required this.animation, this.compact = false});

  final Animation<double> animation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          final write = _easeOutCubic(_interval(t, 0.04, 0.36));
          final scan = _easeInOut(_interval(t, 0.38, 0.65));
          final result = _easeOutCubic(_interval(t, 0.65, 0.9));
          final status = t < 0.38
              ? '학생 필기 입력'
              : t < 0.65
              ? 'AI 채점 중'
              : '피드백 생성';

          return LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 360 || compact;
              final graphHeight = math.max(150.0, constraints.maxHeight - 188);
              return _DemoCard(
                padding: narrow ? 12 : 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          color: Color(0xFF1B402B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '문제 풀이 UI',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1B402B),
                              fontSize: narrow ? 15 : 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!narrow) _StatusPill(label: status),
                      ],
                    ),
                    SizedBox(height: narrow ? 10 : 14),
                    if (!compact) ...[
                      const _ProblemCard(),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      height: compact
                          ? constraints.maxHeight - 68
                          : graphHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _NotebookPainter(
                                  writeProgress: write,
                                  resultProgress: result,
                                ),
                              ),
                            ),
                            if (scan > 0 && result < 0.98)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _ScanPainter(progress: scan),
                                ),
                              ),
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: Opacity(
                                opacity: result,
                                child: const _ResultPill(label: '정답 근거 확인'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 12),
                      _Timeline(
                        progress: t,
                        labels: const ['필기', '채점', '리포트'],
                        points: const [0.18, 0.51, 0.78],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E8E0)),
      ),
      child: Text(
        'f(x)=x²-4x+3 의 x절편을 구하고, 그래프로 풀이를 검산하세요.',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: const Color(0xFF102116),
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GraphDemo extends StatelessWidget {
  const _GraphDemo({required this.animation, this.compact = false});

  final Animation<double> animation;
  final bool compact;

  static const _scenes = [
    _GraphScene('이차함수의 축과 절편', '수학 상', 'y=a(x-h)²+k', _GraphKind.quad),
    _GraphScene('원의 방정식', '수학 하', 'x²+y²=r²', _GraphKind.circle),
    _GraphScene('삼각함수의 주기', '수학 1', 'y=a sin(bx+c)', _GraphKind.sine),
    _GraphScene('삼차함수와 도함수', '미적분', 'f(x), f′(x)', _GraphKind.cubic),
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final raw = (animation.value * _scenes.length) % _scenes.length;
          final index = raw.floor().clamp(0, _scenes.length - 1);
          final local = raw - index;
          final scene = _scenes[index];
          final draw = _easeOutCubic(_interval(local, 0.08, 0.76));
          final morph =
              (math.sin(animation.value * math.pi * 2 + index) + 1) / 2;
          return LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 360 || compact;
              final graphHeight = math.max(150.0, constraints.maxHeight - 178);
              return _DemoCard(
                padding: narrow ? 12 : 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.stacked_line_chart_rounded,
                          color: Color(0xFF1B402B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '그래프 그리기 예제',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1B402B),
                              fontSize: narrow ? 15 : 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!narrow) const _StatusPill(label: '자동 재생'),
                      ],
                    ),
                    SizedBox(height: narrow ? 10 : 14),
                    if (!compact)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  scene.unit,
                                  style: GoogleFonts.inter(
                                    color: scene.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  scene.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF102116),
                                    fontSize: narrow ? 14 : 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!narrow)
                            _FormulaPill(
                              text: scene.formula,
                              color: scene.color,
                            ),
                        ],
                      ),
                    if (!compact) const SizedBox(height: 12),
                    SizedBox(
                      height: compact
                          ? constraints.maxHeight - 68
                          : graphHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CustomPaint(
                          painter: _GraphPainter(
                            scene: scene,
                            drawProgress: draw,
                            morph: morph,
                          ),
                          child: Container(),
                        ),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 12),
                      _Timeline(
                        progress: local,
                        labels: const ['식 선택', '개형 재생', '해석 연결'],
                        points: const [0.16, 0.52, 0.82],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.child, required this.padding});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E8E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.progress,
    required this.labels,
    required this.points,
  });

  final double progress;
  final List<String> labels;
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabels = constraints.maxWidth >= 250;
        return Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              Expanded(
                child: _TimelineItem(
                  label: labels[i],
                  active: progress >= points[i],
                  showLabel: showLabels,
                ),
              ),
              if (i != labels.length - 1)
                Container(
                  width: showLabels ? 20 : 8,
                  height: 2,
                  color: progress >= points[i + 1]
                      ? const Color(0xFF45BF63)
                      : const Color(0xFFDDE5DD),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.label,
    required this.active,
    required this.showLabel,
  });

  final String label;
  final bool active;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF45BF63) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? const Color(0xFF45BF63) : const Color(0xFFCBD8CB),
        ),
      ),
      child: active
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
    if (!showLabel) {
      return Align(alignment: Alignment.centerLeft, child: dot);
    }
    return Row(
      children: [
        dot,
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: active ? const Color(0xFF1B402B) : const Color(0xFF7A877D),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotebookPainter extends CustomPainter {
  const _NotebookPainter({
    required this.writeProgress,
    required this.resultProgress,
  });

  final double writeProgress;
  final double resultProgress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final line = Paint()
      ..color = const Color(0xFFE7EBE7)
      ..strokeWidth = 1;
    for (double y = 26; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final margin = Paint()
      ..color = const Color(0xFFFFA3A3)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(42, 0), Offset(42, size.height), margin);

    final paths = [
      Path()
        ..moveTo(64, size.height * 0.22)
        ..cubicTo(120, 28, 160, 70, size.width * 0.62, size.height * 0.24),
      Path()
        ..moveTo(66, size.height * 0.42)
        ..lineTo(size.width * 0.42, size.height * 0.42)
        ..lineTo(size.width * 0.42, size.height * 0.3)
        ..moveTo(size.width * 0.42, size.height * 0.42)
        ..lineTo(size.width * 0.62, size.height * 0.56),
      Path()
        ..moveTo(66, size.height * 0.66)
        ..cubicTo(
          size.width * 0.26,
          size.height * 0.54,
          size.width * 0.46,
          size.height * 0.74,
          size.width * 0.72,
          size.height * 0.58,
        ),
    ];
    var remaining = writeProgress * paths.length;
    for (final path in paths) {
      final local = remaining.clamp(0.0, 1.0);
      if (local <= 0) break;
      _drawPartialPath(
        canvas,
        path,
        local,
        Paint()
          ..color = const Color(0xFF1E2B21)
          ..strokeWidth = 2.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      remaining -= 1;
    }

    if (resultProgress > 0) {
      final success = Paint()
        ..color = const Color(0xFF238B5E).withValues(alpha: resultProgress)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final center = Offset(size.width - 48, size.height * 0.22);
      canvas.drawCircle(center, 16, success);
      canvas.drawLine(
        center + const Offset(-8, 0),
        center + const Offset(-2, 7),
        success,
      );
      canvas.drawLine(
        center + const Offset(-2, 7),
        center + const Offset(10, -8),
        success,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NotebookPainter oldDelegate) {
    return oldDelegate.writeProgress != writeProgress ||
        oldDelegate.resultProgress != resultProgress;
  }
}

class _ScanPainter extends CustomPainter {
  const _ScanPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = ui.lerpDouble(-20, size.height + 20, progress)!;
    final overlay = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y - 26),
        Offset(0, y + 26),
        [
          Colors.transparent,
          const Color(0xFF45BF63).withValues(alpha: 0.24),
          Colors.transparent,
        ],
        const [0, 0.5, 1],
      );
    canvas.drawRect(Rect.fromLTWH(0, y - 26, size.width, 52), overlay);
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = const Color(0xFF45BF63).withValues(alpha: 0.75)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.scene,
    required this.drawProgress,
    required this.morph,
  });

  final _GraphScene scene;
  final double drawProgress;
  final double morph;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(38, 14, size.width - 52, size.height - 42);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF8FBF8),
    );
    canvas.drawRect(plot, Paint()..color = Colors.white);

    final grid = Paint()
      ..color = const Color(0xFFE5ECE5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 6; i++) {
      final x = ui.lerpDouble(plot.left, plot.right, i / 6)!;
      final y = ui.lerpDouble(plot.top, plot.bottom, i / 6)!;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }

    double px(double x) => plot.left + (x + 6) / 12 * plot.width;
    double py(double y) => plot.top + (1 - (y + 6) / 12) * plot.height;

    final axis = Paint()
      ..color = const Color(0xFF7C887F)
      ..strokeWidth = 1.3;
    canvas.drawLine(Offset(plot.left, py(0)), Offset(plot.right, py(0)), axis);
    canvas.drawLine(Offset(px(0), plot.top), Offset(px(0), plot.bottom), axis);

    switch (scene.kind) {
      case _GraphKind.quad:
        final h = ui.lerpDouble(-1.6, 1.6, morph)!;
        _drawFunction(
          canvas,
          plot,
          px,
          py,
          (x) => 0.35 * math.pow(x - h, 2) - 2.4,
          scene.color,
        );
        break;
      case _GraphKind.circle:
        final r = ui.lerpDouble(2.1, 2.8, morph)!;
        _drawFunction(canvas, plot, px, py, (x) {
          final inside = r * r - x * x;
          return inside < 0 ? null : math.sqrt(inside);
        }, scene.color);
        _drawFunction(canvas, plot, px, py, (x) {
          final inside = r * r - x * x;
          return inside < 0 ? null : -math.sqrt(inside);
        }, scene.accent);
        break;
      case _GraphKind.sine:
        _drawFunction(
          canvas,
          plot,
          px,
          py,
          (x) => 2.1 * math.sin(x + morph * 2),
          scene.color,
        );
        break;
      case _GraphKind.cubic:
        _drawFunction(
          canvas,
          plot,
          px,
          py,
          (x) => 0.16 * x * x * x - 1.15 * x,
          scene.color,
        );
        _drawFunction(
          canvas,
          plot,
          px,
          py,
          (x) => 0.48 * x * x - 1.15,
          scene.accent,
          width: 2.2,
        );
        break;
    }

    canvas.drawRect(
      plot,
      Paint()
        ..color = const Color(0xFFDCE5DC)
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawFunction(
    Canvas canvas,
    Rect plot,
    double Function(double x) px,
    double Function(double y) py,
    double? Function(double x) fn,
    Color color, {
    double width = 3,
  }) {
    final path = Path();
    var started = false;
    final samples = (160 * drawProgress).round().clamp(2, 160);
    for (var i = 0; i <= samples; i++) {
      final ratio = i / 160;
      if (ratio > drawProgress) break;
      final x = -6 + ratio * 12;
      final y = fn(x);
      if (y == null || y.isNaN || y.isInfinite) {
        started = false;
        continue;
      }
      final point = Offset(px(x), py(y));
      if (!plot.inflate(24).contains(point)) {
        started = false;
        continue;
      }
      if (started) {
        path.lineTo(point.dx, point.dy);
      } else {
        path.moveTo(point.dx, point.dy);
        started = true;
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.scene != scene ||
        oldDelegate.drawProgress != drawProgress ||
        oldDelegate.morph != morph;
  }
}

class _ProcessSection extends StatelessWidget {
  const _ProcessSection({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final steps = const [
      _ProcessStep(
        icon: Icons.draw_rounded,
        title: '학생 풀이를 그대로 받습니다',
        body: '공책처럼 쓰고 지우는 과정이 풀이 데이터로 남습니다.',
        color: Color(0xFF2F7CF6),
      ),
      _ProcessStep(
        icon: Icons.auto_awesome_rounded,
        title: '채점 근거를 즉시 정리합니다',
        body: '답만 맞히는 것이 아니라 어느 단계에서 흔들렸는지 보여줍니다.',
        color: Color(0xFFDD5F34),
      ),
      _ProcessStep(
        icon: Icons.route_rounded,
        title: '다음 학습으로 연결합니다',
        body: '오답, 약점 태그, 그래프 연습을 같은 흐름 안에서 이어갑니다.',
        color: Color(0xFF238B5E),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        return Container(
          width: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 56,
            compact ? 44 : 68,
            compact ? 20 : 56,
            compact ? 54 : 78,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '한 번의 풀이가 학습 데이터가 되는 과정',
                    style: GoogleFonts.interTight(
                      color: const Color(0xFF102116),
                      fontSize: compact ? 30 : 42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      final activeIndex =
                          (animation.value * steps.length).floor() %
                          steps.length;
                      if (compact) {
                        return Column(
                          children: [
                            for (var i = 0; i < steps.length; i++) ...[
                              _ProcessCard(
                                step: steps[i],
                                active: activeIndex == i,
                              ),
                              if (i != steps.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        );
                      }
                      return Row(
                        children: [
                          for (var i = 0; i < steps.length; i++) ...[
                            Expanded(
                              child: _ProcessCard(
                                step: steps[i],
                                active: activeIndex == i,
                              ),
                            ),
                            if (i != steps.length - 1)
                              const SizedBox(width: 14),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({required this.step, required this.active});

  final _ProcessStep step;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF6FAF6) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? step.color : const Color(0xFFE1E8E0),
          width: active ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(step.icon, color: step.color, size: 28),
          const SizedBox(height: 16),
          Text(
            step.title,
            style: GoogleFonts.inter(
              color: const Color(0xFF102116),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.body,
            style: GoogleFonts.inter(
              color: const Color(0xFF5D6C61),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.onContact});

  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Container(
          width: double.infinity,
          color: const Color(0xFF102116),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 20 : 56,
            vertical: compact ? 36 : 48,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ContactCopy(compact: compact),
                        const SizedBox(height: 18),
                        _ContactButton(onContact: onContact),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _ContactCopy(compact: compact)),
                        _ContactButton(onContact: onContact),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ContactCopy extends StatelessWidget {
  const _ContactCopy({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AIFlow 도입 문의',
          style: GoogleFonts.interTight(
            color: Colors.white,
            fontSize: compact ? 28 : 36,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '학원, 학교, 팀 단위 사용은 메일로 문의해주세요.',
          style: GoogleFonts.inter(
            color: const Color(0xFFC8D8CB),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.onContact});

  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onContact,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF45BF63),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.mail_outline_rounded),
      label: const Text('aiflow683@gmail.com', overflow: TextOverflow.ellipsis),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF45BF63).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF45BF63).withValues(alpha: 0.36),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFF1B402B),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FormulaPill extends StatelessWidget {
  const _FormulaPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF238B5E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF07110A).withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProcessStep {
  const _ProcessStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
}

class _GraphScene {
  const _GraphScene(this.title, this.unit, this.formula, this.kind);

  final String title;
  final String unit;
  final String formula;
  final _GraphKind kind;

  Color get color {
    switch (kind) {
      case _GraphKind.quad:
        return const Color(0xFFDD5F34);
      case _GraphKind.circle:
        return const Color(0xFF238B5E);
      case _GraphKind.sine:
        return const Color(0xFF2F7CF6);
      case _GraphKind.cubic:
        return const Color(0xFF8A52E8);
    }
  }

  Color get accent => const Color(0xFFD6477C);
}

enum _GraphKind { quad, circle, sine, cubic }

void _drawPartialPath(Canvas canvas, Path path, double progress, Paint paint) {
  final total = path.computeMetrics().fold<double>(
    0,
    (sum, metric) => sum + metric.length,
  );
  if (total <= 0) return;
  var remaining = total * progress.clamp(0.0, 1.0);
  for (final metric in path.computeMetrics()) {
    if (remaining <= 0) break;
    final length = remaining.clamp(0.0, metric.length);
    canvas.drawPath(metric.extractPath(0, length), paint);
    remaining -= metric.length;
  }
}

double _interval(double value, double start, double end) {
  if (value <= start) return 0;
  if (value >= end) return 1;
  return ((value - start) / (end - start)).clamp(0.0, 1.0);
}

double _easeOutCubic(double value) {
  return 1 - math.pow(1 - value, 3).toDouble();
}

double _easeInOut(double value) {
  return Curves.easeInOut.transform(value.clamp(0.0, 1.0));
}
