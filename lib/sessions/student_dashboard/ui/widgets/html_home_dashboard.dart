import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/business/repositories/rating_store.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

/// HTML 학생 홈의 정보 구조를 Flutter에서도 동일한 순서와 밀도로 렌더링한다.
///
/// 실제 코스·계정·레이팅 값은 기존 저장소/서버 notifier에서 받고, 값이 없는
/// 경우 샘플 수치를 채우지 않고 빈 상태를 표시한다.
class HtmlHomeDashboard extends StatelessWidget {
  const HtmlHomeDashboard({
    super.key,
    required this.username,
    required this.activeCourse,
    required this.todayTaskCount,
    required this.onResume,
    required this.onBrowseCourses,
    required this.onReview,
    required this.onProblemSets,
    required this.onExams,
    required this.onTextbooks,
    required this.onDashboardAction,
    this.onStudyAction,
  });

  final String? username;
  final Course? activeCourse;
  final int todayTaskCount;
  final VoidCallback onResume;
  final VoidCallback onBrowseCourses;
  final VoidCallback onReview;
  final VoidCallback onProblemSets;
  final VoidCallback onExams;
  final VoidCallback onTextbooks;
  final ValueChanged<String> onDashboardAction;
  final ValueChanged<String>? onStudyAction;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final hero = _HtmlStudyMateHero(
      username: username,
      activeCourse: activeCourse,
    );
    final actions = _HtmlHomeActions(
      onResume: onResume,
      onBrowseCourses: onBrowseCourses,
      onReview: onReview,
      onProblemSets: onProblemSets,
      onExams: onExams,
      onTextbooks: onTextbooks,
      onStudyAction: onStudyAction,
    );
    final top = mobile
        ? Column(children: [hero, const SizedBox(height: 10), actions])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 9, child: hero),
              const SizedBox(width: 12),
              Expanded(flex: 11, child: actions),
            ],
          );

    return Padding(
      key: ValueKey(mobile ? 'student-home-mobile' : 'student-home-desktop'),
      padding: EdgeInsets.fromLTRB(
        mobile ? 10 : 18,
        mobile ? 10 : 18,
        mobile ? 10 : 18,
        48,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          top,
          _HtmlMyDashboard(
            todayTaskCount: todayTaskCount,
            onAction: onDashboardAction,
          ),
        ],
      ),
    );
  }
}

class _HtmlStudyMateHero extends StatefulWidget {
  const _HtmlStudyMateHero({
    required this.username,
    required this.activeCourse,
  });

  final String? username;
  final Course? activeCourse;
  @override
  State<_HtmlStudyMateHero> createState() => _HtmlStudyMateHeroState();
}

class _HtmlStudyMateHeroState extends State<_HtmlStudyMateHero> {
  bool _cheered = false;

