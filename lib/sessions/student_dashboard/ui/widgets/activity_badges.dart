import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/sessions/student_dashboard/business/activity_badge_catalog.dart';

class ActivityBadgeSummary extends StatelessWidget {
  const ActivityBadgeSummary({
    super.key,
    required this.snapshot,
    this.accountLevel = 0,
  });

  final ActivitySnapshot snapshot;
  final int accountLevel;

  @override
  Widget build(BuildContext context) {
    final scale = _scale(context);
    final earned = ActivityBadgeCatalog.earnedBadges(
      snapshot,
      accountLevel: accountLevel,
    );
    final next = ActivityBadgeCatalog.nextBadges(
      snapshot,
      limit: 1,
      accountLevel: accountLevel,
    );
    final visibleBadges = _distributedPreviewBadges(earned, count: 4);
    final nextBadge = next.isEmpty ? null : next.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '획득한 뱃지 ${earned.length}/${ActivityBadgeCatalog.allBadges.length}개',
                style: _textStyle(size: 12 * scale, weight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final badge in visibleBadges)
              Padding(
                padding: EdgeInsets.only(left: 6 * scale),
                child: Tooltip(
                  message: badge.badge.title,
                  child: ActivityBadgeIcon(progress: badge, size: 30 * scale),
                ),
              ),
          ],
        ),
        if (nextBadge != null) ...[
          SizedBox(height: 10 * scale),
          Text(
            '다음: ${nextBadge.badge.title} · ${nextBadge.progressText}',
            style: _textStyle(size: 11 * scale, color: Colors.black54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 5 * scale),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: nextBadge.progress,
              minHeight: 6 * scale,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              color: nextBadge.badge.color,
            ),
          ),
        ],
      ],
    );
  }
}

class ActivityBadgeIcon extends StatefulWidget {
  const ActivityBadgeIcon({
    super.key,
    required this.progress,
    required this.size,
  });

  final ActivityBadgeProgress progress;
  final double size;

  @override
  State<ActivityBadgeIcon> createState() => _ActivityBadgeIconState();
}

class _ActivityBadgeIconState extends State<ActivityBadgeIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _badgeAnimationDuration(widget.progress.badge.rarity),
    );
    if (widget.progress.isEarned) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ActivityBadgeIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress.badge.rarity != oldWidget.progress.badge.rarity) {
      _controller.duration = _badgeAnimationDuration(
        widget.progress.badge.rarity,
      );
    }
    if (widget.progress.isEarned && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.progress.isEarned && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.progress.badge;
    final size = widget.size;
    final isEarned = widget.progress.isEarned;
    final color = isEarned ? badge.color : Colors.black38;
    final sparkleLevel = isEarned ? badge.rarity.sparkleLevel : 0;
    final tier = isEarned ? badge.tier.clamp(1, 12).toInt() : 0;
    final goldWeight = tier <= 6 ? 0.0 : ((tier - 6) / 6).clamp(0.0, 1.0);
    final accent = Color.lerp(color, _badgeGold, goldWeight)!;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (isEarned && sparkleLevel >= 2)
                CustomPaint(
                  size: Size.square(size),
                  painter: _BadgeHaloPainter(
                    progress: _controller.value,
                    color: accent,
                    level: sparkleLevel,
                  ),
                ),
              if (isEarned && sparkleLevel >= 3)
                CustomPaint(
                  size: Size.square(size),
                  painter: _BadgeBurstPainter(
                    progress: _controller.value,
                    color: accent,
                    level: sparkleLevel,
                    tier: tier,
                  ),
                ),
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: size * 0.74,
                  height: size * 0.74,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: isEarned ? 0.24 : 0.10),
                        if (goldWeight > 0)
                          _badgeGold.withValues(
                            alpha: 0.22 + goldWeight * 0.28,
                          ),
                        color.withValues(alpha: isEarned ? 0.62 : 0.22),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(size * 0.08),
                    border: Border.all(
                      color: accent.withValues(alpha: isEarned ? 1 : 0.5),
                      width: size * 0.045,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(
                          alpha: isEarned ? 0.18 + sparkleLevel * 0.035 : 0.06,
                        ),
                        blurRadius: size * (0.16 + sparkleLevel * 0.035),
                      ),
                      if (goldWeight > 0)
                        BoxShadow(
                          color: _badgeGold.withValues(
                            alpha: 0.18 + goldWeight * 0.16,
                          ),
                          blurRadius: size * (0.28 + goldWeight * 0.16),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                width: size * 0.64,
                height: size * 0.64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEarned ? Colors.white : const Color(0xFFF1F1F1),
                  border: Border.all(
                    color: color.withValues(alpha: isEarned ? 0.48 : 0.22),
                    width: size * 0.035,
                  ),
                ),
              ),
              if (isEarned && sparkleLevel >= 2)
                CustomPaint(
                  size: Size.square(size * 0.68),
                  painter: _BadgeGemRingPainter(
                    progress: _controller.value,
                    color: accent,
                    level: sparkleLevel,
                    tier: tier,
                  ),
                ),
              if (isEarned && sparkleLevel >= 4)
                CustomPaint(
                  size: Size.square(size * 0.72),
                  painter: _BadgeShinePainter(
                    progress: _controller.value,
                    intensity: goldWeight,
                  ),
                ),
              if (isEarned)
                CustomPaint(
                  size: Size.square(size * 0.78),
                  painter: _BadgeSparklePainter(
                    progress: _controller.value,
                    color: accent,
                    level: sparkleLevel,
                    seed: badge.tier,
                  ),
                ),
              Icon(badge.icon, color: color, size: size * 0.38),
              Positioned(
                bottom: size * 0.05,
                child: Container(
                  width: size * 0.38,
                  height: size * 0.08,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isEarned ? 1 : 0.45),
                    borderRadius: BorderRadius.circular(size),
                  ),
                ),
              ),
              if (!isEarned)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.46),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

