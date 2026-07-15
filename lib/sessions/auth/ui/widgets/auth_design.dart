import 'package:flutter/material.dart';

/// 인증 화면에서 공통으로 사용하는 흑백 색상과 크기 토큰입니다.
abstract final class AuthDesignTokens {
  static const Color canvas = Color(0xFFF0F0F2);
  static const Color surface = Color(0xFFFDFDFE);
  static const Color surfaceMuted = Color(0xFFF3F3F5);
  static const Color ink = Color(0xFF09090B);
  static const Color muted = Color(0xFF71717A);
  static const Color line = Color(0x1A09090B);
  static const Color darkSurface = Color(0xFF111113);
  static const Color darkMuted = Color(0xFF29292D);
  static const double mobileBreakpoint = 760;
  static const double contentMaxWidth = 1180;
}

/// 필요한 변수는 현재 화면 너비입니다.
/// 작동 원리는 760px 이하에서 카드와 선택지를 한 열로 바꾸는 것입니다.
bool isAuthMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width <= AuthDesignTokens.mobileBreakpoint;

/// 필요한 변수는 입력 필드 제목과 선택적인 안내 문구입니다.
/// 작동 원리는 모든 인증 입력에 같은 표면, 테두리, 포커스 상태를 적용하는 것입니다.
InputDecoration authInputDecoration(String label, {String? hintText}) =>
    InputDecoration(
      labelText: label,
      hintText: hintText,
      filled: true,
      fillColor: AuthDesignTokens.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AuthDesignTokens.line),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AuthDesignTokens.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AuthDesignTokens.ink, width: 1.5),
      ),
    );

/// 필요한 변수는 버튼 문구, 실행 함수, 로딩 상태입니다.
/// 작동 원리는 기본 행동을 48px 이상의 검은 캡슐 버튼으로 통일하는 것입니다.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: loading ? null : onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 50),
      elevation: 0,
      backgroundColor: AuthDesignTokens.ink,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFFD4D4D8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    ),
    child: loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(label),
  );
}

/// 필요한 변수는 현재 단계와 전체 단계입니다.
/// 작동 원리는 진행률을 0~1 범위로 제한해 얇은 흑백 트랙으로 표시하는 것입니다.
class AuthProgress extends StatelessWidget {
  const AuthProgress({super.key, required this.value, required this.stepLabel});

  final double value;
  final String stepLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Text(
            'ACCOUNT SETUP',
            style: TextStyle(
              color: AuthDesignTokens.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          Text(
            stepLabel,
            style: const TextStyle(
              color: AuthDesignTokens.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: 6,
          color: AuthDesignTokens.ink,
          backgroundColor: const Color(0xFFE4E4E7),
        ),
      ),
    ],
  );
}

/// 필요한 변수는 화면 제목, 설명, 진행률, 본문과 뒤로가기 동작입니다.
/// 작동 원리는 넓은 화면에서 안내 패널과 폼을 2열로, 모바일에서는 안내를 축약한 1열로 배치합니다.
class AuthFlowScaffold extends StatelessWidget {
  const AuthFlowScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.progress,
    required this.stepLabel,
    required this.child,
    this.onBack,
  });

  final String eyebrow;
  final String title;
  final String description;
  final double progress;
  final String stepLabel;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final mobile = isAuthMobile(context);
    final formCard = Container(
      padding: EdgeInsets.all(mobile ? 22 : 42),
      decoration: BoxDecoration(
        color: AuthDesignTokens.surface.withValues(alpha: .92),
        border: Border.all(color: Colors.white.withValues(alpha: .9)),
        borderRadius: BorderRadius.circular(mobile ? 26 : 32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 48,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthProgress(value: progress, stepLabel: stepLabel),
          SizedBox(height: mobile ? 28 : 40),
          child,
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AuthDesignTokens.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 360,
                height: 360,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x66FFFFFF),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                mobile ? 14 : 34,
                mobile ? 14 : 28,
                mobile ? 14 : 34,
                40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AuthDesignTokens.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AuthBrandBar(onBack: onBack),
                      SizedBox(height: mobile ? 18 : 30),
                      if (mobile) ...[
                        _AuthIntro(
                          eyebrow: eyebrow,
                          title: title,
                          description: description,
                          compact: true,
                        ),
                        const SizedBox(height: 18),
                        formCard,
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 8,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  52,
                                  64,
                                  0,
                                ),
                                child: _AuthIntro(
                                  eyebrow: eyebrow,
                                  title: title,
                                  description: description,
                                ),
                              ),
                            ),
                            Expanded(flex: 10, child: formCard),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 필요한 변수는 뒤로가기 동작입니다.
/// 작동 원리는 로고와 이전 버튼을 하나의 반투명 상단 바에 배치합니다.
class _AuthBrandBar extends StatelessWidget {
  const _AuthBrandBar({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (onBack != null) ...[
        IconButton.filledTonal(
          tooltip: '이전',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
      ],
      Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AuthDesignTokens.ink,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Text(
          'A',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      const SizedBox(width: 10),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AIFlow', style: TextStyle(fontWeight: FontWeight.w900)),
          Text(
            'LEARNING ACCOUNT',
            style: TextStyle(
              color: AuthDesignTokens.muted,
              fontSize: 9,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    ],
  );
}

/// 필요한 변수는 문맥 라벨, 제목, 설명과 모바일 축약 여부입니다.
/// 작동 원리는 시안의 큰 제목과 짧은 설명으로 현재 가입 단계를 먼저 이해하게 합니다.
class _AuthIntro extends StatelessWidget {
  const _AuthIntro({
    required this.eyebrow,
    required this.title,
    required this.description,
    this.compact = false,
  });

  final String eyebrow;
  final String title;
  final String description;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: const TextStyle(
          color: AuthDesignTokens.muted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        title,
        style: TextStyle(
          color: AuthDesignTokens.ink,
          fontSize: compact ? 34 : 54,
          height: 1.02,
          letterSpacing: compact ? -1.6 : -2.8,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        description,
        style: const TextStyle(
          color: AuthDesignTokens.muted,
          fontSize: 14,
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}
