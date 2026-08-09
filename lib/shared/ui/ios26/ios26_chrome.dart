import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/business/repositories/social_notification_store.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/ui/modal/level_detail_modal.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

class Ios26NavItem {
  const Ios26NavItem({required this.label, this.onTap, this.active = false});

  final String label;
  final VoidCallback? onTap;
  final bool active;
}

class Ios26ActionIcon {
  const Ios26ActionIcon({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
}

class Ios26TopBar extends StatelessWidget {
  const Ios26TopBar({
    super.key,
    required this.brandColor,
    this.title = 'AIFlow',
    this.onBack,
    this.onMenu,
    this.onTitleTap,
    this.items = const <Ios26NavItem>[],
    this.actionIcons = const <Ios26ActionIcon>[],
    this.trailingIcons = const <Ios26ActionIcon>[],
    this.trailing,
    this.showLevelIndicator = true,
    this.showUtilityActions = true,
    this.profileLabel,
    this.onSearch,
    this.onNotifications,
    this.onProfile,
    this.leftInset,
    this.showMenuWithBack = false,
    this.hideOnMobile = false,
  });

  final Color brandColor;
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final VoidCallback? onTitleTap;
  final List<Ios26NavItem> items;
  final List<Ios26ActionIcon> actionIcons;
  final List<Ios26ActionIcon> trailingIcons;
  final Widget? trailing;
  final bool showLevelIndicator;
  final bool showUtilityActions;
  final String? profileLabel;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final double? leftInset;
  final bool showMenuWithBack;
  final bool hideOnMobile;

  /// 필요한 변수는 상단 바 자신이 가진 Scaffold 문맥과 선택적 기존 메뉴 콜백이다.
  /// 작동 원리: 상단 바 아래의 Drawer를 먼저 직접 열어, 부모 화면의 오래된 문맥이 전달돼도 전체 메뉴가 열리게 한다.
  void _handleMenuTap(BuildContext context) {
    final scaffoldState = Scaffold.maybeOf(context);
    if (scaffoldState?.hasDrawer ?? false) {
      if (scaffoldState!.isDrawerOpen) {
        Navigator.of(context).pop();
      } else {
        scaffoldState.openDrawer();
      }
      return;
    }
    onMenu?.call();
  }

  /// 필요 변수: 현재 화면 폭과 전달받은 메뉴·행동 목록.
  /// 작동 원리: HTML처럼 PC는 브랜드·중앙 캡슐 메뉴·우측 행동을, 모바일은 햄버거와 행동만 분리 정렬합니다.
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width <= StudentDensityTokens.mobileBreakpoint;
    // 필요한 변수는 모바일 숨김 설정과 현재 화면 폭이다.
    // 작동 원리: 하단 앱바와 화면 내부 제목이 탐색을 맡는 최상위 모바일 화면에서는
    // 브랜드 바를 만들지 않고, PC와 뒤로가기가 필요한 상세 화면은 기존 상단 바를 유지한다.
    if (compact && hideOnMobile) return const SizedBox.shrink();
    final barHeight = compact ? 62.0 : 68.0;
    final effectiveLeftInset = leftInset ?? (compact ? 12.0 : 40.0);
    final showBackButton = onBack != null;
    final showMenuButton =
        onMenu != null && (!showBackButton || showMenuWithBack);
    final hasLeadingControl = showBackButton || showMenuButton;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: barHeight,
          padding: EdgeInsets.only(
            left: effectiveLeftInset,
            right: compact ? 12 : 40,
          ),
          decoration: BoxDecoration(
            color: StudentDensityTokens.background.withValues(alpha: 0.72),
            border: Border(
              bottom: BorderSide(color: StudentDensityTokens.line),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showBackButton)
                      _TopCircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: '뒤로가기',
                        onTap: onBack,
                      ),
                    if (showBackButton && showMenuButton)
                      SizedBox(width: compact ? 7 : 8),
                    if (showMenuButton)
                      _TopCircleButton(
                        key: const ValueKey('student-mobile-menu'),
                        icon: Icons.menu_rounded,
                        tooltip: '전체 메뉴',
                        onTap: () => _handleMenuTap(context),
                      ),
                    if (hasLeadingControl) SizedBox(width: compact ? 7 : 10),
                    GestureDetector(
                      onTap: onTitleTap,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: compact ? 31 : 34,
                            height: compact ? 31 : 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: StudentDensityTokens.dark,
                              borderRadius: BorderRadius.circular(
                                compact ? 10 : 12,
                              ),
                            ),
                            child: const Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Text(
                            title,
                            style: TextStyle(
                              color: StudentDensityTokens.ink,
                              fontSize: compact ? 20 : 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: compact ? -0.8 : -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty && !compact)
                Container(
                  // 앱바와 캡슐 사이의 상하 여백이 드러나도록 시안보다 세로 패딩만 얇게 유지한다.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: StudentDensityTokens.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final item in items) _NavChip(item: item)],
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showUtilityActions) ...[
                      _TopCircleButton(
                        icon: Icons.search_rounded,
                        tooltip: '검색',
                        onTap:
                            onSearch ?? () => showStudentQuickSearch(context),
                      ),
                      const SizedBox(width: 8),
                      _TopCircleButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: '알림',
                        showBadge: true,
                        onTap:
                            onNotifications ??
                            () => showStudentNotifications(context),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 8),
                        _StoredProfile(
                          label: profileLabel,
                          onTap:
                              onProfile ??
                              () => Navigator.of(context).pushNamed('/profile'),
                        ),
                      ],
                    ],
                    if (trailing != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: trailing!,
                      ),
                    if (showLevelIndicator)
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: _Ios26LevelIndicator(
                          brandColor: brandColor,
                          compact: compact,
                        ),
                      ),
                    for (final item
                        in (trailingIcons.isNotEmpty
                            ? trailingIcons
                            : actionIcons))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _ActionIcon(item: item, brandColor: brandColor),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoredProfile extends StatefulWidget {
  const _StoredProfile({required this.label, required this.onTap});

  final String? label;
  final VoidCallback onTap;

  /// 필요 변수는 호출 화면이 전달한 이름과 로컬에 저장된 로그인 아이디다.
  /// 작동 원리는 이름을 우선 표시하고, 없으면 DB 요청 없이 저장된 아이디를 한 번만 읽는 것이다.
  @override
  State<_StoredProfile> createState() => _StoredProfileState();
}

class _StoredProfileState extends State<_StoredProfile> {
  String? _storedUsername;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStoredUsername());
  }

  /// 필요 변수는 AuthStorage에 보관된 현재 계정 아이디다.
  /// 작동 원리는 공백을 제거한 유효한 아이디만 상태에 반영해 앱바를 한 번 갱신하는 것이다.
  Future<void> _loadStoredUsername() async {
    final username = (await AuthStorage.instance.readUsername())?.trim();
    if (!mounted || username == null || username.isEmpty) return;
    setState(() => _storedUsername = username);
  }

  @override
  Widget build(BuildContext context) {
    final suppliedLabel = widget.label?.trim();
    final label = suppliedLabel?.isNotEmpty == true
        ? suppliedLabel!
        : (_storedUsername ?? '사용자');
    return _CompactProfile(label: label, onTap: widget.onTap);
  }
}

