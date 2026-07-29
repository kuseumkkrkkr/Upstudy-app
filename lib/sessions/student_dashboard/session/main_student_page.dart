import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/features/level_test/level_test.dart';
import 'package:s11/app/router.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/curriculum_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/daily_test_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/rating_detail_modal.dart';
import 'package:s11/features/arena/arena_page.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/study_mode_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/today_tasks_modal.dart';
import 'package:s11/sessions/learning_tools/ui/pages/notepad_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/timer_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/focus_mode_page.dart';
import 'package:s11/sessions/graph_tools/session/jsx_graph_page.dart';
import 'package:s11/sessions/student_dashboard/ui/widgets/activity_badges.dart';
import 'package:s11/sessions/student_dashboard/business/activity_badge_catalog.dart';
import 'package:s11/sessions/student_dashboard/ui/widgets/learning_tools_strip.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/business/repositories/attendance_store.dart';
import 'package:s11/shared/business/repositories/rating_store.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/modal/level_detail_modal.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/business/repositories/social_notification_store.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/sessions/course/session/course_learning_page.dart';

const _green = Color(0xFF1B402B);
const _lightGreen = Color(0xFF45BF63);
const _grey = Color(0xFFC9C9C9);

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
const int _ratingEstimateMinSolved = 50;
const double _ratingDeltaPercentMax = 0.5;
const double _homeFooterDesktopHeight = 384;
const double _homeFooterSixWeekHeight = 438;

double _ratingDisplay(double rating) {
  return (math.max(rating, _ratingFloor) - _ratingFloor)
      .clamp(0, _ratingDisplayMax)
      .toDouble();
}

double _ratingOvr(double rating) => _ratingDisplay(rating) / _ratingOvrDivider;

String _formatRatingOvr(double rating) {
  if (rating.isNaN || rating <= 0) return '--';
  return _ratingOvr(rating).toStringAsFixed(1);
}

String _formatRatingDelta(double deltaOvr) {
  if (deltaOvr > 0) return '+${deltaOvr.toStringAsFixed(1)}';
  if (deltaOvr < 0) return deltaOvr.toStringAsFixed(1);
  return '0.0';
}

int _ratingRisePercent(double deltaOvr) {
  if (deltaOvr <= 0) return 0;
  return ((deltaOvr / _ratingDeltaPercentMax) * 100).round().clamp(0, 100);
}

TextStyle _ts({
  double size = 16,
  FontWeight weight = FontWeight.normal,
  Color color = Colors.black,
  bool scaleUp = true,
}) => TextStyle(
  fontSize: size * (scaleUp ? 1.16 : 1.0),
  fontWeight: weight,
  color: color,
);

BoxDecoration _cardDeco({
  double radius = 36,
  Color color = Colors.white,
  DecorationImage? image,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: const [_shadow],
  image: image,
);

double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
  final width = MediaQuery.of(context).size.width;
  final scale = width / 1100;
  if (scale < min) return min;
  if (scale > max) return max;
  return scale;
}

/// 필요한 값은 모바일 여부와 HTML 그리드의 비율이다.
/// 작동 원리: 스크롤 내부 모바일 Column은 전체 폭을 쓰고, PC Row는 시안의 열 비율로 남은 폭을 나눈다.
Widget _bottomResponsiveChild({
  required bool mobile,
  required Widget child,
  int flex = 1,
}) {
  return mobile
      ? SizedBox(width: double.infinity, child: child)
      : Expanded(flex: flex, child: child);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _assignmentKindLabel(String kind) {
  switch (kind) {
    case 'problem':
      return '문제 풀이';
    case 'exam':
      return '시험';
    case 'homework':
      return '숙제';
    default:
      return '과제';
  }
}

enum _TodayTaskTarget { course, group, schedule }

class _TodayTaskItem extends TodayTaskEntry {
  const _TodayTaskItem({
    required super.title,
    required super.caption,
    required super.icon,
    required this.target,
    this.targetId,
  });

  final _TodayTaskTarget target;
  final String? targetId;
}

String _formatSocialNotice(SocialNotificationSnapshot snapshot) {
  final total =
      snapshot.unreadMessages +
      snapshot.friendRequests +
      snapshot.friendRemovals;
  if (total <= 0) return '알림 없음';
  return '놓친 알림 $total개';
}

String _formatDateLabel(String dateKey) {
  final parts = dateKey.split('-');
  if (parts.length == 3) return '${parts[1]}.${parts[2]}';
  return dateKey;
}

String _noticeDateLabel(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  return '${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}';
}

String _buildNoticeHtmlDocument(String title, String body) {
  return '''
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      margin: 0;
      padding: 20px;
      color: #173321;
      background: #f6fbf7;
    }
    article {
      background: #ffffff;
      border-radius: 18px;
      padding: 24px;
      box-shadow: 0 12px 28px rgba(27, 64, 43, 0.08);
    }
    h1 { margin-top: 0; font-size: 28px; }
    img { max-width: 100%; height: auto; }
    table { width: 100%; border-collapse: collapse; }
    td, th { border: 1px solid #d9e5dc; padding: 8px; }
  </style>
</head>
<body>
  <article>
    <h1>$title</h1>
    $body
  </article>
</body>
</html>
''';
}

double _singleLineWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: double.infinity);
  return painter.width;
}

