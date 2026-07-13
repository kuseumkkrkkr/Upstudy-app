import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 필요 변수: 메뉴명, 클릭 콜백, 선택 여부.
/// 작동 원리: 상단 바가 화면별 이동 기능을 잃지 않도록 표시 정보만 전달한다.
class Ios26NavItem {
  const Ios26NavItem({required this.label, this.onTap, this.active = false});

  final String label;
  final VoidCallback? onTap;
  final bool active;
}

/// 필요 변수: 아이콘, 접근성 문구, 클릭 콜백, 선택 여부.
/// 작동 원리: 화면별 액션을 공용 원형 버튼 모양으로 표현한다.
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

/// 필요 변수: 제목, 메뉴/뒤로가기 콜백, 탐색 및 액션 목록.
/// 작동 원리: 기존 콜백은 그대로 호출하고 반투명 블러와 캡슐 상태만 공통 적용한다.
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
  final double? leftInset;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 980;
    final barHeight = compact ? 64.0 : 72.0;
    final effectiveLeftInset = leftInset ?? (compact ? 18.0 : 24.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 16, 10, compact ? 10 : 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: barHeight,
            padding: EdgeInsets.only(
              left: effectiveLeftInset,
              right: compact ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.glassSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 28,
                  color: Color(0x12000000),
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                if (onBack != null) ...[
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 2),
                ],
                if (onMenu != null) ...[
                  IconButton(
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: onMenu,
                  ),
                  const SizedBox(width: 6),
                ],
                if (compact)
                  Flexible(
                    child: GestureDetector(
                      onTap: onTitleTap,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: onTitleTap,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const Spacer(),
                if (items.isNotEmpty && !compact)
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final item in items)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _NavChip(item: item),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (trailingIcons.isNotEmpty || actionIcons.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item
                          in (trailingIcons.isNotEmpty
                              ? trailingIcons
                              : actionIcons))
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _ActionIcon(item: item),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: item.active ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: item.active ? AppColors.primary : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          item.label,
          style: TextStyle(
            color: item.active ? Colors.white : AppColors.primary,
            fontSize: 13,
            fontWeight: item.active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.item});

  final Ios26ActionIcon item;

  @override
  Widget build(BuildContext context) {
    final bg = item.active ? AppColors.primary : AppColors.surfaceMuted;
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
            border: Border.all(
              color: item.active ? AppColors.primary : AppColors.surfaceBorder,
            ),
          ),
          child: Icon(
            item.icon,
            size: 18,
            color: item.active ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// 필요 변수: 자식 위젯, 내부 여백, 모서리 반경.
/// 작동 원리: 콘텐츠 구조를 변경하지 않고 블러·반투명 표면·얕은 그림자를 감싼다.
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
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.glassSurface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 28,
                color: Color(0x10000000),
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
