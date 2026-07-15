import 'package:flutter/material.dart';

/// 학생 밀도 축소 시안에서 공통으로 사용하는 색상과 간격 토큰입니다.
abstract final class StudentDensityTokens {
  static const Color background = Color(0xFFF2F2F4);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF6F6F8);
  static const Color ink = Color(0xFF09090B);
  static const Color muted = Color(0xFF71717A);
  static const Color faint = Color(0xFFA1A1AA);
  static const Color line = Color(0x1A09090B);
  static const Color lineStrong = Color(0x2E09090B);
  static const Color dark = Color(0xFF0A0A0B);
  static const Color darkSecondary = Color(0xFF232326);
  static const double desktopMaxWidth = 1500;
  static const double mobileBreakpoint = 780;
  static const double radiusSmall = 14;
  static const double radiusMedium = 20;
  static const double radius = 28;
  static const double radiusExtraLarge = 38;
}

/// 필요 변수: 현재 화면 너비.
/// 작동 원리: 시안의 780px 기준을 사용해 모바일 재배치 여부를 반환합니다.
bool isStudentDensityMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width <= StudentDensityTokens.mobileBreakpoint;

/// 필요한 변수는 현재 viewport 너비다.
/// 작동 원리: HTML의 모바일 11/14px 및 데스크톱 `clamp(24px, 4vw, 54px)` 가로 여백을 반환한다.
double studentDensityHorizontalPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width <= StudentDensityTokens.mobileBreakpoint) {
    return width <= 390 ? 11 : 14;
  }
  return (width * 0.04).clamp(24, 54);
}

/// 필요한 변수는 현재 viewport 너비다.
/// 작동 원리: 모바일 22px과 데스크톱 `clamp(24px, 4vw, 54px)` 세로 여백을 반환한다.
double studentDensityVerticalPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width <= StudentDensityTokens.mobileBreakpoint) return 22;
  return (width * 0.04).clamp(24, 54);
}

/// 필요 변수: 페이지 본문, 선택적인 바깥 여백과 현재 viewport 너비.
/// 작동 원리: HTML의 `min(1500px, 100%)` 본문과 `clamp(24px, 4vw, 54px)` 여백을 Flutter 제약으로 재현합니다.
class StudentDensityPage extends StatelessWidget {
  const StudentDensityPage({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = studentDensityHorizontalPadding(context);
    final verticalPadding = studentDensityVerticalPadding(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: StudentDensityTokens.desktopMaxWidth,
        ),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
          child: child,
        ),
      ),
    );
  }
}

/// 필요 변수: 카드 본문, 여백, 배경색과 선택적인 탭 동작.
/// 작동 원리: 최신 시안의 흰 표면·얇은 테두리·큰 반경을 한 컴포넌트로 제공합니다.
class StudentDensitySurface extends StatelessWidget {
  const StudentDensitySurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = StudentDensityTokens.surface,
    this.radius = StudentDensityTokens.radius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final decorated = Ink(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: StudentDensityTokens.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 44,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: decorated,
      ),
    );
  }
}

/// 필요 변수: 짧은 영문 또는 상태 라벨.
/// 작동 원리: 시안의 작은 대문자 문맥 라벨을 동일한 자간과 굵기로 표시합니다.
class StudentDensityEyebrow extends StatelessWidget {
  const StudentDensityEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: color ?? StudentDensityTokens.muted,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.3,
    ),
  );
}

/// 필요 변수: 페이지 제목과 선택적인 설명·우측 행동.
/// 작동 원리: 모바일에서는 행동을 제목 아래로 내려 시안의 정보 우선순위를 유지합니다.
class StudentDensityPageHeader extends StatelessWidget {
  const StudentDensityPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.action,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudentDensityEyebrow(eyebrow),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            color: StudentDensityTokens.ink,
            fontSize: mobile ? 32 : 52,
            height: 1.03,
            fontWeight: FontWeight.w900,
            letterSpacing: mobile ? -1.8 : -2.8,
          ),
        ),
        if (description != null) ...[
          SizedBox(height: mobile ? 6 : 8),
          Text(
            description!,
            style: TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: mobile ? 12 : 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
    if (action == null) return copy;
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [copy, const SizedBox(height: 20), action!],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: copy),
        const SizedBox(width: 24),
        action!,
      ],
    );
  }
}

/// 필요 변수: 버튼 문구, 탭 동작과 반전 여부.
/// 작동 원리: 시안의 검은 기본 행동과 흰 보조 행동을 동일한 캡슐 형태로 제공합니다.
class StudentDensityButton extends StatelessWidget {
  const StudentDensityButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
    label: Text(label),
    style: FilledButton.styleFrom(
      elevation: 0,
      backgroundColor: primary
          ? StudentDensityTokens.dark
          : StudentDensityTokens.surface,
      foregroundColor: primary ? Colors.white : StudentDensityTokens.ink,
      disabledBackgroundColor: const Color(0xFFE8E8EB),
      disabledForegroundColor: StudentDensityTokens.muted,
      side: BorderSide(
        color: primary ? StudentDensityTokens.dark : StudentDensityTokens.line,
      ),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
    ),
  );
}
