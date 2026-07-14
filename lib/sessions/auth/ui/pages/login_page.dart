import "package:flutter/material.dart";

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/auth_service.dart';
import 'package:s11/shared/services/auth/kakao_login_service.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/auth/ui/pages/sign_up.dart';

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
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF202022),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('로그인'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _loading ? null : _loginWithKakao,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFEE500),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
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
          label: Text(_loading ? '' : '카카오 로그인'),
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
            backgroundColor: Colors.white, // 버튼 배경
            foregroundColor: Colors.black, // 텍스트 색상
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              //side: const BorderSide(color: Colors.grey), // 테두리
            ),
          ),
          child: const Text('아이디가 없으신가요? 회원가입'),
        ),
      ],
    );
  }

  /// 필요한 변수는 필드 레이블이다.
  /// 작동 원리는 모든 인증 필드에 16px 모서리와 흑백 포커스 테두리를 공유하는 것이다.
  InputDecoration _authInputDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE0E0E2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.black, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final form = Form(key: _formKey, child: _buildFormContents());

    if (widget.asDialog) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '로그인',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                form,
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 24, 14, 40),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
              decoration: BoxDecoration(
                color: const Color(0xFF202022),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A   AIFlow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'WELCOME BACK',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '멈춘 곳에서\n다시 시작해요.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      height: .95,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 34),
                  Text(
                    '로그인하면 코스 진도, 필기, 복습 기록과 그룹 활동을 그대로 이어갑니다.',
                    style: TextStyle(color: Colors.white54, height: 1.5),
                  ),
                  SizedBox(height: 42),
                  _RestoreNotice(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 32, 22, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STUDENT LOGIN',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      color: Colors.black54,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    '로그인',
                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '아이디 또는 이메일로 로그인하세요.',
                    style: TextStyle(color: Colors.black45),
                  ),
                  form,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
