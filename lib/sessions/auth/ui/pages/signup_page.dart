import "package:flutter/material.dart";

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/auth_service.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';

class SignupPage extends StatefulWidget {
  static const routeName = '/signup';
  const SignupPage({super.key, this.preview = false});

  final bool preview;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _emailController = TextEditingController();
  final _pwController = TextEditingController();
  final _pwConfirmController = TextEditingController();
  final _profileImageController = TextEditingController();
  final _schoolController = TextEditingController();
  String _subject = '수학';
  bool _loading = false;

  /// 필요한 변수는 미리보기 여부다.
  /// 작동 원리는 시안 캡처일 때만 학생 정보를 채워 네트워크 없이 완성 상태를 보이는 것이다.
  @override
  void initState() {
    super.initState();
    if (!widget.preview) return;
    _nameController.text = '김학생';
    _gradeController.text = '2학년';
    _schoolController.text = 'AIFlow 중학교';
    _idController.text = 'student01';
    _pwController.text = 'password123';
    _pwConfirmController.text = 'password123';
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _gradeController.dispose();
    _emailController.dispose();
    _pwController.dispose();
    _pwConfirmController.dispose();
    _profileImageController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pwController.text != _pwConfirmController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 서로 일치하지 않습니다.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final token = await AuthService().register(
        username: _idController.text.trim(),
        password: _pwController.text,
        name: _nameController.text.trim(),
        grade: _gradeController.text.trim(),
        profileImageUrl: _profileImageController.text.trim().isEmpty
            ? null
            : _profileImageController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
      );
      await ApiClient.instance.setToken(
        token,
        username: _idController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              MainStudentPage(username: _nameController.text.trim()),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('회원가입 실패: ${error.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 24, 14, 40),
          children: [
            const Row(
              children: [
                _SignupLogo(),
                SizedBox(width: 10),
                Text(
                  'AIFlow',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'CREATE ACCOUNT',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.6,
                color: Colors.black54,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              '나에게 맞는 학습을\n설정해 볼까요?',
              style: TextStyle(
                fontSize: 36,
                height: .98,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('로그인으로 돌아가기'),
            ),
            const SizedBox(height: 16),
            const _SignupSteps(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE4E4E6)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _signupField(_nameController, '이름', required: true),
                    const SizedBox(height: 14),
                    _signupField(_gradeController, '학년', required: true),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _subject,
                      decoration: _signupDecoration('과목'),
                      items: const [
                        DropdownMenuItem(value: '수학', child: Text('수학')),
                        DropdownMenuItem(value: '과학', child: Text('과학')),
                      ],
                      onChanged: (value) =>
                          setState(() => _subject = value ?? '수학'),
                    ),
                    const SizedBox(height: 14),
                    _signupField(_schoolController, '학교'),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF202022),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('계정 정보 입력하기 →'),
                    ),
                    const SizedBox(height: 24),
                    _signupField(_idController, '아이디', required: true),
                    const SizedBox(height: 14),
                    _signupField(_emailController, '이메일'),
                    const SizedBox(height: 14),
                    _signupField(
                      _pwController,
                      '비밀번호',
                      required: true,
                      obscure: true,
                    ),
                    const SizedBox(height: 14),
                    _signupField(
                      _pwConfirmController,
                      '비밀번호 확인',
                      required: true,
                      obscure: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 컨트롤러·레이블·필수·비밀번호 여부다.
  /// 작동 원리는 회원가입 모든 필드에 동일한 둥근 테두리와 필수 검증을 적용하는 것이다.
  Widget _signupField(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool obscure = false,
  }) => TextFormField(
    controller: controller,
    obscureText: obscure,
    decoration: _signupDecoration(label),
    validator: required
        ? (value) =>
              value == null || value.trim().isEmpty ? '$label을(를) 입력하세요' : null
        : null,
  );

  /// 필요한 변수는 필드 레이블이다.
  /// 작동 원리는 16px 모서리와 엷은 회색 테두리를 회원가입 필드에 공유하는 것이다.
  InputDecoration _signupDecoration(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE0E0E2)),
    ),
  );
}

class _SignupLogo extends StatelessWidget {
  const _SignupLogo();

  /// 필요한 변수는 없으며 A 초성을 검은 로고 표면에 배치한다.
  /// 작동 원리는 상단 브랜드와 스텝 색상을 같은 흑백 토큰으로 맞추는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF202022),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      'A',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
    ),
  );
}

class _SignupSteps extends StatelessWidget {
  const _SignupSteps();

  /// 필요한 변수는 없으며 회원가입 세 단계를 고정 레이블로 표시한다.
  /// 작동 원리는 첫 단계만 검은 배지로 활성화해 HTML 진행 표시를 재현하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE4E4E6)),
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('01  기본 정보', style: TextStyle(fontWeight: FontWeight.w900)),
        Text('02  계정 만들기', style: TextStyle(color: Colors.black38)),
        Text('03  최종 확인', style: TextStyle(color: Colors.black38)),
      ],
    ),
  );
}
