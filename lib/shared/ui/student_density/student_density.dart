import 'package:flutter/material.dart';

/// 학생 밀도 축소 시안에서 공통으로 사용하는 색상과 간격 토큰입니다.
abstract final class StudentDensityTokens {
  // The reference export uses #f0f0f2 as its page canvas. Keep the token
  // centralized so every student surface follows the same visual baseline.
  static const Color background = Color(0xFFF0F0F2);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF3F3F5);
  static const Color ink = Color(0xFF09090B);
  static const Color muted = Color(0xFF71717A);
  static const Color faint = Color(0xFFA1A1AA);
  static const Color line = Color(0x1A09090B);
  static const Color lineStrong = Color(0x2E09090B);
  static const Color dark = Color(0xFF111113);
  static const Color darkSecondary = Color(0xFF232326);
  static const double desktopMaxWidth = 1500;

  /// The HTML reference switches the shared shell at 720px. Individual
  /// immersive workspaces may keep their own narrower layout thresholds.
  static const double mobileBreakpoint = 720;
  static const double desktopBreakpoint = 1040;
  static const double radiusSmall = 14;
  static const double radiusMedium = 20;
  static const double radius = 28;
  static const double radiusExtraLarge = 38;
}

/// 필요 변수: 현재 화면 너비.
/// 작동 원리: 기준 HTML의 720px 기준을 사용해 모바일 재배치 여부를 반환합니다.
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
/// 작동 원리: 모바일은 테두리·그림자 없는 플랫 표면을, PC는 기존 카드 깊이를 제공합니다.
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
    final mobile = isStudentDensityMobile(context);
    final decorated = Ink(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: mobile ? null : Border.all(color: StudentDensityTokens.line),
        boxShadow: mobile
            ? null
            : const [
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
/// 작동 원리: PC에서만 문맥 라벨을 표시하고 모바일은 제목만 남겨 텍스트 밀도를 줄입니다.
class StudentDensityEyebrow extends StatelessWidget {
  const StudentDensityEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (isStudentDensityMobile(context)) return const SizedBox.shrink();
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color ?? StudentDensityTokens.muted,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.3,
      ),
    );
  }
}

/// 필요 변수: 페이지 제목과 선택적인 설명·우측 행동.
/// 작동 원리: 모바일은 영문 라벨과 기본 설명을 생략하고 제목·행동만 남기며 PC는 기존 정보를 유지합니다.
class StudentDensityPageHeader extends StatelessWidget {
  const StudentDensityPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.action,
    this.showMobileDescription = false,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final Widget? action;
  final bool showMobileDescription;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!mobile) ...[
          StudentDensityEyebrow(eyebrow),
          const SizedBox(height: 10),
        ],
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
        if (description != null && (!mobile || showMobileDescription)) ...[
          SizedBox(height: mobile ? 6 : 8),
          Text(
            description!,
            style: TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 14,
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
        children: [copy, const SizedBox(height: 14), action!],
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
/// 작동 원리: 모바일은 큰 무테 Material 버튼을, PC는 기존 시안의 캡슐 버튼을 제공합니다.
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
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return FilledButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: primary
            ? StudentDensityTokens.dark
            : mobile
            ? StudentDensityTokens.surfaceMuted
            : StudentDensityTokens.surface,
        foregroundColor: primary ? Colors.white : StudentDensityTokens.ink,
        disabledBackgroundColor: const Color(0xFFE8E8EB),
        disabledForegroundColor: StudentDensityTokens.muted,
        side: mobile
            ? BorderSide.none
            : BorderSide(
                color: primary
                    ? StudentDensityTokens.dark
                    : StudentDensityTokens.line,
              ),
        minimumSize: Size(0, mobile ? 52 : 44),
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 18 : 16,
          vertical: mobile ? 14 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mobile ? 18 : 16),
        ),
        textStyle: TextStyle(
          fontSize: mobile ? 14 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
