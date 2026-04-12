import "package:flutter/material.dart";

import "../services/api_client.dart";
import "../services/auth_service.dart";
import "package:s11/mainstudent.dart";

class SignupPage extends StatefulWidget {
  static const routeName = '/signup';
  const SignupPage({super.key});

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
  bool _loading = false;

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _gradeController.dispose();
    _emailController.dispose();
    _pwController.dispose();
    _pwConfirmController.dispose();
    _profileImageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pwController.text != _pwConfirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 서로 일치하지 않습니다.')),
      );
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
          builder: (_) => MainStudentPage(
            username: _nameController.text.trim(),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 실패: ${error.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '계정 정보 만들기',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: '아이디',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? '아이디를 입력하세요'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? '이름을 입력하세요'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _gradeController,
                    decoration: const InputDecoration(
                      labelText: '학년 (예: 3학년)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? '학년을 입력하세요'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _profileImageController,
                    decoration: const InputDecoration(
                      labelText: '프로필 이미지 URL (선택)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: '이메일(선택)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pwController,
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) =>
                        (value == null || value.isEmpty)
                            ? '비밀번호를 입력하세요'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pwConfirmController,
                    decoration: const InputDecoration(
                      labelText: '비밀번호 확인',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) =>
                        (value == null || value.isEmpty)
                            ? '비밀번호를 다시 입력하세요'
                            : null,
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('가입하기'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                    child: const Text('이미 계정이 있으신가요? 로그인'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
