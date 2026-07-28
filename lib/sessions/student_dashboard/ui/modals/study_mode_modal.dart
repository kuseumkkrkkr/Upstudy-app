import 'package:flutter/material.dart';
import 'package:s11/sessions/course/ui/modals/course_mode.dart';
import 'package:s11/sessions/course/ui/modals/resume_mode.dart';
import 'package:s11/sessions/textbook/ui/modals/book_mode.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/owned_marketplace_modal.dart';
import 'package:s11/features/wrong_answer/wrong_answer.dart';
import 'package:s11/shared/ui/ios26/ios26_modal.dart';

/// 필요한 변수는 학생 홈 context다.
/// 작동 원리는 학습 메뉴와 보유 세트 메뉴를 한 번에 하나씩 열고, 보유 세트에서
/// 뒤로가면 학습 메뉴를 다시 열어 겹친 다이얼로그와 불필요한 라우트 누적을 막는 것이다.
Future<T?> showStudyModeModal<T>({required BuildContext context}) async {
  while (context.mounted) {
    final destination = await showIos26Modal<_ModeDestination>(
      context: context,
      maxWidth: 980,
      maxHeight: 490,
      mobileFullScreen: true,
      child: const StudypageCopyWidget(),
    );
    if (!context.mounted) return null;

    final kind = switch (destination) {
      _ModeDestination.ownedProblemSet => 'problem_set',
      _ModeDestination.ownedExam => 'exam',
      _ => null,
    };
    if (kind == null) return null;

    final result = await showOwnedMarketplaceModal(
      context: context,
      kind: kind,
    );
    if (!context.mounted || result == OwnedMarketplaceModalResult.itemOpened) {
      return null;
    }
  }
  return null;
}

class StudypageCopyWidget extends StatelessWidget {
  const StudypageCopyWidget({super.key});

  /// 필요한 변수는 화면 너비, 여섯 학습 모드와 현재 Navigator다.
  /// 작동 원리는 세로 화면에서는 한 줄 목록, 가로 화면에서는 3열 카드로 시안의 정보 밀도를 맞추고 문제세트·시험지는 마켓 탐색으로 연결하는 것이다.
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 780;
    if (mobile) {
      return _buildMobilePanel(context);
    }
    return SizedBox(
      width: 980,
      height: 490,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: const Color(0xFFF9F9FA),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 18, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STUDY MODE',
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '학습하기',
                            style: TextStyle(
                              fontSize: 30,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 38, 24, 20),
                child: const Text(
                  '기존 앱과 동일하게 학습 유형을 먼저 고른 뒤 해당 전체 화면으로 이동합니다.',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.9,
                  ),
                  itemCount: _kModes.length,
                  itemBuilder: (context, index) =>
                      _buildModeCard(context, _kModes[index]),
                ),
              ),
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
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 모바일 화면 context와 여섯 학습 모드다.
  /// 작동 원리는 순백 바탕에 순흑 정보만 사용하고, 중복 하단 닫기를 제거한 압축 목록으로 모든 메뉴를 한 화면에서 빠르게 선택하게 하는 것이다.
  Widget _buildMobilePanel(BuildContext context) {
    return Material(
      key: const ValueKey('study-mode-mobile-surface'),
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 18, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '학습하기',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 38,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.8,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: IconButton(
                      key: const ValueKey('study-mode-mobile-close'),
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black,
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 30),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 2, thickness: 2, color: Colors.black),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Text(
                '무엇을 학습할까요?',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                key: const ValueKey('study-mode-mobile-list'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _kModes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _MobileModeCard(
                  key: ValueKey('study-mode-mobile-${_kModes[index].label}'),
                  mode: _kModes[index],
                  onTap: _actionFor(context, _kModes[index].destination),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 화면 문맥과 선택할 학습 모드다.
  /// 작동 원리는 모드 데이터와 이동 콜백을 하나의 카드로 조합해 가로·세로 배치에서 같은 동작을 보장하는 것이다.
  Widget _buildModeCard(BuildContext context, _StudyMode mode) {
    return _ModeCard(
      icon: mode.icon,
      label: mode.label,
      description: mode.description,
      onTap: _actionFor(context, mode.destination),
    );
  }

  /// 필요한 변수는 화면 context와 학습 목적지다.
  /// 작동 원리는 시각 행과 기존 코스·복습·마켓·교재 기능 사이의 콜백을 한곳에서 결정하는 것이다.
  VoidCallback? _actionFor(BuildContext context, _ModeDestination destination) {
    return switch (destination) {
      _ModeDestination.resume => buildResumeAction(context),
      _ModeDestination.course => buildCourseAction(context),
      _ModeDestination.ownedProblemSet || _ModeDestination.ownedExam => () {
        Navigator.of(context).pop(destination);
      },
      _ModeDestination.book => buildBookAction(context),
      _ModeDestination.weaknessReview => () => showWrongAnswerReviewPreview(
        context: context,
      ),
      _ModeDestination.none => null,
    };
  }
}

const _kModes = [
  _StudyMode(
    icon: Icons.restart_alt_sharp,
    label: '이어하기',
    description: '마지막 학습 위치',
    destination: _ModeDestination.resume,
  ),
  _StudyMode(
    icon: Icons.crop_din_outlined,
    label: '코스보기',
    description: '코스 탐색과 상세',
    destination: _ModeDestination.course,
  ),
  _StudyMode(
    icon: Icons.done_outline,
    label: '복습',
    description: '오답과 약점 태그',
    destination: _ModeDestination.weaknessReview,
  ),
  _StudyMode(
    icon: Icons.inventory_2_outlined,
    label: '문제세트',
    description: '보유 문제세트 이어풀기',
    destination: _ModeDestination.ownedProblemSet,
  ),
  _StudyMode(
    icon: Icons.assignment_outlined,
    label: '시험지',
    description: '보유 시험지 이어풀기',
    destination: _ModeDestination.ownedExam,
  ),
  _StudyMode(
    icon: Icons.menu_book_outlined,
    label: '교재보기',
    description: '책가방에서 교재 선택',
    destination: _ModeDestination.book,
  ),
];

enum _ModeDestination {
  none,
  resume,
  course,
  weaknessReview,
  ownedProblemSet,
  ownedExam,
  book,
}

class _StudyMode {
  const _StudyMode({
    required this.icon,
    required this.label,
    required this.description,
    this.destination = _ModeDestination.none,
  });

  final IconData icon;
  final String label;
  final String description;
  final _ModeDestination destination;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.label,
    required this.description,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback? onTap;

  /// 필요한 변수는 모드 아이콘·이름·설명·선택 콜백이다.
  /// 작동 원리는 가로 화면의 그리드와 세로 화면의 목록에서 공용 카드 규격을 사용해 시안의 버튼 모양을 유지하는 것이다.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE0E0E3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _MobileModeCard extends StatelessWidget {
  const _MobileModeCard({super.key, required this.mode, required this.onTap});

  final _StudyMode mode;
  final VoidCallback? onTap;

  /// 필요한 변수는 학습 모드 정보와 선택 콜백이다.
  /// 작동 원리는 52px 아이콘과 20px 제목을 순백·순흑 카드에 배치하고, 82px 이상의 터치 높이로 작은 모바일 화면에서도 오선택을 줄이는 것이다.
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Colors.black, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 82),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(mode.icon, size: 27, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.label,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        mode.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          height: 1.1,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 28,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
