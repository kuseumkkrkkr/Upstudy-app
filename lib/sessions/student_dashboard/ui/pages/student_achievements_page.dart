import 'package:flutter/material.dart';

import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';
import 'package:s11/sessions/student_dashboard/business/activity_badge_catalog.dart';

/// Displays real badge progress using the standalone HTML achievements layout.
class StudentAchievementsPage extends StatefulWidget {
  const StudentAchievementsPage({super.key});

  @override
  State<StudentAchievementsPage> createState() =>
      _StudentAchievementsPageState();
}

class _StudentAchievementsPageState extends State<StudentAchievementsPage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<ActivitySnapshot>(
        valueListenable: ActivityStore.notifier,
        builder: (context, snapshot, _) {
          final accountLevel =
              ActivityStore.accountSummaryNotifier.value?.level ?? 0;
          final all = ActivityBadgeCatalog.evaluate(
            snapshot,
            accountLevel: accountLevel,
          );
          final earned = all.where((item) => item.isEarned).toList();
          final progress = all.where((item) => !item.isEarned).toList();
          final visible = switch (_selectedTab) {
            1 => earned,
            2 => all,
            _ => progress,
          };
          final nextBadges = ActivityBadgeCatalog.nextBadges(
            snapshot,
            limit: 1,
            accountLevel: accountLevel,
          );
          final nearest = nextBadges.isEmpty ? null : nextBadges.first;

          return StudentHtmlShell(
            key: const ValueKey('student-achievements-page'),
            title: '업적 보관함',
            activeRoute: '/student/dashboard',
            mobileBackButton: true,
            onMenu: () => Navigator.of(context).maybePop(),
            railWidth: 84,
            child: _buildCollection(
              context,
              nearest: nearest,
              progress: progress,
              earned: earned,
              all: all,
              visible: visible,
            ),
          );
        },
      );

  Widget _buildCollection(
    BuildContext context, {
    required ActivityBadgeProgress? nearest,
    required List<ActivityBadgeProgress> progress,
    required List<ActivityBadgeProgress> earned,
    required List<ActivityBadgeProgress> all,
    required List<ActivityBadgeProgress> visible,
  }) {
    final mobile = isStudentDensityMobile(context);
    final columns = mobile ? 1 : 2;

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NearestAchievementBanner(item: nearest),
          _AchievementTabs(
            selected: _selectedTab,
            counts: [progress.length, earned.length, all.length],
            onChanged: (index) => setState(() => _selectedTab = index),
          ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('표시할 업적이 없습니다.'),
            )
          else
            GridView.count(
              key: const ValueKey('student-achievement-list'),
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: mobile ? 2.6 : 3.05,
              children: [
                for (final item in visible)
                  _AchievementListCard(
                    item: item,
                    onTap: () => _showDetail(context, item),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    ActivityBadgeProgress item,
  ) async {
    final mobile = isStudentDensityMobile(context);
    final content = _AchievementDetail(item: item);
    if (mobile) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(),
        builder: (_) => content,
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: content,
        ),
      ),
    );
  }
}

class _NearestAchievementBanner extends StatelessWidget {
  const _NearestAchievementBanner({required this.item});

  final ActivityBadgeProgress? item;

  @override
  Widget build(BuildContext context) {
    final target = item;
    final mobile = isStudentDensityMobile(context);
    return Container(
      key: const ValueKey('student-achievement-nearest'),
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 24, 18, 16, 18),
      color: const Color(0xFF09090B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가장 가까운 업적',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  target?.badge.title ?? '모든 업적을 달성했어요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (target != null)
                Text(
                  '${(target.progress * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            target == null
                ? '새로운 학습 기록을 쌓아보세요.'
                : '${target.badge.metricLabel} · 다음 목표 ${target.progressText}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 12),
          ClipRect(
            child: LinearProgressIndicator(
              minHeight: 5,
              value: target?.progress ?? 1,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTabs extends StatelessWidget {
  const _AchievementTabs({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final int selected;
  final List<int> counts;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['진행 중', '획득', '전체'];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++)
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == index,
              child: InkWell(
                key: ValueKey('student-achievement-tab-$index'),
                onTap: () => onChanged(index),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == index
                        ? const Color(0xFF09090B)
                        : Colors.white,
                    border: Border(
                      right: BorderSide(
                        color: Colors.black.withValues(alpha: .08),
                      ),
                      bottom: BorderSide(
                        color: Colors.black.withValues(alpha: .08),
                      ),
                    ),
                  ),
                  child: Text(
                    '${labels[index]}  ${counts[index]}',
                    style: TextStyle(
                      color: selected == index
                          ? Colors.white
                          : const Color(0xFF71717A),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AchievementListCard extends StatelessWidget {
  const _AchievementListCard({required this.item, required this.onTap});

  final ActivityBadgeProgress item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = item.badge;
    final percent = (item.progress * 100).round();
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 118),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.black.withValues(alpha: .08)),
              bottom: BorderSide(color: Colors.black.withValues(alpha: .08)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                color: item.isEarned
                    ? const Color(0xFF09090B)
                    : const Color(0xFFF3F3F5),
                child: Text(
                  badge.tier.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: item.isEarned
                        ? Colors.white
                        : const Color(0xFF09090B),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.isEarned ? '획득' : '진행 중',
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      badge.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF09090B),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      badge.metricLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      minHeight: 5,
                      value: item.progress,
                      backgroundColor: const Color(0xFFF3F3F5),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF09090B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.progressText} · $percent%',
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios,
                size: 15,
                color: Color(0xFF71717A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementDetail extends StatelessWidget {
  const _AchievementDetail({required this.item});

  final ActivityBadgeProgress item;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.isEarned ? '획득한 업적' : '진행 중인 업적',
                  style: const TextStyle(
                    color: Color(0xFF71717A),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.badge.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            item.badge.description,
            style: const TextStyle(
              color: Color(0xFF71717A),
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '${item.progressText} · ${item.isEarned ? '획득 완료' : '다음 단계 진행 중'}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            minHeight: 6,
            value: item.progress,
            backgroundColor: const Color(0xFFF3F3F5),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF09090B)),
          ),
          const SizedBox(height: 20),
          if (!item.isEarned)
            FilledButton(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.pushNamed('/student/dashboard?scene=today-tasks');
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF09090B),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: const RoundedRectangleBorder(),
              ),
              child: const Text('오늘 학습하기'),
            ),
        ],
      ),
    ),
  );
}
