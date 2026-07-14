import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/services/api/api_client.dart';
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
    this.profileLabel = '김학생',
    this.onSearch,
    this.onNotifications,
    this.onProfile,
    this.leftInset,
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
  final String profileLabel;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final double? leftInset;

  /// 필요 변수: 현재 화면 폭과 전달받은 메뉴·행동 목록.
  /// 작동 원리: HTML처럼 좌측 메뉴·브랜드, 중앙 캡슐 메뉴, 우측 검색·알림·프로필을 독립 정렬합니다.
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width <= StudentDensityTokens.mobileBreakpoint;
    final barHeight = compact ? 58.0 : 68.0;
    final effectiveLeftInset = leftInset ?? (compact ? 12.0 : 40.0);

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
                    if (onBack != null)
                      _TopCircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: '뒤로가기',
                        onTap: onBack,
                      )
                    else if (onMenu != null)
                      _TopCircleButton(
                        key: const ValueKey('student-mobile-menu'),
                        icon: Icons.menu_rounded,
                        tooltip: '전체 메뉴',
                        onTap: onMenu,
                      ),
                    if (onBack != null || onMenu != null)
                      SizedBox(width: compact ? 7 : 10),
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
                            style: const TextStyle(
                              color: StudentDensityTokens.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty && !compact)
                Transform.translate(
                  offset: const Offset(-22, 0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: StudentDensityTokens.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in items) _NavChip(item: item),
                      ],
                    ),
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
                        onTap: onSearch,
                      ),
                      const SizedBox(width: 8),
                      _TopCircleButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: '알림',
                        showBadge: true,
                        onTap: onNotifications,
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 8),
                        _CompactProfile(label: profileLabel, onTap: onProfile),
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: item.onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: item.active ? StudentDensityTokens.dark : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          item.label,
          style: TextStyle(
            color: item.active ? Colors.white : StudentDensityTokens.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
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
