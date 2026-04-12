import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'docx_box.dart' as docx;
import 'friend.dart';
import 'study_center.dart' as study_center;
import 'widgets/app_drawer.dart';
import 'widgets/modals/curriculum_modal.dart';
import 'widgets/modals/daily_test_modal.dart';
import 'widgets/modals/rating_detail_modal.dart';
import 'widgets/modals/social_modal.dart';
import 'widgets/modals/study_mode_modal.dart';
import 'widgets/modals/today_tasks_modal.dart';
import 'pages/learning_tools/notepad_page.dart';
import 'pages/learning_tools/timer_page.dart';
import 'pages/learning_tools/focus_mode_page.dart';
import 'pages/learning_tools/server_chat_page.dart';
import 'widgets/learning_tools/learning_tools_strip.dart';
import 'services/activity_store.dart';
import 'services/attendance_store.dart';
import 'services/rating_store.dart';
import 'services/social_notification_store.dart';
import '../models/course.dart';
import 'pages/course_pages.dart';

const _green = Color(0xFF1B402B);
const _lightGreen = Color(0xFF45BF63);
const _headerGreen = Color(0xFF22593A);
const _grey = Color(0xFFC9C9C9);
const _bgGrey = Color(0xFFF7F7F7);
const List<Color> _activityTileColors = [
  Color(0xFFE6E6E6),
  Color(0xFFBEE7C8),
  Color(0xFF7ED39A),
  Color(0xFF4CBD72),
  Color(0xFF2E9853),
  Color(0xFF1C6D3B),
];
const int _problemSolveTarget = 50;
const _shadow = BoxShadow(
  blurRadius: 4,
  color: Color(0x33000000),
  offset: Offset(0, 2),
);

const double _ratingFloor = 1200;
const double _ratingDisplayMax = 32767;
const double _ratingOvrDivider = 128;

double _ratingDisplay(double rating) {
  return (math.max(rating, _ratingFloor) - _ratingFloor)
      .clamp(0, _ratingDisplayMax)
      .toDouble();
}

double _ratingOvr(double rating) {
  return _ratingDisplay(rating) / _ratingOvrDivider;
}

String _formatRatingOvr(double rating) {
  return _ratingOvr(rating).toStringAsFixed(1);
}

TextStyle _ts({
  double size = 16,
  FontWeight weight = FontWeight.normal,
  Color color = Colors.black,
  bool scaleUp = true,
}) => TextStyle(
  fontSize: size * (scaleUp ? 1.1 : 1.0),
  fontWeight: weight,
  color: color,
);

BoxDecoration _cardDeco({double radius = 36}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: const [_shadow],
);

double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
  final width = MediaQuery.of(context).size.width;
  final scale = width / 1100;
  if (scale < min) return min;
  if (scale > max) return max;
  return scale;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _formatTasksSummary(List<String> tasks) {
  if (tasks.isEmpty) return '등록된 일정이 없습니다.';
  if (tasks.length == 1) return tasks.first;
  if (tasks.length == 2) return '${tasks[0]}\n${tasks[1]}';
  return '${tasks[0]}\n${tasks[1]} 외 ${tasks.length - 2}개';
}

String _formatSocialNotice(SocialNotificationSnapshot snapshot) {
  final total = snapshot.unreadMessages + snapshot.friendRequests + snapshot.friendRemovals;
  if (total <= 0) return '알림 없음';
  return '놓친 알림 ${total}개';
}

String _formatDateLabel(String dateKey) {
  final parts = dateKey.split('-');
  if (parts.length == 3) {
    return '${parts[1]}.${parts[2]}';
  }
  return dateKey;
}

class MainStudentPage extends StatefulWidget {
  const MainStudentPage({super.key, this.username});

  final String? username;

  @override
  State<MainStudentPage> createState() => _MainStudentPageState();
}