/// 필요한 변수는 현재 Navigator 문맥이다.
/// 작동 원리는 HTML QUICK FIND와 같은 검색 시트를 열고 코스·교재·친구·마켓 명명 라우트로 연결하는 것이다.
void showStudentQuickSearch(BuildContext context) {
  _showStudentUtilityPanel(
    context: context,
    child: const _StudentQuickSearchSheet(),
  );
}

/// 필요한 변수는 현재 Navigator 문맥이다.
/// 작동 원리는 시스템 공지와 친구 요청을 한 번에 조회하는 HTML 알림 센터 시트를 여는 것이다.
void showStudentNotifications(BuildContext context) {
  _showStudentUtilityPanel(
    context: context,
    child: const _StudentNotificationsSheet(),
  );
}

/// 필요한 변수는 현재 Navigator 문맥과 검색·알림 패널 본문이다.
/// 작동 원리: 검색과 알림은 PC에서 오른쪽 560px 패널로 열고,
/// 모바일에서는 상단 앱바처럼 보이지 않는 둥근 바텀시트로 연다.
Future<void> _showStudentUtilityPanel({
  required BuildContext context,
  required Widget child,
}) async {
  if (isStudentDensityMobile(context)) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF4F4F6),
      barrierColor: Colors.black.withValues(alpha: .30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: .88,
        child: Material(
          color: const Color(0xFFF4F4F6),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
    return;
  }
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: Colors.black.withValues(alpha: .28),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final width = MediaQuery.sizeOf(context).width;
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: width <= StudentDensityTokens.mobileBreakpoint ? width : 560,
          height: double.infinity,
          child: Material(color: const Color(0xFFFAFAFB), child: child),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      );
    },
  );
}