double _fitSingleLineFontSize({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required double minFontSize,
}) {
  final baseFontSize = style.fontSize ?? 16;
  if (maxWidth <= 0 ||
      _singleLineWidth(text, style.copyWith(fontSize: baseFontSize)) <=
          maxWidth) {
    return baseFontSize;
  }

  var low = minFontSize;
  var high = baseFontSize;
  for (var i = 0; i < 8; i++) {
    final mid = (low + high) / 2;
    final width = _singleLineWidth(text, style.copyWith(fontSize: mid));
    if (width <= maxWidth) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return low;
}

class MainStudentPage extends StatefulWidget {
  const MainStudentPage({super.key, this.username});
  final String? username;

  @override
  State<MainStudentPage> createState() => _MainStudentPageState();
}

class _MainStudentPageState extends State<MainStudentPage> {
  final ScrollController _scrollController = ScrollController();
  List<_TodayTaskItem> _todayTeacherTasks = const [];
  List<_TodayTaskItem> _todayPersonalTasks = const [];
  String? _displayName;
  Key _courseLoaderKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _displayName = widget.username?.trim();
    unawaited(_refreshDisplayName());
    unawaited(ActivityStore.load().catchError((_) => ActivitySnapshot.empty()));
    unawaited(
      AttendanceStore.ensureDailyAttendance().catchError(
        (_) => AttendanceSnapshot.empty(),
      ),
    );
    unawaited(RatingStore.refresh());
    unawaited(_refreshTeacherTasks());
    unawaited(_refreshPersonalTasks());
  }

  @override
  void didUpdateWidget(covariant MainStudentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.username?.trim() != oldWidget.username?.trim()) {
      _displayName = widget.username?.trim();
      unawaited(_refreshDisplayName());
    }
  }

  /// 필요 변수는 프로필의 이름·아이디와 로컬에 저장된 로그인 아이디다.
  /// 작동 원리는 이름, 프로필 아이디, 저장 아이디, 전달값 순서로 첫 번째 유효한 값을 앱바에 반영한다.
  Future<void> _refreshDisplayName() async {
    final stored = (await AuthStorage.instance.readUsername())?.trim();
    final prefs = await SharedPreferences.getInstance();
    final legacyStored = prefs.getString('username')?.trim();
    UserProfile? profile;
    try {
      profile = await ApiClient.instance.getMyProfile();
    } catch (_) {
      // 프로필 조회가 실패해도 로컬 아이디로 앱바를 계속 표시한다.
    }
    final candidates = <String?>[
      profile?.name,
      profile?.username,
      stored,
      legacyStored,
      _displayName,
      widget.username,
    ];
    final candidate = candidates
        .map((value) => value?.trim())
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '사용자');
    if (!mounted) return;
    if (candidate != _displayName) {
      setState(() => _displayName = candidate);
    }
  }

  /// 필요한 변수는 교사가 배정한 과제의 종류·마감일·참조 ID다.
  /// 작동 원리: 오늘 마감인 모든 지정 과제를 카드 모델로 변환하고, 카드별 목적지로
  /// 코스·그룹 학습 화면을 분기한다.
  Future<void> _refreshTeacherTasks() async {
    try {
      final res = await ApiClient.instance.listMyAssignments();
      final today = _dateOnly(DateTime.now());
      final tasks = <_TodayTaskItem>[];
      for (final item in res.data ?? const <StudentAssignmentTask>[]) {
        final due = DateTime.tryParse(item.assignment.dueDate ?? '');
        if (due == null || _dateOnly(due) != today) continue;
        final title = item.assignment.title?.trim().isNotEmpty == true
            ? item.assignment.title!.trim()
            : item.assignment.refId;
        final isCourse = item.assignment.kind == 'course';
        tasks.add(
          _TodayTaskItem(
            title: title,
            caption: isCourse
                ? '교사 지정 코스 · 학습하러 가기'
                : '교사 지정 ${_assignmentKindLabel(item.assignment.kind)} · 확인하러 가기',
            icon: isCourse ? Icons.menu_book_rounded : Icons.assignment_rounded,
            target: isCourse ? _TodayTaskTarget.course : _TodayTaskTarget.group,
            targetId: isCourse
                ? item.assignment.refId
                : item.assignment.groupId,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _todayTeacherTasks = tasks);
    } catch (_) {
      if (!mounted) return;
      setState(() => _todayTeacherTasks = const []);
    }
  }

  /// 필요한 변수는 서버에 저장된 개인 일정의 날짜와 제목이다.
  /// 작동 원리: 오늘 날짜와 같은 일정만 홈의 알림 카드로 만들고, 선택 시 일정 화면으로 이동시킨다.
  Future<void> _refreshPersonalTasks() async {
    try {
      final res = await ApiClient.instance.listMyStudentSchedule();
      final today = _dateOnly(DateTime.now());
      final tasks = (res.data ?? const <StudentScheduleTask>[])
          .where(
            (item) => _dateOnly(DateTime.tryParse(item.date) ?? today) == today,
          )
          .where((item) => item.title.trim().isNotEmpty)
          .map(
            (item) => _TodayTaskItem(
              title: item.title.trim(),
              caption: '내 일정 · 일정에서 보기',
              icon: Icons.event_note_rounded,
              target: _TodayTaskTarget.schedule,
            ),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() => _todayPersonalTasks = tasks);
    } catch (_) {
      if (!mounted) return;
      setState(() => _todayPersonalTasks = const []);
    }
  }

  /// 필요한 변수는 카드가 가리키는 기능 종류와 참조 ID다.
  /// 작동 원리: 개인 일정은 일정으로, 교사 지정 코스는 코스 목록으로, 나머지 과제는
  /// 해당 그룹 화면으로 바로 보낸다.
  void _openTodayTask(_TodayTaskItem task) {
    switch (task.target) {
      case _TodayTaskTarget.course:
        Navigator.of(context).pushNamed(AppRoutes.courses);
        return;
      case _TodayTaskTarget.group:
        final groupId = task.targetId?.trim();
        if (groupId == null || groupId.isEmpty) return;
        Navigator.of(
          context,
        ).pushNamed(AppRoutes.groupDetail, arguments: groupId);
        return;
      case _TodayTaskTarget.schedule:
        Navigator.of(context).pushNamed(AppRoutes.schedule);
        return;
    }
  }

  Future<void> _handleCourseTap() async {
    final selected = await showCurriculumModal(context: context);
    if (!mounted) return;
    setState(() => _courseLoaderKey = UniqueKey());
    if (selected != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CourseLearningPage(course: selected)),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final portraitMobile =
        mobile && MediaQuery.orientationOf(context) == Orientation.portrait;
    final todayTasks = [..._todayTeacherTasks, ..._todayPersonalTasks];
    // 필요한 변수는 화면 방향과 인사 문구의 실제 높이다.
    // 작동 원리: 세로형 모바일은 설명을 덜어낸 전용 히어로를 사용하고,
    // 가로형·태블릿은 기존 정보형 히어로를 유지한다.
    final heroExtent = portraitMobile
        ? 214.0
        : mobile
        ? 250.0
        : 294.0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: StudentDensityTokens.background,
        drawer: mobile ? null : const AppDrawer(),
        bottomNavigationBar: mobile ? const MobileStudentBottomAppBar() : null,
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                displayName: _displayName,
                mobile: mobile,
                onProfileChanged: _refreshDisplayName,
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroSection(
                        username: _displayName,
                        height: heroExtent,
                        portraitMobile: portraitMobile,
                      ),
                      _CourseLoader(
                        key: _courseLoaderKey,
                        builder: (course) => _LearningSection(
                          todayTasks: todayTasks,
                          activeCourse: course,
                          portraitMobile: portraitMobile,
                          onCourseTap: _handleCourseTap,
                          onTodayTasksTap: () => showTodayTasksModal(
                            context: context,
                            tasks: todayTasks,
                            onTaskTap: (task) =>
                                _openTodayTask(task as _TodayTaskItem),
                          ),
                        ),
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

class _CourseLoader extends StatefulWidget {
  const _CourseLoader({super.key, required this.builder});
  final Widget Function(Course? course) builder;

  @override
  State<_CourseLoader> createState() => _CourseLoaderState();
}

class _CourseLoaderState extends State<_CourseLoader> {
  Course? _course;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final courses = await CourseService.fetchMyCourses();
      setState(() {
        // 완료 코스는 다시 활성 코스로 선택하지 않고 검색 화면에서만 미리보기를 제공한다.
        final activeCourses = courses
            .where((course) => !course.isCompleted)
            .toList(growable: false);
        if (activeCourses.isEmpty) {
          _course = null;
        } else {
          _course = activeCourses.firstWhere(
            (Course c) => c.progress > 0 && !c.isDemo,
            orElse: () => activeCourses.firstWhere(
              (Course c) => !c.isDemo,
              orElse: () => activeCourses.first,
            ),
          );
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return widget.builder(null);
    return widget.builder(_course);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.displayName,
    required this.mobile,
    required this.onProfileChanged,
  });

  final String? displayName;
  final bool mobile;
  final Future<void> Function() onProfileChanged;

  /// 필요 변수는 현재 Navigator와 프로필 변경 후 실행할 새로고침 함수다.
  /// 작동 원리는 프로필 화면이 닫히면 이름과 아이디를 다시 읽어 앱바에 즉시 반영하는 것이다.
  Future<void> _openProfile(BuildContext context) async {
    await Navigator.of(context).pushNamed('/profile');
    await onProfileChanged();
  }

  /// 필요한 변수는 현재 학생 화면 문맥과 활성 홈 메뉴다.
  /// 공용 상단 내비게이션을 사용해 홈을 포함한 학습 목적지의 이동 계약을 유지한다.
  @override
  Widget build(BuildContext context) {
    return Ios26TopBar(
      brandColor: _green,
      onMenu: mobile ? null : () => toggleAppDrawer(context),
      showLevelIndicator: false,
      showUtilityActions: !mobile,
      profileLabel: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : null,
      onNotifications: () => showStudentNotifications(context),
      onProfile: () => unawaited(_openProfile(context)),
      items: studentTopNavItems(context, active: StudentTopDestination.home),
    );
  }
}

class _AppBarLevelIndicator extends StatefulWidget {
  const _AppBarLevelIndicator();

  @override
  State<_AppBarLevelIndicator> createState() => _AppBarLevelIndicatorState();
}

class _AppBarLevelIndicatorState extends State<_AppBarLevelIndicator> {
  late final Future<AccountSummary> _summary;
  AccountSummary? _latestSummary;

  @override
  void initState() {
    super.initState();
    _summary = ApiClient.instance.fetchAccountSummary().then((summary) {
      ActivityStore.accountSummaryNotifier.value = summary;
      return summary;
    });
    ActivityStore.accountSummaryNotifier.addListener(_handleAccountSummary);
  }

  @override
  void dispose() {
    ActivityStore.accountSummaryNotifier.removeListener(_handleAccountSummary);
    super.dispose();
  }

  void _handleAccountSummary() {
    if (!mounted) return;
    setState(() {
      _latestSummary = ActivityStore.accountSummaryNotifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountSummary>(
      future: _summary,
      builder: (context, snapshot) {
        final account = _latestSummary ?? snapshot.data;
        if (account == null) {
          return const SizedBox.shrink();
        }

        return InkWell(
          onTap: () => LevelDetailModal.show(context, account),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _green.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: account.levelProgress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        _lightGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'lv. ${account.level}',
                  style: const TextStyle(
                    color: _green,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.username,
    required this.height,
    required this.portraitMobile,
  });
  final String? username;
  final double? height;
  final bool portraitMobile;

  /// 필요 변수: 로그인 사용자 이름과 화면 폭.
  /// 작동 원리: 배경 사진과 통계 회전을 제거하고 최신 시안의 짧은 인사 문맥만 먼저 표시합니다.
  @override
  Widget build(BuildContext context) {
    final name = username?.trim();
    final hasDisplayName = name != null && name.isNotEmpty;
    final greeting = portraitMobile
        ? hasDisplayName
              ? '$name님,\n바로 시작해요.'
              : '오늘도,\n바로 시작해요.'
        : hasDisplayName
        ? '$name님,\n오늘도 시작해 볼까요?'
        : isStudentDensityMobile(context)
        ? '오늘도,\n학습을 시작해 볼까요?'
        : '사용자님,\n오늘도 시작해 볼까요?';
    final now = DateTime.now();
    final mobile = isStudentDensityMobile(context);
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return SizedBox(
      key: ValueKey(mobile ? 'student-home-mobile' : 'student-home-desktop'),
      height: height,
      child: StudentDensityPage(
        padding: EdgeInsets.fromLTRB(
          studentDensityHorizontalPadding(context),
          portraitMobile ? 18 : studentDensityVerticalPadding(context),
          studentDensityHorizontalPadding(context),
          0,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: portraitMobile
                ? 10
                : mobile
                ? 24
                : 38,
            vertical: portraitMobile
                ? 20
                : mobile
                ? 24
                : 30,
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudentDensityEyebrow(
                  '${weekdays[now.weekday - 1]}DAY · ${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}',
                ),
                const SizedBox(height: 8),
                Text(
                  greeting,
                  style: TextStyle(
                    color: StudentDensityTokens.ink,
                    fontSize: portraitMobile
                        ? 46
                        : mobile
                        ? 38
                        : 56,
                    height: portraitMobile ? 1.02 : 0.98,
                    fontWeight: FontWeight.w900,
                    letterSpacing: portraitMobile
                        ? -2.7
                        : mobile
                        ? -2
                        : -3.4,
                  ),
                ),
                if (!portraitMobile) ...[
                  SizedBox(height: mobile ? 9 : 12),
                  Text(
                    '어제 멈춘 학습과 오늘 일정은 아래 학습 영역에서 이어집니다.',
                    style: TextStyle(
                      color: StudentDensityTokens.muted,
                      fontSize: mobile ? 11 : 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatPager extends StatefulWidget {
  const StatPager({
    super.key,
    required this.displayName,
    required this.titleFontSize,
    required this.titleHeight,
    required this.isLongName,
    required this.contentScale,
  });
  final String displayName;
  final double titleFontSize;
  final double titleHeight;
  final bool isLongName;
  final double contentScale;

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
                : Colors.black.withValues(alpha: 0.35),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context) * widget.contentScale;
    final pagerHeight = (260 * scale) + (widget.isLongName ? 20 * scale : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final sideWidth = math.max(44.0, 48 * scale);
        final pagerWidth = math.min(
          620 * scale,
          math.max(180.0, availableWidth - sideWidth * 2),
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: sideWidth,
              child: IconButton(
                onPressed: _prev,
                icon: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: 26 * scale,
                ),
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
                        _StatPage1(
                          displayName: widget.displayName,
                          titleFontSize: widget.titleFontSize,
                          titleHeight: widget.titleHeight,
                          contentScale: widget.contentScale,
                        ),
                        _StatPage2(
                          displayName: widget.displayName,
                          titleFontSize: widget.titleFontSize,
                          titleHeight: widget.titleHeight,
                          contentScale: widget.contentScale,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  _buildIndicator(scale),
                ],
              ),
            ),
            SizedBox(
              width: sideWidth,
              child: IconButton(
                onPressed: _next,
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 26 * scale,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GreetingTitle extends StatelessWidget {
  const _GreetingTitle({
    required this.displayName,
    required this.fontSize,
    required this.height,
    required this.contentScale,
  });

  final String displayName;
  final double fontSize;
  final double height;
  final double contentScale;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context) * contentScale;
    final text = '안녕하세요, $displayName님';
    final baseStyle = _ts(
      size: fontSize * scale,
      color: Colors.white,
      weight: FontWeight.w700,
    ).copyWith(height: height);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final baseFontSize = baseStyle.fontSize ?? fontSize * scale;
        final minFontSize = math.max(18 * scale, baseFontSize * 0.62);
        final fittedFontSize = _fitSingleLineFontSize(
          text: text,
          style: baseStyle,
          maxWidth: availableWidth,
          minFontSize: minFontSize,
        );

        return Text(
          text,
          style: baseStyle.copyWith(fontSize: fittedFontSize),
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _StatPage1 extends StatelessWidget {
  const _StatPage1({
    required this.displayName,
    required this.titleFontSize,
    required this.titleHeight,
    required this.contentScale,
  });
  final String displayName;
  final double titleFontSize;
  final double titleHeight;
  final double contentScale;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context) * contentScale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final graphWidth = math.min(260 * scale, constraints.maxWidth);
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GreetingTitle(
                    displayName: displayName,
                    fontSize: titleFontSize,
                    height: titleHeight,
                    contentScale: contentScale,
                  ),
                  SizedBox(height: 12 * scale),
                  ValueListenableBuilder<ActivitySnapshot>(
                    valueListenable: ActivityStore.notifier,
                    builder: (context, snapshot, _) {
                      final recent = ActivityStore.recentDays(snapshot, 7);
                      final todayScore = recent.isNotEmpty
                          ? recent.last.score
                          : 0;
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
                          _SimpleProgressBar(
                            value: percent,
                            width: graphWidth,
                            height: 6 * scale,
                          ),
                          SizedBox(height: 14 * scale),
                          _SimpleMiniChart(
                            width: graphWidth,
                            height: 60 * scale,
                            scores: scores,
                          ),
                          SizedBox(height: 8 * scale),
                          Text(
                            '일주일간의 활동 추이를 보여줍니다.',
                            style: _ts(size: 12 * scale, color: _grey),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatPage2 extends StatelessWidget {
  const _StatPage2({
    required this.displayName,
    required this.titleFontSize,
    required this.titleHeight,
    required this.contentScale,
  });
  final String displayName;
  final double titleFontSize;
  final double titleHeight;
  final double contentScale;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context) * contentScale;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Padding(
                padding: EdgeInsets.only(top: 18 * scale, bottom: 8 * scale),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GreetingTitle(
                      displayName: displayName,
                      fontSize: titleFontSize,
                      height: titleHeight,
                      contentScale: contentScale,
                    ),
                    SizedBox(height: 22 * scale),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ValueListenableBuilder<ActivitySnapshot>(
                              valueListenable: ActivityStore.notifier,
                              builder: (context, snapshot, _) {
                                final percent = _problemSolveTarget <= 0
                                    ? 0.0
                                    : (snapshot.totalSolvedCount /
                                              _problemSolveTarget)
                                          .clamp(0.0, 1.0)
                                          .toDouble();
                                return _CircleStat(
                                  percent: percent,
                                  color: const Color(0xFFEFB339),
                                  label: '${snapshot.totalSolvedCount}개',
                                  subtitle: '문제 풀이',
                                  contentScale: contentScale,
                                );
                              },
                            ),
                            SizedBox(width: 16 * scale),
                            ValueListenableBuilder<RatingSnapshot>(
                              valueListenable: RatingStore.notifier,
                              builder: (context, snapshot, _) {
                                final delta = snapshot.isLoaded
                                    ? snapshot.delta
                                    : 0.0;
                                final deltaDisplay = delta >= 0
                                    ? '+${delta.toStringAsFixed(2)}'
                                    : delta.toStringAsFixed(2);
                                final progress = delta <= 0
                                    ? 0.0
                                    : (delta.clamp(0.0, 0.5) / 0.5);
                                return _CircleStat(
                                  percent: progress,
                                  color: const Color(0xFFEF394D),
                                  label: snapshot.isLoaded
                                      ? deltaDisplay
                                      : '--',
                                  subtitle: '전날 대비 OVR',
                                  contentScale: contentScale,
                                );
                              },
                            ),
                            SizedBox(width: 16 * scale),
                            ValueListenableBuilder<AttendanceSnapshot>(
                              valueListenable: AttendanceStore.notifier,
                              builder: (context, snapshot, _) {
                                final count = snapshot.weekCount;
                                final percent = (count / 7)
                                    .clamp(0.0, 1.0)
                                    .toDouble();
                                return _CircleStat(
                                  percent: percent,
                                  color: const Color(0xFF3965EF),
                                  label: '$count일',
                                  subtitle: '이번 주 출석',
                                  contentScale: contentScale,
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
                                  contentScale: contentScale,
                                );
                              },
                            ),
                          ],
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
    );
  }
}

class _LearningSection extends StatelessWidget {
  const _LearningSection({
    required this.todayTasks,
    required this.activeCourse,
    required this.portraitMobile,
    required this.onCourseTap,
    required this.onTodayTasksTap,
  });
  final List<_TodayTaskItem> todayTasks;
  final Course? activeCourse;
  final bool portraitMobile;
  final VoidCallback onCourseTap;
  final VoidCallback onTodayTasksTap;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final progressPercent = activeCourse == null
        ? null
        : (activeCourse!.progress * 100).round();
    final courseTitle = activeCourse?.title ?? '시작할 코스를 선택하세요';
    final courseMeta = activeCourse == null
        ? '코스 탐색 · 맞춤 추천'
        : activeCourse!.isDemo
        ? '체험 전용 코스'
        : '진행률 $progressPercent%';

    /// 필요한 변수는 도구별 이동 콜백이다.
    /// 작동 원리: HTML 학습 도구 카드의 네 빠른 실행을 기존 기능 화면과 연결한다.
    final tools = LearningToolsStrip(
      onNotepad: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const NotepadPage())),
      onTimer: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const TimerPage())),
      onFocusMode: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const FocusModePage())),
      onGraph: () {
        unawaited(
          ActivityStore.recordGraphPractice(
            graphId: 'dashboard_graph_tool',
            meta: const {'source': 'dashboard_tool'},
          ),
        );
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const JsxGraphPage()));
      },
    );

    // 필요한 변수는 학습 도구 제목·빠른 실행 배지·도구 목록이다.
    // 작동 원리: 학습 도구는 바깥의 연회색 학습 컨테이너에 통합하고,
    // 오른쪽 코스·알림 카드만 흰색 surface로 분리해 시안의 계층을 유지한다.
    final toolCard = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '학습 도구',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              _DashboardPill('빠른 실행'),
            ],
          ),
          const SizedBox(height: 16),
          tools,
        ],
      ),
    );

    final featureStack = Column(
      children: [
        _HomeFeatureCard(
          icon: Icons.play_arrow_rounded,
          title: '현재 코스',
          description: '$courseTitle · $courseMeta',
          onTap: onCourseTap,
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<SocialNotificationSnapshot>(
          valueListenable: SocialNotificationStore.notifier,
          builder: (context, snapshot, _) => _HomeFeatureCard(
            icon: Icons.notifications_none_rounded,
            title: '알림',
            description: _formatSocialNotice(snapshot),
            onTap: () => showStudentNotifications(context),
          ),
        ),
      ],
    );

    final moduleGrid = mobile
        ? Column(children: [toolCard, const SizedBox(height: 12), featureStack])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 13, child: toolCard),
              const SizedBox(width: 12),
              Expanded(flex: 7, child: featureStack),
            ],
          );

    final statusCards = [
      Expanded(
        child: portraitMobile
            ? _HomeStatusCard(
                label: '현재 코스',
                value: progressPercent == null ? '선택' : '$progressPercent%',
                meta: '',
                onTap: onCourseTap,
                hideMeta: true,
              )
            : _DailyQuestProgressCard(courseId: activeCourse?.id),
      ),
      Expanded(
        child: _HomeStatusCard(
          label: '오늘 할 일',
          value: '${todayTasks.length}개',
          meta: todayTasks.isEmpty ? '오늘 해야 할 일이 없습니다.' : '카드를 눌러 할 일을 확인하세요.',
          onTap: onTodayTasksTap,
          hideMeta: portraitMobile,
        ),
      ),
    ];

    return Center(
      key: ValueKey(
        mobile
            ? 'student-home-learning-mobile'
            : 'student-home-learning-desktop',
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: StudentDensityTokens.desktopMaxWidth,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            studentDensityHorizontalPadding(context),
            0,
            studentDensityHorizontalPadding(context),
            14,
          ),
          child: Container(
            padding: EdgeInsets.all(portraitMobile ? 14 : 20),
            decoration: BoxDecoration(
              color: portraitMobile
                  ? StudentDensityTokens.background
                  : StudentDensityTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(portraitMobile ? 0 : 34),
              border: portraitMobile
                  ? null
                  : Border.all(color: StudentDensityTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LearnBanner(
                  portraitMobile: portraitMobile,
                  onTap: () => showStudyModeModal(context: context),
                ),
                SizedBox(height: portraitMobile ? 16 : 12),
                if (portraitMobile)
                  _MobileHomeStatusGroup(
                    courseValue: progressPercent == null
                        ? '코스 선택'
                        : '진행률 $progressPercent%',
                    taskValue: todayTasks.isEmpty
                        ? '할 일 없음'
                        : '${todayTasks.length}개 남음',
                    onCourseTap: onCourseTap,
                    onTodayTasksTap: onTodayTasksTap,
                  )
                else
                  Row(
                    children: [
                      statusCards[0],
                      SizedBox(width: mobile ? 8 : 12),
                      statusCards[1],
                    ],
                  ),
                SizedBox(height: portraitMobile ? 22 : 12),
                if (portraitMobile) ...[
                  const Text(
                    '빠른 도구',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  tools,
                  const SizedBox(height: 18),
                  _HomeFeatureCard(
                    icon: Icons.play_arrow_rounded,
                    title: '코스 이어하기',
                    description: courseTitle,
                    onTap: onCourseTap,
                    compactMobile: true,
                  ),
                ] else
                  moduleGrid,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardPill extends StatelessWidget {
  const _DashboardPill(this.label);

  final String label;

  /// 필요한 변수는 짧은 상태 문구다.
  /// 작동 원리: HTML의 28px 회색 캡슐 배지를 동일한 경계와 굵기로 표시한다.
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: StudentDensityTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StudentDensityTokens.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: StudentDensityTokens.muted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 필요한 변수는 코스·오늘 할 일 상태와 각 이동 콜백이다.
/// 작동 원리: 모바일의 상태 카드 두 개를 하나의 흰 Material 그룹 안 행으로 합쳐 도형 수를 줄인다.
class _MobileHomeStatusGroup extends StatelessWidget {
  const _MobileHomeStatusGroup({
    required this.courseValue,
    required this.taskValue,
    required this.onCourseTap,
    required this.onTodayTasksTap,
  });

  final String courseValue;
  final String taskValue;
  final VoidCallback onCourseTap;
  final VoidCallback onTodayTasksTap;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('student-home-mobile-status-group'),
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        _MobileHomeStatusRow(
          icon: Icons.play_circle_outline_rounded,
          label: '현재 코스',
          value: courseValue,
          onTap: onCourseTap,
        ),
        _MobileHomeStatusRow(
          icon: Icons.today_outlined,
          label: '오늘 할 일',
          value: taskValue,
          onTap: onTodayTasksTap,
        ),
      ],
    ),
  );
}

/// 필요한 변수는 상태 아이콘·이름·값·이동 콜백이다.
/// 작동 원리: 68px 행 전체를 터치 영역으로 사용하고 보조 설명 없이 현재 값만 보여 준다.
class _MobileHomeStatusRow extends StatelessWidget {
  const _MobileHomeStatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: StudentDensityTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: StudentDensityTokens.muted,
          ),
        ],
      ),
    ),
  );
}

class _HomeStatusCard extends StatelessWidget {
  const _HomeStatusCard({
    required this.label,
    required this.value,
    required this.meta,
    required this.onTap,
    this.showBadge = false,
    this.hideMeta = false,
  });

  final String label;
  final String value;
  final String meta;
  final VoidCallback? onTap;
  final bool showBadge;
  final bool hideMeta;

  /// 필요한 변수는 상태 라벨·핵심 수치·보조 설명과 탭 콜백이다.
  /// 작동 원리: HTML의 132px 홈 상태 버튼을 큰 수치 중심의 흰 카드로 재현한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return SizedBox(
      width: double.infinity,
      height: hideMeta
          ? 126
          : mobile
          ? 118
          : 132,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          StudentDensitySurface(
            padding: EdgeInsets.zero,
            radius: mobile ? 20 : StudentDensityTokens.radius,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(mobile ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: StudentDensityTokens.muted,
                      fontSize: hideMeta
                          ? 15
                          : mobile
                          ? 10
                          : 12,
                      fontWeight: hideMeta ? FontWeight.w800 : FontWeight.w400,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: StudentDensityTokens.ink,
                      fontSize: hideMeta
                          ? 38
                          : mobile
                          ? 28
                          : 42,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: mobile ? -1.7 : -2.5,
                    ),
                  ),
                  if (!hideMeta)
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudentDensityTokens.ink,
                        fontSize: mobile ? 9 : 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeFeatureCard extends StatelessWidget {
  const _HomeFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.compactMobile = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool compactMobile;

  /// 필요한 변수는 기능 아이콘·제목·설명과 이동 콜백이다.
  /// 작동 원리: HTML의 118px 기능 카드를 48px 아이콘과 우측 화살표의 3열 구조로 만든다.
  @override
  Widget build(BuildContext context) {
    return StudentDensitySurface(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compactMobile ? 92 : 118),
        child: Padding(
          padding: EdgeInsets.all(compactMobile ? 16 : 20),
          child: Row(
            children: [
              Container(
                width: compactMobile ? 56 : 48,
                height: compactMobile ? 56 : 48,
                decoration: BoxDecoration(
                  color: StudentDensityTokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: StudentDensityTokens.line),
                ),
                child: Icon(
                  icon,
                  color: StudentDensityTokens.ink,
                  size: compactMobile ? 28 : 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: compactMobile ? 19 : 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudentDensityTokens.muted,
                        fontSize: compactMobile ? 15 : 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '›',
                style: TextStyle(
                  color: StudentDensityTokens.muted,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineCta extends StatelessWidget {
  const _InlineCta({
    required this.onTap,
    this.label,
    this.textStyle,
    this.iconSize = 12,
    this.padding = const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    this.radius = 8,
  });

  final VoidCallback? onTap;
  final String? label;
  final TextStyle? textStyle;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null) ...[
                Text(label!, style: textStyle),
                SizedBox(width: iconSize * 0.5),
              ],
              Icon(Icons.arrow_forward_ios, size: iconSize, color: _green),
            ],
          ),
        ),
      ),
    );
    return child;
  }
}

class _LearnBanner extends StatelessWidget {
  const _LearnBanner({this.onTap, this.portraitMobile = false});
  final VoidCallback? onTap;
  final bool portraitMobile;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: portraitMobile
            ? 142
            : mobile
            ? 118
            : 150,
      ),
      decoration: BoxDecoration(
        color: StudentDensityTokens.darkSecondary,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? 20 : 28,
              vertical: portraitMobile
                  ? 22
                  : mobile
                  ? 17
                  : 24,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!portraitMobile) ...[
                        const StudentDensityEyebrow(
                          'LEARNING START',
                          color: Color(0xFF9B9BA3),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        portraitMobile ? '학습 시작' : '학습하기',
                        style: TextStyle(
                          fontSize: portraitMobile
                              ? 36
                              : mobile
                              ? 26
                              : 38,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      if (!portraitMobile) ...[
                        const SizedBox(height: 7),
                        const Text(
                          '이어하기 · 코스보기 · 복습 · 문제세트 · 시험지 · 교재보기',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFAFAFB6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Container(
                  width: portraitMobile
                      ? 68
                      : mobile
                      ? 56
                      : 58,
                  height: portraitMobile
                      ? 68
                      : mobile
                      ? 56
                      : 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: StudentDensityTokens.dark,
                    size: 34,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyQuestProgressCard extends StatefulWidget {
  const _DailyQuestProgressCard({required this.courseId});

  final String? courseId;

  @override
  State<_DailyQuestProgressCard> createState() =>
      _DailyQuestProgressCardState();
}

class _DailyQuestProgressCardState extends State<_DailyQuestProgressCard> {
  Future<DailyQuestBundle?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _DailyQuestProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId) {
      _future = _load();
    }
  }

  Future<DailyQuestBundle?> _load() async {
    final courseId = widget.courseId?.trim();
    if (courseId == null || courseId.isEmpty) return null;
    return ApiClient.instance.fetchDailyQuestBundle(courseId: courseId);
  }

  Future<void> _openDailyQuestModal() async {
    await showDailyTestModal(context: context, courseId: widget.courseId);
    if (!mounted) return;
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DailyQuestBundle?>(
      future: _future,
      builder: (context, snapshot) {
        final bundle = snapshot.data;
        final items = bundle?.items ?? const <DailyQuestItem>[];
        final loadFailed = snapshot.hasError;
        final completed = items
            .where((item) => item.status == 'completed')
            .length;
        final total = items.length;
        final claimable = items.any(
          (item) =>
              item.claimable ||
              (item.status == 'completed' && !item.rewardClaimed),
        );
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final meta = loadFailed
            ? '퀘스트를 불러오는데 실패했어요'
            : widget.courseId?.trim().isNotEmpty == true
            ? loading
                  ? '불러오는 중'
                  : '오늘 진행 · 자세히 보기'
            : '활성 코스가 없습니다.';

        return _HomeStatusCard(
          label: '일일 테스트',
          value: loadFailed ? '오류' : '$completed / $total',
          meta: meta,
          showBadge: claimable,
          onTap: _openDailyQuestModal,
        );
      },
    );
  }
}

class _BottomSection extends StatelessWidget {
  const _BottomSection();

  /// 필요 변수는 레이팅 산정 가능 여부와 현재 화면 문맥이다.
  /// 작동 원리는 레이팅이 준비되면 상세 보고서를, 준비 전이면 레벨 테스트를 연다.
  void _handleRatingTap(BuildContext context, bool isEligible) {
    if (isEligible) {
      showRatingDetailModal(context: context);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LevelTestHomePage()));
  }

  /// 필요 변수는 모바일 여부와 공통 학생 화면의 본문 최대 폭·가로 여백이다.
  /// 작동 원리는 레이팅부터 공지까지의 하단 콘텐츠를 시안과 같은 1500px 본문 안에
  /// 배치해 넓은 모니터에서도 카드 비율과 좌우 정렬이 학습 영역에서 이어지게 한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final horizontalPadding = studentDensityHorizontalPadding(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: StudentDensityTokens.desktopMaxWidth,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            horizontalPadding,
          ),
          child: Column(
            children: [
              Flex(
                direction: mobile ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bottomResponsiveChild(
                    mobile: mobile,
                    flex: 85,
                    child: ValueListenableBuilder<ActivitySnapshot>(
                      valueListenable: ActivityStore.notifier,
                      builder: (context, activitySnapshot, __) {
                        final solvedCount = activitySnapshot.totalSolvedCount;
                        final remainingCount =
                            (_ratingEstimateMinSolved - solvedCount).clamp(
                              0,
                              _ratingEstimateMinSolved,
                            );
                        final isEligible = remainingCount == 0;
                        return ValueListenableBuilder<RatingSnapshot>(
                          valueListenable: RatingStore.notifier,
                          builder: (context, ratingSnapshot, _) {
                            final ovrText = ratingSnapshot.isLoaded
                                ? _formatRatingOvr(ratingSnapshot.ovr)
                                : '--';
                            final deltaOvr =
                                ratingSnapshot.delta / _ratingOvrDivider;
                            final deltaText = ratingSnapshot.isLoaded
                                ? _formatRatingDelta(deltaOvr)
                                : '--';
                            final deltaColor = deltaOvr > 0
                                ? Colors.red
                                : deltaOvr < 0
                                ? Colors.blue
                                : Colors.black54;
                            final risePercent = _ratingRisePercent(deltaOvr);
                            final percentText = ratingSnapshot.isLoaded
                                ? '$risePercent%'
                                : '--';
                            final ctaText = isEligible
                                ? '레이팅 자세히 보기 및 보고서 보기'
                                : '레벨테스트 풀러 가기';

                            return _HomeRatingCard(
                              isEligible: isEligible,
                              remainingCount: remainingCount,
                              ovrText: ovrText,
                              deltaText: deltaText,
                              deltaColor: deltaColor,
                              risePercent: risePercent,
                              percentText: percentText,
                              ctaText: ctaText,
                              onTap: () =>
                                  _handleRatingTap(context, isEligible),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(width: mobile ? 0 : 14, height: mobile ? 14 : 0),
                  _bottomResponsiveChild(
                    mobile: mobile,
                    flex: 115,
                    child: Container(
                      width: double.infinity,
                      height: mobile ? 210 : 240,
                      margin: const EdgeInsets.only(top: 14),
                      decoration: _cardDeco(
                        radius: 26,
                        color: const Color(0xFFF0F0F3),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            bottom: -64,
                            child: Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFD7D7DB),
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 124,
                                  height: 124,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFD7D7DB),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const StudentDensityEyebrow('REAL-TIME MATCH'),
                                const SizedBox(height: 12),
                                const Text(
                                  '수학 대결장',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  '1v1 · 2v2 실시간 실력 대결',
                                  style: TextStyle(
                                    color: StudentDensityTokens.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: () => showArena(context),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: StudentDensityTokens.dark,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('대결장 입장 ›'),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 22,
                            right: 24,
                            child: Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: StudentDensityTokens.dark,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _ActivityRewardsRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeRatingCard extends StatelessWidget {
  const _HomeRatingCard({
    required this.isEligible,
    required this.remainingCount,
    required this.ovrText,
    required this.deltaText,
    required this.deltaColor,
    required this.risePercent,
    required this.percentText,
    required this.ctaText,
    required this.onTap,
  });

  final bool isEligible;
  final int remainingCount;
  final String ovrText;
  final String deltaText;
  final Color deltaColor;
  final int risePercent;
  final String percentText;
  final String ctaText;
  final VoidCallback onTap;

  /// 필요 변수는 레이팅 값·변화량·산정 가능 여부와 상세 이동 함수다.
  /// 작동 원리는 HTML 시안의 MY RATING 제목, 등급 배지, 상승 진행률을 유지하고
  /// 산정 전에는 같은 카드 안에서 남은 문제 수와 레벨 테스트 이동을 보여준다.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 240,
        child: StudentDensitySurface(
          padding: const EdgeInsets.all(20),
          radius: 26,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StudentDensityEyebrow('MY RATING'),
              const SizedBox(height: 8),
              if (isEligible) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OVR $ovrText',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '전날 대비 $deltaText · B Tier',
                            style: TextStyle(color: deltaColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const _HomeRankBadge(),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    _DashboardPill('상승 $percentText'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: risePercent / 100,
                        minHeight: 7,
                        color: StudentDensityTokens.dark,
                        backgroundColor: const Color(0xFFE4E4E7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: StudentDensityTokens.dark,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('레이팅 자세히 보기'),
                ),
              ] else ...[
                const Text(
                  '나의 레이팅',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '아직 문제를 다 풀지 않았어요',
                          style: TextStyle(
                            color: StudentDensityTokens.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '레이팅 추정까지 $remainingCount문제 남았어요',
                          style: const TextStyle(
                            color: StudentDensityTokens.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 12),
                _InlineCta(
                  label: ctaText,
                  onTap: onTap,
                  iconSize: 13,
                  radius: 8,
                  textStyle: _ts(size: 13),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeRankBadge extends StatelessWidget {
  const _HomeRankBadge();

  /// 필요 변수는 고정된 홈 미리보기 등급이다.
  /// 작동 원리는 HTML의 검은 62px B 등급 배지를 흰 이중 테두리와 함께 재현한다.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: StudentDensityTokens.dark,
        border: Border.all(color: Colors.white, width: 4),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12)],
      ),
      child: const Text(
        'B',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActivityRewardsRow extends StatelessWidget {
  const _ActivityRewardsRow();

  /// 필요한 변수는 하단 영역의 실제 가로 폭과 현재 월의 주 수다.
  /// 작동 원리: HTML `home-footer-grid`처럼 PC는 1.35:.72:.9, 태블릿은 달력 전체 폭 후
  /// 1.2:.8, 모바일은 세로로 배치하고 6주인 달에는 세 카드 높이를 함께 늘린다.
  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final footerHeight = _homeMonthCells(DateTime.now()).length > 35
            ? _homeFooterSixWeekHeight
            : _homeFooterDesktopHeight;
        if (viewportWidth <= 780) {
          return Column(
            key: const ValueKey('student-home-footer-mobile'),
            children: [
              _ActivityHistoryCard(),
              SizedBox(height: 10 * scale),
              const _ChallengeAchievementCard(),
              SizedBox(height: 10 * scale),
              const _SystemNoticeCard(),
            ],
          );
        }

        if (viewportWidth <= 1180) {
          return Column(
            key: const ValueKey('student-home-footer-tablet'),
            children: [
              _ActivityHistoryCard(),
              SizedBox(height: 12 * scale),
              SizedBox(
                height: footerHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(
                      flex: 12,
                      child: _ChallengeAchievementCard(),
                    ),
                    SizedBox(width: 12 * scale),
                    const Expanded(flex: 8, child: _SystemNoticeCard()),
                  ],
                ),
              ),
            ],
          );
        }

        return SizedBox(
          key: const ValueKey('student-home-footer-desktop'),
          height: footerHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 135, child: _ActivityHistoryCard()),
              SizedBox(width: 12 * scale),
              const Expanded(flex: 72, child: _ChallengeAchievementCard()),
              SizedBox(width: 12 * scale),
              const Expanded(flex: 90, child: _SystemNoticeCard()),
            ],
          ),
        );
      },
    );
  }
}

class _SystemNoticeCard extends StatefulWidget {
  const _SystemNoticeCard();

  @override
  State<_SystemNoticeCard> createState() => _SystemNoticeCardState();
}

class _SystemNoticeCardState extends State<_SystemNoticeCard> {
  late Future<List<StudyGroupNotice>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadNotices();
  }

  /// 필요한 변수는 전체 공지와 현재 학생이 속한 학원 공지, 각 공지의 갱신 시각이다.
  /// 작동 원리는 두 캐시 GET을 병렬 실행하고 중복을 제거한 뒤 최신순으로 정렬해 홈에는 상위 3개만 노출한다.
  Future<List<StudyGroupNotice>> _loadNotices() async {
    final results = await Future.wait<List<StudyGroupNotice>>([
      ApiClient.instance
          .listGlobalSystemNotices(limit: 20)
          .onError((_, _) => const <StudyGroupNotice>[]),
      ApiClient.instance
          .listMySystemGroupNotices(limit: 20)
          .onError((_, _) => const <StudyGroupNotice>[]),
    ]);
    final unique = <String, StudyGroupNotice>{};
    for (final notice in results.expand((items) => items)) {
      final key = notice.noticeId.isNotEmpty
          ? notice.noticeId
          : '${notice.scope}|${notice.groupId}|${notice.title}|${notice.updatedAt}';
      unique[key] = notice;
    }
    final notices = unique.values.toList(growable: false);
    notices.sort((a, b) {
      final ad =
          DateTime.tryParse(a.updatedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd =
          DateTime.tryParse(b.updatedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return notices;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StudyGroupNotice>>(
      future: _future,
      builder: (context, snapshot) {
        final notices = snapshot.data ?? const <StudyGroupNotice>[];
        return StudentDensitySurface(
          radius: 26,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '공지사항',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  OutlinedButton(
                    onPressed: () => showStudentNotifications(context),
                    child: const Text('전체 보기'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildBody(context, snapshot, notices),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<List<StudyGroupNotice>> snapshot,
    List<StudyGroupNotice> notices,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 72),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasError) {
      return const _NoticePreviewRow(
        icon: '!',
        title: '공지를 불러오지 못했습니다.',
        meta: '알림 센터에서 다시 확인해 주세요.',
      );
    }
    if (notices.isEmpty) {
      return const _NoticePreviewRow(
        icon: '◎',
        title: '새로운 공지가 없습니다.',
        meta: '전체 공지 · 학원 공지',
      );
    }
    return Column(
      children: [
        for (var index = 0; index < notices.take(3).length; index++) ...[
          _NoticePreviewRow(
            icon: index == 1 ? '◎' : '!',
            title: notices[index].title,
            meta:
                '${notices[index].scope == 'global' ? '전체 공지' : (notices[index].groupName ?? '학원 공지')} · ${_noticeDateLabel(notices[index].updatedAt)}',
            active: index == 0,
            onTap: () => _showNoticePreview(context, notices[index]),
          ),
          if (index != notices.take(3).length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  void _showNoticePreview(BuildContext context, StudyGroupNotice notice) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(notice.title),
        content: SizedBox(
          width: 720,
          height: 520,
          child: InAppWebView(
            initialData: InAppWebViewInitialData(
              data: _buildNoticeHtmlDocument(notice.title, notice.contentHtml),
            ),
            initialSettings: InAppWebViewSettings(transparentBackground: true),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}

class _NoticePreviewRow extends StatelessWidget {
  const _NoticePreviewRow({
    required this.icon,
    required this.title,
    required this.meta,
    this.active = false,
    this.onTap,
  });

  final String icon;
  final String title;
  final String meta;
  final bool active;
  final VoidCallback? onTap;

  /// 필요한 변수는 공지 아이콘·제목·범위·날짜와 강조 상태다.
  /// 작동 원리: HTML 공지 목록의 72px 행과 첫 행 검은 반전 상태를 그대로 재현한다.
  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : StudentDensityTokens.ink;
    final secondary = active ? Colors.white70 : StudentDensityTokens.muted;
    return Material(
      color: active ? StudentDensityTokens.dark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: active ? StudentDensityTokens.dark : StudentDensityTokens.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : StudentDensityTokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: StudentDensityTokens.line),
                  ),
                  child: Text(
                    icon,
                    style: const TextStyle(
                      color: StudentDensityTokens.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        style: TextStyle(color: secondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text('›', style: TextStyle(color: foreground, fontSize: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeAchievementCard extends StatelessWidget {
  const _ChallengeAchievementCard();

  /// 필요한 변수는 활동 기록, 계정 레벨과 업적 카탈로그 평가 결과다.
  /// 작동 원리: 보관함과 동일한 카탈로그로 획득 수, 곧 획득할 트로피, 획득한
  /// 트로피를 계산해 홈 미리보기와 상세 보관함의 수치가 항상 일치하도록 한다.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActivitySnapshot>(
      valueListenable: ActivityStore.notifier,
      builder: (context, snapshot, _) {
        return ValueListenableBuilder<AccountSummary?>(
          valueListenable: ActivityStore.accountSummaryNotifier,
          builder: (context, account, __) {
            final accountLevel = account?.level ?? 0;
            final allBadges = ActivityBadgeCatalog.evaluate(
              snapshot,
              accountLevel: accountLevel,
            );
            final earnedBadges = ActivityBadgeCatalog.earnedBadges(
              snapshot,
              accountLevel: accountLevel,
            );
            final nearBadges = ActivityBadgeCatalog.nextBadges(
              snapshot,
              accountLevel: accountLevel,
              limit: 2,
            );
            return LayoutBuilder(
              builder: (context, constraints) {
                // 필요한 변수는 HTML 3열 배치에서 할당된 업적 카드 폭이다.
                // 작동 원리: 좁은 PC 열에서 제목이 2줄이 되면 내용 높이를 늘려 오버플로를 방지한다.
                final contentHeight = constraints.maxWidth < 360
                    ? 340.0
                    : 286.0;
                return StudentDensitySurface(
                  padding: const EdgeInsets.all(20),
                  radius: 26,
                  child: SizedBox(
                    height: contentHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StudentDensityEyebrow('ACHIEVEMENT'),
                                  SizedBox(height: 8),
                                  Text(
                                    '도전과제 / 업적',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _DashboardPill(
                              '${earnedBadges.length} / ${allBadges.length}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _AchievementTrophySection(
                          title: '곧 획득할 트로피',
                          emptyLabel: '모든 트로피를 획득했어요.',
                          trophies: nearBadges,
                        ),
                        const SizedBox(height: 12),
                        _AchievementTrophySection(
                          title: '획득한 트로피',
                          emptyLabel: '첫 학습 기록으로 트로피를 모아보세요.',
                          trophies: earnedBadges
                              .take(3)
                              .toList(growable: false),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => showActivityBadgeDialog(
                              context: context,
                              snapshot: snapshot,
                              accountLevel: accountLevel,
                            ),
                            child: const Text('업적 보관함'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AchievementTrophySection extends StatelessWidget {
  const _AchievementTrophySection({
    required this.title,
    required this.emptyLabel,
    required this.trophies,
  });

  final String title;
  final String emptyLabel;
  final List<ActivityBadgeProgress> trophies;

  /// 필요한 변수는 구분 제목, 비어 있을 때 안내 문구, 표시할 업적 진행 목록이다.
  /// 작동 원리: 홈에는 최대 세 개의 트로피만 보여 주고 각 트로피의 현재 달성량을
  /// 함께 표시해, 상세 보관함을 열기 전에도 다음 행동을 빠르게 파악하게 한다.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: StudentDensityTokens.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        if (trophies.isEmpty)
          Text(
            emptyLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 11,
            ),
          )
        else
          Row(
            children: [
              for (var index = 0; index < trophies.length; index++) ...[
                Expanded(
                  child: _AchievementTrophyPreview(progress: trophies[index]),
                ),
                if (index != trophies.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _AchievementTrophyPreview extends StatelessWidget {
  const _AchievementTrophyPreview({required this.progress});

  final ActivityBadgeProgress progress;

  /// 필요한 변수는 업적의 현재 진행 상태와 트로피 정의다.
  /// 작동 원리: 기존 트로피 위젯을 그대로 사용하고 이름·달성량만 작은 보조 정보로
  /// 붙여 홈 카드에서도 트로피의 종류와 목표를 구분할 수 있게 한다.
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${progress.badge.title} · ${progress.progressText}',
      child: Row(
        children: [
          ActivityBadgeIcon(progress: progress, size: 36),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              progress.progressText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: progress.isEarned
                    ? progress.badge.color
                    : StudentDensityTokens.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const int _activityHistoryDayCount = 56;

Color _activityTileColorForScore(int score) {
  final level = ActivityStore.activityLevelForScore(score);
  return _activityTileColors[level.clamp(0, _activityTileColors.length - 1)];
}

int _activityStreakDays(ActivitySnapshot snapshot) {
  var streak = 0;
  var cursor = _dateOnly(DateTime.now());
  while (ActivityStore.scoreForDate(snapshot, cursor) > 0) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// 필요 변수는 표시할 달의 연도와 월이다.
/// 작동 원리는 일요일 시작 월간 달력에 필요한 앞쪽 빈 칸과 실제 날짜를 계산하고,
/// 마지막 주가 완성되도록 35칸 또는 42칸으로 반환한다.
List<DateTime?> _homeMonthCells(DateTime month) {
  final firstDay = DateTime(month.year, month.month);
  final dayCount = DateTime(month.year, month.month + 1, 0).day;
  final leadingBlankCount = firstDay.weekday % DateTime.daysPerWeek;
  final usedCellCount = leadingBlankCount + dayCount;
  final totalCellCount = ((usedCellCount + 6) ~/ 7) * 7;
  return List<DateTime?>.generate(totalCellCount, (index) {
    final day = index - leadingBlankCount + 1;
    if (day < 1 || day > dayCount) return null;
    return DateTime(month.year, month.month, day);
  });
}

/// 필요 변수는 달력 기준 날짜다.
/// 작동 원리는 HTML 시안의 영문 월·연도 eyebrow 형식으로 변환한다.
String _homeMonthLabel(DateTime month) {
  const labels = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];
  return '${labels[month.month - 1]} ${month.year}';
}

class _ActivityHistoryCard extends StatefulWidget {
  const _ActivityHistoryCard();

  @override
  State<_ActivityHistoryCard> createState() => _ActivityHistoryCardState();
}

class _ActivityHistoryCardState extends State<_ActivityHistoryCard> {
  void _showModal() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        final width = math.min(media.size.width - 28, 560.0);
        final height = math.min(media.size.height - 40, 620.0);
        return Dialog(
          insetPadding: const EdgeInsets.all(14),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: const _ActivityHistorySheet(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActivitySnapshot>(
      valueListenable: ActivityStore.notifier,
      builder: (context, snapshot, _) {
        final now = _dateOnly(DateTime.now());
        final days = _homeMonthCells(now);
        return StudentDensitySurface(
          padding: const EdgeInsets.all(20),
          radius: 26,
          onTap: _showModal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StudentDensityEyebrow(_homeMonthLabel(now)),
                        const SizedBox(height: 8),
                        const Text(
                          '일정 달력',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _showModal,
                    child: const Text('전체 일정'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  mainAxisExtent: 48,
                ),
                itemBuilder: (context, index) {
                  final date = days[index];
                  final score = date == null
                      ? 0
                      : ActivityStore.scoreForDate(snapshot, date);
                  final isToday = date == now;
                  final hasActivity = score > 0;
                  return Opacity(
                    opacity: date == null ? .35 : 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isToday
                            ? StudentDensityTokens.dark
                            : StudentDensityTokens.surfaceMuted,
                        border: Border.all(color: StudentDensityTokens.line),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: date == null
                          ? null
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    color: isToday
                                        ? Colors.white
                                        : StudentDensityTokens.ink,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (hasActivity)
                                  Positioned(
                                    bottom: 5,
                                    child: Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? Colors.white
                                            : StudentDensityTokens.dark,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
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

class _ActivityHistorySheet extends StatefulWidget {
  const _ActivityHistorySheet();

  @override
  State<_ActivityHistorySheet> createState() => _ActivityHistorySheetState();
}

class _ActivityHistorySheetState extends State<_ActivityHistorySheet> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return SafeArea(
      top: false,
      child: ValueListenableBuilder<ActivitySnapshot>(
        valueListenable: ActivityStore.notifier,
        builder: (context, snapshot, _) {
          final days = ActivityStore.recentDays(
            snapshot,
            _activityHistoryDayCount,
          );
          final selectedIndex = _selectedIndex == null
              ? days.length - 1
              : math.min(_selectedIndex!, days.length - 1);
          final selectedRecord = days[selectedIndex];
          final activeDays = days.where((record) => record.score > 0).length;
          final streakDays = _activityStreakDays(snapshot);
          final todayPercent = ActivityStore.activityPercentFromScore(
            ActivityStore.scoreForDate(snapshot, DateTime.now()),
          );
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  22 * scale,
                  18 * scale,
                  14 * scale,
                  8 * scale,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36 * scale,
                      height: 36 * scale,
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10 * scale),
                      ),
                      child: Icon(
                        Icons.calendar_month,
                        color: _green,
                        size: 20 * scale,
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '매일 출석',
                            style: _ts(
                              size: 19 * scale,
                              weight: FontWeight.w900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2 * scale),
                          Text(
                            '최근 $_activityHistoryDayCount일 학습 기록',
                            style: _ts(size: 11 * scale, color: Colors.black45),
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
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    22 * scale,
                    8 * scale,
                    22 * scale,
                    22 * scale,
                  ),
                  children: [
                    _ActivitySummaryStrip(
                      activeDays: activeDays,
                      streakDays: streakDays,
                      todayPercent: todayPercent,
                    ),
                    SizedBox(height: 16 * scale),
                    Container(
                      padding: EdgeInsets.all(14 * scale),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAF8),
                        borderRadius: BorderRadius.circular(14 * scale),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return _ActivityHeatmap(
                            days: days,
                            selectedIndex: selectedIndex,
                            maxWidth: constraints.maxWidth,
                            onSelected: (index) {
                              setState(() => _selectedIndex = index);
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    _ActivityDayDetail(record: selectedRecord),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityHeatmap extends StatelessWidget {
  const _ActivityHeatmap({
    required this.days,
    required this.selectedIndex,
    required this.maxWidth,
    required this.onSelected,
  });

  final List<ActivityDayRecord> days;
  final int selectedIndex;
  final double maxWidth;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    const rows = 7;
    final columns = (days.length / rows).ceil();
    final gap = 5 * scale;
    final available = maxWidth - gap * (columns - 1);
    final tileSize = (available / columns).clamp(13.0, 22.0);
    final gridWidth = columns * tileSize + gap * (columns - 1);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: gridWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(columns, (column) {
            return Padding(
              padding: EdgeInsets.only(right: column == columns - 1 ? 0 : gap),
              child: Column(
                children: List.generate(rows, (row) {
                  final index = column * rows + row;
                  if (index >= days.length) {
                    return SizedBox(width: tileSize, height: tileSize);
                  }
                  final record = days[index];
                  final isSelected = index == selectedIndex;
                  return Padding(
                    padding: EdgeInsets.only(bottom: row == rows - 1 ? 0 : gap),
                    child: Tooltip(
                      message: _activityTileSummary(record),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4 * scale),
                        onTap: () => onSelected(index),
                        child: Container(
                          width: tileSize,
                          height: tileSize,
                          decoration: BoxDecoration(
                            color: _activityTileColorForScore(record.score),
                            borderRadius: BorderRadius.circular(4 * scale),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black87
                                  : Colors.black.withValues(alpha: 0.06),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ),
    );
  }
}

String _activityTileSummary(ActivityDayRecord record) {
  return '${_formatDateLabel(record.dateKey)} · ${record.score}점';
}

class _ActivitySummaryStrip extends StatelessWidget {
  const _ActivitySummaryStrip({
    required this.activeDays,
    required this.streakDays,
    required this.todayPercent,
  });

  final int activeDays;
  final int streakDays;
  final double todayPercent;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Row(
      children: [
        Expanded(
          child: _ActivityMiniMetric(
            label: '오늘',
            value: '${(todayPercent * 100).round()}%',
            icon: Icons.bolt,
          ),
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: _ActivityMiniMetric(
            label: '연속',
            value: '$streakDays일',
            icon: Icons.local_fire_department,
          ),
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: _ActivityMiniMetric(
            label: '활동일',
            value: '$activeDays일',
            icon: Icons.check_circle,
          ),
        ),
      ],
    );
  }
}

class _ActivityMiniMetric extends StatelessWidget {
  const _ActivityMiniMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 11 * scale,
        vertical: 10 * scale,
      ),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Row(
        children: [
          Icon(icon, color: _green, size: 16 * scale),
          SizedBox(width: 7 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: _ts(
                    size: 9 * scale,
                    weight: FontWeight.w700,
                    color: Colors.black45,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: _ts(size: 13 * scale, weight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityDayDetail extends StatelessWidget {
  const _ActivityDayDetail({required this.record});

  final ActivityDayRecord record;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final percent = ActivityStore.activityPercentFromScore(record.score);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_formatDateLabel(record.dateKey)} 활동',
                  style: _ts(size: 16 * scale, weight: FontWeight.w900),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: _ts(
                  size: 18 * scale,
                  weight: FontWeight.w900,
                  color: _green,
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 7 * scale,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              color: _lightGreen,
            ),
          ),
          SizedBox(height: 14 * scale),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8 * scale,
            crossAxisSpacing: 8 * scale,
            childAspectRatio: 2.7,
            children: [
              _ActivityDetailTile(
                icon: Icons.edit_note,
                label: '문제',
                values: record.problemNumbers,
                unit: '문제',
              ),
              _ActivityDetailTile(
                icon: Icons.assignment_turned_in,
                label: '시험지',
                values: record.examNumbers,
                unit: '회',
              ),
              _ActivityDetailTile(
                icon: Icons.menu_book,
                label: '교재',
                values: record.bookNumbers,
                unit: '회',
              ),
              _ActivityDetailTile(
                icon: Icons.school,
                label: '강의',
                values: record.courseNumbers,
                unit: '회',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityDetailTile extends StatelessWidget {
  const _ActivityDetailTile({
    required this.icon,
    required this.label,
    required this.values,
    required this.unit,
  });

  final IconData icon;
  final String label;
  final List<String> values;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final text = values.isEmpty ? '기록 없음' : _compactActivityValues(values);
    final hasValues = values.isNotEmpty;
    return Container(
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 28 * scale,
            height: 28 * scale,
            decoration: BoxDecoration(
              color: hasValues
                  ? _green.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            child: Icon(
              icon,
              size: 16 * scale,
              color: hasValues ? _green : Colors.black38,
            ),
          ),
          SizedBox(width: 9 * scale),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label ${values.length}$unit',
                  style: _ts(size: 11 * scale, weight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2 * scale),
                Text(
                  text,
                  style: _ts(
                    size: 10 * scale,
                    color: hasValues ? Colors.black54 : Colors.black38,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _compactActivityValues(List<String> values) {
  final visible = values.take(2).map(_compactActivityValue).join(', ');
  final hiddenCount = values.length - 2;
  if (hiddenCount <= 0) return visible;
  return '$visible 외 $hiddenCount개';
}

String _compactActivityValue(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 12) return trimmed;
  return '${trimmed.substring(0, 8)}...';
}

class _SimpleProgressBar extends StatelessWidget {
  const _SimpleProgressBar({
    required this.value,
    required this.width,
    this.height,
  });
  final double value;
  final double width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6 * scale),
        child: LinearProgressIndicator(
          value: value,
          minHeight: height ?? 6 * scale,
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
    if (values.length < 2) return;
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
    this.contentScale = 1.0,
  });
  final double percent;
  final Color color;
  final String label;
  final String subtitle;
  final double contentScale;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context) * contentScale;
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