class _MainStudentPageState extends State<MainStudentPage> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  Map<DateTime, List<String>> _tasksByDate = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    unawaited(ActivityStore.load().catchError((_) => ActivitySnapshot.empty()));
    unawaited(
      AttendanceStore.ensureDailyAttendance().catchError(
        (_) => AttendanceSnapshot.empty(),
      ),
    );
    unawaited(RatingStore.refresh());
  }

  void _handleScroll() {
    final offset = _scrollController.offset;
    if (offset == _scrollOffset) return;
    setState(() => _scrollOffset = offset);
  }

  void _handleTasksChanged(Map<DateTime, List<String>> updated) {
    setState(() {
      _tasksByDate = {
        for (final entry in updated.entries)
          _dateOnly(entry.key): List<String>.from(entry.value),
      };
    });
  }

  Future<void> _handleCourseTap() async {
    final selected = await showCurriculumModal(context: context);
    if (!mounted || selected == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CourseDetailPage(course: selected)),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final media = MediaQuery.of(context);
    final safeHeight =
        media.size.height - media.padding.top - media.padding.bottom;
    final headerHeight = 72 * scale;
    final heroHeight = math.max(360 * scale, safeHeight - headerHeight);
    final fadeDistance = heroHeight;
    final heroOpacity = fadeDistance <= 0
        ? 1.0
        : (1 - (_scrollOffset / fadeDistance)).clamp(0.0, 1.0) as double;
    final today = _dateOnly(DateTime.now());
    final todayTasks = _tasksByDate[today] ?? const <String>[];
    final activeCourse = kSampleCourses.isNotEmpty
        ? kSampleCourses.first
        : null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        drawer: const AppDrawer(),
        body: SafeArea(
          child: Column(
            children: [
              _Header(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: _HeroScrollPhysics(
                    heroExtent: heroHeight,
                    multiplier: 4.4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroSection(
                        username: widget.username,
                        height: heroHeight,
                        opacity: heroOpacity,
                        onScrollDown: () {
                          final target = math.min(
                            heroHeight,
                            _scrollController.position.maxScrollExtent,
                          );
                          _scrollController.animateTo(
                            target,
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                      _LearningSection(
                        todayTasks: todayTasks,
                        activeCourse: activeCourse,
                        onCourseTap: _handleCourseTap,
                        onTodayTasksTap: () {
                          showTodayTasksModal(
                            context: context,
                            tasksByDate: _tasksByDate,
                            onTasksChanged: _handleTasksChanged,
                          );
                        },
                      ),
                      _BottomSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);

    return Container(
      height: 72 * scale,
      color: Colors.white,
      child: Row(
        children: [
          SizedBox(width: 16 * scale),

          IconButton(
            iconSize: 28 * scale,
            icon: const Icon(Icons.menu_outlined, color: _green),
            onPressed: () => toggleAppDrawer(context),
          ),

          // 메뉴 버튼과 로고 기본 간격
          SizedBox(width: 12 * scale),

          // 브랜드 여백
          SizedBox(width: 12 * scale),

          Text(
            'AIFlow',
            style: _ts(
              size: 36 * scale,
              weight: FontWeight.bold,
              color: _green,
              scaleUp: false,
            ),
          ),

          // 브랜드 뒤 여백
          SizedBox(width: 120 * scale),

          Expanded(
            child: Container(
              color: _headerGreen,
              height: 72 * scale,
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in [
                      _NavItemData(
                        '학습터',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const study_center.SoWidget(),
                            ),
                          );
                        },
                      ),
                      _NavItemData(
                        '문서함',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const docx.BookWidget(),
                            ),
                          );
                        },
                      ),
                      _NavItemData(
                        '친구/소셜',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SoWidget()),
                          );
                        },
                      ),
                      const _NavItemData('마켓플레이스'),
                    ])
                      Padding(
                        padding: EdgeInsets.only(
                          right: item.label == '마켓플레이스' ? 24 * scale : 0,
                        ),
                        child: _NavItem(
                          label: item.label,
                          fontSize: 16 * scale,
                          onTap: item.onTap,
                        ),
                      ),
                    SizedBox(width: 16 * scale),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData(this.label, {this.onTap});
  final String label;
  final VoidCallback? onTap;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.fontSize, this.onTap});
  final String label;
  final double fontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: _ts(size: fontSize, color: Colors.white, scaleUp: false),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.username,
    required this.height,
    required this.opacity,
    required this.onScrollDown,
  });
  final String? username;
  final double height;
  final double opacity;
  final VoidCallback onScrollDown;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final name = username?.trim();
    final displayName = (name == null || name.isEmpty) ? '사용자' : name;
    final baseHeroHeight = 360 * scale;
    final contentScale = (height / baseHeroHeight).clamp(1.1, 1.35) as double;
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1495465798138-718f86d1a4bc?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwxMHx8c3R1ZHl8ZW58MHx8fHwxNzcwNDE0OTExfDA&ixlib=rb-4.1.0&q=80&w=1080',
              fit: BoxFit.cover,
            ),
            Container(color: const Color(0xAA000000)),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: contentScale,
                  child: StatPager(displayName: displayName),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 16 * scale),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onScrollDown,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                    size: 36 * scale,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroScrollPhysics extends ScrollPhysics {
  const _HeroScrollPhysics({
    required this.heroExtent,
    this.multiplier = 1.6,
    ScrollPhysics? parent,
  }) : super(parent: parent);

  final double heroExtent;
  final double multiplier;

  @override
  _HeroScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _HeroScrollPhysics(
      heroExtent: heroExtent,
      multiplier: multiplier,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final base = parent?.applyPhysicsToUserOffset(position, offset) ?? offset;
    if (position.pixels < heroExtent) {
      return base * multiplier;
    }
    return base;
  }
}