void showActivityBadgeDialog({
  required BuildContext context,
  required ActivitySnapshot snapshot,
  int accountLevel = 0,
}) {
  // 필요한 변수는 현재 화면 크기와 업적 진행 기록이다.
  // 작동 원리: 세로 모바일은 한 손 스크롤에 맞춘 전폭 바텀시트를 열고,
  // 태블릿·PC는 기존 정보 밀도가 높은 중앙 다이얼로그를 유지한다.
  final media = MediaQuery.of(context);
  final isPortraitMobile =
      media.size.width <= 720 && media.size.height >= media.size.width;
  if (isPortraitMobile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.93,
        minChildSize: 0.72,
        maxChildSize: 0.98,
        expand: false,
        builder: (context, scrollController) => _MobileActivityBadgeSheet(
          snapshot: snapshot,
          accountLevel: accountLevel,
          scrollController: scrollController,
        ),
      ),
    );
    return;
  }
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) =>
        _ActivityBadgeDialog(snapshot: snapshot, accountLevel: accountLevel),
  );
}

class _MobileActivityBadgeSheet extends StatelessWidget {
  const _MobileActivityBadgeSheet({
    required this.snapshot,
    required this.accountLevel,
    required this.scrollController,
  });

  final ActivitySnapshot snapshot;
  final int accountLevel;
  final ScrollController scrollController;

