import "package:flutter/material.dart";

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/auth_service.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
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
  bool _passwordObscured = true;
  String? _errorText;

  /// 필요한 변수는 로그인 제출 가능 여부다.
  /// 작동 원리는 기준 HTML처럼 두 필드가 채워진 경우에만 기본 제출 버튼을
  /// 활성화하고, 실제 검증은 `_submit`에서 다시 수행하는 것이다.
  bool get _canSubmit =>
      !_loading &&
      _idController.text.trim().isNotEmpty &&
      _pwController.text.isNotEmpty;

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
        _errorText = studentFacingApiError(
          error,
          fallback: '카카오 로그인을 완료하지 못했어요.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 필요한 변수는 현재 인증 화면 문맥, 비밀번호 표시 상태와 로딩 상태다.
  /// 작동 원리는 일반 로그인 화면처럼 입력·로그인·간편 로그인을 순서대로
  /// 제공하고, 비밀번호 표시 여부만 화면 내부 상태로 전환하는 것이다.
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
          decoration: _authInputDecoration('비밀번호').copyWith(
            suffixIcon: IconButton(
              tooltip: _passwordObscured ? '비밀번호 표시' : '비밀번호 숨기기',
              onPressed: () => setState(() {
                _passwordObscured = !_passwordObscured;
              }),
              icon: Icon(
                _passwordObscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          obscureText: _passwordObscured,
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

  /// 필요한 변수는 HTML 로그인 필드의 외부 레이블과 입력 상태다.
  /// 작동 원리는 기준 HTML처럼 레이블을 입력창 밖에 두고 52px 직각 입력을
  /// 사용하되, 기존 컨트롤러·검증·비밀번호 표시 상태는 그대로 재사용하는 것이다.
  Widget _buildHtmlLoginFormContents(BuildContext context) {
    InputDecoration fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AuthDesignTokens.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AuthDesignTokens.line),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AuthDesignTokens.ink),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AuthDesignTokens.ink),
      ),
    );

    Widget label(String value) => Text(
      value,
      style: const TextStyle(
        color: AuthDesignTokens.muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorText != null) ...[
          Text(
            _errorText!,
            style: const TextStyle(
              color: AuthDesignTokens.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        label('아이디'),
        const SizedBox(height: 7),
        SizedBox(
          height: 52,
          child: TextFormField(
            controller: _idController,
            decoration: fieldDecoration('아이디를 입력하세요'),
            onChanged: (_) => setState(() {}),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? '아이디를 입력하세요' : null,
          ),
        ),
        const SizedBox(height: 14),
        label('비밀번호'),
        const SizedBox(height: 7),
        SizedBox(
          height: 52,
          child: TextFormField(
            controller: _pwController,
            obscureText: _passwordObscured,
            onChanged: (_) => setState(() {}),
            decoration: fieldDecoration('비밀번호를 입력하세요').copyWith(
              suffixIcon: TextButton(
                onPressed: () => setState(() {
                  _passwordObscured = !_passwordObscured;
                }),
                style: TextButton.styleFrom(
                  foregroundColor: AuthDesignTokens.muted,
                  minimumSize: const Size(56, 44),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_passwordObscured ? '보기' : '숨기기'),
              ),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? '비밀번호를 입력하세요' : null,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AuthDesignTokens.ink,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AuthDesignTokens.ink.withValues(
                alpha: .42,
              ),
              disabledForegroundColor: Colors.white.withValues(alpha: .82),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '로그인',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 22),
        const Row(
          children: [
            Expanded(child: Divider(color: AuthDesignTokens.line)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '또는',
                style: TextStyle(fontSize: 10, color: AuthDesignTokens.muted),
              ),
            ),
            Expanded(child: Divider(color: AuthDesignTokens.line)),
          ],
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _loginWithKakao,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEE500),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('카카오로 계속하기'),
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '처음이신가요?',
                style: TextStyle(color: AuthDesignTokens.muted, fontSize: 12),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const SignupPage()),
                      ),
                style: TextButton.styleFrom(
                  foregroundColor: AuthDesignTokens.ink,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.underline,
                  ),
                ),
                child: const Text('계정 만들기'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = Form(
      key: _formKey,
      child: widget.asDialog || widget.embedded
          ? _buildFormContents(context)
          : _buildHtmlLoginFormContents(context),
    );

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

    // 필요한 변수는 화면 크기와 HTML 로그인 폼이다.
    // 작동 원리: 기준 HTML처럼 모바일은 화면 폭 전체, PC는 좌측 그리드에
    // 460px 패널을 두고,
    // 입력·간편 로그인·가입 진입 순서를 동일하게 유지한다.
    return Scaffold(
      backgroundColor: AuthDesignTokens.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth > 720;
            final panelWidth = desktop
                ? (constraints.maxWidth - 40).clamp(0.0, 460.0).toDouble()
                : constraints.maxWidth;
            final panelPadding = desktop
                ? (constraints.maxWidth * .05).clamp(30.0, 48.0).toDouble()
                : 20.0;
            return SingleChildScrollView(
              padding: desktop
                  ? const EdgeInsets.fromLTRB(28, 72, 20, 72)
                  : EdgeInsets.zero,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: desktop
                      ? constraints.maxHeight - 144
                      : constraints.maxHeight,
                ),
                child: Align(
                  alignment: desktop ? Alignment.topLeft : Alignment.topCenter,
                  child: Container(
                    key: const ValueKey('html-login-panel'),
                    width: panelWidth,
                    padding: desktop
                        ? EdgeInsets.all(panelPadding)
                        : const EdgeInsets.fromLTRB(20, 28, 20, 38),
                    decoration: const BoxDecoration(
                      color: AuthDesignTokens.surface,
                      border: Border(
                        top: BorderSide(color: AuthDesignTokens.ink, width: 3),
                        left: BorderSide(color: AuthDesignTokens.line),
                        right: BorderSide(color: AuthDesignTokens.line),
                        bottom: BorderSide(color: AuthDesignTokens.line),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _HtmlLoginBrand(),
                        const SizedBox(height: 38),
                        const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 32,
                            letterSpacing: -1.9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          '학습 기록을 이어서 확인하세요.',
                          style: TextStyle(
                            color: AuthDesignTokens.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 30),
                        form,
                      ],
                    ),
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

class _HtmlLoginBrand extends StatelessWidget {
  const _HtmlLoginBrand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AuthDesignTokens.ink,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(3),
            bottomRight: Radius.circular(10),
            bottomLeft: Radius.circular(3),
          ),
        ),
        child: const Text(
          'A',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      const SizedBox(width: 9),
      const Text(
        'AIFlow',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    ],
  );
}