class StatPager extends StatefulWidget {
  const StatPager({super.key, required this.displayName});
  final String displayName;

  @override
  State<StatPager> createState() => _StatPagerState();
}

class _StatPagerState extends State<StatPager> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _prev() {
    if (_page > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _next() {
    if (_page < 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildIndicator(double scale) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(2, (i) {
        final isActive = i == _page;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 6 * scale),
          width: isActive ? 18 * scale : 8 * scale,
          height: 8 * scale,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isActive
                ? const Color(0xFF27B24B)
                : Colors.black.withOpacity(0.35),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final pagerHeight = 260 * scale;
    final pagerWidth = 360 * scale;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _prev,
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 26 * scale,
          ),
        ),
        SizedBox(
          width: pagerWidth,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: pagerWidth,
                height: pagerHeight,
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _StatPage1(displayName: widget.displayName),
                    _StatPage2(displayName: widget.displayName),
                  ],
                ),
              ),
              SizedBox(height: 12 * scale),
              _buildIndicator(scale),
            ],
          ),
        ),
        IconButton(
          onPressed: _next,
          icon: Icon(
            Icons.arrow_forward_ios,
            color: Colors.white,
            size: 26 * scale,
          ),
        ),
      ],
    );
  }
}

class _StatPage1 extends StatelessWidget {
  const _StatPage1({required this.displayName});
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);

    return Column(
      children: [
        const Spacer(),

        // 상단 인사 및 활동 요약 영역
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '안녕하세요, $displayName님',
              style: _ts(
                size: 36 * scale,
                color: Colors.white,
                weight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12 * scale),
            ValueListenableBuilder<ActivitySnapshot>(
              valueListenable: ActivityStore.notifier,
              builder: (context, snapshot, _) {
                final recent = ActivityStore.recentDays(snapshot, 7);
                final todayScore = recent.isNotEmpty ? recent.last.score : 0;
                final percent = ActivityStore.activityPercentFromScore(
                  todayScore,
                );
                final percentText = '${(percent * 100).round()}%';
                final scores = recent.map((e) => e.score).toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '오늘의 활동률',
                          style: _ts(size: 12 * scale, color: _grey),
                        ),
                        SizedBox(width: 8 * scale),
                        Text(
                          percentText,
                          style: _ts(size: 20 * scale, color: _grey),
                        ),
                      ],
                    ),
                    SizedBox(height: 8 * scale),
                    _SimpleProgressBar(value: percent, width: 260 * scale),
                    SizedBox(height: 14 * scale),
                    _SimpleMiniChart(
                      width: 260 * scale,
                      height: 60 * scale,
                      scores: scores,
                    ),
                    SizedBox(height: 8 * scale),
                    Text(
                      '일주일간의 활동 추이를 보여줍니다.',
                      style: _ts(size: 12 * scale, color: _grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ],
        ),

        // 하단 여백
        const Spacer(),
      ],
    );
  }
}

