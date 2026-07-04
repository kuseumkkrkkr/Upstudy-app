import 'dart:ui';

import 'package:flutter/material.dart';

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

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: barHeight,
          padding: EdgeInsets.only(
            left: effectiveLeftInset,
            right: compact ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.07)),
            ),
          ),
          child: Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: brandColor,
                  ),
                  onPressed: onBack,
                ),
                const SizedBox(width: 2),
              ],
              IconButton(
                icon: Icon(Icons.menu_rounded, color: brandColor),
                onPressed: onMenu,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onTitleTap,
                child: Text(
                  title,
                  style: TextStyle(
                    color: brandColor,
                    fontSize: compact ? 28 : 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const Spacer(),
              if (items.isNotEmpty)
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
                              child: _NavChip(
                                item: item,
                                brandColor: brandColor,
                              ),
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
                        child: _ActionIcon(item: item, brandColor: brandColor),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.item, required this.brandColor});

  final Ios26NavItem item;
  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    final activeBg = brandColor.withValues(alpha: 0.16);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: item.active ? activeBg : Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: brandColor.withValues(alpha: 0.2)),
        ),
        child: Text(
          item.label,
          style: TextStyle(
            color: brandColor,
            fontSize: 13,
            fontWeight: item.active ? FontWeight.w700 : FontWeight.w500,
          ),
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
        ? brandColor.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.62);
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
            border: Border.all(color: brandColor.withValues(alpha: 0.2)),
          ),
          child: Icon(item.icon, size: 18, color: brandColor),
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
