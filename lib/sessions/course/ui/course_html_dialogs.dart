import 'package:flutter/material.dart';

import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/services/api/course_service.dart';

/// 필요한 변수는 현재 수강 중 코스와 저장 후 갱신 콜백이다.
/// 작동 원리는 HTML 순서 편집 모달에서 드래그 순서를 바꾸고 저장 시 서버 등록 순서를 한 번 갱신한다.
Future<void> showCourseReorderDialog(
  BuildContext context, {
  required List<Course> courses,
  required VoidCallback onSaved,
}) async {
  final reordered = List<Course>.from(courses);
  final saved = await _showCourseActionPanel<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setModalState) => _CourseActionDialog(
        kicker: 'MY COURSE ORDER',
        title: '수강 순서 편집',
        description: '홈과 코스 화면에 표시할 수강 중 코스 순서를 변경합니다.',
        body: SizedBox(
          height: 330,
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: reordered.length,
            onReorderItem: (oldIndex, newIndex) {
              setModalState(() {
                final course = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, course);
              });
            },
            itemBuilder: (context, index) {
              final course = reordered[index];
              return Container(
                key: ValueKey(course.id),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F8),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: ListTile(
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_indicator_rounded),
                  ),
                  title: Text(
                    course.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text('진행률 ${(course.progress * 100).round()}%'),
                  trailing: Text('${index + 1}'.padLeft(2, '0')),
                ),
              );
            },
          ),
        ),
        primaryLabel: '순서 저장',
        onPrimary: () async {
          await CourseService.reorderEnrollments(
            reordered.map((course) => course.id).toList(growable: false),
          );
          if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
        },
      ),
    ),
  );
  if (saved == true) onSaved();
}

/// 필요한 변수는 비교할 추천 코스 목록이다.
/// 작동 원리는 추천 점수 상위 두 코스의 OVR 범위·모듈·기간·진행률을 같은 폭 카드로 비교한다.
Future<void> showCourseCompareDialog(
  BuildContext context, {
  required List<Course> courses,
}) {
  final visible = courses.take(2).toList(growable: false);
  return _showCourseActionPanel<void>(
    context: context,
    builder: (context) => _CourseActionDialog(
      kicker: 'COMPARE COURSES',
      title: '추천 코스 비교',
      description: '추천 점수가 높은 두 코스의 목표와 학습 구성을 비교합니다.',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cards = [
            for (var index = 0; index < visible.length; index++)
              _CourseCompareCard(course: visible[index], score: 91 - index * 7),
          ];
          if (constraints.maxWidth < 540) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final card in cards) ...[card, const SizedBox(height: 9)],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                Expanded(child: cards[index]),
                if (index < cards.length - 1) const SizedBox(width: 10),
              ],
            ],
          );
        },
      ),
    ),
  );
}

/// 필요한 변수는 현재 화면 context다.
/// 작동 원리는 교재 런타임의 최소 시간·하트비트·완료 후 갱신 정책을 HTML 세 단계 목록으로 보여준다.
Future<void> showCoursePolicyDialog(BuildContext context) {
  return _showCourseActionPanel<void>(
    context: context,
    builder: (context) => const _CourseActionDialog(
      kicker: 'RUNTIME POLICY',
      title: '학습 완료 조건',
      description: '현재 미션을 완료하고 다음 학습이 열리는 조건입니다.',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PolicyRow(
            number: '01',
            title: '최소 학습 시간',
            detail: '교재 화면에서 실제로 학습한 시간이 8분 이상이어야 합니다.',
            meta: '08:00',
          ),
          _PolicyRow(
            number: '02',
            title: '진행 시간 보존',
            detail: '학습 중 현재 위치와 체류 시간을 주기적으로 보존합니다.',
            meta: '60s',
          ),
          _PolicyRow(
            number: '03',
            title: '완료 후 다음 모듈',
            detail: '결과 제출 성공 후 코스를 다시 불러오고 다음 미션을 엽니다.',
            meta: 'NEXT',
          ),
        ],
      ),
    ),
  );
}

/// 필요한 변수는 현재 Navigator 문맥과 코스 액션 본문 빌더다.
/// 작동 원리: PC는 오른쪽 720px, 모바일은 전체 화면으로 HTML 액션 패널을 슬라이드 표시한다.
Future<T?> _showCourseActionPanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: Colors.black.withValues(alpha: .3),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final width = MediaQuery.sizeOf(context).width;
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: width <= 780 ? width : 720,
          height: double.infinity,
          child: builder(context),
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

class _CourseActionDialog extends StatelessWidget {
  const _CourseActionDialog({
    required this.kicker,
    required this.title,
    required this.description,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
  });

  final String kicker;
  final String title;
  final String description;
  final Widget body;
  final String? primaryLabel;
  final Future<void> Function()? onPrimary;

  /// 필요한 변수는 모달 제목·설명·본문·선택 저장 동작이다.
  /// 작동 원리는 코스 관련 HTML 액션이 같은 여백과 흑백 버튼을 공유하도록 전면 모달 틀을 제공한다.
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFAFAFB),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 18, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E4E6)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    description,
                    style: const TextStyle(color: Colors.black45),
                  ),
                  const SizedBox(height: 22),
                  body,
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E4E6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(onPrimary == null ? '닫기' : '취소'),
                ),
                if (onPrimary != null) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF202022),
                    ),
                    onPressed: () => onPrimary!(),
                    child: Text(primaryLabel ?? '저장'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CourseCompareCard extends StatelessWidget {
  const _CourseCompareCard({required this.course, required this.score});
  final Course course;
  final int score;

  /// 필요한 변수는 코스와 추천 점수다.
  /// 작동 원리는 HTML 비교 카드에 코스 제목·레벨·모듈·기간·진행률을 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F6F8),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MATCH $score%',
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.3,
            color: Colors.black54,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          course.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 13),
        Text(
          '목표 ${course.level} · ${course.units.length}강 · ${course.duration}',
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: course.progress.clamp(0, 1),
          minHeight: 6,
          color: const Color(0xFF202022),
          backgroundColor: const Color(0xFFDDDEE2),
        ),
      ],
    ),
  );
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.number,
    required this.title,
    required this.detail,
    required this.meta,
  });
  final String number;
  final String title;
  final String detail;
  final String meta;

  /// 필요한 변수는 단계 번호·제목·설명·정책 값이다.
  /// 작동 원리는 정책 단계를 한 줄 카드로 표현한다.
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F6F8),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF202022),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(number, style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                detail,
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(meta, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}
