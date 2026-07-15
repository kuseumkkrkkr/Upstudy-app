import "package:flutter/material.dart";

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/auth_service.dart';
import 'package:s11/shared/services/auth/kakao_login_service.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/auth/ui/pages/sign_up.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/sessions/auth/ui/widgets/auth_design.dart';

class LoginPage extends StatefulWidget {
  static const routeName = '/login';
  const LoginPage({
    super.key,
    this.asDialog = false,
    this.initialUsername,
    this.initialPassword,
  });

  /// Dialog로 사용할 때 모달 형태로 렌더링합니다.
  final bool asDialog;
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

  Widget _buildFormContents() {
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
        const SizedBox(height: 28),
        TextFormField(
          controller: _idController,
          decoration: _authInputDecoration('아이디 또는 이메일'),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? '아이디를 입력하세요' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pwController,
          decoration: _authInputDecoration('비밀번호'),
          obscureText: true,
          validator: (value) =>
              (value == null || value.isEmpty) ? '비밀번호를 입력하세요' : null,
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: '로그인', onPressed: _submit, loading: _loading),
        const SizedBox(height: 18),
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
        const SizedBox(height: 18),
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
        const SizedBox(height: 12),
        TextButton(
          onPressed: _loading
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BuildpageWidget()),
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
        const SizedBox(height: 12),
      ],
    );
  }

  /// 필요한 변수는 필드 레이블이다.
  /// 작동 원리는 모든 인증 필드에 16px 모서리와 흑백 포커스 테두리를 공유하는 것이다.
  InputDecoration _authInputDecoration(String label) =>
      authInputDecoration(label);

  /// 필요한 변수는 로그인 폼과 현재 화면 폭입니다.
  /// 작동 원리는 데스크톱에서 안내와 폼을 2열로, 모바일에서는 읽기 순서대로 1열로 배치하는 것입니다.
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
      child: const Column(
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
          SizedBox(height: 46),
          Text(
            'WELCOME BACK',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 14),
          Text(
            '멈춘 곳에서\n다시 시작해요.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              height: 1.02,
              letterSpacing: -2.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 24),
          Text(
            '코스 진도, 필기, 복습 기록과 그룹 활동을\n안전하게 불러와 그대로 이어갑니다.',
            style: TextStyle(color: Colors.white60, height: 1.6),
          ),
          SizedBox(height: 38),
          _RestoreNotice(),
        ],
      ),
    );
    final formCard = Container(
      padding: EdgeInsets.all(mobile ? 24 : 52),
      decoration: BoxDecoration(
        color: AuthDesignTokens.surface,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(mobile ? 0 : 32),
          bottomLeft: Radius.circular(mobile ? 32 : 0),
          bottomRight: const Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text(
            '로그인',
            style: TextStyle(
              fontSize: mobile ? 36 : 44,
              letterSpacing: -2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '아이디 또는 이메일로 로그인하세요.',
            style: TextStyle(color: AuthDesignTokens.muted),
          ),
          form,
        ],
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: mobile
          ? Column(children: [story, formCard])
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
    final form = Form(key: _formKey, child: _buildFormContents());

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

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: Colors.black,
                showLevelIndicator: false,
                onMenu: () => toggleAppDrawer(context),
                items: const [],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  isAuthMobile(context) ? 14 : 34,
                  isAuthMobile(context) ? 18 : 34,
                  isAuthMobile(context) ? 14 : 34,
                  40,
                ),
                children: [Center(child: _buildLoginLayout(context, form))],
              ),
            ),
          ],
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
