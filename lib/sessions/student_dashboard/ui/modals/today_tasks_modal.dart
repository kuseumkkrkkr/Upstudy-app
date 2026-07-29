import 'dart:ui';

import 'package:flutter/material.dart';

class TodayTaskEntry {
  const TodayTaskEntry({
    required this.title,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String caption;
  final IconData icon;
}

/// 필요한 변수는 오늘 할 일 카드와 항목별 화면 이동 콜백이다.
/// 작동 원리: 홈의 요약 카드를 누르면 읽기 전용 모달을 열고, 실제 할 일은 각각
/// 독립된 알림 카드로만 표시해 탭 즉시 해당 기능 화면으로 이동시킨다.
Future<T?> showTodayTasksModal<T>({
  required BuildContext context,
  required List<TodayTaskEntry> tasks,
  required ValueChanged<TodayTaskEntry> onTaskTap,
}) {
  final mobile = MediaQuery.sizeOf(context).width <= 780;
  if (mobile) {
    // 필요한 변수는 오늘 할 일 목록과 모바일 화면 높이다.
    // 작동 원리: 빈 전체 화면을 띄우지 않고 68% 높이의 둥근 하단 시트에서
    // 할 일만 보여 주며, 항목 선택 시 기존 목적지 이동 콜백을 그대로 실행한다.
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF4F4F6),
      barrierColor: Colors.black.withValues(alpha: 0.38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.68,
        child: TodayTasksModal(
          tasks: tasks,
          onTaskTap: onTaskTap,
          mobileSheet: true,
        ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (dialogContext) => Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
          Center(
            child: TodayTasksModal(tasks: tasks, onTaskTap: onTaskTap),
          ),
        ],
      ),
    ),
  );
}

class TodayTasksModal extends StatelessWidget {
  const TodayTasksModal({
    super.key,
    required this.tasks,
    required this.onTaskTap,
    this.mobileSheet = false,
  });

  final List<TodayTaskEntry> tasks;
  final ValueChanged<TodayTaskEntry> onTaskTap;
  final bool mobileSheet;

  /// 필요한 변수는 화면 크기와 오늘의 할 일 목록이다.
  /// 작동 원리: 모달 본문은 스크롤 가능한 상세 카드 목록만 두며, 일정 편집·달력·
  /// 별도 상세보기 버튼은 제공하지 않는다.
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width <= 780;
    return Container(
      key: mobileSheet ? const ValueKey('today-tasks-mobile-sheet') : null,
      width: mobile
          ? double.infinity
          : (size.width > 760 ? 720 : size.width * .94),
      constraints: BoxConstraints(
        maxHeight: mobileSheet
            ? double.infinity
            : mobile
            ? size.height
            : size.height * .82,
      ),
      decoration: BoxDecoration(
        color: mobileSheet ? const Color(0xFFF4F4F6) : Colors.white,
        borderRadius: BorderRadius.circular(
          mobileSheet
              ? 0
              : mobile
              ? 0
              : 28,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              mobileSheet ? 22 : 24,
              mobileSheet ? 2 : 22,
              mobileSheet ? 14 : 18,
              mobileSheet ? 14 : 20,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!mobileSheet) ...[
                        const Text(
                          'TODAY TASKS',
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      const Text(
                        '오늘 할 일',
                        style: TextStyle(
                          fontSize: 29,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(48),
                    backgroundColor: mobileSheet ? Colors.white : null,
                  ),
                ),
              ],
            ),
          ),
          if (!mobileSheet) const Divider(height: 1, color: Color(0xFFE4E4E6)),
          Expanded(
            child: tasks.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          color: Colors.black38,
                          size: 42,
                        ),
                        SizedBox(height: 14),
                        Text(
                          '오늘은 예정된 할 일이 없어요',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '바로 학습을 시작해도 좋아요.',
                          style: TextStyle(color: Colors.black45, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _TodayTaskCard(
                      task: tasks[index],
                      onTap: () {
                        Navigator.of(context).pop();
                        onTaskTap(tasks[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TodayTaskCard extends StatelessWidget {
  const _TodayTaskCard({required this.task, required this.onTap});

  final TodayTaskEntry task;
  final VoidCallback onTap;

  /// 필요한 변수는 할 일의 제목·안내 문구·아이콘과 이동 콜백이다.
  /// 작동 원리: 카드 전체를 탭 영역으로 만들어 사용자가 상세보기 단계를 거치지 않고
  /// 지정된 코스·과제·일정으로 이동하게 한다.
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.11),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(task.icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.caption,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black45),
          ],
        ),
      ),
    ),
  );
}
