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
            onTap: _showAccountLinkSheet,
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

  /// HTML의 계정 연동 시트를 열어 역할·방법·입력 장면을 순서대로 표시한다.
  /// 실제 연동 API가 없는 환경에서는 전송하지 않고 준비 상태를 명시한다.
  void _showAccountLinkSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: StudentDensityTokens.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => const _AccountLinkSheet(),
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

enum _AccountLinkStep { role, method, id, scan, show }

/// HTML 계정 연동 모달의 내부 장면을 보존하는 로컬 전용 시트다.
/// 실제 요청 API가 연결되기 전까지 입력은 전송하지 않고 안내 상태만 보여 준다.
class _AccountLinkSheet extends StatefulWidget {
  const _AccountLinkSheet();

  @override
  State<_AccountLinkSheet> createState() => _AccountLinkSheetState();
}

class _AccountLinkSheetState extends State<_AccountLinkSheet> {
  _AccountLinkStep _step = _AccountLinkStep.role;
  String _role = '학부모';
  String _message = '';
  final TextEditingController _idController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  /// 선택한 역할에 맞춰 다음 연동 방법 장면을 연다.
  void _selectRole(String role) {
    setState(() {
      _role = role;
      _step = _AccountLinkStep.method;
      _message = '';
    });
  }

  /// API 미연결 상태를 숨기지 않고 연동 시트 안에 표시한다.
  void _showUnavailable() {
    setState(() => _message = '연동 API가 준비되기 전까지 실제 요청을 보내지 않습니다.');
  }

  void _backToRole() => setState(() {
    _step = _AccountLinkStep.role;
    _message = '';
  });

  void _backToMethod() => setState(() {
    _step = _AccountLinkStep.method;
    _message = '';
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _AccountLinkStep.role => '다른 계정 연동',
      _ => '$_role 계정 연동',
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 720),
      child: Material(
        color: StudentDensityTokens.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACCOUNT LINK',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                            color: StudentDensityTokens.muted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('settings-account-link-close'),
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(child: SingleChildScrollView(child: _buildStep())),
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  _message,
                  key: const ValueKey('settings-account-link-message'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: StudentDensityTokens.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      _AccountLinkStep.role => _buildRoleStep(),
      _AccountLinkStep.method => _buildMethodStep(),
      _AccountLinkStep.id => _buildIdStep(),
      _AccountLinkStep.scan => _buildScanStep(),
      _AccountLinkStep.show => _buildShowStep(),
    };
  }

  Widget _buildRoleStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '연동할 계정 유형을 선택하세요. 상대방은 요청을 확인한 뒤에만 학습 정보를 볼 수 있어요.',
        style: TextStyle(
          fontSize: 12,
          height: 1.6,
          color: StudentDensityTokens.muted,
        ),
      ),
      const SizedBox(height: 16),
      _AccountLinkChoice(
        key: const ValueKey('settings-account-role-parent'),
        icon: Icons.person_outline,
        title: '학부모',
        detail: '학습 현황 확인',
        onTap: () => _selectRole('학부모'),
      ),
      _AccountLinkChoice(
        key: const ValueKey('settings-account-role-teacher'),
        icon: Icons.edit_outlined,
        title: '교사 · 과외',
        detail: '과제와 풀이 확인',
        onTap: () => _selectRole('교사 · 과외'),
      ),
    ],
  );

  Widget _buildMethodStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton.icon(
        onPressed: _backToRole,
        icon: const Icon(Icons.arrow_back, size: 17),
        label: const Text('계정 유형 다시 선택'),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.zero,
          foregroundColor: StudentDensityTokens.muted,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '$_role 계정과 연결할 방법을 고르세요.',
        style: const TextStyle(fontSize: 12, color: StudentDensityTokens.muted),
      ),
      const SizedBox(height: 14),
      _AccountLinkChoice(
        key: const ValueKey('settings-account-method-id'),
        icon: Icons.person_outline,
        title: 'ID 입력',
        detail: '상대방 AIFlow ID를 직접 입력',
        onTap: () => setState(() => _step = _AccountLinkStep.id),
      ),
      _AccountLinkChoice(
        key: const ValueKey('settings-account-method-scan'),
        icon: Icons.qr_code_scanner,
        title: 'QR 코드 스캔',
        detail: '상대방 화면의 QR 코드를 카메라로 읽기',
        onTap: () => setState(() => _step = _AccountLinkStep.scan),
      ),
      _AccountLinkChoice(
        key: const ValueKey('settings-account-method-show'),
        icon: Icons.qr_code_2,
        title: '내 QR 코드 띄우기',
        detail: '상대방이 이 화면을 스캔',
        onTap: () => setState(() => _step = _AccountLinkStep.show),
      ),
    ],
  );

  Widget _buildIdStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton.icon(
        onPressed: _backToMethod,
        icon: const Icon(Icons.arrow_back, size: 17),
        label: const Text('연동 방법'),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.zero,
          foregroundColor: StudentDensityTokens.muted,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _idController,
        maxLength: 24,
        decoration: InputDecoration(
          labelText: '$_role AIFlow ID',
          hintText: '예: parent_park',
          border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '연동 요청이 전송되며, 상대방의 승인 후 연결됩니다.',
        style: TextStyle(fontSize: 11, color: StudentDensityTokens.muted),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _showUnavailable,
        style: _actionStyle(),
        child: const Text('연동 요청 보내기'),
      ),
    ],
  );

  Widget _buildScanStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton.icon(
        onPressed: _backToMethod,
        icon: const Icon(Icons.arrow_back, size: 17),
        label: const Text('연동 방법'),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.zero,
          foregroundColor: StudentDensityTokens.muted,
        ),
      ),
      const SizedBox(height: 12),
      Container(
        height: 190,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border.fromBorderSide(
            BorderSide(color: StudentDensityTokens.ink),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 44),
            SizedBox(height: 12),
            Text(
              'QR 코드를 화면 중앙에 맞추세요',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 5),
            Text(
              '카메라 권한을 허용하면 자동으로 읽습니다.',
              style: TextStyle(fontSize: 11, color: StudentDensityTokens.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: _showUnavailable,
        style: _actionStyle(),
        child: const Text('QR 코드 확인하기'),
      ),
    ],
  );

  Widget _buildShowStep() => Column(
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _backToMethod,
          icon: const Icon(Icons.arrow_back, size: 17),
          label: const Text('연동 방법'),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: StudentDensityTokens.muted,
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: 190,
        height: 190,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: 49,
          itemBuilder: (context, index) => ColoredBox(
            color: _qrDark(index)
                ? StudentDensityTokens.dark
                : StudentDensityTokens.surface,
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'STUDENT-8F2K',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.8,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '이 코드는 5분 동안만 유효합니다. 상대방이 스캔하면 연동 요청이 도착합니다.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          height: 1.5,
          color: StudentDensityTokens.muted,
        ),
      ),
    ],
  );

  bool _qrDark(int index) => const {
    0,
    1,
    2,
    4,
    6,
    7,
    8,
    10,
    12,
    14,
    15,
    16,
    18,
    20,
    21,
    22,
    24,
    26,
    28,
    29,
    31,
    32,
    34,
    35,
    36,
    38,
    40,
    42,
    43,
    45,
    47,
    48,
  }.contains(index);

  ButtonStyle _actionStyle() => FilledButton.styleFrom(
    backgroundColor: StudentDensityTokens.dark,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(52),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  );
}

class _AccountLinkChoice extends StatelessWidget {
  const _AccountLinkChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: StudentDensityTokens.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 10,
                    color: StudentDensityTokens.muted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, size: 18),
        ],
      ),
    ),
  );
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
