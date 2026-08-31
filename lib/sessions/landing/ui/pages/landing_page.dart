import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:s11/sessions/auth/ui/pages/login_page.dart';
import 'package:s11/sessions/auth/ui/pages/signup_page.dart';
import 'package:s11/sessions/auth/ui/widgets/auth_design.dart';
import 'package:s11/sessions/landing/ui/pages/landing_about_page.dart';

class LandingPage extends StatefulWidget {
  static const routeName = '/';
  static const _contactEmail = 'aiflow683@gmail.com';

  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  /// 필요한 변수는 현재 화면의 Navigator와 Dialog 컨텍스트입니다.
  /// 작동 원리는 랜딩 위에 반응형 로그인 모달을 표시하고 성공 시 기존 인증 이동 흐름을 유지하는 것입니다.
  void _goToLogin(BuildContext context) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: .46),
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: LoginPage(asDialog: true),
      ),
    );
  }

  /// 필요한 변수는 현재 Navigator입니다.
  /// 작동 원리는 정식 `/signup`과 같은 회원가입 화면을 전체 페이지로 여는 것입니다.
  void _goToSignup(BuildContext context) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => const SignupPage()));
  }

  /// 필요한 변수는 현재 Navigator입니다.
  /// 작동 원리는 서비스 소개 화면을 기존 라우팅 방식 그대로 여는 것입니다.
  void _goToAbout(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LandingAboutPage()));
  }

  /// 필요한 변수는 현재 화면 컨텍스트와 문의 이메일입니다.
  /// 작동 원리는 외부 메일 앱을 열고 실패하면 화면 하단에 주소를 안내하는 것입니다.
  Future<void> _contactByEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: LandingPage._contactEmail,
      queryParameters: const {
        'subject': 'AIFlow 문의',
        'body': '안녕하세요. AIFlow 도입 문의드립니다.',
      },
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('메일 앱을 열 수 없습니다. aiflow683@gmail.com 으로 문의해주세요.'),
      ),
    );
  }

  /// 필요한 변수는 로그인·가입·소개·문의 콜백과 화면 폭입니다.
  /// 작동 원리는 데스크톱에서 소개와 인증 선택을 2열로 두고, 모바일에서는
  /// 일반 앱 로그인처럼 브랜드와 폼을 한 열로 두어 작은 세로 화면에서도 입력을 보장하는 것입니다.
  @override
  Widget build(BuildContext context) {
    final mobile = isAuthMobile(context);
    final inlineSignup = useInlineSignupEntry(context);
    final story = _LandingStory(
      onAbout: () => _goToAbout(context),
      onContact: () => _contactByEmail(context),
    );
    final entry = _LandingEntry(
      onLogin: () => _goToLogin(context),
      onSignup: () => _goToSignup(context),
      showSignupButton: !inlineSignup,
    );

    return Scaffold(
      backgroundColor: AuthDesignTokens.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(top: -130, right: -100, child: _AmbientOrb()),
            LayoutBuilder(
              builder: (context, constraints) {
                final content = ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: mobile ? 0 : constraints.maxHeight - 56,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(mobile ? 28 : 38),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x24000000),
                          blurRadius: 80,
                          offset: Offset(0, 28),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: mobile
                        ? entry
                        : IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 11, child: story),
                                Expanded(flex: 9, child: entry),
                              ],
                            ),
                          ),
                  ),
                );
                if (mobile) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 44).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: Center(child: content),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Center(child: content),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingStory extends StatelessWidget {
  const _LandingStory({required this.onAbout, required this.onContact});

  final VoidCallback onAbout;
  final VoidCallback onContact;

  /// 필요한 변수는 소개·문의 콜백과 현재 화면 폭입니다.
  /// 작동 원리는 검은 브랜드 면에 제품 가치와 보조 링크를 우선순위대로 배치하는 것입니다.
  @override
  Widget build(BuildContext context) {
    final mobile = isAuthMobile(context);
    return Container(
      color: AuthDesignTokens.darkSurface,
      padding: EdgeInsets.all(mobile ? 24 : 54),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LandingBrand(light: true),
          SizedBox(height: mobile ? 54 : 108),
          const Text(
            'LEARN WITH FLOW',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '나만의 학습 흐름을\n완성하세요.',
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile ? 40 : 62,
              height: 1.02,
              letterSpacing: mobile ? -2 : -3.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: const Text(
              '진도, 문제 풀이, 필기와 복습 기록을 한곳에서 연결하고 필요한 학습을 다음 흐름으로 이어갑니다.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.65,
              ),
            ),
          ),
          SizedBox(height: mobile ? 48 : 80),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DarkLinkButton(label: 'AIFlow 알아보기', onPressed: onAbout),
              _DarkLinkButton(label: '도입 문의', onPressed: onContact),
            ],
          ),
        ],
      ),
    );
  }
}