class _StatPage2 extends StatelessWidget {
  const _StatPage2({required this.displayName});
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);

    return Padding(
      padding: EdgeInsets.only(top: 18 * scale, bottom: 8 * scale),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '안녕하세요, $displayName님',
            style: _ts(
              size: 36 * scale,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12 * scale),
          SizedBox(height: 10 * scale),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ValueListenableBuilder<ActivitySnapshot>(
                  valueListenable: ActivityStore.notifier,
                  builder: (context, snapshot, _) {
                    final percent = _problemSolveTarget <= 0
                        ? 0.0
                        : (snapshot.totalSolvedCount / _problemSolveTarget)
                              .clamp(0.0, 1.0)
                              .toDouble();
                    return _CircleStat(
                      percent: percent,
                      color: const Color(0xFFEFB339),
                      label: '${snapshot.totalSolvedCount}개',
                      subtitle: '문제 풀이',
                    );
                  },
                ),
                SizedBox(width: 16 * scale),
                _CircleStat(
                  percent: 0.4,
                  color: const Color(0xFFEF394D),
                  label: '9.54',
                  subtitle: '평균 점수',
                ),
                SizedBox(width: 16 * scale),
                ValueListenableBuilder<AttendanceSnapshot>(
                  valueListenable: AttendanceStore.notifier,
                  builder: (context, snapshot, _) {
                    final count = snapshot.weekCount;
                    final percent = (count / 7).clamp(0.0, 1.0).toDouble();
                    return _CircleStat(
                      percent: percent,
                      color: const Color(0xFF3965EF),
                      label: '${count}일',
                      subtitle: '이번 주 출석',
                    );
                  },
                ),
                SizedBox(width: 16 * scale),
                ValueListenableBuilder<ActivitySnapshot>(
                  valueListenable: ActivityStore.notifier,
                  builder: (context, snapshot, _) {
                    final correct = snapshot.totalSolvedCount;
                    final incorrect = snapshot.totalIncorrectCount;
                    final total = correct + incorrect;
                    final percent = total == 0
                        ? 0.0
                        : (correct / total).clamp(0.0, 1.0);
                    final label = '${(percent * 100).round()}%';
                    return _CircleStat(
                      percent: percent,
                      color: const Color(0xFF03A113),
                      label: label,
                      subtitle: '정답률',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningSection extends StatelessWidget {
  const _LearningSection({
    required this.todayTasks,
    required this.activeCourse,
    required this.onCourseTap,
    required this.onTodayTasksTap,
  });

  final List<String> todayTasks;
  final Course? activeCourse;
  final VoidCallback onCourseTap;
  final VoidCallback onTodayTasksTap;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final todayCount = todayTasks.length;
    final todaySummary = _formatTasksSummary(todayTasks);
    final progressPercent = activeCourse == null
        ? null
        : (activeCourse!.progress * 100).round();
    final courseSummary = activeCourse == null
        ? '시작할 과정을 선택하세요.'
        : '${activeCourse!.title}\n진행률 $progressPercent%';

    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 20 * scale, 20 * scale, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _bgGrey,
          borderRadius: BorderRadius.circular(20 * scale),
          boxShadow: const [_shadow],
        ),
        padding: EdgeInsets.symmetric(vertical: 20 * scale),
        child: Column(
          children: [
            _LearnBanner(onTap: () => showStudyModeModal(context: context)),
            Padding(
              padding: EdgeInsets.only(
                top: 16 * scale,
                left: 14 * scale,
                right: 14 * scale,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<AttendanceSnapshot>(
                      valueListenable: AttendanceStore.notifier,
                      builder: (context, snapshot, _) {
                        final todayDone = AttendanceStore.isTodayChecked(
                          snapshot,
                        );
                        const total = 1;
                        final completed = todayDone ? 1 : 0;
                        final progress = todayDone ? 1.0 : 0.0;
                        final statusText = todayDone ? '출석 완료' : '출석 필요';
                        return _ProgressCard(
                          title: '일일 퀘스트',
                          subtitle: '자세히 보기',
                          progressText: '$statusText ($completed / $total)',
                          progressValue: progress,
                          onTap: () => showDailyTestModal(context: context),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 6 * scale),
                  Expanded(
                    child: _ProgressCard(
                      title: '오늘 할 일 ${todayCount}개',
                      subtitle: '자세히 보기',
                      progressText: todaySummary,
                      progressValue: null,
                      showProgressBar: false,
                      onTap: onTodayTasksTap,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 6 * scale),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14 * scale),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: _cardDeco(radius: 16 * scale),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12 * scale,
                          vertical: 10 * scale,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '학습 도구',
                              style:
                                  _ts(size: 18 * scale, weight: FontWeight.bold),
                            ),
                            SizedBox(height: 20 * scale),
                            LearningToolsStrip(
                              onNotepad: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const NotepadPage(),
                                  ),
                                );
                              },
                              onTimer: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const TimerPage(),
                                  ),
                                );
                              },
                              onFocusMode: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const FocusModePage(),
                                  ),
                                );
                              },
                              onChat: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ServerChatPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 6 * scale),
                    Expanded(
                      child: Column(
                        children: [
                          _ProgressCard(
                            title: '과정 트랙',
                            subtitle: '',
                            progressText: courseSummary,
                            progressValue: activeCourse?.progress,
                            showProgressBar: activeCourse != null,
                            onTap: onCourseTap,
                          ),
                          SizedBox(height: 6 * scale),
                          ValueListenableBuilder<SocialNotificationSnapshot>(
                            valueListenable: SocialNotificationStore.notifier,
                            builder: (context, snapshot, _) {
                              final noticeText = _formatSocialNotice(snapshot);
                              return _ProgressCard(
                                title: '알림',
                                subtitle: '',
                                progressText: noticeText,
                                progressValue: null,
                                showProgressBar: false,
                                onTap: () => showSocialModal(context: context),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearnBanner extends StatelessWidget {
  const _LearnBanner({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56 * scale,
        margin: EdgeInsets.symmetric(horizontal: 14 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20 * scale),
          boxShadow: const [_shadow],
          border: Border.all(color: _green, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow, color: _green, size: 32 * scale),
            Text(
              '학습하기',
              style: _ts(
                size: 28 * scale,
                weight: FontWeight.w900,
                color: _green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.subtitle,
    required this.progressText,
    required this.progressValue,
    this.showProgressBar = true,
    this.height = 100,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String progressText;
  final double? progressValue;
  final bool showProgressBar;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    Widget wrapTap(Widget child) {
      if (onTap == null) return child;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
    }

    return Container(
      height: height,
      decoration: _cardDeco(radius: 16 * scale),
      padding: EdgeInsets.symmetric(horizontal: 18 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 12 * scale),
                child: Text(
                  title,
                  style: _ts(size: 18 * scale, weight: FontWeight.bold),
                ),
              ),
              if (subtitle.isNotEmpty)
                wrapTap(
                  Padding(
                    padding: EdgeInsets.only(top: 12 * scale, right: 0),
                    child: Row(
                      children: [
                        Text(
                          subtitle,
                          style: _ts(size: 12 * scale, weight: FontWeight.bold),
                        ),
                        SizedBox(width: 6 * scale),
                        Icon(Icons.arrow_forward_ios, size: 12 * scale),
                      ],
                    ),
                  ),
                )
              else
                wrapTap(
                  Padding(
                    padding: EdgeInsets.only(
                      top: 12 * scale,
                      right: 10 * scale,
                    ),
                    child: Icon(Icons.arrow_forward_ios, size: 12 * scale),
                  ),
                ),
            ],
          ),
          if (showProgressBar && progressValue != null) ...[
            SizedBox(height: 6 * scale),
            ClipRRect(
              borderRadius: BorderRadius.circular(6 * scale),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 6 * scale,
                backgroundColor: const Color(0xFFDDDDDD),
                color: _lightGreen,
              ),
            ),
          ],
          if (progressText.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 6 * scale),
              child: Text(
                progressText,
                style: _ts(size: 10 * scale, weight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 0, 20 * scale, 20 * scale),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  height: 190 * scale,
                  margin: EdgeInsets.only(top: 12 * scale),
                  decoration: _cardDeco(radius: 16 * scale),
                  padding: EdgeInsets.symmetric(horizontal: 18 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: 12 * scale,
                          bottom: 6 * scale,
                        ),
                        child: Text(
                          '나의 레이팅',
                          style: _ts(size: 18 * scale, weight: FontWeight.bold),
                        ),
                      ),
                      ValueListenableBuilder<RatingSnapshot>(
                        valueListenable: RatingStore.notifier,
                        builder: (context, snapshot, _) {
                          final ovrText = snapshot.isLoaded
                              ? _formatRatingOvr(snapshot.ovr)
                              : '--';
                          final deltaValue = snapshot.delta / _ratingOvrDivider;
                          final deltaColor = deltaValue > 0
                              ? Colors.red
                              : deltaValue < 0
                              ? Colors.blue
                              : Colors.black54;
                          final deltaText = snapshot.isLoaded
                              ? (deltaValue >= 0
                                    ? '+ ${deltaValue.toStringAsFixed(1)}'
                                    : deltaValue.toStringAsFixed(1))
                              : '--';
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ovrText,
                                style: _ts(
                                  size: 40 * scale,
                                  weight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 8 * scale),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    deltaText,
                                    style: _ts(
                                      size: 10 * scale,
                                      color: deltaColor,
                                    ),
                                  ),
                                  Text(
                                    '??? 34%',
                                    style: _ts(
                                      size: 10 * scale,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      Divider(thickness: 1, height: 16 * scale),
                      Padding(
                        padding: EdgeInsets.only(
                          top: 4 * scale,
                          bottom: 10 * scale,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8 * scale),
                            onTap: () =>
                                showRatingDetailModal(context: context),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 6 * scale,
                                horizontal: 4 * scale,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '레이팅 자세히 보기 및 보고서 보기',
                                    style: _ts(size: 12 * scale),
                                  ),
                                  SizedBox(width: 6 * scale),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12 * scale,
                                    color: _green,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Container(
                  height: 190 * scale,
                  margin: EdgeInsets.only(top: 12 * scale),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16 * scale),
                    boxShadow: const [_shadow],
                    image: const DecorationImage(
                      fit: BoxFit.cover,
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1676302440263-c6b4cea29567?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHw3fHwlRUMlODglOTglRUQlOTUlOTl8ZW58MHx8fHwxNzcwODcxODUyfDA&ixlib=rb-4.1.0&q=80&w=1080',
                      ),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16 * scale),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'AIFlow',
                          style: _ts(
                            size: 30 * scale,
                            weight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 6 * scale),
                        Text(
                          '학습 커뮤니티입니다.\n멘토링/상담 게시물을 확인하세요.',
                          textAlign: TextAlign.center,
                          style: _ts(
                            size: 10 * scale,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          _ActivityHistoryCard(),
          SizedBox(height: 12 * scale),
          Container(
            width: double.infinity,
            height: 190 * scale,
            decoration: _cardDeco(radius: 16 * scale),
            padding: EdgeInsets.symmetric(horizontal: 18 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 12 * scale),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '대회 일정',
                        style: _ts(size: 18 * scale, weight: FontWeight.bold),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: 8 * scale,
                          right: 4 * scale,
                        ),
                        child: Icon(Icons.arrow_forward_ios, size: 12 * scale),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityHistoryCard extends StatefulWidget {
  @override
  State<_ActivityHistoryCard> createState() => _ActivityHistoryCardState();
}

class _ActivityHistoryCardState extends State<_ActivityHistoryCard> {
  int? _selectedIndex;

  Color _tileColorForScore(int score) {
    final level = ActivityStore.activityLevelForScore(score);
    return _activityTileColors[level.clamp(0, _activityTileColors.length - 1)];
  }

  String _detailTextFor(ActivityDayRecord record) {
    final dateLabel = _formatDateLabel(record.dateKey);
    final problems = record.problemNumbers.length;
    final exams = record.examNumbers.length;
    final books = record.bookNumbers.length;
    final score = record.score;
    return '$dateLabel · $score점 · 문제 $problems문제 · 시험지 $exams회 · 교재 $books회';
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return ValueListenableBuilder<ActivitySnapshot>(
      valueListenable: ActivityStore.notifier,
      builder: (context, snapshot, _) {
        final days = ActivityStore.recentDays(snapshot, 60);
        final selected =
            (_selectedIndex != null &&
                _selectedIndex! >= 0 &&
                _selectedIndex! < days.length)
            ? days[_selectedIndex!]
            : null;
        return Container(
          width: double.infinity,
          decoration: _cardDeco(radius: 16 * scale),
          padding: EdgeInsets.fromLTRB(
            18 * scale,
            12 * scale,
            18 * scale,
            14 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '매일 출석',
                style: _ts(size: 18 * scale, weight: FontWeight.bold),
              ),
              SizedBox(height: 10 * scale),
              LayoutBuilder(
                builder: (context, constraints) {
                  const count = 60;
                  final gap = 3 * scale;
                  final available = constraints.maxWidth - gap * (count - 1);
                  final rawSize = available / count;
                  final tileSize = rawSize.clamp(6.0, 16.0);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(count, (index) {
                            final record = index < days.length
                                ? days[index]
                                : null;
                            final color = record == null
                                ? Colors.transparent
                                : _tileColorForScore(record.score);
                            final isSelected = index == _selectedIndex;
                            final tile = Container(
                              width: tileSize,
                              height: tileSize,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(
                                  3 * scale,
                                ),
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.black87,
                                        width: 1,
                                      )
                                    : null,
                              ),
                            );
                            final content = GestureDetector(
                              onTap: record == null
                                  ? null
                                  : () =>
                                        setState(() => _selectedIndex = index),
                              child: tile,
                            );
                            final child = record == null
                                ? content
                                : Tooltip(
                                    message: _detailTextFor(record),
                                    triggerMode: TooltipTriggerMode.tap,
                                    preferBelow: false,
                                    verticalOffset: 10 * scale,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8 * scale,
                                      vertical: 6 * scale,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(
                                        6 * scale,
                                      ),
                                    ),
                                    textStyle: _ts(
                                      size: 10 * scale,
                                      color: Colors.white,
                                      scaleUp: false,
                                    ),
                                    showDuration: const Duration(
                                      milliseconds: 2200,
                                    ),
                                    child: content,
                                  );
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index == count - 1 ? 0 : gap,
                              ),
                              child: child,
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SimpleProgressBar extends StatelessWidget {
  const _SimpleProgressBar({required this.value, required this.width});
  final double value;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6 * scale),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 6 * scale,
          backgroundColor: const Color(0x33FFFFFF),
          color: _lightGreen,
        ),
      ),
    );
  }
}

class _SimpleMiniChart extends StatelessWidget {
  const _SimpleMiniChart({
    required this.width,
    required this.height,
    required this.scores,
  });
  final double width;
  final double height;
  final List<int> scores;

  @override
  Widget build(BuildContext context) {
    final cap = ActivityStore.scoreCap();
    final values = scores.isEmpty
        ? const <double>[]
        : scores
              .map(
                (score) =>
                    cap <= 0 ? 0.0 : score.clamp(0, cap).toDouble() / cap,
              )
              .toList();
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _MiniChartPainter(values: values)),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  _MiniChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _lightGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (values.length < 2) {
      return;
    }
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height * (1 - values[i].clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

class _CircleStat extends StatelessWidget {
  const _CircleStat({
    required this.percent,
    required this.color,
    required this.label,
    required this.subtitle,
  });
  final double percent;
  final Color color;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Column(
      children: [
        SizedBox(
          width: 52 * scale,
          height: 52 * scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 52 * scale,
                height: 52 * scale,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 5 * scale,
                  backgroundColor: const Color(0x33FFFFFF),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Text(
                label,
                style: _ts(size: 10 * scale, color: _grey),
              ),
            ],
          ),
        ),
        SizedBox(height: 4 * scale),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: _ts(size: 10 * scale, color: _grey),
        ),
      ],
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({
    required this.count,
    required this.current,
    required this.onTap,
  });
  final int count;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == current;
        return GestureDetector(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.symmetric(horizontal: 3 * scale),
            width: active ? 14 * scale : 6 * scale,
            height: 6 * scale,
            decoration: BoxDecoration(
              color: active ? _lightGreen : _green,
              borderRadius: BorderRadius.circular(4 * scale),
            ),
          ),
        );
      }),
    );
  }
}
