import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/shared/services/textbook_reader_preferences.dart';
import 'package:s11/shared/theme/app_colors.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';
import 'package:s11/sessions/auth/ui/pages/profile_page.dart';

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
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E6DC)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
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
      borderRadius: BorderRadius.circular(20),
      child: tile,
    );
  }

  /// 필요한 변수는 교재 보기·알림·로딩 상태이다.
  /// 작동 원리는 HTML의 로컬 환경 히어로와 세 개 번호 카드에 기존 저장 콜백을 연결하는 것이다.
  Widget _buildHtmlSettings(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!isStudentDensityMobile(context)) return _buildDesktopSettings(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      drawer: null,
      bottomNavigationBar: const MobileStudentBottomAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: Colors.black,
                showLevelIndicator: false,
                onMenu: () => MobileStudentBottomAppBar.openMore(context),
                items: studentTopNavItems(
                  context,
                  active: StudentTopDestination.learning,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 24, 14, 40),
                children: [
                  const Text(
                    'PREFERENCES',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.7,
                      color: Colors.black54,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '설정',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '실제로 저장되는 학습 환경만 간결하게 조정합니다.',
                    style: TextStyle(color: Colors.black45),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    ),
                    child: const Text('프로필로 돌아가기'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202022),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Row(
                      children: [
                        _SettingsHeroIcon(),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LOCAL PREFERENCES',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '이 기기의 학습 환경',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '자동 저장',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsPanel(
                    number: '01',
                    title: '교재 보기',
                    subtitle: '본문을 연속 스크롤 또는 PDF형 페이지로 봅니다.',
                    child: _settingTile(
                      icon: Icons.auto_stories_outlined,
                      title: 'PDF형 페이지 보기',
                      subtitle: _textbookPageMode
                          ? '현재 페이지 단위로 열립니다.'
                          : '현재 연속 스크롤로 열립니다.',
                      trailing: Switch.adaptive(
                        value: _textbookPageMode,
                        onChanged: _setTextbookPageMode,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsPanel(
                    number: '02',
                    title: '모바일 문제풀이',
                    subtitle: '세로 모바일에서는 풀이 흐름을 순서대로 확인하는 간편풀이를 사용할 수 있습니다.',
                    child: _settingTile(
                      icon: Icons.route_outlined,
                      title: '모바일 간편풀이',
                      subtitle: _mobileQuickSolve
                          ? '모바일에서 필기 대신 풀이 흐름을 표시합니다.'
                          : '모바일에서도 일반 필기 풀이를 사용합니다.',
                      trailing: Switch.adaptive(
                        value: _mobileQuickSolve,
                        onChanged: _setMobileQuickSolve,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsPanel(
                    number: '03',
                    title: '알림',
                    subtitle: '멤버 모든 알림을 한 번에 켜거나 끕니다.',
                    child: _settingTile(
                      icon: Icons.notifications_none_rounded,
                      title: '모든 알림',
                      subtitle: _notificationsEnabled
                          ? '현재 모든 알림이 켜져 있습니다.'
                          : '현재 모든 알림이 꺼져 있습니다.',
                      trailing: Switch.adaptive(
                        value: _notificationsEnabled,
                        onChanged: _setNotificationsEnabled,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsPanel(
                    number: '04',
                    title: '앱 정보',
                    subtitle: 'AIFlow에 포함된 오픈소스 라이선스를 확인합니다.',
                    child: _settingTile(
                      icon: Icons.receipt_long_outlined,
                      title: '라이선스 보기',
                      subtitle: 'Flutter와 포함된 패키지 정보',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showLicenses,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPreferenceNotice(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 교재·알림 설정값과 라이선스 이동 콜백이다.
  /// 작동 원리는 HTML의 설정 본문과 보조 안내를 PC 2열로 분리하고, 모바일과 동일한 저장 콜백을 사용한다.
  Widget _buildDesktopSettings(BuildContext context) => Scaffold(
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
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                studentDensityHorizontalPadding(context),
                studentDensityVerticalPadding(context),
                studentDensityHorizontalPadding(context),
                48,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StudentDensityPageHeader(
                          eyebrow: 'PREFERENCES',
                          title: '설정',
                          description: '실제로 저장되는 학습 환경만 간결하게 조정합니다.',
                          action: OutlinedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProfilePage(),
                              ),
                            ),
                            child: const Text('프로필로 돌아가기'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSettingsHero(),
                                  const SizedBox(height: 16),
                                  _buildSettingsPanelList(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 330,
                              child: _buildPreferenceNotice(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  /// 필요한 변수는 교재 보기·알림 상태와 각 저장 콜백이다.
  /// 작동 원리는 세 설정을 같은 카드 순서로 재사용해 화면 폭과 관계없이 기능 계약을 유지한다.
  Widget _buildSettingsPanelList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SettingsPanel(
        number: '01',
        title: '교재 보기',
        subtitle: '본문을 연속 스크롤 또는 PDF형 페이지로 봅니다.',
        child: _settingTile(
          icon: Icons.auto_stories_outlined,
          title: 'PDF형 페이지 보기',
          subtitle: _textbookPageMode ? '현재 페이지 단위로 열립니다.' : '현재 연속 스크롤로 열립니다.',
          trailing: Switch.adaptive(
            value: _textbookPageMode,
            onChanged: _setTextbookPageMode,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _SettingsPanel(
        number: '02',
        title: '모바일 문제풀이',
        subtitle: '세로 모바일에서 풀이 흐름을 순서대로 확인합니다.',
        child: _settingTile(
          icon: Icons.route_outlined,
          title: '모바일 간편풀이',
          subtitle: _mobileQuickSolve ? '모바일 간편풀이를 사용합니다.' : '일반 필기 풀이를 사용합니다.',
          trailing: Switch.adaptive(
            value: _mobileQuickSolve,
            onChanged: _setMobileQuickSolve,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _SettingsPanel(
        number: '03',
        title: '알림',
        subtitle: '앱의 모든 알림을 한 번에 켜거나 끕니다.',
        child: _settingTile(
          icon: Icons.notifications_none_rounded,
          title: '모든 알림',
          subtitle: _notificationsEnabled
              ? '현재 모든 알림이 켜져 있습니다.'
              : '현재 모든 알림이 꺼져 있습니다.',
          trailing: Switch.adaptive(
            value: _notificationsEnabled,
            onChanged: _setNotificationsEnabled,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _SettingsPanel(
        number: '04',
        title: '앱 정보',
        subtitle: 'AIFlow에 포함된 오픈소스 라이선스를 확인합니다.',
        child: _settingTile(
          icon: Icons.receipt_long_outlined,
          title: '라이선스 보기',
          subtitle: 'Flutter와 포함된 패키지 정보',
          trailing: const Icon(Icons.chevron_right),
          onTap: _showLicenses,
        ),
      ),
    ],
  );

  /// 필요한 변수는 없으며 사용자에게 표시할 저장 안내다.
  /// 작동 원리는 개발용 키·엔드포인트를 노출하지 않고 변경 내용이 이 기기에 바로 적용된다는 결과만 안내한다.
  Widget _buildPreferenceNotice() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFF202022),
      borderRadius: BorderRadius.circular(28),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '학습 환경',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.6,
            color: Colors.white54,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 12),
        Text(
          '변경 내용은\n바로 적용돼요.',
          style: TextStyle(
            fontSize: 26,
            height: 1.02,
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 14),
        Text(
          '알림과 교재 보기 방식은 언제든 이 화면에서 다시 바꿀 수 있습니다.',
          style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.45),
        ),
      ],
    ),
  );

  /// 필요한 변수는 없으며 설정 상단의 시각적 문맥 카드다.
  /// 작동 원리는 모바일 히어로와 동일한 안내를 넓은 PC 본문에 맞춰 한 줄로 확장한다.
  Widget _buildSettingsHero() => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: const Color(0xFF202022),
      borderRadius: BorderRadius.circular(28),
    ),
    child: const Row(
      children: [
        _SettingsHeroIcon(),
        SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LOCAL PREFERENCES',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '이 기기의 학습 환경',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Text(
          '자동 저장',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

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

class _SettingsHeroIcon extends StatelessWidget {
  const _SettingsHeroIcon();

  /// 필요한 변수는 없으며 설정 히어로의 톱니바퀴 아이콘을 표시한다.
  /// 작동 원리는 밝은 정사각 표면으로 어두운 히어로와 대비를 만드는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
    ),
    child: const Icon(Icons.settings_outlined, size: 20),
  );
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String number;
  final String title;
  final String subtitle;
  final Widget child;

  /// 필요한 변수는 순서·제목·설명·설정 제어다.
  /// 작동 원리는 HTML의 큰 흰색 카드 안에 번호 배지와 실제 제어를 수직 배치하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFE0E0E2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF202022),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 46),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
        ),
        const SizedBox(height: 22),
        child,
      ],
    ),
  );
}
