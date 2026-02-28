import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'sign_up_3.dart';
import 'signup_flow.dart';

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
      ApiClient.instance.setToken(token);
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
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 헤더
                _buildHeader(),

                // 진행률 표시
                LinearPercentIndicator(
                  percent: _progressPercent,
                  lineHeight: 8,
                  animation: true,
                  animateFromLastPercent: true,
                  progressColor: const Color(0xFF1B402B),
                  backgroundColor: const Color(0xFFE6E6E6),
                  padding: EdgeInsets.zero,
                ),

                const SizedBox(height: 20),

                // 아이디 입력
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

                // 액션 버튼
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: ElevatedButton(
                    onPressed: (_submitting || _checkingId || _checkingPassword)
                        ? null
                        : _idConfirmed
                        ? _passwordConfirmed
                              ? _submit
                              : _confirmPassword
                        : _checkUsername,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B402B),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(150, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _idConfirmed
                          ? _passwordConfirmed
                                ? '가입하기'
                                : '▼ 계속하기'
                          : '중복확인',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),

                // 로그인 버튼
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      minimumSize: const Size(300, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '이미 계정이 있으신가요? 로그인',
                      style: TextStyle(color: Color(0xFF575757), fontSize: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 70,
      color: Colors.white,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Color(0xFF3B3B3B),
                size: 50,
              ),
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            ),
          ),
          const Text(
            'AIFlow',
            style: TextStyle(
              color: Color(0xFF1B402B),
              fontSize: 50,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(48, topPadding, 0, 0),
          child: Text(
            label,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 20, 48, 0),
          child: TextField(
            controller: controller,
            enabled: enabled,
            style: const TextStyle(fontSize: 30),
            decoration: InputDecoration(
              hintText: 'TextField',
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
        if (hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 5, 0, 0),
            child: Text(
              hint,
              style: const TextStyle(color: Color(0xFF45BF63), fontSize: 16),
            ),
          ),
      ],
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
