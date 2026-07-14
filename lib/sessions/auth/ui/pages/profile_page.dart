import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/services/textbook_reader_preferences.dart';
import 'package:s11/shared/theme/app_colors.dart';
import 'package:s11/sessions/landing/ui/pages/landing_page.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

class ProfilePage extends StatefulWidget {
  static const routeName = '/profile';

  const ProfilePage({
    super.key,
    this.initialProfile,
    this.initialTextbookPageMode,
    this.showDeleteDialogOnStart = false,
  });

  final UserProfile? initialProfile;
  final bool? initialTextbookPageMode;
  final bool showDeleteDialogOnStart;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _trackController = TextEditingController();
  final _subjectController = TextEditingController();
  final _schoolController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _deletePasswordController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  bool _textbookPageMode = false;
  String? _errorText;
  UserProfile? _profile;
  String? _originalUsername;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProfile;
    if (initial == null) {
      _loadProfile();
      return;
    }
    _applyProfile(initial);
    _textbookPageMode = widget.initialTextbookPageMode ?? _textbookPageMode;
    _loading = false;
    if (widget.showDeleteDialogOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDeleteModal());
    }
  }

  /// 필요한 변수는 사용자 프로필 응답이다.
  /// 작동 원리는 서버·미리보기 데이터를 동일한 폼 컨트롤러에 복사하는 것이다.
  void _applyProfile(UserProfile profile) {
    _profile = profile;
    _originalUsername = profile.username;
    _usernameController.text = profile.username;
    _nameController.text = profile.name;
    _gradeController.text = profile.grade ?? '';
    _trackController.text = profile.track ?? '';
    _subjectController.text = profile.subject ?? '';
    _schoolController.text = profile.school ?? '';
    _emailController.text = profile.email ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _gradeController.dispose();
    _trackController.dispose();
    _subjectController.dispose();
    _schoolController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _deletePasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final results = await Future.wait<Object>([
        ApiClient.instance.getMyProfile(),
        TextbookReaderPreferences.loadPageMode(),
      ]);
      final profile = results[0] as UserProfile;
      final textbookPageMode = results[1] as bool;
      if (!mounted) return;
      setState(() {
        _textbookPageMode = textbookPageMode;
        _applyProfile(profile);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _passwordConfirmController.text.trim();
    if (newPassword.isNotEmpty && newPassword != confirmPassword) {
      _showSnack('새 비밀번호가 서로 일치하지 않습니다.');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final updated = await ApiClient.instance.updateMyProfile(
        username: _usernameController.text.trim(),
        name: _nameController.text.trim(),
        grade: _gradeController.text.trim(),
        track: _trackController.text.trim(),
        subject: _subjectController.text.trim(),
        school: _schoolController.text.trim(),
        email: _emailController.text.trim(),
        password: newPassword.isEmpty ? null : newPassword,
      );
      final originalUsername = _originalUsername;
      if (originalUsername != null && updated.username != originalUsername) {
        await AuthStorage.instance.saveUsername(updated.username);
      }
      if (!mounted) return;
      _showSnack('프로필을 저장했습니다.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteAccount({bool skipConfirmation = false}) async {
    if (_deletePasswordController.text.trim().isEmpty) {
      _showSnack('비밀번호를 입력해 주세요.');
      return;
    }

    final confirmed = skipConfirmation
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('회원탈퇴'),
              content: const Text('정말로 계정을 삭제할까요? 삭제 후에는 되돌릴 수 없습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('삭제'),
                ),
              ],
            ),
          );
    if (confirmed != true) return;

    setState(() {
      _deleting = true;
      _errorText = null;
    });
    try {
      await ApiClient.instance.deleteMyProfile(
        password: _deletePasswordController.text.trim(),
      );
      await ApiClient.instance.clearToken();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingPage()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  /// 필요한 변수는 현재 비밀번호 컨트롤러와 계정 삭제 상태다.
  /// 작동 원리는 HTML DANGER ZONE 버튼에서 설명·비밀번호·취소·삭제를 갖춘 전용 모달을 여는 것이다.
  Future<void> _openDeleteModal() async {
    _deletePasswordController.clear();
    final delete = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .48),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'DANGER ZONE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '계정 삭제',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                '계정 삭제는 되돌릴 수 없으며 현재 비밀번호 확인이 필요합니다.',
                style: TextStyle(color: Colors.black54, height: 1.45),
              ),
              const SizedBox(height: 20),
              _field(
                controller: _deletePasswordController,
                label: '현재 비밀번호',
                obscureText: true,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: const Text('계정 삭제'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (delete == true && mounted) await _deleteAccount(skipConfirmation: true);
  }

  /// 필요한 변수는 저장된 인증 토큰과 현재 Navigator다.
  /// 작동 원리는 이 기기의 인증 캐시를 정리하고 인증 랜딩으로 모든 화면을 교체하는 것이다.
  Future<void> _logout() async {
    await ApiClient.instance.clearToken();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingPage()),
      (route) => false,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  Future<void> _setTextbookPageMode(bool value) async {
    setState(() => _textbookPageMode = value);
    await TextbookReaderPreferences.savePageMode(value);
  }

  String _avatarLetter() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) return String.fromCharCode(name.runes.first);
    final username = _usernameController.text.trim();
    if (username.isNotEmpty) return String.fromCharCode(username.runes.first);
    return '?';
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF7F7F4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE3E5DF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE3E5DF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  /// 필요한 변수는 로드된 프로필·폼·저장 상태이다.
  /// 작동 원리는 HTML의 계정 히어로와 학습 정보 폼을 한 스크롤에 배치하고 기존 저장 로직을 연결하는 것이다.
  Widget _buildHtmlProfile(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profile == null) return _buildLegacyProfile(context);
    final name = _nameController.text.trim().isEmpty
        ? _usernameController.text.trim()
        : _nameController.text.trim();
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
                items: studentTopNavItems(
                  context,
                  active: StudentTopDestination.learning,
                ),
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 24, 14, 40),
                  children: [
                    const Text(
                      'MY ACCOUNT',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.7,
                        color: Colors.black54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '프로필',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '학습 정보와 계정 정보를 확인하고 필요한 항목만 수정합니다.',
                      style: TextStyle(color: Colors.black45),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _openSettings,
                      child: const Text('설정'),
                    ),
                    const SizedBox(height: 12),
                    _ProfileHero(
                      name: name,
                      username: _usernameController.text,
                      grade: _gradeController.text,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: _profileCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LEARNING PROFILE',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.6,
                              color: Colors.black54,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '학생 정보',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '코스 추천과 학습 분석에 사용하는 정보입니다.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F3F5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE1E1E4),
                                ),
                              ),
                              child: const Text(
                                'GET /auth/me',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _field(
                            controller: _nameController,
                            label: '이름',
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? '이름을 입력해 주세요.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _field(
                            controller: _usernameController,
                            label: '아이디',
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'ID를 입력해 주세요.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _field(controller: _trackController, label: '과정'),
                          const SizedBox(height: 14),
                          _field(controller: _gradeController, label: '학년'),
                          const SizedBox(height: 14),
                          _field(controller: _subjectController, label: '과목'),
                          const SizedBox(height: 14),
                          _field(controller: _schoolController, label: '학교'),
                          const SizedBox(height: 14),
                          _field(
                            controller: _emailController,
                            label: '이메일',
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _htmlAccountCard(
                      eyebrow: 'SECURITY',
                      title: '비밀번호 변경',
                      description: '변경하지 않으려면 두 입력란을 비워두세요.',
                      children: [
                        _field(
                          controller: _passwordController,
                          label: '새 비밀번호',
                          hintText: '8–20자 영문+숫자',
                          obscureText: true,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _passwordConfirmController,
                          label: '새 비밀번호 확인',
                          hintText: '한 번 더 입력',
                          obscureText: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF202022),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('변경사항 저장'),
                    ),
                    const SizedBox(height: 12),
                    _htmlAccountCard(
                      eyebrow: 'READER',
                      title: '교재 보기',
                      description: '교재를 PDF형 페이지 단위로 표시합니다.',
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _textbookPageMode,
                          onChanged: _setTextbookPageMode,
                          title: Text(
                            _textbookPageMode ? '페이지 보기 켜짐' : '페이지 보기 꺼짐',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _htmlAccountCard(
                      eyebrow: 'SESSION',
                      title: '로그인 상태',
                      description: '이 기기의 JWT와 사용자명을 삭제하고 로그아웃합니다.',
                      children: [
                        OutlinedButton(
                          onPressed: _logout,
                          child: const Text('로그아웃'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7F6),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFF0B8B2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'DANGER ZONE',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.6,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '계정 삭제',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '현재 비밀번호 확인 후 계정과 로그인 정보를 삭제합니다. 되돌릴 수 없습니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _deleting ? null : _openDeleteModal,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            child: const Text('계정 삭제'),
                          ),
                        ],
                      ),
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

  /// 필요한 변수는 없으며 프로필 카드의 공용 표면을 만든다.
  /// 작동 원리는 흰 배경과 28px 둥근 모서리로 HTML 정보 카드를 재현하는 것이다.
  BoxDecoration _profileCardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: const Color(0xFFE0E0E2)),
  );

  /// 필요한 변수는 섹션 표식·제목·설명·내부 컨트롤이다.
  /// 작동 원리는 프로필 하단의 SECURITY·READER·SESSION 카드를 HTML과 같은 간격으로 재사용하는 것이다.
  Widget _htmlAccountCard({
    required String eyebrow,
    required String title,
    required String description,
    required List<Widget> children,
  }) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: Color(0xFFE0E0E2)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.6,
              color: Colors.black54,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => _buildHtmlProfile(context);

  /// 필요한 변수는 기존 프로필 상태이다.
  /// 작동 원리는 데이터 로드 오류일 때 기존 재시도 화면을 제공하는 것이다.
  Widget _buildLegacyProfile(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F6F1),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F6F1),
        appBar: AppBar(
          title: const Text('프로필'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_rounded),
              tooltip: '설정',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errorText ?? '프로필을 불러오지 못했습니다.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadProfile,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F1),
      appBar: AppBar(
        title: const Text('프로필'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_rounded),
            tooltip: '설정',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFE9E7DD)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _avatarLetter(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.trim().isEmpty
                                ? _usernameController.text.trim()
                                : _nameController.text.trim(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${_usernameController.text.trim()}',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_errorText != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF0B5B0)),
                  ),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _section(
                title: '기본 정보',
                subtitle: '회원가입 때 입력했던 내용을 수정할 수 있습니다.',
                children: [
                  _field(
                    controller: _usernameController,
                    label: 'ID',
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'ID를 입력해 주세요.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _nameController,
                    label: '이름',
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? '이름을 입력해 주세요.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _gradeController,
                    label: '학년',
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? '학년을 입력해 주세요.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _emailController,
                    label: '이메일',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _field(controller: _schoolController, label: '학교'),
                  const SizedBox(height: 14),
                  _field(controller: _trackController, label: '계열'),
                  const SizedBox(height: 14),
                  _field(controller: _subjectController, label: '과목'),
                ],
              ),
              const SizedBox(height: 16),
              _section(
                title: '교재 보기 설정',
                subtitle: '교재 본문을 읽는 기본 방식을 선택합니다.',
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F4),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE3E5DF)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PDF형 페이지 보기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _textbookPageMode
                                    ? '교재가 페이지 단위로 열립니다.'
                                    : '교재가 아래로 스크롤되는 형태로 열립니다.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black.withValues(alpha: 0.58),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _textbookPageMode,
                          onChanged: _setTextbookPageMode,
                          activeThumbColor: AppColors.primaryLight,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _section(
                title: '비밀번호 변경',
                subtitle: '새 비밀번호를 입력할 때만 변경됩니다.',
                children: [
                  _field(
                    controller: _passwordController,
                    label: '새 비밀번호',
                    obscureText: true,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _passwordConfirmController,
                    label: '새 비밀번호 확인',
                    obscureText: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFFFD4D0)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '회원탈퇴',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '비밀번호를 입력한 뒤 계정을 완전히 삭제할 수 있습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _field(
                      controller: _deletePasswordController,
                      label: '현재 비밀번호',
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _deleting ? null : _deleteAccount,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _deleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('회원탈퇴'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('저장하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.username,
    required this.grade,
  });
  final String name;
  final String username;
  final String grade;

  /// 필요한 변수는 이름·아이디·학년이다.
  /// 작동 원리는 초성, 학습 메타, OVR·티어·누적 풀이를 어두운 HTML 계정 카드에 집약하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
    decoration: BoxDecoration(
      color: const Color(0xFF202022),
      borderRadius: BorderRadius.circular(38),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'STUDENT PROFILE',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                name.isEmpty ? '?' : name.characters.first,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '@$username · AIFlow 중학교 $grade',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '학교 과정   수학   개인 학습 생활',
                    style: TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              _ProfileMetric(label: '현재 OVR', value: '18.6'),
              _ProfileMetric(label: '티어', value: 'B'),
              _ProfileMetric(label: '누적 풀이', value: '128'),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.label, required this.value});
  final String label;
  final String value;

  /// 필요한 변수는 통계 레이블과 값이다.
  /// 작동 원리는 세 통계를 동일 너비로 나눠 계정 상태를 빠르게 비교하게 하는 것이다.
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}