class _StudentQuickSearchSheet extends StatefulWidget {
  const _StudentQuickSearchSheet();

  /// 필요한 변수는 검색 시트 위젯이다.
  /// 작동 원리는 입력값에 따라 네 개 핵심 학생 목적지를 즉시 필터링하는 상태를 만든다.
  @override
  State<_StudentQuickSearchSheet> createState() =>
      _StudentQuickSearchSheetState();
}

class _StudentQuickSearchSheetState extends State<_StudentQuickSearchSheet> {
  static const _destinations =
      <({String title, String detail, String keywords, String route})>[
        (
          title: '코스',
          detail: '수강 중·추천·완료 코스 찾기',
          keywords: '수학 함수 개념 학습 강의',
          route: '/courses',
        ),
        (
          title: '책가방',
          detail: '교재·시험지·북마크 찾기',
          keywords: '책 문서 문제세트 보관함',
          route: '/bookbag',
        ),
        (
          title: '오답 노트',
          detail: '틀린 문제와 오늘 복습 확인',
          keywords: '오답 문제 복습 수학',
          route: '/wrong_answers',
        ),
        (
          title: '레벨 테스트',
          detail: '현재 실력과 추천 난이도 확인',
          keywords: '진단 평가 OVR 배치',
          route: '/level_test',
        ),
        (
          title: '친구/소셜',
          detail: '친구 요청과 새 대화 확인',
          keywords: '친구 쪽지 대화 소셜',
          route: '/social',
        ),
        (
          title: '스터디 그룹',
          detail: '내 그룹과 초대 코드 참가',
          keywords: '그룹 학원 같이 공부',
          route: '/groups',
        ),
        (
          title: 'AI 학습 튜터',
          detail: '개념과 막힌 문제 질문',
          keywords: 'AI 도구 질문 풀이 수학 함수',
          route: '/tools',
        ),
        (
          title: '마켓플레이스',
          detail: '문제·교재·태그 찾기',
          keywords: '문제세트 시험지 수학 자료',
          route: '/marketplace',
        ),
      ];
  String _query = '';

  /// 필요한 변수는 선택 목적지와 현재 시트 Navigator다.
  /// 작동 원리는 시트를 먼저 닫고 루트 Navigator에서 공용 명명 라우트를 연다.
  void _open(
    ({String title, String detail, String keywords, String route}) destination,
  ) {
    final navigator = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop();
    navigator.pushNamed(destination.route);
  }

  /// 필요한 변수는 검색어와 네 목적지 메타다.
  /// 작동 원리는 제목·설명에 포함되는 목적지만 HTML식 고밀도 목록으로 표시하는 것이다.
  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final visible = _destinations
        .where(
          (item) =>
              normalized.isEmpty ||
              '${item.title} ${item.detail} ${item.keywords}'
                  .toLowerCase()
                  .contains(normalized),
        )
        .toList(growable: false);
    return _StudentUtilitySheet(
      kicker: 'QUICK FIND',
      title: '전체 검색',
      description: '코스, 교재, 문제, 친구를 현재 기능별 검색으로 연결합니다.',
      children: [
        TextField(
          autofocus: true,
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: '함수, 코스, 친구 검색',
          ),
        ),
        const SizedBox(height: 14),
        for (final item in visible)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(item.detail),
            trailing: const Icon(Icons.arrow_forward_rounded),
            onTap: () => _open(item),
          ),
        if (visible.isEmpty)
          isStudentDensityMobile(context)
              ? const _QuickSearchEmpty()
              : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('연결할 검색 화면이 없습니다.')),
                ),
      ],
    );
  }
}

