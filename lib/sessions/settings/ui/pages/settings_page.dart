import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/shared/services/textbook_reader_preferences.dart';
import 'package:s11/shared/theme/app_colors.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

class SettingsPage extends StatefulWidget {
  static const routeName = '/settings';

  const SettingsPage({
    super.key,
    this.preview = false,
    this.showLicensesOnStart = false,
  });

  final bool preview;
  final bool showLicensesOnStart;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _notificationsKey = 'settings.notifications_enabled';
  static const _mobileQuickSolveKey = 'settings.mobile_quick_solve';

  bool _loading = true;
  bool _notificationsEnabled = true;
  bool _textbookPageMode = false;
  bool _mobileQuickSolve = false;

  @override
  void initState() {
    super.initState();
    if (widget.preview) {
      _loading = false;
      if (widget.showLicensesOnStart) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showLicenses());
      }
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_notificationsKey);
    final textbookPageMode = await TextbookReaderPreferences.loadPageMode();
    final mobileQuickSolve = prefs.getBool(_mobileQuickSolveKey) ?? false;
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled ?? true;
      _textbookPageMode = textbookPageMode;
      _mobileQuickSolve = mobileQuickSolve;
      _loading = false;
    });
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }

  Future<void> _setTextbookPageMode(bool value) async {
    setState(() => _textbookPageMode = value);
    await TextbookReaderPreferences.savePageMode(value);
  }

  /// 필요한 변수는 모바일 간편풀이 선택값이다.
  /// 작동 원리는 기기 로컬 설정만 저장하고 다음 문제풀이 진입부터 즉시 적용하는 것이다.
  Future<void> _setMobileQuickSolve(bool value) async {
    setState(() => _mobileQuickSolve = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mobileQuickSolveKey, value);
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'AIFlow',
      applicationVersion: '1.0.0',
    );
  }

  Widget _pageShell({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE6E8DD)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
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
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final mobile = isStudentDensityMobile(context);
    final tile = Container(
      key: mobile ? ValueKey('settings-mobile-tile-$title') : null,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 14 : 16,
        vertical: mobile ? 15 : 14,
      ),
      decoration: BoxDecoration(
        color: mobile ? const Color(0xFFF4F4F6) : const Color(0xFFF7F7F4),
        borderRadius: BorderRadius.circular(mobile ? 18 : 20),
        border: mobile ? null : Border.all(color: const Color(0xFFE8E6DC)),
      ),
      child: Row(
        children: [
          Container(
            width: mobile ? 42 : 46,
            height: mobile ? 42 : 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: mobile ? 17 : 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: mobile ? 3 : 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: mobile ? 13 : 12,
                    height: 1.35,
                    color: Colors.black.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );

    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(mobile ? 18 : 20),
      child: tile,
    );
  }

  /// 필요한 변수는 교재 보기·알림·로딩 상태이다.
  /// 작동 원리는 기준 HTML의 직각형 단일 패널과 5개 행 순서를 그대로 사용하고,
  /// 각 행에는 기존 로컬 저장 콜백만 연결하는 것이다.
  Widget _buildHtmlSettings(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final panel = Container(
      key: const ValueKey('html-settings-panel'),
      constraints: const BoxConstraints(maxWidth: 760),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border.all(color: StudentDensityTokens.ink),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: EdgeInsets.symmetric(horizontal: mobile ? 16 : 22),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: StudentDensityTokens.ink),
              ),
            ),
            child: const Text(
              '이 기기',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          _HtmlSettingsRow(
            key: const ValueKey('html-settings-textbook'),
            icon: Icons.menu_book_outlined,
            title: '교재 페이지',
            subtitle: '교재를 페이지 단위로 넘겨 봅니다.',
            value: _textbookPageMode,
            onChanged: _setTextbookPageMode,
          ),
          _HtmlSettingsRow(
            key: const ValueKey('html-settings-quick-solve'),
            icon: Icons.edit_outlined,
            title: '모바일 간편풀이',
            subtitle: '세로 화면에서 풀이 단계를 간단히 표시합니다.',
            value: _mobileQuickSolve,
            onChanged: _setMobileQuickSolve,
          ),
          _HtmlSettingsRow(
            key: const ValueKey('html-settings-notifications'),
            icon: Icons.notifications_none_outlined,
            title: '전체 알림',
            subtitle: '학습 알림을 이 기기에서 받습니다.',
            value: _notificationsEnabled,
            onChanged: _setNotificationsEnabled,
          ),
          _HtmlSettingsActionRow(
            key: const ValueKey('html-settings-account-link'),
            icon: Icons.person_outline,
            title: '다른 계정 연동',
            subtitle: '학부모 또는 교사(과외)와 학습 정보를 연결합니다.',
            actionLabel: '연동',
            onTap: _showAccountLinkNotice,
          ),
          _HtmlSettingsActionRow(
            key: const ValueKey('html-settings-licenses'),
            icon: Icons.settings_outlined,
            title: '오픈소스 라이선스',
            subtitle: 'Flutter와 포함된 패키지 정보를 확인합니다.',
            actionLabel: '보기',
            onTap: _showLicenses,
            last: true,
          ),
        ],
      ),
    );

    return StudentHtmlShell(
      title: '설정',
      activeRoute: '/student/dashboard',
      onSearch: () => showStudentQuickSearch(context),
      onNotifications: () => showStudentNotifications(context),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                mobile ? 14 : 24,
                mobile ? 16 : 52,
                mobile ? 14 : 24,
                40,
              ),
              child: Center(child: panel),
            ),
    );
  }

  void _showAccountLinkNotice() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Text(
          '다른 계정 연동은 준비 중입니다. 현재 계정과 학습 데이터는 변경되지 않습니다.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const bool.fromEnvironment('USE_LEGACY_SETTINGS')
      ? _buildLegacySettings(context)
      : _buildHtmlSettings(context);

  /// 필요한 변수는 기존 설정 상태이다.
  /// 작동 원리는 회귀 비교 시 기존 단일 스크롤 설정 화면을 구성하는 것이다.
  Widget _buildLegacySettings(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F6F1),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F1),
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.88),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '앱 설정',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '필요한 설정만 남겨서 빠르게 조정할 수 있습니다.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _pageShell(
            title: '교재 보기',
            subtitle: '교재 본문을 연속 스크롤 또는 PDF형 페이지로 볼 수 있습니다.',
            children: [
              _settingTile(
                icon: Icons.auto_stories_rounded,
                title: 'PDF형 페이지 보기',
                subtitle: _textbookPageMode
                    ? '교재가 페이지 단위로 열립니다.'
                    : '교재가 아래로 스크롤되는 형태로 열립니다.',
                trailing: Switch.adaptive(
                  value: _textbookPageMode,
                  onChanged: _setTextbookPageMode,
                  activeThumbColor: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _pageShell(
            title: '알림 설정',
            subtitle: '모든 알림을 한 번에 켜거나 끌 수 있습니다.',
            children: [
              _settingTile(
                icon: Icons.notifications_active_rounded,
                title: '모든 알림',
                subtitle: _notificationsEnabled
                    ? '현재 모든 알림이 켜져 있습니다.'
                    : '현재 모든 알림이 꺼져 있습니다.',
                trailing: Switch.adaptive(
                  value: _notificationsEnabled,
                  onChanged: _setNotificationsEnabled,
                  activeThumbColor: AppColors.primaryLight,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '알림 범위는 추후 세부 항목으로 확장할 수 있습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _pageShell(
            title: '오픈소스 라이선스',
            subtitle: '앱에 포함된 오픈소스 라이브러리 정보를 확인합니다.',
            children: [
              _settingTile(
                icon: Icons.receipt_long_rounded,
                title: '라이선스 보기',
                subtitle: 'Flutter와 포함된 패키지의 라이선스를 표시합니다.',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                ),
                onTap: _showLicenses,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HtmlSettingsRow extends StatelessWidget {
  const _HtmlSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Container(
      constraints: BoxConstraints(minHeight: mobile ? 76 : 82),
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 22, 12, mobile ? 12 : 22, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: StudentDensityTokens.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: mobile ? 28 : 30,
            child: Icon(
              icon,
              size: mobile ? 20 : 19,
              color: StudentDensityTokens.ink,
            ),
          ),
          SizedBox(width: mobile ? 12 : 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: mobile ? 14 : 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudentDensityTokens.muted,
                    fontSize: mobile ? 10 : 10,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value ? '켜짐' : '꺼짐',
            style: const TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          _HtmlToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _HtmlSettingsActionRow extends StatelessWidget {
  const _HtmlSettingsActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Semantics(
      button: true,
      label: '$title $actionLabel',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: mobile ? 76 : 82),
          padding: EdgeInsets.fromLTRB(
            mobile ? 16 : 22,
            12,
            mobile ? 16 : 22,
            12,
          ),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(
                    bottom: BorderSide(color: StudentDensityTokens.line),
                  ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: mobile ? 28 : 30,
                child: Icon(
                  icon,
                  size: mobile ? 20 : 19,
                  color: StudentDensityTokens.ink,
                ),
              ),
              SizedBox(width: mobile ? 12 : 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: mobile ? 14 : 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StudentDensityTokens.muted,
                        fontSize: 10,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                actionLabel,
                style: const TextStyle(
                  color: StudentDensityTokens.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _HtmlToggle extends StatelessWidget {
  const _HtmlToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: value ? '켜짐' : '꺼짐',
    child: GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: value ? StudentDensityTokens.dark : Colors.transparent,
          border: Border.all(color: StudentDensityTokens.ink),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 18,
          height: 18,
          color: value ? Colors.white : StudentDensityTokens.dark,
        ),
      ),
    ),
  );
}
