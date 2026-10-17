import 'package:flutter/material.dart';

/// 학생 밀도 축소 시안에서 공통으로 사용하는 색상과 간격 토큰입니다.
abstract final class StudentDensityTokens {
  // The reference export uses #f0f0f2 as its page canvas. Keep the token
  // centralized so every student surface follows the same visual baseline.
  static const Color background = Color(0xFFF0F0F2);
  static const Color surface = Color(0xFFFDFDFE);
  static const Color surfaceMuted = Color(0xFFF3F3F5);
  static const Color ink = Color(0xFF09090B);
  static const Color muted = Color(0xFF71717A);
  static const Color faint = Color(0xFFA1A1AA);
  static const Color line = Color(0x1A09090B);
  static const Color lineStrong = Color(0x2E09090B);
  static const Color dark = Color(0xFF111113);
  static const Color darkSecondary = Color(0xFF29292D);
  static const double desktopMaxWidth = 1500;

  /// The HTML reference switches the shared shell at 720px. Individual
  /// immersive workspaces may keep their own narrower layout thresholds.
  static const double mobileBreakpoint = 720;
  static const double desktopBreakpoint = 1040;
  static const double mobileTextMultiplier = 1.2;
  static const double mobileIconMultiplier = 1.25;
  // The reference keeps shared surfaces square. Rounded corners are opt-in
  // only where the HTML screen explicitly overrides the global rule.
  static const double radiusSmall = 0;
  static const double radiusMedium = 0;
  static const double radius = 0;
  static const double radiusExtraLarge = 0;
}

/// 필요 변수: 현재 화면 너비.
/// 작동 원리: 기준 HTML의 720px 기준을 사용해 모바일 재배치 여부를 반환합니다.
bool isStudentDensityMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width <= StudentDensityTokens.mobileBreakpoint;

/// Keeps HTML-sized cards compact while retaining system zoom and a 12px mobile floor.
TextScaler studentReferenceCardTextScaler(BuildContext context) {
  final current = MediaQuery.textScalerOf(context);
  final source = current is _StudentReadableTextScaler
      ? current.original
      : current;
  return _StudentMinimumReadableTextScaler(source);
}

class _StudentMinimumReadableTextScaler extends TextScaler {
  const _StudentMinimumReadableTextScaler(this.source);

  final TextScaler source;

  @override
  double scale(double fontSize) {
    if (fontSize == 0) return 0;
    final scaled = source.scale(fontSize);
    return scaled < 12 ? 12 : scaled;
  }

  @override
  double get textScaleFactor => scale(14) / 14;
}

/// 모바일 가독성 조정. 사용자의 접근성 확대값은 보존하며 작은 문구는 12px 이상 표시한다.
class StudentMobileReadability extends StatelessWidget {
  const StudentMobileReadability({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width > StudentDensityTokens.mobileBreakpoint) return child;
    return MediaQuery(
      data: media.copyWith(
        textScaler: _StudentReadableTextScaler(media.textScaler),
      ),
      child: IconTheme.merge(data: const IconThemeData(size: 30), child: child),
    );
  }
}

class _StudentReadableTextScaler extends TextScaler {
  const _StudentReadableTextScaler(this.original);
  final TextScaler original;

  @override
  double scale(double fontSize) {
    if (fontSize == 0) return 0;
    final scaled =
        original.scale(fontSize) * StudentDensityTokens.mobileTextMultiplier;
    return scaled < 12 ? 12 : scaled;
  }

  @override
  double get textScaleFactor => scale(14) / 14;
}

/// SVG glyphs used by the HTML reference for shared navigation and home actions.
enum StudentHtmlIcon {
  home,
  courses,
  market,
  more,
  play,
  check,
  spark,
  calendar,
  book,
  arrow,
  filter,
  courseBookmark,
  chart,
  search,
  pageSearch,
  menu,
  back,
  bell,
  close,
}

/// Draws an HTML reference SVG path with the same 24px stroke geometry.
class StudentHtmlGlyph extends StatelessWidget {
  const StudentHtmlGlyph({
    super.key,
    required this.icon,
    required this.color,
    this.size = 20,
    this.scaleForMobile = true,
  });

