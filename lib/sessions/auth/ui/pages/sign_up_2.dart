import 'package:s11/shared/services/api/auth_service.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:flutter/material.dart';

import 'sign_up_3.dart';
import 'package:s11/sessions/auth/session/signup_flow.dart';
import 'package:s11/sessions/auth/ui/widgets/auth_design.dart';

class BuildpageCopyWidget extends StatefulWidget {
  const BuildpageCopyWidget({
    super.key,
    required this.draft,
    required this.completedSteps,
    required this.totalSteps,
  });

  final SignupDraft draft;
  final int completedSteps;
  final int totalSteps;

  @override
  State<BuildpageCopyWidget> createState() => _BuildpageCopyWidgetState();
}

class _BuildpageCopyWidgetState extends State<BuildpageCopyWidget> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _idConfirmed = false;
  bool _passwordConfirmed = false;
  bool _checkingId = false;
  bool _checkingPassword = false;
  bool _submitting = false;
  String _idHint = '4자리 ~ 16자리 영어 대소문자와 숫자만 가능합니다';
  String _passwordHint = ' 8 ~ 20자리 영어 대소문자와 숫자를 포함하여야 합니다';
  String _emailHint = '';
  int _idHintToken = 0;
  int _passwordHintToken = 0;
  int _emailHintToken = 0;

  bool get _showPasswordSection => _idConfirmed;
  bool get _showEmailSection => _passwordConfirmed;

  int get _completedSteps =>
      widget.completedSteps +
      (_idConfirmed ? 1 : 0) +
      (_passwordConfirmed ? 1 : 0);

  double get _progressPercent {
    final total = widget.totalSteps;
    if (total <= 0) return 0;
    final value = _completedSteps / total;
    return value.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool _isUsernameValid(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final pattern = RegExp(r'^[A-Za-z0-9]{4,16}$');
    return pattern.hasMatch(trimmed);
  }

  bool _isPasswordValid(String value) {
    if (value.isEmpty) return false;
    final pattern = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,20}$');
    return pattern.hasMatch(value);
  }

  bool _isEmailValid(String value) {
    if (value.trim().isEmpty) return true;
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return pattern.hasMatch(value.trim());
  }

  Future<void> _showTemporaryIdHint(String message) async {
    final token = ++_idHintToken;
    setState(() => _idHint = message);
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || token != _idHintToken) return;
    setState(() => _idHint = '4자리 ~ 16자리 영어 대소문자와 숫자만 가능합니다');
  }

  Future<void> _showTemporaryPasswordHint(String message) async {
    final token = ++_passwordHintToken;
    setState(() => _passwordHint = message);
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || token != _passwordHintToken) return;
    setState(() => _passwordHint = ' 8 ~ 20자리 영어 대소문자와 숫자를 포함하여야 합니다');
  }

  Future<void> _showTemporaryEmailHint(String message) async {
    final token = ++_emailHintToken;
    setState(() => _emailHint = message);
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || token != _emailHintToken) return;
    setState(() => _emailHint = '');
  }

  Future<void> _checkUsername() async {
    if (_checkingId) return;
    final username = _idController.text.trim();
    if (!_isUsernameValid(username)) {
      await _showTemporaryIdHint('형식이 다릅니다');
      return;
    }
    setState(() => _checkingId = true);
    try {
      final result = await AuthService().checkUsername(username);
      if (!result.available) {
        await _showTemporaryIdHint(result.reason ?? '중복 미확인!');
        return;
      }
      setState(() {
        _idConfirmed = true;
        _idHint = '4자리 ~ 16자리 영어 대소문자와 숫자만 가능합니다';
      });
      if (!mounted) return;
      FocusScope.of(context).unfocus();
    } catch (_) {
      await _showTemporaryIdHint('확인에 실패했습니다');
      return;
    } finally {
      if (mounted) {
        setState(() => _checkingId = false);
      }
    }
  }

  Future<void> _confirmPassword() async {
    if (_checkingPassword) return;
    final password = _passwordController.text;
    if (!_isPasswordValid(password)) {
      await _showTemporaryPasswordHint('형식이 다릅니다');
      return;
    }
    setState(() => _checkingPassword = true);
    try {
      final result = await AuthService().validateField(
        field: 'password',
        value: password,
      );
      if (!result.valid) {
        await _showTemporaryPasswordHint(result.reason ?? '형식이 다릅니다');
        return;
      }
      setState(() => _passwordConfirmed = true);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
    } catch (_) {
      await _showTemporaryPasswordHint('확인에 실패했습니다');
      return;
    } finally {
      if (mounted) {
        setState(() => _checkingPassword = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final email = _emailController.text.trim();
    if (!_isEmailValid(email)) {
      await _showTemporaryEmailHint('형식이 다릅니다');
      return;
    }
    setState(() => _submitting = true);
    try {
      final validation = await AuthService().validateField(
        field: 'email',
        value: email,
      );
      if (!validation.valid) {
        await _showTemporaryEmailHint(validation.reason ?? '형식이 다릅니다');
        return;
      }
      final token = await AuthService().register(
        username: _idController.text.trim(),
        password: _passwordController.text,
        name: widget.draft.displayName,
        grade: widget.draft.gradeSummary,
        email: email.isEmpty ? null : email,
        track: widget.draft.track,
        subject: widget.draft.subject,
        school: widget.draft.schoolName,
      );
      await ApiClient.instance.setToken(
        token,
        username: _idController.text.trim(),
      );
      if (!mounted) return;
      final completedSteps = _completedSteps + 1; // signup submission step
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BuildpageCopyCopyWidget(
            draft: widget.draft,
            completedSteps: completedSteps,
            totalSteps: widget.totalSteps,
            username: _idController.text.trim(),
          ),
        ),
      );
    } catch (_) {
      await _showTemporaryEmailHint('확인에 실패했습니다');
      return;
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AuthFlowScaffold(
        eyebrow: 'New account · Security',
        title: '안전한 계정을\n완성해요.',
        description: '로그인에 사용할 아이디와 비밀번호를 설정합니다. 이메일은 계정 복구에 활용할 수 있어요.',
        progress: _progressPercent,
        stepLabel: '2 / 3',
        onBack: () => Navigator.of(context).maybePop(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputSection(
              label: '사용할 아이디를 알려주세요',
              hint: _idHint,
              controller: _idController,
              enabled: !_idConfirmed,
              onChanged: (_) {
                if (_idConfirmed) return;
                if (_idHint != '4자리 ~ 16자리 영어 대소문자와 숫자만 가능합니다') {
                  setState(() {
                    _idHint = '4자리 ~ 16자리 영어 대소문자와 숫자만 가능합니다';
                  });
                }
              },
            ),

            _buildSlidingSection(
              visible: _showPasswordSection,
              sectionKey: 'password',
              child: _buildInputSection(
                label: '사용하실 비밀번호를 입력해주세요',
                hint: _passwordHint,
                controller: _passwordController,
                topPadding: 10,
                enabled: !_passwordConfirmed,
                onChanged: (_) {
                  if (_passwordConfirmed) return;
                  if (_passwordHint != ' 8 ~ 20자리 영어 대소문자와 숫자를 포함하여야 합니다') {
                    setState(() {
                      _passwordHint = ' 8 ~ 20자리 영어 대소문자와 숫자를 포함하여야 합니다';
                    });
                  }
                },
              ),
            ),

            _buildSlidingSection(
              visible: _showEmailSection,
              sectionKey: 'email',
              child: _buildInputSection(
                label: '이메일을 입력해 주세요(선택)',
                hint: _emailHint,
                controller: _emailController,
                topPadding: 10,
                onChanged: (_) {
                  if (_emailHint.isNotEmpty) {
                    setState(() => _emailHint = '');
                  }
                },
              ),
            ),

            const SizedBox(height: 18),
            AuthPrimaryButton(
              label: _idConfirmed
                  ? _passwordConfirmed
                        ? '가입 완료하기'
                        : '비밀번호 확인'
                  : '아이디 중복 확인',
              onPressed: (_submitting || _checkingId || _checkingPassword)
                  ? null
                  : _idConfirmed
                  ? _passwordConfirmed
                        ? _submit
                        : _confirmPassword
                  : _checkUsername,
              loading: _submitting || _checkingId || _checkingPassword,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                '이미 계정이 있으신가요? 로그인',
                style: TextStyle(
                  color: AuthDesignTokens.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection({
    required String label,
    required String hint,
    required TextEditingController controller,
    double topPadding = 0,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AuthDesignTokens.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: enabled,
            obscureText: label.contains('비밀번호'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            decoration: authInputDecoration(
              label.contains('아이디')
                  ? '아이디'
                  : label.contains('비밀번호')
                  ? '비밀번호'
                  : '이메일 (선택)',
            ),
            onChanged: onChanged,
          ),
          if (hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                hint.trim(),
                style: const TextStyle(
                  color: AuthDesignTokens.muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlidingSection({
    required bool visible,
    required String sectionKey,
    required Widget child,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation);
        return ClipRect(
          child: SlideTransition(
            position: offset,
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: visible
          ? KeyedSubtree(key: ValueKey(sectionKey), child: child)
          : const SizedBox.shrink(),
    );
  }
}