  void _requestCheer() {
    if (_cheered) return;
    setState(() => _cheered = true);
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final activeCourse = widget.activeCourse;
    final course = activeCourse?.title.trim();
    final progress = activeCourse?.progress.clamp(0.0, 1.0).toDouble();
    final hasCourse = activeCourse != null;
    final nearFinish = (progress ?? 0) >= .75;
    final moodBadge = !hasCourse
        ? Icons.add
        : nearFinish
        ? Icons.star
        : Icons.menu_book;
    final message = _cheered
        ? '좋아요! 오늘도 할 수 있는 만큼만 같이 해봐요.'
        : !hasCourse
        ? '오늘은 어떤 코스부터 시작해볼까요?'
        : nearFinish
        ? '마지막 구간이에요. 같이 마무리해요.'
        : '오늘도 한 문제씩 같이 풀어봐요.';
    final actionLabel = _cheered ? '응원 받았어요' : '응원 받기';
    return Container(
      key: const ValueKey('home-study-mate-hero'),
      height: mobile ? 168 : 208,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border.all(color: StudentDensityTokens.lineStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: mobile ? 86 : 112,
            child: ColoredBox(
              color: StudentDensityTokens.surfaceMuted,
              child: Center(
                child: Semantics(
                  button: true,
                  label:
                      '${widget.username?.trim().isNotEmpty == true ? '${widget.username!.trim()}님, ' : ''}학습 메이트 응원 받기',
                  child: InkWell(
                    key: const ValueKey('home-study-mate-character'),
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _cheered = !_cheered),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Stack(
                        key: ValueKey(_cheered),
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size.square(mobile ? 56 : 66),
                            painter: _StudyMateFacePainter(cheered: _cheered),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: StudentDensityTokens.dark,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _cheered ? Icons.favorite : moodBadge,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(mobile ? 12 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '오늘의 학습 메이트',
                    style: TextStyle(
                      color: StudentDensityTokens.muted,
                      fontSize: mobile ? 11 : 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: StudentDensityTokens.ink,
                      fontSize: mobile
                          ? 17
                          : (viewportWidth * .018).clamp(18, 23).toDouble(),
                      height: 1.2,
                      letterSpacing: -.4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (hasCourse) ...[
                    const SizedBox(height: 5),
                    Text(
                      '${course ?? '현재 코스'} · ${((progress ?? 0) * 100).round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StudentDensityTokens.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Semantics(
                    key: const ValueKey('home-study-mate-action'),
                    button: true,
                    label: actionLabel,
                    child: InkWell(
                      onTap: _requestCheer,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        color: StudentDensityTokens.dark,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                actionLabel,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyMateFacePainter extends CustomPainter {
  const _StudyMateFacePainter({required this.cheered});

  final bool cheered;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 66;
    canvas.save();
    canvas.scale(scale);
    final dark = Paint()..color = StudentDensityTokens.dark;
    final white = Paint()..color = StudentDensityTokens.surface;
    final line = Paint()
      ..color = StudentDensityTokens.dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final ears = Path()
      ..moveTo(12, 25)
      ..lineTo(18, 5)
      ..lineTo(29, 20)
      ..moveTo(37, 20)
      ..lineTo(48, 5)
      ..lineTo(54, 25);
    canvas.drawPath(ears, dark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 15, 50, 45),
        const Radius.circular(18),
      ),
      dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 21, 38, 31),
        const Radius.circular(14),
      ),
      white,
    );
    canvas.drawCircle(const Offset(26, 34), 2, dark);
    canvas.drawCircle(const Offset(40, 34), 2, dark);
    final smile = Path()
      ..moveTo(27, cheered ? 39 : 41)
      ..quadraticBezierTo(33, cheered ? 51 : 47, 39, cheered ? 39 : 41);
    canvas.drawPath(smile, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StudyMateFacePainter oldDelegate) =>
      oldDelegate.cheered != cheered;
}

class _HtmlHomeActions extends StatelessWidget {
  const _HtmlHomeActions({
    required this.onResume,
    required this.onBrowseCourses,
    required this.onReview,
    required this.onProblemSets,
    required this.onExams,
    required this.onTextbooks,
    this.onStudyAction,
  });

  final VoidCallback onResume;
  final VoidCallback onBrowseCourses;
  final VoidCallback onReview;
  final VoidCallback onProblemSets;
  final VoidCallback onExams;
  final VoidCallback onTextbooks;
  final ValueChanged<String>? onStudyAction;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    void open(String id, VoidCallback fallback) {
      (onStudyAction ?? (_) => fallback())(id);
    }

    final entries =
        <({String id, String label, StudentHtmlIcon icon, VoidCallback onTap})>[
          (
            id: 'resume',
            label: '이어하기',
            icon: StudentHtmlIcon.play,
            onTap: () => open('resume', onResume),
          ),
          (
            id: 'courses',
            label: '코스보기',
            icon: StudentHtmlIcon.courses,
            onTap: () => open('courses', onBrowseCourses),
          ),
          (
            id: 'review',
            label: '복습',
            icon: StudentHtmlIcon.check,
            onTap: () => open('review', onReview),
          ),
          (
            id: 'problemsets',
            label: '문제세트',
            icon: StudentHtmlIcon.spark,
            onTap: () => open('problemsets', onProblemSets),
          ),
          (
            id: 'exams',
            label: '시험지',
            icon: StudentHtmlIcon.calendar,
            onTap: () => open('exams', onExams),
          ),
          (
            id: 'textbooks',
            label: '교재보기',
            icon: StudentHtmlIcon.book,
            onTap: () => open('textbooks', onTextbooks),
          ),
        ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: StudentDensityTokens.line),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: mobile ? 2 : 3,
          mainAxisExtent: mobile ? 72 : 121,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Semantics(
            button: true,
            label: entry.label,
            child: Material(
              color: StudentDensityTokens.surface,
              child: InkWell(
                onTap: entry.onTap,
                child: Padding(
                  padding: EdgeInsets.all(mobile ? 10 : 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Center(
                          child: StudentHtmlGlyph(
                            key: ValueKey('home-action-glyph-${entry.id}'),
                            icon: entry.icon,
                            size: 20,
                            scaleForMobile: false,
                            color: StudentDensityTokens.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          entry.label,
                          style: const TextStyle(
                            color: StudentDensityTokens.ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HtmlMyDashboard extends StatelessWidget {
  const _HtmlMyDashboard({
    required this.todayTaskCount,
    required this.onAction,
  });

  final int todayTaskCount;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<AccountSummary?>(
          valueListenable: ActivityStore.accountSummaryNotifier,
          builder: (context, account, _) {
            return ValueListenableBuilder<RatingSnapshot>(
              valueListenable: RatingStore.notifier,
              builder: (context, rating, _) {
                return ValueListenableBuilder<ActivitySnapshot>(
                  valueListenable: ActivityStore.notifier,
                  builder: (context, activity, _) {
                    final accountCard = _AccountCard(
                      account: account,
                      onTap: () => onAction('level'),
                    );
                    final ovrCard = _OvrCard(
                      rating: rating,
                      onTap: () => onAction('ovr'),
                    );
                    final todayCard = _DashboardCard(
                      key: const ValueKey('html-home-today'),
                      icon: Icons.calendar_today_outlined,
                      title: '오늘 할 일',
                      value: '0 / $todayTaskCount',
                      onTap: () => onAction('today'),
                      spanOnMobile: false,
                    );
                    final streakCard = _StreakCard(
                      days: _activityStreak(activity),
                      onTap: () => onAction('streak'),
                    );
                    final achievementsCard = _DashboardCard(
                      key: const ValueKey('home-achievements-card'),
                      icon: Icons.emoji_events_outlined,
                      title: '업적',
                      value: '데이터 없음',
                      onTap: () => onAction('achievements'),
                      spanOnMobile: true,
                      isAchievement: true,
                    );
                    final weekCard = _WeekCard(
                      activity: activity,
                      onTap: () => onAction('week'),
                    );
                    final weaknessCard = _DashboardCard(
                      icon: Icons.check,
                      title: '약점 태그',
                      value: activity.totalIncorrectCount > 0
                          ? '복습 필요'
                          : '데이터 없음',
                      meta: activity.totalIncorrectCount > 0
                          ? '${activity.totalIncorrectCount}개 오답'
                          : null,
                      onTap: () => onAction('weakness'),
                      spanOnMobile: false,
                    );
                    final arenaCard = _DashboardCard(
                      icon: Icons.emoji_events_outlined,
                      title: '대결 기록',
                      value: '데이터 없음',
                      onTap: () => onAction('arena'),
                      spanOnMobile: false,
                    );
                    return _HtmlDashboardLayout(
                      mobile: mobile,
                      account: accountCard,
                      ovr: ovrCard,
                      today: todayCard,
                      streak: streakCard,
                      achievements: achievementsCard,
                      week: weekCard,
                      weakness: weaknessCard,
                      arena: arenaCard,
                      tutor: _TutorCard(onTap: () => onAction('tutor')),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _HtmlDashboardLayout extends StatelessWidget {
  const _HtmlDashboardLayout({
    required this.mobile,
    required this.account,
    required this.ovr,
    required this.today,
    required this.streak,
    required this.achievements,
    required this.week,
    required this.weakness,
    required this.arena,
    required this.tutor,
  });

  final bool mobile;
  final Widget account;
  final Widget ovr;
  final Widget today;
  final Widget streak;
  final Widget achievements;
  final Widget week;
  final Widget weakness;
  final Widget arena;
  final Widget tutor;

  Widget _row(
    List<Widget> children, {
    required double height,
    List<int>? flexes,
  }) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: mobile ? 8 : 10),
            Expanded(flex: flexes?[i] ?? 1, child: children[i]),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox(height: mobile ? 8 : 10);
    if (mobile) {
      return Container(
        key: const ValueKey('home-dashboard-grid-outline-mobile'),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              account,
              gap,
              ovr,
              gap,
              SizedBox(height: 104, child: _row([today, streak], height: 104)),
              gap,
              SizedBox(height: 84, child: achievements),
              gap,
              SizedBox(height: 132, child: week),
              gap,
              _row([weakness, arena], height: 104),
              gap,
              tutor,
            ],
          ),
        ),
      );
    }
    return Container(
      key: const ValueKey('home-dashboard-grid-outline-desktop'),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 64, child: account),
            gap,
            _row([ovr, today, streak], height: 158, flexes: const [2, 1, 1]),
            gap,
            SizedBox(height: 92, child: achievements),
            gap,
            _row([week, weakness, arena], height: 138),
            gap,
            SizedBox(height: 92, child: tutor),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.onTap});

  final AccountSummary? account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = account;
    return Semantics(
      button: true,
      label: '레벨과 포인트',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: StudentDensityTokens.surfaceMuted,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '레벨',
                          style: TextStyle(
                            color: StudentDensityTokens.muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          summary == null ? '—' : 'Lv. ${summary.level}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        value: summary?.levelProgress,
                        backgroundColor: StudentDensityTokens.surface,
                        valueColor: const AlwaysStoppedAnimation(
                          StudentDensityTokens.dark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: StudentDensityTokens.line),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '포인트',
                      style: TextStyle(
                        color: StudentDensityTokens.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      summary == null ? '—' : '${summary.totalPoints} P',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
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
}

class _OvrCard extends StatelessWidget {
  const _OvrCard({required this.rating, required this.onTap});

  final RatingSnapshot rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final tier = rating.levelity?.tier;
    final tierColor = _levelityAccent(tier);
    return Semantics(
      button: true,
      label: '레벨리티 ${tier ?? '배정 전'}, 최근 학습 지표',
      child: InkWell(
        onTap: onTap,
        child: Container(
          key: const ValueKey('home-dashboard-ovr-card'),
          height: mobile ? 138 : 158,
          padding: const EdgeInsets.all(16),
          color: tier == null ? StudentDensityTokens.dark : tierColor,
          child: Row(
            children: [
              Expanded(
                flex: 36,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '학습 지표',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '레벨리티',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tier ?? (rating.isLoaded ? '배정 전' : '데이터 확인 중'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(flex: 64, child: _RatingSignal(rating: rating)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingSignal extends StatelessWidget {
  const _RatingSignal({required this.rating});

  final RatingSnapshot rating;

  @override
  Widget build(BuildContext context) {
    final accuracy = rating.recentAccuracy <= 1
        ? rating.recentAccuracy
        : rating.recentAccuracy / 100;
    final normalized = accuracy.clamp(0.0, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '최근 정답률',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          rating.isLoaded ? '${(normalized * 100).round()}%' : '—',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: rating.isLoaded ? normalized : null,
          minHeight: 5,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation(Colors.white),
        ),
      ],
    );
  }
}

Color _levelityAccent(String? tier) => switch (tier) {
  'Cheer Up' => const Color(0xFF355E47),
  'Plain 0' => const Color(0xFF59616B),
  'Plain+' => const Color(0xFF96512A),
  'Insane 0' => const Color(0xFF986315),
  'Insane+' => const Color(0xFF4F5C18),
  'Powerful 0' => const Color(0xFF00675D),
  'Powerful+' => const Color(0xFF173D85),
  'Prime 0' => const Color(0xFF7D3357),
  'Prime+' => const Color(0xFF141414),
  _ => StudentDensityTokens.dark,
};

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.days, required this.onTap});

  final int days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      leading: const Text('🔥', style: TextStyle(fontSize: 20)),
      title: '연속 학습',
      value: days > 0 ? '$days일' : '데이터 없음',
      onTap: onTap,
      spanOnMobile: false,
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.activity, required this.onTap});

  final ActivitySnapshot activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = activity.days.values.where((day) => day.score > 0).length;
    return Semantics(
      button: true,
      label: '이번 주 학습',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.all(14),
          color: StudentDensityTokens.surface,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.show_chart, size: 18),
                        SizedBox(width: 7),
                        Text(
                          '이번 주 학습',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$days일 학습',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 124, child: _WeekBars(activity: activity)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.activity});

  final ActivitySnapshot activity;

  @override
  Widget build(BuildContext context) {
    final scores = activity
        .sortedDays(limit: 7)
        .map((day) => day.score)
        .toList();
    final maxScore = scores.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final score = index < scores.length ? scores[index] : 0;
          final height = maxScore == 0
              ? 4.0
              : (score / maxScore * 52).clamp(4.0, 52.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: height,
                  color: StudentDensityTokens.dark,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TutorCard extends StatelessWidget {
  const _TutorCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final copy = Row(
      children: [
        const Expanded(
          flex: 40,
          child: Row(
            children: [
              StudentHtmlGlyph(
                icon: StudentHtmlIcon.spark,
                color: StudentDensityTokens.muted,
                size: 20,
              ),
              SizedBox(width: 7),
              Text(
                'AI 튜터',
                style: TextStyle(
                  color: StudentDensityTokens.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          flex: 60,
          child: Text(
            '궁금한 풀이를 바로 물어보세요.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
    final action = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: StudentDensityTokens.dark,
      child: Row(
        mainAxisAlignment: mobile
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.start,
        mainAxisSize: mobile ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const Text(
            '대화하기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 9),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: 'AI 튜터에게 묻기',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: mobile ? 96 : 92),
          padding: const EdgeInsets.all(14),
          color: StudentDensityTokens.surface,
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [copy, const SizedBox(height: 8), action],
                )
              : Row(
                  children: [
                    Expanded(child: copy),
                    action,
                  ],
                ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    super.key,
    this.icon,
    this.leading,
    this.isAchievement = false,
    required this.title,
    required this.value,
    required this.onTap,
    required this.spanOnMobile,
    this.meta,
  });

  final IconData? icon;
  final Widget? leading;
  final bool isAchievement;
  final String title;
  final String value;
  final String? meta;
  final VoidCallback onTap;
  final bool spanOnMobile;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title $value',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(13),
          color: StudentDensityTokens.surface,
          child: isAchievement
              ? Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Row(
                        children: [
                          if (icon != null) Icon(icon, size: 18),
                          const SizedBox(width: 7),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 9,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: StudentDensityTokens.ink,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Transform.rotate(
                            angle: math.pi / 4,
                            child: Container(
                              width: 20,
                              height: 20,
                              color: StudentDensityTokens.ink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ClipPath(
                            clipper: const _AchievementHexagonClipper(),
                            child: Container(
                              width: 24,
                              height: 24,
                              color: StudentDensityTokens.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            leading ??
                                (icon == null
                                    ? const SizedBox.shrink()
                                    : Icon(icon, size: 18)),
                            if (icon != null || leading != null)
                              const SizedBox(width: 7),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (meta != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            meta!,
                            style: const TextStyle(
                              color: StudentDensityTokens.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AchievementHexagonClipper extends CustomClipper<Path> {
  const _AchievementHexagonClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * .25, size.height * .07)
      ..lineTo(size.width * .75, size.height * .07)
      ..lineTo(size.width, size.height * .5)
      ..lineTo(size.width * .75, size.height * .93)
      ..lineTo(size.width * .25, size.height * .93)
      ..lineTo(0, size.height * .5)
      ..close();
  }

  @override
  bool shouldReclip(covariant _AchievementHexagonClipper oldClipper) => false;
}

int _activityStreak(ActivitySnapshot snapshot) {
  var day = DateTime.now();
  var streak = 0;
  while (true) {
    final key =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final record = snapshot.days[key];
    if (record == null || record.score <= 0) break;
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}