  final StudentHtmlIcon icon;
  final Color color;
  final double size;
  final bool scaleForMobile;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final scale = mobile && scaleForMobile
        ? StudentDensityTokens.mobileIconMultiplier
        : 1.0;
    final glyphSize = size * scale;
    return SizedBox.square(
      dimension: glyphSize,
      child: CustomPaint(painter: _StudentHtmlGlyphPainter(icon, color)),
    );
  }
}

class _StudentHtmlGlyphPainter extends CustomPainter {
  const _StudentHtmlGlyphPainter(this.icon, this.color);

  final StudentHtmlIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final squareStroke =
        icon == StudentHtmlIcon.courseBookmark || icon == StudentHtmlIcon.chart;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = squareStroke ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = squareStroke ? StrokeJoin.miter : StrokeJoin.round
      ..isAntiAlias = true;

    switch (icon) {
      case StudentHtmlIcon.pageSearch:
      case StudentHtmlIcon.search:
        canvas.drawCircle(const Offset(11, 11), 6, stroke);
        canvas.drawLine(const Offset(16, 16), const Offset(20, 20), stroke);
      case StudentHtmlIcon.menu:
        for (final y in const [7.0, 12.0, 17.0]) {
          canvas.drawLine(Offset(5, y), Offset(19, y), stroke);
        }
      case StudentHtmlIcon.back:
        canvas.drawPath(
          Path()
            ..moveTo(15, 5)
            ..lineTo(8, 12)
            ..lineTo(15, 19),
          stroke,
        );
      case StudentHtmlIcon.bell:
        final bell = Path()
          ..moveTo(6, 17)
          ..lineTo(18, 17)
          ..lineTo(16.5, 15)
          ..lineTo(16.5, 10)
          ..cubicTo(16.5, 7.5, 14.5, 5.5, 12, 5.5)
          ..cubicTo(9.5, 5.5, 7.5, 7.5, 7.5, 10)
          ..lineTo(7.5, 15)
          ..close()
          ..moveTo(10, 20)
          ..lineTo(14, 20);
        canvas.drawPath(bell, stroke);
      case StudentHtmlIcon.close:
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), stroke);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), stroke);
      case StudentHtmlIcon.home:
        final path = Path()
          ..moveTo(3, 11.5)
          ..lineTo(12, 4)
          ..lineTo(21, 11.5)
          ..lineTo(21, 19.5)
          ..arcToPoint(
            const Offset(19.5, 21),
            radius: const Radius.circular(1.5),
          )
          ..lineTo(14.5, 21)
          ..lineTo(14.5, 15)
          ..lineTo(9.5, 15)
          ..lineTo(9.5, 21)
          ..lineTo(4.5, 21)
          ..arcToPoint(
            const Offset(3, 19.5),
            radius: const Radius.circular(1.5),
          )
          ..close();
        canvas.drawPath(path, stroke);
      case StudentHtmlIcon.courses:
        final courses = Path()
          ..addRect(const Rect.fromLTRB(5, 4, 19, 9))
          ..addRect(const Rect.fromLTRB(5, 15, 19, 20))
          ..moveTo(8, 9)
          ..lineTo(8, 15)
          ..moveTo(16, 9)
          ..lineTo(16, 15);
        canvas.drawPath(courses, stroke);
      case StudentHtmlIcon.market:
        final market = Path()
          ..moveTo(4, 9)
          ..lineTo(20, 9)
          ..lineTo(19, 4)
          ..lineTo(5, 4)
          ..close()
          ..moveTo(6, 9)
          ..lineTo(6, 19)
          ..lineTo(18, 19)
          ..lineTo(18, 9)
          ..moveTo(9, 19)
          ..lineTo(9, 14)
          ..lineTo(15, 14)
          ..lineTo(15, 19);
        canvas.drawPath(market, stroke);
      case StudentHtmlIcon.more:
        for (final x in const [5.0, 12.0, 19.0]) {
          canvas.drawCircle(Offset(x, 12), 1.5, stroke);
        }
      case StudentHtmlIcon.play:
        final play = Path()
          ..moveTo(9, 6)
          ..lineTo(18, 12)
          ..lineTo(9, 18)
          ..close();
        canvas.drawPath(play, stroke);
      case StudentHtmlIcon.check:
        final check = Path()
          ..moveTo(5, 12)
          ..lineTo(9, 16)
          ..lineTo(19, 6);
        canvas.drawPath(check, stroke);
      case StudentHtmlIcon.spark:
        final spark = Path()
          ..moveTo(12, 2)
          ..lineTo(13.4, 6.6)
          ..lineTo(18, 8)
          ..lineTo(13.4, 9.4)
          ..lineTo(12, 14)
          ..lineTo(10.6, 9.4)
          ..lineTo(6, 8)
          ..lineTo(10.6, 6.6)
          ..close()
          ..moveTo(5, 14)
          ..lineTo(5.8, 16.2)
          ..lineTo(8, 17)
          ..lineTo(5.8, 17.8)
          ..lineTo(5, 20)
          ..lineTo(4.2, 17.8)
          ..lineTo(2, 17)
          ..lineTo(4.2, 16.2)
          ..close();
        canvas.drawPath(spark, stroke);
      case StudentHtmlIcon.calendar:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(4, 5, 20, 20),
            const Radius.circular(2),
          ),
          stroke,
        );
        final calendar = Path()
          ..moveTo(8, 3)
          ..lineTo(8, 7)
          ..moveTo(16, 3)
          ..lineTo(16, 7)
          ..moveTo(4, 10)
          ..lineTo(20, 10);
        canvas.drawPath(calendar, stroke);
      case StudentHtmlIcon.book:
        final book = Path()
          ..moveTo(4, 5.5)
          ..arcToPoint(
            const Offset(7.5, 2),
            radius: const Radius.circular(3.5),
            clockwise: false,
          )
          ..lineTo(12, 2)
          ..lineTo(12, 19)
          ..lineTo(7.5, 19)
          ..arcToPoint(const Offset(4, 22), radius: const Radius.circular(3.5))
          ..close()
          ..moveTo(20, 5.5)
          ..arcToPoint(
            const Offset(16.5, 2),
            radius: const Radius.circular(3.5),
          )
          ..lineTo(12, 2)
          ..lineTo(12, 19)
          ..lineTo(16.5, 19)
          ..arcToPoint(
            const Offset(20, 22),
            radius: const Radius.circular(3.5),
            clockwise: false,
          )
          ..close();
        canvas.drawPath(book, stroke);
      case StudentHtmlIcon.arrow:
        final arrow = Path()
          ..moveTo(5, 12)
          ..lineTo(19, 12)
          ..moveTo(14, 7)
          ..lineTo(19, 12)
          ..lineTo(14, 17);
        canvas.drawPath(arrow, stroke);
      case StudentHtmlIcon.filter:
        final filter = Path()
          ..moveTo(4, 6)
          ..lineTo(20, 6)
          ..moveTo(7, 12)
          ..lineTo(17, 12)
          ..moveTo(10, 18)
          ..lineTo(14, 18);
        canvas.drawPath(filter, stroke);
      case StudentHtmlIcon.courseBookmark:
        final bookmark = Path()
          ..moveTo(5, 4)
          ..lineTo(19, 4)
          ..lineTo(19, 20)
          ..lineTo(12, 17)
          ..lineTo(5, 20)
          ..close()
          ..moveTo(9, 8)
          ..lineTo(15, 8);
        canvas.drawPath(bookmark, stroke);
      case StudentHtmlIcon.chart:
        final chart = Path()
          ..moveTo(4, 20)
          ..lineTo(4, 10)
          ..moveTo(10, 20)
          ..lineTo(10, 4)
          ..moveTo(16, 20)
          ..lineTo(16, 13)
          ..moveTo(22, 20)
          ..lineTo(2, 20);
        canvas.drawPath(chart, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StudentHtmlGlyphPainter oldDelegate) =>
      icon != oldDelegate.icon || color != oldDelegate.color;
}

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
/// 작동 원리: 기본은 PC 문맥 라벨만 표시하며 화면별 허용 시 모바일에도 표시합니다.
class StudentDensityEyebrow extends StatelessWidget {
  const StudentDensityEyebrow(
    this.text, {
    super.key,
    this.color,
    this.showOnMobile = false,
  });

  final String text;
  final Color? color;
  final bool showOnMobile;

  @override
  Widget build(BuildContext context) {
    if (isStudentDensityMobile(context) && !showOnMobile) {
      return const SizedBox.shrink();
    }
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
    this.showMobileEyebrow = false,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final Widget? action;
  final bool showMobileDescription;
  final bool showMobileEyebrow;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!mobile || showMobileEyebrow) ...[
          StudentDensityEyebrow(eyebrow, showOnMobile: showMobileEyebrow),
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: TextStyle(
          fontSize: mobile ? 14 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