class _LandingEntry extends StatelessWidget {
  const _LandingEntry({
    required this.onLogin,
    required this.onSignup,
    required this.showSignupButton,
  });

  final VoidCallback onLogin;
  final VoidCallback onSignup;
  final bool showSignupButton;

  /// 필요한 변수는 로그인·가입 콜백과 현재 화면 폭입니다.
  /// 작동 원리는 모바일에서는 홍보 배너 대신 친숙한 브랜드 헤더와 로그인 폼을 바로 표시하고,
  /// 넓은 화면에서는 기존 모달 진입과 가입 선택을 유지하는 것입니다.
  @override
  Widget build(BuildContext context) {
    final mobile = isAuthMobile(context);
    return Container(
      color: AuthDesignTokens.surface,
      padding: EdgeInsets.all(mobile ? 24 : 54),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (mobile) ...[
            const Row(
              children: [
                _LandingBrand(light: false),
                Spacer(),
                Text(
                  '학습 계정',
                  style: TextStyle(
                    color: AuthDesignTokens.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 42),
            const Text(
              '로그인',
              style: TextStyle(
                color: AuthDesignTokens.ink,
                fontSize: 27,
                letterSpacing: -1.4,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '로그인하고 오늘의 학습을 이어가세요.',
              style: TextStyle(
                color: AuthDesignTokens.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const LoginPage(embedded: true),
          ] else ...[
            const Text(
              'START A SESSION',
              style: TextStyle(
                color: AuthDesignTokens.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'AIFlow 시작하기',
              style: TextStyle(
                color: AuthDesignTokens.ink,
                fontSize: 44,
                letterSpacing: -2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '계정이 있다면 학습 기록을 이어가고, 처음이라면 맞춤 학습 프로필을 만들어 보세요.',
              style: TextStyle(
                color: AuthDesignTokens.muted,
                fontSize: 13,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 34),
            AuthPrimaryButton(label: '로그인', onPressed: onLogin),
            if (showSignupButton) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: onSignup,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: AuthDesignTokens.ink,
                  side: const BorderSide(color: AuthDesignTokens.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Text('새 계정 만들기'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _LandingBrand extends StatelessWidget {
  const _LandingBrand({required this.light});

  final bool light;

  /// 필요한 변수는 밝은 표면 여부입니다.
  /// 작동 원리는 표면 명도에 따라 로고 전경과 배경을 반전하는 것입니다.
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: light ? Colors.white : AuthDesignTokens.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'A',
          style: TextStyle(
            color: light ? AuthDesignTokens.ink : Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(width: 11),
      Text(
        'AIFlow',
        style: TextStyle(
          color: light ? Colors.white : AuthDesignTokens.ink,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _DarkLinkButton extends StatelessWidget {
  const _DarkLinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  /// 필요한 변수는 버튼 문구와 실행 함수입니다.
  /// 작동 원리는 어두운 면의 보조 행동을 반투명 캡슐 버튼으로 표시하는 것입니다.
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    child: Text(label),
  );
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb();

  /// 필요한 변수는 없으며 랜딩 배경에 정적인 밝은 원형 레이어를 표시합니다.
  /// 작동 원리는 이미지 네트워크 요청 없이 중성 배경에 얕은 깊이를 추가하는 것입니다.
  @override
  Widget build(BuildContext context) => Container(
    width: 420,
    height: 420,
    decoration: const BoxDecoration(
      color: Color(0x88FFFFFF),
      shape: BoxShape.circle,
    ),
  );
}
