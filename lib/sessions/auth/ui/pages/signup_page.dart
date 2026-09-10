import "package:flutter/material.dart";

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/auth_service.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';

const _signupMobileBreakpoint = 780.0;

bool _isSignupCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width <= _signupMobileBreakpoint;

class SignupPage extends StatefulWidget {
  static const routeName = '/signup';
  const SignupPage({super.key, this.preview = false, this.initialStage = 0});

  final bool preview;
  final int initialStage;

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
  String _track = '중학교';
  String _subject = '확률과통계';
  int _stage = 0;
  bool _agreed = false;
  bool _loading = false;
  bool _passwordVisible = false;
  bool _passwordConfirmVisible = false;

  /// 필요한 변수는 미리보기 여부다.
  /// 작동 원리는 시안 캡처일 때만 학생 정보를 채워 네트워크 없이 완성 상태를 보이는 것이다.
  @override
  void initState() {
    super.initState();
    _stage = widget.initialStage.clamp(0, 2);
    _gradeController.text = '1학년';
    if (!widget.preview) return;
    _nameController.text = '김학생';
    _gradeController.text = '2학년';
    _schoolController.text = 'AIFlow 중학교';
    _idController.text = 'student01';
    _emailController.text = 'student@example.com';
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
    final validationError = _registrationValidationError();
    if (validationError != null) {
      _showValidationError(validationError);
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
        track: _track,
        subject: _subject,
        school: _schoolController.text.trim(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            studentFacingApiError(error, fallback: '회원가입을 완료하지 못했어요.'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// 필요한 변수는 회원가입 입력 컨트롤러 전체다.
  /// 작동 원리는 서버와 같은 형식을 제출 전에 검사하고 오류가 있는 단계와 문구를 반환한다.
  (int, String)? _registrationValidationError() {
    return _profileValidationError() ?? _accountValidationError();
  }

  /// 필요한 변수는 학생 기본 정보 컨트롤러다.
  /// 작동 원리는 1단계를 떠나기 전에 필수값과 이름 형식을 확인해 빈 프로필로 다음 단계에 진입하지 못하게 한다.
  (int, String)? _profileValidationError() {
    final name = _nameController.text.trim();
    final grade = _gradeController.text.trim();
    if (name.isEmpty || grade.isEmpty) {
      return (0, '닉네임과 학년을 입력해 주세요.');
    }
    if (!RegExp(r'^[가-힣A-Za-z0-9 ]{1,20}$').hasMatch(name)) {
      return (0, '이름은 한글·영문·숫자 20자 이내로 입력해 주세요.');
    }
    return null;
  }

  /// 필요한 변수는 계정 정보 컨트롤러다.
  /// 작동 원리는 2단계를 떠나기 전에 아이디·비밀번호·선택 이메일을 서버 규칙과 같은 형식으로 확인한다.
  (int, String)? _accountValidationError() {
    final username = _idController.text.trim();
    final password = _pwController.text;
    if (!RegExp(r'^[A-Za-z0-9]{4,16}$').hasMatch(username)) {
      return (1, '아이디는 영문과 숫자 4–16자로 입력해 주세요.');
    }
    if (!RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,20}$',
    ).hasMatch(password)) {
      return (1, '비밀번호는 영문과 숫자를 포함한 8–20자로 입력해 주세요.');
    }
    if (password != _pwConfirmController.text) {
      return (1, '비밀번호가 서로 일치하지 않습니다.');
    }
    final email = _emailController.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return (1, '이메일 형식을 확인해 주세요.');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _buildHtmlSignupScreen(context);
  }

  /// HTML 가입 시안의 고정 패널·단계 헤더·폼 순서를 렌더링한다.
  /// 실제 가입 API와 단계 검증은 기존 상태 메서드를 그대로 사용한다.
  Widget _buildHtmlSignupScreen(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 720;
    final pagePadding = compact
        ? EdgeInsets.zero
        : EdgeInsets.only(
            left: 20,
            right: 35,
            top: (width * .05).clamp(28, 64),
            bottom: (width * .05).clamp(28, 64),
          );
    final panelPadding = compact
        ? const EdgeInsets.fromLTRB(20, 28, 20, 38)
        : EdgeInsets.all((width * .05).clamp(30, 48));
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: pagePadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                key: const ValueKey('signup-html-panel'),
                width: double.infinity,
                padding: panelPadding,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFDFE),
                  border: Border(
                    top: const BorderSide(color: Color(0xFF09090B), width: 3),
                    left: BorderSide(
                      color: const Color(
                        0xFF09090B,
                      ).withValues(alpha: compact ? 0 : .1),
                    ),
                    right: BorderSide(
                      color: const Color(
                        0xFF09090B,
                      ).withValues(alpha: compact ? 0 : .1),
                    ),
                    bottom: BorderSide(
                      color: const Color(
                        0xFF09090B,
                      ).withValues(alpha: compact ? 0 : .1),
                    ),
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SignupHtmlBrand(),
                      const SizedBox(height: 38),
                      _buildHtmlStepHead(),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: switch (_stage) {
                          0 => _buildHtmlProfileStage(),
                          1 => _buildHtmlAccountStage(),
                          _ => _buildHtmlConfirmStage(),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHtmlStepHead() {
    const labels = ['학습 정보', '계정 정보', '가입 확인'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_stage + 1} / 3',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF71717A),
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              labels[_stage],
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < 3; index++) ...[
              Expanded(
                child: Container(
                  height: 3,
                  color: index <= _stage
                      ? const Color(0xFF09090B)
                      : const Color(0xFFF3F3F5),
                ),
              ),
              if (index != 2) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHtmlHeading(String title, String description) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 26 : 32,
            height: 1.15,
            letterSpacing: -.055,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: Color(0xFF71717A),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildHtmlProfileStage() => KeyedSubtree(
    key: const ValueKey('signup-profile'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHtmlHeading('기본 정보를 알려주세요', '학년에 맞는 학습 내용을 준비하는 데 사용해요.'),
        _htmlTextField(
          _nameController,
          '닉네임',
          hint: '닉네임을 입력하세요',
          helper: '다른 학습자에게 표시되는 이름이에요.',
          required: true,
        ),
        const SizedBox(height: 18),
        _htmlTrackField(),
        const SizedBox(height: 18),
        _htmlSelectField(
          label: '학년',
          value: _gradeController.text.isEmpty ? '1학년' : _gradeController.text,
          items: const ['1학년', '2학년', '3학년'],
          onChanged: (value) => setState(() => _gradeController.text = value),
        ),
        const SizedBox(height: 18),
        _htmlSelectField(
          label: '과목',
          value: _subject,
          items: const ['확률과통계', '미적분', '기하'],
          enabled: _track == '고등학교',
          helper: _track == '중학교' ? '중학교 과정은 과목을 따로 선택하지 않아요.' : null,
          onChanged: (value) => setState(() => _subject = value),
        ),
        const SizedBox(height: 18),
        _htmlTextField(
          _schoolController,
          '학교명',
          hint: '학교명을 입력하세요',
          helper: '입력하지 않아도 가입할 수 있고, 나중에 추가할 수 있어요.',
        ),
        const SizedBox(height: 18),
        _htmlPrimaryButton('계정 정보 입력하기', () => _requestStage(1)),
        const SizedBox(height: 22),
        _htmlLoginEntry(),
      ],
    ),
  );

  Widget _htmlTrackField() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '과정',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 7),
      Row(
        children: [
          Expanded(child: _htmlSegment('중학교')),
          const SizedBox(width: 8),
          Expanded(child: _htmlSegment('고등학교')),
        ],
      ),
    ],
  );

  Widget _htmlSegment(String value) => OutlinedButton(
    onPressed: () => setState(() {
      _track = value;
      if (value == '중학교') _subject = '확률과통계';
    }),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      padding: EdgeInsets.zero,
      side: const BorderSide(color: Color(0x1A09090B)),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      foregroundColor: _track == value ? Colors.white : const Color(0xFF09090B),
      backgroundColor: _track == value
          ? const Color(0xFF09090B)
          : const Color(0xFFFDFDFE),
    ),
    child: Text(
      value,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );

  Widget _buildHtmlAccountStage() => KeyedSubtree(
    key: const ValueKey('signup-account'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHtmlHeading('계정 정보를 입력해 주세요', '로그인에 사용할 아이디와 비밀번호예요.'),
        _htmlTextField(
          _idController,
          '아이디',
          helper: '영문과 숫자 4–16자',
          required: true,
        ),
        const SizedBox(height: 18),
        _htmlPasswordField(
          _pwController,
          '비밀번호',
          helper: '영문과 숫자를 포함한 8–20자',
          visible: _passwordVisible,
          onToggle: () => setState(() => _passwordVisible = !_passwordVisible),
        ),
        const SizedBox(height: 18),
        _htmlPasswordField(
          _pwConfirmController,
          '비밀번호 확인',
          visible: _passwordConfirmVisible,
          onToggle: () => setState(
            () => _passwordConfirmVisible = !_passwordConfirmVisible,
          ),
        ),
        const SizedBox(height: 18),
        _htmlTextField(
          _emailController,
          '이메일',
          optional: true,
          helper: '입력하지 않아도 가입할 수 있어요.',
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            SizedBox(
              width: 96,
              child: _htmlSecondaryButton('이전', () => _setStage(0)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _htmlPrimaryButton('입력 정보 확인하기', () => _requestStage(2)),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildHtmlConfirmStage() => KeyedSubtree(
    key: const ValueKey('signup-complete'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHtmlHeading('입력 정보를 확인해 주세요', '가입 후에도 프로필에서 변경할 수 있어요.'),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x1A09090B))),
          ),
          child: Column(
            children: [
              _htmlSummaryRow('닉네임', _nameController.text),
              _htmlSummaryRow('학습 과정', '$_track · ${_gradeController.text}'),
              _htmlSummaryRow('학교명', _schoolController.text),
              _htmlSummaryRow('아이디', _idController.text),
              _htmlSummaryRow('이메일', _emailController.text),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _agreed,
            onChanged: (value) => setState(() => _agreed = value ?? false),
            title: const Text(
              '입력 정보와 서비스 이용 안내를 확인했습니다.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _htmlPrimaryButton(
          '가입하고 학습 시작하기',
          _agreed && !_loading ? _submit : null,
        ),
        const SizedBox(height: 10),
        _htmlSecondaryButton('이전 단계 수정', () => _setStage(1)),
      ],
    ),
  );

  Widget _htmlTextField(
    TextEditingController controller,
    String label, {
    String? hint,
    String? helper,
    bool required = false,
    bool optional = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _htmlFieldLabel(label, optional: optional),
      const SizedBox(height: 7),
      TextFormField(
        controller: controller,
        minLines: 1,
        decoration: _htmlInputDecoration().copyWith(hintText: hint),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? '$label을(를) 입력하세요'
                  : null
            : null,
      ),
      if (helper != null) ...[
        const SizedBox(height: 7),
        Text(
          helper,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF71717A),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ],
  );

  Widget _htmlPasswordField(
    TextEditingController controller,
    String label, {
    String? helper,
    required bool visible,
    required VoidCallback onToggle,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _htmlFieldLabel(label),
      const SizedBox(height: 7),
      TextFormField(
        controller: controller,
        obscureText: !visible,
        decoration: _htmlInputDecoration().copyWith(
          suffixIcon: TextButton(
            onPressed: onToggle,
            child: Text(visible ? '숨기기' : '보기'),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 56,
            minHeight: 48,
          ),
        ),
      ),
      if (helper != null) ...[
        const SizedBox(height: 7),
        Text(
          helper,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF71717A),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ],
  );

  Widget _htmlSelectField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    String? helper,
    bool enabled = true,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _htmlFieldLabel(label),
      const SizedBox(height: 7),
      DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : items.first,
        decoration: _htmlInputDecoration(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        items: [
          for (final item in items)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: enabled
            ? (next) {
                if (next != null) onChanged(next);
              }
            : null,
      ),
      if (helper != null) ...[
        const SizedBox(height: 7),
        Text(
          helper,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF71717A),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ],
  );

  Widget _htmlFieldLabel(String label, {bool optional = false}) => Row(
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      if (optional)
        const Text(
          '  선택',
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF71717A),
            fontWeight: FontWeight.w700,
          ),
        ),
    ],
  );

  InputDecoration _htmlInputDecoration() => const InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: Color(0x1A09090B)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: Color(0x1A09090B)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: Color(0xFF09090B)),
    ),
  );

  Widget _htmlSummaryRow(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 15),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF71717A)),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '선택 안 함' : value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _htmlPrimaryButton(String label, VoidCallback? onPressed) =>
      FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          backgroundColor: const Color(0xFF09090B),
          disabledBackgroundColor: const Color(0x6B09090B),
          disabledForegroundColor: const Color(0x6BFFFFFF),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            if (_loading && onPressed != null)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Text(
                '→',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
          ],
        ),
      );

  Widget _htmlSecondaryButton(String label, VoidCallback onPressed) =>
      OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: const BorderSide(color: Color(0x1A09090B)),
          foregroundColor: const Color(0xFF09090B),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      );

  Widget _htmlLoginEntry() => Center(
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          '이미 계정이 있으신가요? ',
          style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(48, 48),
          ),
          child: const Text(
            '로그인',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    ),
  );

  /// 이전 가입 시안 호출부와의 호환을 위해 보존한다.
  /// 작동 원리는 HTML과 같은 브랜드·제목·로그인 복귀 버튼을 한 헤더에 배치하는 것이다.
  // ignore: unused_element
  Widget _buildHeader() => LayoutBuilder(
    builder: (context, constraints) {
      const brand = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SignupLogo(),
          SizedBox(width: 10),
          Text(
            'AIFlow',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      );
      const title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CREATE ACCOUNT',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.6,
              color: Colors.black54,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 26),
          Text(
            '나에게 맞는 학습을\n설정해 볼까요?',
            style: TextStyle(
              fontSize: 36,
              height: .98,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
      final login = OutlinedButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('로그인으로 돌아가기'),
      );
      if (_isSignupCompact(context)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(alignment: Alignment.centerLeft, child: brand),
            const SizedBox(height: 14),
            title,
            const SizedBox(height: 28),
            login,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(child: brand),
          const Expanded(flex: 2, child: title),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: login),
          ),
        ],
      );
    },
  );

  /// 필요한 변수는 이동할 단계 번호다.
  /// 작동 원리는 진행 배지나 다음 버튼을 누르면 해당 HTML 패널만 표시하는 것이다.
  void _setStage(int stage) => setState(() => _stage = stage.clamp(0, 2));

  /// 필요한 변수는 사용자가 이동하려는 회원가입 단계다.
  /// 작동 원리는 이전 단계 입력을 순서대로 검증하고 오류 단계로 되돌려, 단계 배지로 필수 입력을 건너뛰지 못하게 한다.
  void _requestStage(int stage) {
    final target = stage.clamp(0, 2);
    if (target <= _stage) {
      _setStage(target);
      return;
    }

    for (var prerequisite = 0; prerequisite < target; prerequisite++) {
      final validationError = switch (prerequisite) {
        0 => _profileValidationError(),
        1 => _accountValidationError(),
        _ => null,
      };
      if (validationError != null) {
        _showValidationError(validationError);
        return;
      }
    }
    _setStage(target);
  }

  /// 필요한 변수는 오류가 발생한 단계와 사용자 안내 문구다.
  /// 작동 원리는 해당 단계로 이동해 인라인 필드 오류를 갱신하고 같은 내용을 하단 안내로 한 번 더 알린다.
  void _showValidationError((int, String) validationError) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(validationError.$2)));
    _setStage(validationError.$1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _stage != validationError.$1) return;
      _formKey.currentState?.validate();
    });
  }

  /// 필요한 변수는 학생 기본 정보와 다음 단계 콜백이다.
  /// 작동 원리는 시안의 STEP 01 설명·필수 요약·과정 폼을 한 카드에 구성하는 것이다.
  // ignore: unused_element
  Widget _buildProfileStage() => _stageCard(
    key: const ValueKey('signup-profile'),
    eyebrow: 'STEP 01 · PROFILE',
    title: '먼저 학생 정보를\n알려주세요.',
    description: '과정과 학년은 커리큘럼 추천의 기준이 되며 프로필에서 언제든 수정할 수 있습니다.',
    summary: const ['필수  이름 · 과정 · 학년 · 학교', '선택  고등 과정의 과목'],
    children: [_buildProfileFields()],
  );

  /// 필요한 변수는 이름·과정·학년·과목·학교 입력값과 현재 폼 폭이다.
  /// 작동 원리는 HTML처럼 PC에서는 기본 입력을 2열로, 모바일에서는 읽기 순서대로 1열로 배치하는 것이다.
  Widget _buildProfileFields() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = _isSignupCompact(context);
      final trackField = DropdownButtonFormField<String>(
        initialValue: _track,
        decoration: _signupDecoration('과정'),
        items: const [
          DropdownMenuItem(value: '중학교', child: Text('중학교')),
          DropdownMenuItem(value: '고등학교', child: Text('고등학교')),
        ],
        onChanged: (value) => setState(() => _track = value ?? '중학교'),
      );
      final subjectField = DropdownButtonFormField<String>(
        initialValue: _subject,
        decoration: _signupDecoration('과목'),
        items: const [
          DropdownMenuItem(value: '수학', child: Text('수학')),
          DropdownMenuItem(value: '수학Ⅰ', child: Text('수학Ⅰ')),
          DropdownMenuItem(value: '미적분', child: Text('미적분')),
        ],
        onChanged: (value) => setState(() => _subject = value ?? '수학'),
      );
      final fields = <Widget>[
        _signupField(_nameController, '이름', required: true),
        trackField,
        _signupField(_gradeController, '학년', required: true),
        subjectField,
      ];
      final grid = compact
          ? Column(
              children: [
                for (var index = 0; index < fields.length; index++) ...[
                  fields[index],
                  if (index != fields.length - 1) const SizedBox(height: 14),
                ],
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 14),
                    Expanded(child: fields[1]),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: fields[2]),
                    const SizedBox(width: 14),
                    Expanded(child: fields[3]),
                  ],
                ),
              ],
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          grid,
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _signupField(_schoolController, '학교', required: true),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 58,
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('학교 찾기'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '학교명을 입력하면 자동완성 결과를 확인합니다.',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 18),
          _primaryButton('계정 정보 입력하기 →', () => _requestStage(1)),
        ],
      );
    },
  );

  /// 필요한 변수는 계정 컨트롤러와 다음 단계 콜백이다.
  /// 작동 원리는 STEP 02 규칙·아이디·비밀번호·선택 이메일 입력을 별도 패널로 제공하는 것이다.
  // ignore: unused_element
  Widget _buildAccountStage() => _stageCard(
    key: const ValueKey('signup-account'),
    eyebrow: 'STEP 02 · ACCOUNT',
    title: '사용할 계정을\n만들어 주세요.',
    description: '각 단계가 확인되어야 다음 입력이 열립니다.',
    summary: const ['아이디  영문·숫자 4–16자', '비밀번호  영문+숫자 8–20자', '이메일  선택 입력'],
    children: [
      _signupField(_idController, '아이디', required: true),
      const SizedBox(height: 6),
      _buildUsernameFormatHint(),
      const SizedBox(height: 14),
      _signupField(_pwController, '비밀번호', required: true, obscure: true),
      const SizedBox(height: 14),
      _signupField(
        _pwConfirmController,
        '비밀번호 확인',
        required: true,
        obscure: true,
      ),
      const SizedBox(height: 14),
      _signupField(_emailController, '이메일 · 선택'),
      const SizedBox(height: 18),
      _primaryButton('입력 정보 확인하기 →', () => _requestStage(2)),
    ],
  );

  /// 필요한 변수는 지금까지 입력한 학생·계정 정보와 동의 상태다.
  /// 작동 원리는 STEP 03에서 최종 값을 요약하고 실제 가입 API 버튼을 연결하는 것이다.
  // ignore: unused_element
  Widget _buildConfirmStage() => _stageCard(
    key: const ValueKey('signup-confirm'),
    eyebrow: 'STEP 03 · CONFIRM',
    title: '이 정보로\n시작할게요.',
    description: '가입 완료 후 JWT가 저장되고 학생 홈으로 이동합니다.',
    children: [
      _confirmRow('학생', _nameController.text),
      _confirmRow('학습 과정', '$_track ${_gradeController.text} · $_subject'),
      _confirmRow('학교', _schoolController.text),
      _confirmRow('아이디', _idController.text),
      _confirmRow('이메일', _emailController.text),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _agreed,
        onChanged: (value) => setState(() => _agreed = value ?? false),
        title: const Text(
          '입력 정보와 서비스 이용 안내를 확인했습니다.',
          style: TextStyle(fontSize: 12),
        ),
      ),
      _primaryButton('가입하고 학습 시작하기', _agreed && !_loading ? _submit : null),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => _setStage(1),
        child: const Text('이전 단계 수정'),
      ),
    ],
  );

  /// 필요한 변수는 단계 키·설명 문구·요약·폼 자식이다.
  /// 작동 원리는 모든 가입 단계를 동일한 흰 카드와 설명/입력 2영역 구조로 묶는 것이다.
  Widget _stageCard({
    required Key key,
    required String eyebrow,
    required String title,
    required String description,
    List<String> summary = const [],
    required List<Widget> children,
  }) {
    Widget buildCopy({required bool compact}) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: compact ? const Color(0xFFF0F0F2) : const Color(0xFF202022),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              color: compact ? Colors.black54 : Colors.white54,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: compact ? Colors.black : Colors.white,
              fontSize: 28,
              height: 1.02,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: compact ? Colors.black45 : Colors.white54,
              height: 1.45,
            ),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in summary)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    final form = Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFFE4E4E6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
    return KeyedSubtree(
      key: key,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_isSignupCompact(context)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                form,
                const SizedBox(height: 10),
                buildCopy(compact: true),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: buildCopy(compact: false)),
              const SizedBox(width: 10),
              Expanded(flex: 10, child: form),
            ],
          );
        },
      ),
    );
  }

  /// 필요한 변수는 버튼 레이블과 선택적 콜백이다.
  /// 작동 원리는 회원가입의 주요 행동을 50px 검은 전폭 버튼으로 통일하는 것이다.
  Widget _primaryButton(String label, VoidCallback? onPressed) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF202022),
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        : Text(label),
  );

  /// 필요한 변수는 아이디 입력 컨트롤러의 현재 값이다.
  /// 작동 원리는 영문·숫자 4–16자 규칙을 만족한 경우에만 긍정 안내를 노출해 빈 입력을 유효하다고 오해하지 않게 한다.
  Widget _buildUsernameFormatHint() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _idController,
    builder: (context, value, child) {
      final valid = RegExp(r'^[A-Za-z0-9]{4,16}$').hasMatch(value.text.trim());
      if (!valid) return const SizedBox.shrink();
      return const Text(
        '사용 가능한 형식입니다.',
        style: TextStyle(
          fontSize: 11,
          color: Color(0xFF227A43),
          fontWeight: FontWeight.w700,
        ),
      );
    },
  );

  /// 필요한 변수는 요약 레이블과 현재 입력값이다.
  /// 작동 원리는 최종 확인 정보를 구분선이 있는 한 행으로 표시하는 것이다.
  Widget _confirmRow(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE7E7E9))),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '선택 안 함' : value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

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

class _SignupHtmlBrand extends StatelessWidget {
  const _SignupHtmlBrand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        color: const Color(0xFF09090B),
        child: const Text(
          'A',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      const SizedBox(width: 10),
      const Text(
        'AIFlow',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
    ],
  );
}

// ignore: unused_element
class _SignupSteps extends StatelessWidget {
  const _SignupSteps({required this.stage, required this.onSelected});

  final int stage;
  final ValueChanged<int> onSelected;

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
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final item in const [
          (0, '01', '기본 정보'),
          (1, '02', '계정 만들기'),
          (2, '03', '최종 확인'),
        ])
          Expanded(
            child: TextButton(
              onPressed: () => onSelected(item.$1),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${item.$2}  ${item.$3}',
                  style: TextStyle(
                    fontSize: 12,
                    color: stage == item.$1 ? Colors.black : Colors.black38,
                    fontWeight: stage == item.$1
                        ? FontWeight.w900
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