class _QuickSearchEmpty extends StatelessWidget {
  const _QuickSearchEmpty();

  /// 필요한 변수는 결과가 없는 통합 검색 상태다.
  /// 작동 원리: 막힌 기능처럼 보이는 문구 대신 검색어를 바꿀 방법과 실제 탐색 가능한 범위를 안내한다.
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFF202022),
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.search_off_rounded, color: Colors.white, size: 30),
        SizedBox(height: 14),
        Text(
          '검색 결과가 없어요',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '코스, 교재, 오답, 친구, 그룹처럼 기능 이름이나 학습 키워드로 다시 검색해 보세요.',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
      ],
    ),
  );
}

class _StudentNotificationSnapshot {
  const _StudentNotificationSnapshot({
    required this.globalNotices,
    required this.academyNotices,
    required this.friendRequests,
    required this.directMessages,
  });

  final List<StudyGroupNotice> globalNotices;
  final List<StudyGroupNotice> academyNotices;
  final List<FriendRequest> friendRequests;
  final List<DirectMessage> directMessages;
}

class _StudentNotificationsSheet extends StatefulWidget {
  const _StudentNotificationsSheet();

  /// 필요한 변수는 알림 센터 위젯이다.
  /// 작동 원리는 한 번만 생성되는 공지·친구 요청 병렬 조회 Future를 보관하는 상태를 만든다.
  @override
  State<_StudentNotificationsSheet> createState() =>
      _StudentNotificationsSheetState();
}

