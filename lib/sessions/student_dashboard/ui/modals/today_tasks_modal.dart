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
    // 작동 원리: 축소된 데스크톱 패널 대신 86% 높이의 단일 열 하단 시트에서
    // 할 일의 우선순위와 목적지를 한 번에 보여 주며, 항목 선택 시 기존 이동
    // 콜백을 그대로 실행한다.
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
        heightFactor: 0.86,
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
  /// 작동 원리: 작은 화면에서는 하나의 세로 목록, PC에서는 넓은 중앙 패널을
  /// 사용하되 각 카드와 일정 버튼은 기존의 목적지 콜백만 호출한다.
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width <= 780;
    final scheduleTask = _scheduleTaskFor(tasks);
    return Container(
      key: mobileSheet
          ? const ValueKey('today-tasks-mobile-sheet')
          : const ValueKey('today-tasks-desktop-dialog'),
      width: mobile
          ? double.infinity
          : (size.width * .72).clamp(640.0, 920.0).toDouble(),
      constraints: BoxConstraints(
        maxHeight: mobileSheet
            ? double.infinity
            : mobile
            ? size.height
            : size.height * .82,
      ),
      decoration: BoxDecoration(
        color: mobileSheet ? const Color(0xFFF4F4F6) : Colors.white,
        borderRadius: BorderRadius.circular(mobileSheet || mobile ? 0 : 28),
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
                      const Text(
                        'TODAY TASKS',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 5),
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
                    side: const BorderSide(color: Color(0xFFDCDCE0)),
                  ),
                ),
              ],
            ),
          ),
          if (!mobileSheet) const Divider(height: 1, color: Color(0xFFE4E4E6)),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 22, 24, 0),
            child: Text(
              '별도 페이지를 열지 않고 홈에서 교사 과제와 개인 일정을 확인합니다.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ),
          const SizedBox(height: 18),
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
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    children: [
                      for (var index = 0; index < tasks.length; index++) ...[
                        _TodayTaskCard(
                          task: tasks[index],
                          emphasized: index == 0,
                          onTap: () {
                            Navigator.of(context).pop();
                            onTaskTap(tasks[index]);
                          },
                        ),
                        if (index < tasks.length - 1)
                          const SizedBox(height: 12),
                      ],
                      if (scheduleTask != null) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onTaskTap(scheduleTask);
                            },
                            child: const Text('일정 달력에서 보기'),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E4E6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayTaskCard extends StatelessWidget {
  const _TodayTaskCard({
    required this.task,
    required this.onTap,
    required this.emphasized,
  });

  final TodayTaskEntry task;
  final VoidCallback onTap;
  final bool emphasized;

  /// 필요한 변수는 할 일의 제목·안내 문구·아이콘과 이동 콜백이다.
  /// 작동 원리: 카드 전체를 탭 영역으로 만들어 사용자가 상세보기 단계를 거치지 않고
  /// 지정된 코스·과제·일정으로 이동하게 한다.
  @override
  Widget build(BuildContext context) => Material(
    color: emphasized ? Colors.black : Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: emphasized ? Colors.black : const Color(0xFFDCDCE0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: emphasized ? Colors.white : const Color(0xFFF4F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDCDCE0)),
              ),
              child: Icon(task.icon, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: emphasized ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: emphasized ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
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

/// 개인 일정 행이 있을 때만 참조 시안의 달력 CTA를 표시한다. 별도 라우트나
/// 가짜 데이터를 만들지 않고, 이미 주입된 목적지 콜백을 그대로 재사용한다.
TodayTaskEntry? _scheduleTaskFor(List<TodayTaskEntry> tasks) {
  for (final task in tasks) {
    if (task.icon == Icons.event_note_rounded) return task;
  }
  return null;
}
