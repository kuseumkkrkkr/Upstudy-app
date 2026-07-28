import "package:flutter/material.dart";

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/auth_service.dart';
import 'package:s11/shared/services/auth/kakao_login_service.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/auth/ui/pages/signup_page.dart';
import 'package:s11/sessions/auth/ui/widgets/auth_design.dart';

class LoginPage extends StatefulWidget {
  static const routeName = '/login';
  const LoginPage({
    super.key,
    this.asDialog = false,
    this.embedded = false,
    this.initialUsername,
    this.initialPassword,
  });

  /// Dialog로 사용할 때 모달 형태로 렌더링합니다.
  final bool asDialog;

  /// 랜딩 화면 안에 로그인 폼만 직접 표시할 때 사용합니다.
  final bool embedded;
  final String? initialUsername;
  final String? initialPassword;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  final KakaoLoginService _kakaoLoginService = KakaoLoginService();
  bool _loading = false;
  String? _errorText;

  /// 필요한 변수는 미리보기용 아이디와 비밀번호다.
  /// 작동 원리는 초기값이 있을 때만 폼 컨트롤러에 넣어 네트워크 없이 시안 상태를 재현하는 것이다.
  @override
  void initState() {
    super.initState();
    _idController.text = widget.initialUsername ?? '';
    _pwController.text = widget.initialPassword ?? '';
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final token = await AuthService().login(
        username: _idController.text.trim(),
        password: _pwController.text,
      );
      await ApiClient.instance.setToken(
        token,
        username: _idController.text.trim(),
      );
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainStudentPage(username: _idController.text.trim()),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = 'ID혹은 비밀번호가 다릅니다';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loginWithKakao() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final result = await _kakaoLoginService.signIn();
      await ApiClient.instance.setToken(
        result.token,
        username: result.displayName,
      );
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainStudentPage(username: result.displayName),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error is StateError
            ? error.message
            : '카카오 로그인에 실패했습니다. ${error.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 필요한 변수는 현재 인증 화면 문맥이다.
  /// 작동 원리는 좁거나 세로인 화면에서만 가입 진입을 폼 안에 두고,
  /// 어떤 진입점도 동일한 SignupPage와 가입 API를 사용하게 하는 것이다.
  Widget _buildFormContents(BuildContext context) {
    final showInlineSignup = useInlineSignupEntry(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorText != null) ...[
          Text(
            _errorText!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(height: isAuthMobile(context) ? 16 : 28),
        TextFormField(
          controller: _idController,
          decoration: _authInputDecoration('아이디 또는 이메일'),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? '아이디를 입력하세요' : null,
        ),
        SizedBox(height: isAuthMobile(context) ? 12 : 16),
        TextFormField(
          controller: _pwController,
          decoration: _authInputDecoration('비밀번호'),
          obscureText: true,
          validator: (value) =>
              (value == null || value.isEmpty) ? '비밀번호를 입력하세요' : null,
        ),
        SizedBox(height: isAuthMobile(context) ? 16 : 24),
        AuthPrimaryButton(label: '로그인', onPressed: _submit, loading: _loading),
        SizedBox(height: isAuthMobile(context) ? 12 : 18),
        const Row(
          children: [
            Expanded(child: Divider(color: Color(0xFFE5E5E7))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '또는',
                style: TextStyle(fontSize: 11, color: Colors.black38),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFFE5E5E7))),
          ],
        ),
        SizedBox(height: isAuthMobile(context) ? 12 : 18),
        ElevatedButton.icon(
          onPressed: _loading ? null : _loginWithKakao,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFEE500),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Icon(Icons.chat_bubble_outline),
          label: Text(_loading ? '' : '카카오로 계속하기'),
        ),
        if (showInlineSignup) ...[
          SizedBox(height: isAuthMobile(context) ? 10 : 12),
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const SignupPage()),
                    );
                  },
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AuthDesignTokens.line),
              ),
            ),
            child: const Text('처음 오셨나요? 회원가입'),
          ),
          SizedBox(height: isAuthMobile(context) ? 0 : 12),
        ],
      ],
    );
  }

  /// 필요한 변수는 필드 레이블이다.
  /// 작동 원리는 모든 인증 필드에 16px 모서리와 흑백 포커스 테두리를 공유하는 것이다.
  InputDecoration _authInputDecoration(String label) =>
      authInputDecoration(label);

  /// 필요한 변수는 로그인 폼과 현재 화면 폭입니다.
  /// 작동 원리는 데스크톱에서 안내와 폼을 2열로, 모바일에서는 한 화면에 들어가는 단일 로그인 카드로 배치하는 것입니다.
  Widget _buildLoginLayout(BuildContext context, Widget form) {
    final mobile = isAuthMobile(context);
    final story = Container(
      padding: EdgeInsets.all(mobile ? 24 : 52),
      decoration: BoxDecoration(
        color: AuthDesignTokens.darkSurface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(32),
          topRight: Radius.circular(mobile ? 32 : 0),
          bottomLeft: Radius.circular(mobile ? 0 : 32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BrandMark(),
              SizedBox(width: 12),
              Text(
                'AIFlow',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: mobile ? 28 : 46),
          Text(
            mobile ? '다시 시작해요.' : '멈춘 곳에서\n다시 시작해요.',
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile ? 32 : 48,
              height: 1.02,
              letterSpacing: mobile ? -1.6 : -2.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (!mobile) ...[
            SizedBox(height: 24),
            Text(
              '코스 진도, 필기, 복습 기록과 그룹 활동을\n안전하게 불러와 그대로 이어갑니다.',
              style: TextStyle(color: Colors.white60, height: 1.6),
            ),
            SizedBox(height: 38),
            _RestoreNotice(),
          ],
        ],
      ),
    );
    final formCard = Container(
      padding: EdgeInsets.all(mobile ? 20 : 52),
      decoration: BoxDecoration(
        color: AuthDesignTokens.surface,
        borderRadius: mobile
            ? BorderRadius.circular(28)
            : const BorderRadius.only(
                topRight: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mobile) ...[
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AuthDesignTokens.ink,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Text(
                    'A',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'AIFlow',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 22),
          ],
          if (!mobile) ...[
            const Text(
              'STUDENT LOGIN',
              style: TextStyle(
                color: AuthDesignTokens.muted,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 30),
          ],
          Text(
            '로그인',
            style: TextStyle(
              fontSize: mobile ? 32 : 44,
              letterSpacing: -2,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (!mobile) ...[
            const SizedBox(height: 10),
            const Text(
              '아이디 또는 이메일로 로그인하세요.',
              style: TextStyle(color: AuthDesignTokens.muted),
            ),
          ],
          form,
        ],
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: mobile
          ? formCard
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 11, child: story),
                  Expanded(flex: 9, child: formCard),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = Form(key: _formKey, child: _buildFormContents(context));

    if (widget.asDialog) {
      return Material(
        color: AuthDesignTokens.surface,
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isAuthMobile(context) ? 22 : 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
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
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'AIFlow',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '닫기',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                const Text(
                  'WELCOME BACK',
                  style: TextStyle(
                    color: AuthDesignTokens.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '학습을 이어가세요.',
                  style: TextStyle(
                    color: AuthDesignTokens.ink,
                    fontSize: 34,
                    letterSpacing: -1.6,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '아이디 또는 이메일로 안전하게 로그인합니다.',
                  style: TextStyle(color: AuthDesignTokens.muted, fontSize: 12),
                ),
                form,
              ],
            ),
          ),
        ),
      );
    }

    if (widget.embedded) {
      return Material(
        color: Colors.transparent,
        child: Form(key: _formKey, child: _buildFormContents(context)),
      );
    }

    // 필요한 변수는 화면 크기와 로그인 폼이다.
    // 작동 원리: 모바일은 한 화면용으로 축약한 단일 카드를 스크롤 없이
    // 중앙에 배치하고, 데스크톱만 긴 화면을 대비한 세로 스크롤을 사용한다.
    return Scaffold(
      backgroundColor: AuthDesignTokens.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobile = isAuthMobile(context);
            final content = _buildLoginLayout(context, form);
            if (mobile) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(child: content),
              );
            }
            return ClipRect(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(34, 34, 34, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: AuthDesignTokens.contentMaxWidth,
                      minWidth: 0,
                      minHeight: (constraints.maxHeight - 58).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: content,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  /// 필요한 변수는 없으며 흰색 AIFlow 심볼을 고정 크기로 표시합니다.
  /// 작동 원리는 어두운 소개 패널 안에서 브랜드 진입점을 명확히 만드는 것입니다.
  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
    ),
    child: const Text(
      'A',
      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
    ),
  );
}

class _RestoreNotice extends StatelessWidget {
  const _RestoreNotice();

  /// 필요한 변수는 없으며 로그인 복원 정책을 고정 문구로 안내한다.
  /// 작동 원리는 어두운 히어로 안에 한 단계 밝은 표면을 쓰여 세션 안내를 구분하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF2C2C2F),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SESSION RESTORE',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 9,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '저장된 로그인은 안전하게 확인합니다.',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 5),
        Text(
          'JWT 불러오기 → /auth/me 호출 검증',
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    ),
  );
}