class _StudentNotificationsSheetState
    extends State<_StudentNotificationsSheet> {
  late final Future<_StudentNotificationSnapshot> _future = _load();
  final Set<String> _resolvedRequestIds = <String>{};

  /// 필요한 변수는 전체 공지, 내 학원 공지, 친구 요청 API다.
  /// 작동 원리는 세 GET을 병렬 실행해 순차 요청 없이 알림 패널을 한 번에 갱신하는 것이다.
  Future<_StudentNotificationSnapshot> _load() async {
    final results = await Future.wait<Object>([
      ApiClient.instance
          .listGlobalSystemNotices(limit: 8)
          .onError((_, _) => const <StudyGroupNotice>[]),
      ApiClient.instance
          .listMySystemGroupNotices(limit: 12)
          .onError((_, _) => const <StudyGroupNotice>[]),
      ApiClient.instance.listFriendRequests().onError(
        (_, _) => const <FriendRequest>[],
      ),
      ApiClient.instance
          .fetchConversationThreads(forceRefresh: true)
          .onError((_, _) => const <DirectMessage>[]),
    ]);
    final friendRequests = results[2] as List<FriendRequest>;
    final directMessages = results[3] as List<DirectMessage>;
    SocialNotificationStore.update(
      friendRequests: friendRequests
          .where(
            (request) =>
                request.direction == 'incoming' && request.status == 'pending',
          )
          .length,
      unreadMessages: directMessages
          .where((message) => !message.isMine && !message.isRead)
          .length,
    );
    return _StudentNotificationSnapshot(
      globalNotices: results[0] as List<StudyGroupNotice>,
      academyNotices: results[1] as List<StudyGroupNotice>,
      friendRequests: friendRequests,
      directMessages: directMessages,
    );
  }

  /// 필요한 변수는 받은 친구 요청이다.
  /// 작동 원리는 발신자와 메시지를 확인한 뒤 기존 수락 API를 호출하고 성공한 요청만 현재 알림에서 제거하는 것이다.
  Future<void> _confirmFriendRequest(FriendRequest request) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${request.username}님의 친구 요청'),
        content: Text(
          request.message?.trim().isNotEmpty == true
              ? request.message!.trim()
              : '친구 요청을 수락하시겠어요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('수락'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await ApiClient.instance.acceptFriendRequest(request.requestId);
      if (!mounted) return;
      setState(() => _resolvedRequestIds.add(request.requestId));
      final current = SocialNotificationStore.notifier.value.friendRequests;
      SocialNotificationStore.update(friendRequests: current - 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request.username}님과 친구가 되었습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구 요청을 수락하지 못했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  /// 필요한 변수는 소셜 알림 상태와 전체·학원 공지·친구 요청 비동기 결과다.
  /// 작동 원리는 알림과 공지를 구역으로 나누고 공지를 누르면 실제 본문을 같은 패널 위에서 확인한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return _StudentUtilitySheet(
      kicker: 'LIVE STATUS',
      title: '알림 센터',
      showMobileClose: false,
      description: mobile ? '' : '과제 마감, 친구 요청, 그룹 공지, 코스 학습 상태를 한곳에서 확인합니다.',
      children: [
        const _UtilitySectionTitle('알림'),
        ValueListenableBuilder<SocialNotificationSnapshot>(
          valueListenable: SocialNotificationStore.notifier,
          builder: (context, social, _) => Column(
            children: [
              _UtilityNoticeRow(
                title: '새 메시지',
                detail: social.unreadMessages == 0
                    ? '읽지 않은 메시지가 없습니다.'
                    : '친구와 그룹에서 도착한 메시지를 확인하세요.',
                meta: '${social.unreadMessages}',
              ),
              if (social.friendRemovals > 0)
                _UtilityNoticeRow(
                  title: '친구 상태 변경',
                  detail: '친구 목록에서 변경된 관계를 확인하세요.',
                  meta: '${social.friendRemovals}',
                ),
            ],
          ),
        ),
        FutureBuilder<_StudentNotificationSnapshot>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const _UtilityNoticeRow(
                title: '알림을 불러오지 못했습니다.',
                detail: '네트워크 연결 후 알림 센터를 다시 열어 주세요.',
                meta: '재시도',
              );
            }
            final data = snapshot.data!;
            final unreadMessages = data.directMessages
                .where((message) => !message.isMine && !message.isRead)
                .toList(growable: false);
            final incomingRequests = data.friendRequests
                .where(
                  (request) =>
                      request.direction == 'incoming' &&
                      request.status == 'pending' &&
                      !_resolvedRequestIds.contains(request.requestId),
                )
                .toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final message in unreadMessages)
                  _UtilityNoticeRow(
                    title: '${message.from}님의 새 쪽지',
                    detail: message.text,
                    meta: '새 쪽지',
                  ),
                for (final request in incomingRequests)
                  _UtilityNoticeRow(
                    title: '${request.username}님의 친구 요청',
                    detail: request.message?.trim().isNotEmpty == true
                        ? request.message!.trim()
                        : '눌러서 요청을 확인하고 수락할 수 있어요.',
                    meta: '확인',
                    onTap: () => _confirmFriendRequest(request),
                  ),
                if (incomingRequests.isEmpty)
                  const _UtilityNoticeRow(
                    title: '친구 요청',
                    detail: '새로운 친구 요청이 없습니다.',
                    meta: '0',
                  ),
                const SizedBox(height: 24),
                const _UtilitySectionTitle('공지'),
                for (final notice in data.globalNotices)
                  _UtilityNoticeRow(
                    title: notice.title.isEmpty ? '시스템 공지' : notice.title,
                    detail: _plainNoticeContent(notice.contentHtml),
                    meta: '전체 공지',
                    onTap: () => showStudentNoticeDetail(context, notice),
                  ),
                for (final notice in data.academyNotices)
                  _UtilityNoticeRow(
                    title: notice.title.isEmpty ? '학원 공지' : notice.title,
                    detail: _plainNoticeContent(notice.contentHtml),
                    meta: notice.groupName?.trim().isNotEmpty == true
                        ? notice.groupName!.trim()
                        : '학원 공지',
                    onTap: () => showStudentNoticeDetail(context, notice),
                  ),
                if (data.globalNotices.isEmpty && data.academyNotices.isEmpty)
                  const _UtilityNoticeRow(
                    title: '확인할 공지가 없습니다.',
                    detail: '새 공지가 도착하면 이곳에 표시됩니다.',
                    meta: '0',
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StudentUtilitySheet extends StatelessWidget {
  const _StudentUtilitySheet({
    required this.kicker,
    required this.title,
    required this.description,
    required this.children,
    this.showMobileClose = true,
  });

  final String kicker;
  final String title;
  final String description;
  final List<Widget> children;
  final bool showMobileClose;

  /// 필요한 변수는 시트 제목·설명·본문이다.
  /// 작동 원리는 HTML 공용 액션 모달의 여백·타이포·최대 높이를 모든 화면에서 동일하게 유지하는 것이다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return SafeArea(
      top: !mobile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: mobile
                ? const EdgeInsets.fromLTRB(20, 2, 14, 12)
                : const EdgeInsets.fromLTRB(24, 24, 18, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!mobile) ...[
                        Text(
                          kicker,
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.7,
                            color: Colors.black54,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                      ],
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!mobile || showMobileClose)
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(48),
                      backgroundColor: mobile ? Colors.white : null,
                      side: mobile
                          ? BorderSide.none
                          : const BorderSide(color: Color(0xFFB9B9BD)),
                    ),
                  ),
              ],
            ),
          ),
          if (!mobile) const Divider(height: 1, color: Color(0xFFE4E4E6)),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                mobile ? 20 : 24,
                mobile ? 8 : 28,
                mobile ? 20 : 24,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              children: [
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: TextStyle(
                      color: mobile ? Colors.black54 : Colors.black45,
                      fontSize: mobile ? 15 : null,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: mobile ? 24 : 18),
                ],
                ...children,
              ],
            ),
          ),
          if (!mobile) ...[
            const Divider(height: 1, color: Color(0xFFE4E4E6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UtilityNoticeRow extends StatelessWidget {
  const _UtilityNoticeRow({
    required this.title,
    required this.detail,
    required this.meta,
    this.onTap,
  });

  final String title;
  final String detail;
  final String meta;
  final VoidCallback? onTap;

  /// 필요한 변수는 알림 제목·본문·메타다.
  /// 작동 원리는 PC에서는 구분선 목록을 유지하고 모바일에서는 큰 글자의 부드러운 알림 카드로 표시한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final row = Container(
      margin: EdgeInsets.only(bottom: mobile ? 9 : 0),
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 16 : 0,
        vertical: mobile ? 16 : 14,
      ),
      decoration: BoxDecoration(
        color: mobile ? Colors.white : Colors.transparent,
        borderRadius: mobile ? BorderRadius.circular(20) : null,
        border: mobile
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFE4E4E6))),
        boxShadow: mobile
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .055),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: mobile ? 16 : null,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: mobile ? 6 : 4),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mobile ? 14 : 12,
                    height: 1.35,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            meta,
            style: TextStyle(
              fontSize: mobile ? 12 : 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 5),
            Icon(Icons.chevron_right_rounded, size: mobile ? 22 : 16),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(mobile ? 20 : 0),
        child: row,
      ),
    );
  }
}

