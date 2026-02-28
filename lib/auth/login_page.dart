import "package:flutter/material.dart";

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/kakao_login_service.dart';
import '../mainstudent.dart';
import 'sign_up.dart';

class LoginPage extends StatefulWidget {
  static const routeName = '/login';
  const LoginPage({super.key, this.asDialog = false});

  /// Dialog ????? Scaffold ?? ?? ??? ?????.
  final bool asDialog;

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
      ApiClient.instance.setToken(token);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainStudentPage(username: _idController.text.trim()),
        ),
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
      ApiClient.instance.setToken(result.token);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainStudentPage(username: result.displayName),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error is StateError
            ? error.message
            : '??? ???? ??????. ${error.toString()}';
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
        const SizedBox(height: 24),
        TextFormField(
          controller: _idController,
          decoration: InputDecoration(
            labelText: '아이디 혹은 이메일',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
          ),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? '아이디를 입력하세요' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pwController,
          decoration: const InputDecoration(
            labelText: '비밀번호',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
          ),
          obscureText: true,
          validator: (value) =>
              (value == null || value.isEmpty) ? '비밀번호를 입력하세요' : null,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white, // ?? ??
            foregroundColor: Colors.black, // ??? ?
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0, // ??? ?? (??)
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.grey), // ??? (??)
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black, // ?? ????? ?
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
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const BuildpageWidget()));
                },
          style: TextButton.styleFrom(
            backgroundColor: Colors.white, // ? ??
            foregroundColor: Colors.black, // ??? ?
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              //side: const BorderSide(color: Colors.grey), // ???
            ),
          ),
          child: const Text('아이디가 없으신가요? 회원가입'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = Form(key: _formKey, child: _buildFormContents());

    if (widget.asDialog) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
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
      appBar: AppBar(title: const Text('로그인')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(padding: const EdgeInsets.all(24), child: form),
        ),
      ),
    );
  }
}
