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

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final hero = _HtmlHomeHero(
      username: username,
      activeCourse: activeCourse,
      onResume: onResume,
    );
    final actions = _HtmlHomeActions(
      onResume: onResume,
      onBrowseCourses: onBrowseCourses,
      onReview: onReview,
      onProblemSets: onProblemSets,
      onExams: onExams,
      onTextbooks: onTextbooks,
    );
    final top = mobile
        ? Column(children: [hero, const SizedBox(height: 10), actions])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: hero),
              const SizedBox(width: 12),
              Expanded(flex: 11, child: actions),
            ],
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(10, mobile ? 10 : 20, 10, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          top,
          const SizedBox(height: 10),
          _HtmlMyDashboard(
            todayTaskCount: todayTaskCount,
            onAction: onDashboardAction,
          ),
        ],
      ),
    );
  }
}

class _HtmlHomeHero extends StatelessWidget {
  const _HtmlHomeHero({
    required this.username,
    required this.activeCourse,
    required this.onResume,
  });

  final String? username;
  final Course? activeCourse;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final name = username?.trim().isNotEmpty == true ? username!.trim() : '사용자';
    final course = activeCourse?.title.trim();
    final progress = activeCourse == null
        ? null
        : activeCourse!.progress.clamp(0.0, 1.0).toDouble();
    return Container(
      height: mobile ? 198 : 244,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border.all(color: StudentDensityTokens.lineStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: mobile ? 58 : 84,
            child: ColoredBox(
              color: StudentDensityTokens.dark,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: mobile ? 17 : 24),
                  child: Text(
                    'A',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: mobile ? 18 : 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(mobile ? 16 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        '$name님,\n다시 만나 반가워요.',
                        style: TextStyle(
                          color: StudentDensityTokens.ink,
                          fontSize: mobile ? 27 : 38,
                          height: 1.08,
                          letterSpacing: -1.4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          course ?? '현재 코스 없음',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: StudentDensityTokens.ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        progress == null ? '—' : '${(progress * 100).round()}%',
                        style: const TextStyle(
                          color: StudentDensityTokens.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    child: SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: StudentDensityTokens.surfaceMuted,
                        valueColor: const AlwaysStoppedAnimation(
                          StudentDensityTokens.dark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    button: true,
                    label: '이어 학습하기',
                    child: InkWell(
                      onTap: onResume,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 50),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        color: StudentDensityTokens.dark,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '이어 학습하기',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 18,
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

class _HtmlHomeActions extends StatelessWidget {
  const _HtmlHomeActions({
    required this.onResume,
    required this.onBrowseCourses,
    required this.onReview,
    required this.onProblemSets,
    required this.onExams,
    required this.onTextbooks,
  });

  final VoidCallback onResume;
  final VoidCallback onBrowseCourses;
  final VoidCallback onReview;
  final VoidCallback onProblemSets;
  final VoidCallback onExams;
  final VoidCallback onTextbooks;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final entries = <({String label, IconData icon, VoidCallback onTap})>[
      (label: '이어하기', icon: Icons.play_arrow_outlined, onTap: onResume),
      (label: '코스보기', icon: Icons.view_list_outlined, onTap: onBrowseCourses),
      (label: '복습', icon: Icons.check, onTap: onReview),
      (label: '문제세트', icon: Icons.auto_awesome_outlined, onTap: onProblemSets),
      (label: '시험지', icon: Icons.calendar_today_outlined, onTap: onExams),
      (label: '교재보기', icon: Icons.menu_book_outlined, onTap: onTextbooks),
    ];
    return GridView.builder(
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
                      child: Icon(
                        entry.icon,
                        size: 19,
                        color: StudentDensityTokens.ink,
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
                    const Icon(
                      Icons.arrow_forward,
                      size: 15,
                      color: StudentDensityTokens.ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
        Container(
          constraints: const BoxConstraints(minHeight: 42),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: StudentDensityTokens.lineStrong),
            ),
          ),
          child: const Text(
            '마이 대시보드',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 8),
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
                      icon: Icons.emoji_events_outlined,
                      title: '업적',
                      value: '데이터 없음',
                      onTap: () => onAction('achievements'),
                      spanOnMobile: true,
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

  Widget _row(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gap = const SizedBox(height: 8);
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          account,
          gap,
          ovr,
          gap,
          _row([today, streak]),
          gap,
          achievements,
          gap,
          week,
          gap,
          _row([weakness, arena]),
          gap,
          tutor,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        account,
        gap,
        _row([ovr, today, streak]),
        gap,
        achievements,
        gap,
        _row([week, weakness, arena]),
        gap,
        tutor,
      ],
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
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 16),
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
    final value = rating.isLoaded ? rating.ovr.toStringAsFixed(1) : '—';
    return Semantics(
      button: true,
      label: '내 오버롤 $value',
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: isStudentDensityMobile(context) ? 138 : 158,
          padding: const EdgeInsets.all(16),
          color: StudentDensityTokens.dark,
          child: Row(
            children: [
              SizedBox(
                width: 84,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'MY OVR',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _OvrPainter(),
                  child: const SizedBox.expand(),
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

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
              const Icon(Icons.arrow_forward, size: 16),
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
    return Semantics(
      button: true,
      label: 'AI 튜터',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(14),
          color: StudentDensityTokens.surface,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'AI 튜터',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
              const Expanded(
                child: Text(
                  '궁금한 풀이를 바로 물어보세요.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                color: StudentDensityTokens.dark,
                child: const Row(
                  children: [
                    Text(
                      '대화하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 9),
                    Icon(Icons.arrow_forward, color: Colors.white, size: 15),
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

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    required this.value,
    required this.onTap,
    required this.spanOnMobile,
    this.meta,
  });

  final IconData? icon;
  final Widget? leading;
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
          child: Stack(
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
              const Positioned(
                right: 0,
                top: 0,
                child: Icon(Icons.arrow_forward, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

class _OvrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final points = <Offset>[
      Offset(0, size.height * .78),
      Offset(size.width * .16, size.height * .68),
      Offset(size.width * .32, size.height * .72),
      Offset(size.width * .48, size.height * .45),
      Offset(size.width * .64, size.height * .57),
      Offset(size.width * .8, size.height * .2),
      Offset(size.width, size.height * .28),
    ];
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