class _UtilitySectionTitle extends StatelessWidget {
  const _UtilitySectionTitle(this.title);

  final String title;

  /// 필요한 변수는 알림 패널의 구역 제목이다.
  /// 작동 원리는 모바일에서 18px 제목을 사용해 알림과 공지 목록의 시작점을 빠르게 구분하는 것이다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mobile ? 10 : 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: mobile ? 18 : 12,
          fontWeight: FontWeight.w900,
          letterSpacing: mobile ? 0 : .4,
        ),
      ),
    );
  }
}

/// 필요한 변수는 HTML이 포함될 수 있는 공지 본문이다.
/// 작동 원리는 기본 태그와 엔티티를 제거해 목록과 간단 상세에서 읽을 수 있는 UTF-8 텍스트로 바꾼다.
String _plainNoticeContent(String contentHtml) {
  return contentHtml
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp('<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();
}

/// 필요한 변수는 현재 화면 문맥과 선택한 전체 또는 학원 공지다.
/// 작동 원리는 알림 사이드바 위에 제목, 출처, 실제 본문을 표시해 목록에서 바로 열람하게 한다.
Future<void> showStudentNoticeDetail(
  BuildContext context,
  StudyGroupNotice notice,
) {
  final source = notice.scope == 'global'
      ? '전체 공지'
      : (notice.groupName?.trim().isNotEmpty == true
            ? notice.groupName!.trim()
            : '학원 공지');
  final content = _plainNoticeContent(notice.contentHtml);
  if (isStudentDensityMobile(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF4F4F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: .72,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notice.title.isEmpty ? '공지사항' : notice.title,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        fixedSize: const Size.square(48),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  source,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(22),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(
                        content.isEmpty ? '공지 본문이 없습니다.' : content,
                        style: const TextStyle(fontSize: 16, height: 1.65),
                      ),
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
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(notice.title.isEmpty ? '공지사항' : notice.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                source,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                content.isEmpty ? '공지 본문이 없습니다.' : content,
                style: const TextStyle(fontSize: 14, height: 1.65),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

class _Ios26LevelIndicator extends StatefulWidget {
  const _Ios26LevelIndicator({required this.brandColor, required this.compact});

  final Color brandColor;
  final bool compact;

  @override
  State<_Ios26LevelIndicator> createState() => _Ios26LevelIndicatorState();
}

class _Ios26LevelIndicatorState extends State<_Ios26LevelIndicator> {
  late final Future<AccountSummary> _summary = ApiClient.instance
      .fetchAccountSummary();
  AccountSummary? _latestSummary;

  @override
  void initState() {
    super.initState();
    ActivityStore.accountSummaryNotifier.addListener(_handleAccountSummary);
  }

  @override
  void dispose() {
    ActivityStore.accountSummaryNotifier.removeListener(_handleAccountSummary);
    super.dispose();
  }

  void _handleAccountSummary() {
    if (!mounted) return;
    setState(() {
      _latestSummary = ActivityStore.accountSummaryNotifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountSummary>(
      future: _summary,
      builder: (context, snapshot) {
        final account = _latestSummary ?? snapshot.data;
        if (account == null) {
          return const SizedBox.shrink();
        }

        return InkWell(
          onTap: () => LevelDetailModal.show(context, account),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: widget.compact ? 40 : 132,
            height: widget.compact ? 40 : null,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: widget.brandColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: widget.brandColor.withValues(alpha: 0.16),
              ),
            ),
            child: widget.compact
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: account.levelProgress,
                        strokeWidth: 2.5,
                        color: StudentDensityTokens.dark,
                        backgroundColor: StudentDensityTokens.line,
                      ),
                      Text(
                        '${account.level}',
                        style: const TextStyle(
                          color: StudentDensityTokens.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: account.levelProgress,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.9,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.brandColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'lv. ${account.level}',
                        style: TextStyle(
                          color: widget.brandColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.item});

  final Ios26NavItem item;

  /// 필요 변수: `item.label`, `item.active`, `item.onTap`이다.
  /// 작동 원리: 30px 높이의 캡슐 안에서 텍스트를 중앙 정렬하고, 활성 상태는 배경과 글자색만 바꾼다.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('student-top-nav-${item.label}'),
      borderRadius: BorderRadius.circular(999),
      onTap: item.onTap,
      child: Container(
        height: 30,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: item.active ? StudentDensityTokens.dark : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          item.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: item.active ? Colors.white : StudentDensityTokens.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool showBadge;

  /// 필요한 변수는 아이콘·툴팁·선택 콜백과 알림 배지 여부다.
  /// 작동 원리: HTML의 38px 원형 상단 행동 버튼과 우측 상단 상태점을 그린다.
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.76),
                shape: BoxShape.circle,
                border: Border.all(color: StudentDensityTokens.line),
              ),
              child: Icon(icon, size: 18, color: StudentDensityTokens.ink),
            ),
            if (showBadge)
              Positioned(
                top: 5,
                right: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: StudentDensityTokens.dark,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactProfile extends StatelessWidget {
  const _CompactProfile({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  /// 필요한 변수는 사용자 표시명과 프로필 이동 콜백이다.
  /// 작동 원리: HTML의 원형 아바타와 이름이 결합된 40px 캡슐을 표시한다.
  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? '학' : label.trim().characters.first;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.fromLTRB(4, 3, 11, 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: StudentDensityTokens.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: StudentDensityTokens.dark,
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.item, required this.brandColor});

  final Ios26ActionIcon item;
  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    final bg = item.active
        ? StudentDensityTokens.dark
        : StudentDensityTokens.surface;
    return Tooltip(
      message: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: item.onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: StudentDensityTokens.line),
          ),
          child: Icon(
            item.icon,
            size: 18,
            color: item.active ? Colors.white : StudentDensityTokens.ink,
          ),
        ),
      ),
    );
  }
}

class Ios26FrostedCard extends StatelessWidget {
  const Ios26FrostedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}
