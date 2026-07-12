import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/services/textbook_reader_preferences.dart';
import 'package:s11/shared/theme/app_colors.dart';
import 'package:s11/sessions/landing/ui/pages/landing_page.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';

class ProfilePage extends StatefulWidget {
  static const routeName = '/profile';

  const ProfilePage({super.key});

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
    _loadProfile();
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
        _profile = profile;
        _textbookPageMode = textbookPageMode;
        _originalUsername = profile.username;
        _usernameController.text = profile.username;
        _nameController.text = profile.name;
        _gradeController.text = profile.grade ?? '';
        _trackController.text = profile.track ?? '';
        _subjectController.text = profile.subject ?? '';
        _schoolController.text = profile.school ?? '';
        _emailController.text = profile.email ?? '';
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

  Future<void> _deleteAccount() async {
    if (_deletePasswordController.text.trim().isEmpty) {
      _showSnack('비밀번호를 입력해 주세요.');
      return;
    }

    final confirmed = await showDialog<bool>(
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

  @override
  Widget build(BuildContext context) {
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