  /// 필요한 변수는 활동 기록, 계정 레벨, 바텀시트 스크롤 컨트롤러다.
  /// 작동 원리: 전체 업적을 가족 단위 세로 카드로 나누고 각 카드는 고정 4열
  /// 트로피 그리드를 사용해 작은 모바일에서도 번호와 진행 상태를 읽을 수 있게 한다.
  @override
  Widget build(BuildContext context) {
    final all = ActivityBadgeCatalog.evaluate(
      snapshot,
      accountLevel: accountLevel,
    );
    final earnedCount = all.where((entry) => entry.isEarned).length;
    final groups = _groupBadgeProgress(all);

    return Material(
      key: const ValueKey('activity-badge-mobile-sheet'),
      color: const Color(0xFFF5F5F7),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
      clipBehavior: Clip.antiAlias,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 14, 18),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A4A52),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '업적 보관함',
                              style: TextStyle(
                                fontSize: 30,
                                height: 1.08,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$earnedCount개 획득 · 잠긴 트로피를 눌러 미리보기',
                              style: const TextStyle(
                                color: Color(0xFF66666D),
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Semantics(
                        button: true,
                        label: '업적 보관함 닫기',
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).pop(),
                            child: const SizedBox(
                              width: 54,
                              height: 54,
                              child: Icon(Icons.close_rounded, size: 29),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.separated(
              itemCount: groups.length,
              itemBuilder: (context, index) =>
                  _MobileBadgeGroupCard(group: groups[index]),
              separatorBuilder: (context, index) => const SizedBox(height: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileBadgeGroupCard extends StatelessWidget {
  const _MobileBadgeGroupCard({required this.group});

  final _BadgeProgressGroup group;

  /// 필요한 변수는 같은 목표를 공유하는 12단계 트로피 목록이다.
  /// 작동 원리: 목표 설명과 획득 수를 먼저 보여주고 트로피를 항상 4열로 배치한 뒤,
  /// 카드 하단에서 다음 단계의 수치와 진행률을 한 줄로 안내한다.
  @override
  Widget build(BuildContext context) {
    final first = group.items.first.badge;
    final title = ActivityBadgeCatalog.familyTitleOf(first.family);
    final earned = group.items.where((entry) => entry.isEarned).length;
    final next = _firstLocked(group.items);
    final color = first.color;

    return Container(
      key: ValueKey('activity-badge-mobile-group-${first.family}'),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(first.icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$earned/${group.items.length} · ${first.metricLabel}',
                      style: const TextStyle(
                        color: Color(0xFF696970),
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            key: ValueKey('activity-badge-mobile-grid-${first.family}'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: group.items.length,
            itemBuilder: (context, index) => _CompactBadgeTile(
              progress: group.items[index],
              iconSize: 58,
              labelSize: 13,
              labelSpacing: 7,
            ),
          ),
          const SizedBox(height: 16),
          if (next == null)
            Text(
              '이 그룹의 모든 트로피를 획득했어요.',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            )
          else ...[
            Text(
              '다음: ${next.badge.title} · ${next.progressText}',
              style: const TextStyle(
                color: Color(0xFF5F5F66),
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: next.progress,
                minHeight: 7,
                backgroundColor: const Color(0xFFF0F0F2),
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityBadgeDialog extends StatelessWidget {
  const _ActivityBadgeDialog({
    required this.snapshot,
    required this.accountLevel,
  });

  final ActivitySnapshot snapshot;
  final int accountLevel;

  @override
  Widget build(BuildContext context) {
    final scale = _scale(context);
    final all = ActivityBadgeCatalog.evaluate(
      snapshot,
      accountLevel: accountLevel,
    );
    final earnedCount = all.where((entry) => entry.isEarned).length;
    final groups = _groupBadgeProgress(all);
    final media = MediaQuery.of(context);
    final width = math.min(media.size.width - 56, 1224.0);
    final height = math.min(media.size.height - 42, 862.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: width,
        height: height,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20 * scale,
                  18 * scale,
                  14 * scale,
                  10 * scale,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '업적 보관함',
                            style: _textStyle(
                              size: 20 * scale,
                              weight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            '총 ${ActivityBadgeCatalog.allBadges.length}종 · 획득 $earnedCount개 · 잠긴 트로피를 누르면 미리볼 수 있어요',
                            style: _textStyle(
                              size: 12 * scale,
                              color: Colors.black54,
                              weight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16 * scale,
                    14 * scale,
                    16 * scale,
                    18 * scale,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _groupGridColumns(context),
                    mainAxisSpacing: 12 * scale,
                    crossAxisSpacing: 12 * scale,
                    childAspectRatio: _groupAspectRatio(context),
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    return _BadgeGroupCard(group: groups[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeGroupCard extends StatelessWidget {
  const _BadgeGroupCard({required this.group});

  final _BadgeProgressGroup group;

  @override
  Widget build(BuildContext context) {
    final scale = _scale(context);
    final first = group.items.first.badge;
    final title = ActivityBadgeCatalog.familyTitleOf(first.family);
    final earned = group.items.where((entry) => entry.isEarned).length;
    final next = _firstLocked(group.items);
    final color = first.color;

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32 * scale,
                height: 32 * scale,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
                child: Icon(first.icon, color: color, size: 18 * scale),
              ),
              SizedBox(width: 9 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _textStyle(
                        size: 13 * scale,
                        weight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2 * scale),
                    Text(
                      '$earned/${group.items.length} · ${first.metricLabel}',
                      style: _textStyle(
                        size: 10 * scale,
                        color: Colors.black54,
                        weight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tile = _badgeTileSize(constraints.maxWidth, scale);
                return Wrap(
                  spacing: 10 * scale,
                  runSpacing: 10 * scale,
                  children: [
                    for (final progress in group.items)
                      SizedBox(
                        width: tile,
                        child: _CompactBadgeTile(
                          progress: progress,
                          iconSize: math.min(tile * 0.72, 54 * scale),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: 8 * scale),
          if (next == null)
            Text(
              '이 그룹을 모두 획득했습니다.',
              style: _textStyle(
                size: 10 * scale,
                color: color,
                weight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '다음: ${next.badge.title} · ${next.progressText}',
                  style: _textStyle(size: 10 * scale, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 5 * scale),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: next.progress,
                    minHeight: 5 * scale,
                    backgroundColor: Colors.black.withValues(alpha: 0.06),
                    color: color,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CompactBadgeTile extends StatefulWidget {
  const _CompactBadgeTile({
    required this.progress,
    required this.iconSize,
    this.labelSize,
    this.labelSpacing,
  });

  final ActivityBadgeProgress progress;
  final double iconSize;
  final double? labelSize;
  final double? labelSpacing;

  @override
  State<_CompactBadgeTile> createState() => _CompactBadgeTileState();
}

class _CompactBadgeTileState extends State<_CompactBadgeTile> {
  Timer? _previewTimer;
  bool _previewActive = false;

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  void _showPreview() {
    if (widget.progress.isEarned) return;
    _previewTimer?.cancel();
    setState(() => _previewActive = true);
    _previewTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _previewActive = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = _scale(context);
    final displayProgress = _previewActive
        ? ActivityBadgeProgress(
            badge: widget.progress.badge,
            value: widget.progress.badge.threshold,
            progress: 1,
            isEarned: true,
          )
        : widget.progress;

    return Tooltip(
      message:
          '${widget.progress.badge.title}\n${widget.progress.progressText}',
      child: Semantics(
        button: !widget.progress.isEarned,
        label: widget.progress.badge.title,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.progress.isEarned ? null : _showPreview,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ActivityBadgeIcon(
                progress: displayProgress,
                size: widget.iconSize,
              ),
              SizedBox(height: widget.labelSpacing ?? 4 * scale),
              Text(
                '${widget.progress.badge.tier}',
                style: _textStyle(
                  size: widget.labelSize ?? 9 * scale,
                  weight: FontWeight.w900,
                  color: displayProgress.isEarned
                      ? widget.progress.badge.color
                      : Colors.black38,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const Color _badgeGold = Color(0xFFFFD766);
const Color _badgeGoldHot = Color(0xFFFFF3A6);

Duration _badgeAnimationDuration(ActivityBadgeRarity rarity) {
  return Duration(
    milliseconds: (4200 - rarity.index * 420).clamp(1500, 4200).toInt(),
  );
}

class _BadgeSparklePainter extends CustomPainter {
  const _BadgeSparklePainter({
    required this.progress,
    required this.color,
    required this.level,
    required this.seed,
  });

  final double progress;
  final Color color;
  final int level;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final count = 2 + level * 2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.42;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.34 + level * 0.06)
      ..strokeWidth = math.max(1.0, size.shortestSide * 0.018)
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      final turn = progress + i / count + seed * 0.071;
      final angle = turn * math.pi * 2;
      final pulse = 0.55 + 0.45 * math.sin((progress * 2 + i) * math.pi);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final length = size.shortestSide * (0.025 + level * 0.006) * pulse;
      canvas.drawLine(
        Offset(point.dx - length, point.dy),
        Offset(point.dx + length, point.dy),
        paint,
      );
      canvas.drawLine(
        Offset(point.dx, point.dy - length),
        Offset(point.dx, point.dy + length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeSparklePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        level != oldDelegate.level ||
        seed != oldDelegate.seed;
  }
}

class _BadgeBurstPainter extends CustomPainter {
  const _BadgeBurstPainter({
    required this.progress,
    required this.color,
    required this.level,
    required this.tier,
  });

  final double progress;
  final Color color;
  final int level;
  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    final count = 8 + level * 2;
    final center = Offset(size.width / 2, size.height / 2);
    final innerRadius = size.shortestSide * (0.38 + level * 0.012);
    final outerRadius = size.shortestSide * (0.44 + level * 0.018);
    final tierPulse = (tier / 12).clamp(0.0, 1.0);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(
        1.0,
        size.shortestSide * (0.008 + tierPulse * 0.006),
      );

    for (var i = 0; i < count; i++) {
      final turn = progress * (0.35 + tierPulse * 0.2) + i / count;
      final angle = turn * math.pi * 2;
      final pulse = 0.62 + 0.38 * math.sin((progress * 2 + i / 3) * math.pi);
      final start =
          center + Offset(math.cos(angle), math.sin(angle)) * innerRadius;
      final end =
          center +
          Offset(math.cos(angle), math.sin(angle)) *
              (outerRadius + size.shortestSide * 0.035 * pulse);
      paint.color = Color.lerp(
        color,
        _badgeGoldHot,
        tierPulse,
      )!.withValues(alpha: 0.18 + level * 0.035);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeBurstPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        level != oldDelegate.level ||
        tier != oldDelegate.tier;
  }
}

class _BadgeGemRingPainter extends CustomPainter {
  const _BadgeGemRingPainter({
    required this.progress,
    required this.color,
    required this.level,
    required this.tier,
  });

  final double progress;
  final Color color;
  final int level;
  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    final count = math.min(12, 4 + level * 2);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.48;
    final dotSize = size.shortestSide * (0.018 + level * 0.002);
    final tierPulse = (tier / 12).clamp(0.0, 1.0);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final angle = (i / count + progress * 0.08) * math.pi * 2;
      final pulse = 0.74 + 0.26 * math.sin((progress * 2 + i / 2) * math.pi);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      paint.color = Color.lerp(
        color,
        _badgeGoldHot,
        tierPulse,
      )!.withValues(alpha: 0.32 + tierPulse * 0.24);
      canvas.drawCircle(point, dotSize * pulse, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeGemRingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        level != oldDelegate.level ||
        tier != oldDelegate.tier;
  }
}

class _BadgeShinePainter extends CustomPainter {
  const _BadgeShinePainter({required this.progress, required this.intensity});

  final double progress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final sweep = (progress * 2 - 0.5) * size.width;
    final width = size.width * (0.22 + intensity * 0.14);
    final rect = Rect.fromLTWH(sweep - width / 2, 0, width, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0),
          _badgeGoldHot.withValues(alpha: 0.22 + intensity * 0.2),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);

    canvas.save();
    canvas.rotate(-math.pi / 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide)),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BadgeShinePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        intensity != oldDelegate.intensity;
  }
}

class _BadgeHaloPainter extends CustomPainter {
  const _BadgeHaloPainter({
    required this.progress,
    required this.color,
    required this.level,
  });

  final double progress;
  final Color color;
  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide * (0.36 + level * 0.018);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.shortestSide * 0.015)
      ..color = color.withValues(alpha: 0.10 + level * 0.018);

    for (var i = 0; i < math.min(level, 4); i++) {
      final radius = baseRadius + i * size.shortestSide * 0.055;
      final start = (progress + i * 0.18) * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.pi * (0.38 + level * 0.035),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeHaloPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        level != oldDelegate.level;
  }
}

List<ActivityBadgeProgress> _distributedPreviewBadges(
  List<ActivityBadgeProgress> badges, {
  required int count,
}) {
  final selected = <ActivityBadgeProgress>[];
  final seenFamilies = <String>{};
  for (final badge in badges) {
    if (seenFamilies.add(badge.badge.family)) {
      selected.add(badge);
      if (selected.length == count) return selected;
    }
  }
  for (final badge in badges) {
    if (!selected.contains(badge)) {
      selected.add(badge);
      if (selected.length == count) return selected;
    }
  }
  return selected;
}

List<_BadgeProgressGroup> _groupBadgeProgress(
  List<ActivityBadgeProgress> badges,
) {
  final groups = <String, List<ActivityBadgeProgress>>{};
  for (final badge in badges) {
    groups.putIfAbsent(badge.badge.family, () => <ActivityBadgeProgress>[]);
    groups[badge.badge.family]!.add(badge);
  }
  final results = groups.values.map((items) {
    items.sort((a, b) => a.badge.tier.compareTo(b.badge.tier));
    return _BadgeProgressGroup(List.unmodifiable(items));
  }).toList();
  return results;
}

ActivityBadgeProgress? _firstLocked(List<ActivityBadgeProgress> badges) {
  for (final badge in badges) {
    if (!badge.isEarned) return badge;
  }
  return null;
}

double _badgeTileSize(double maxWidth, double scale) {
  final gap = 10 * scale;
  final columns = maxWidth >= 300 * scale ? 6 : 4;
  return (maxWidth - gap * (columns - 1)) / columns;
}

int _groupGridColumns(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width >= 900) return 2;
  return 1;
}

double _groupAspectRatio(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width >= 900) return 1.75;
  if (width >= 620) return 2.2;
  return 1.25;
}

class _BadgeProgressGroup {
  const _BadgeProgressGroup(this.items);

  final List<ActivityBadgeProgress> items;
}

double _scale(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return (width / 1100).clamp(0.72, 1.0).toDouble();
}

TextStyle _textStyle({
  double size = 16,
  FontWeight weight = FontWeight.normal,
  Color color = Colors.black,
}) {
  return TextStyle(fontSize: size, fontWeight: weight, color: color);
}
