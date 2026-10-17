import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/features/level_test/level_test.dart';
import 'package:s11/app/router.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/shared/ui/drawer/student_navigation.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/curriculum_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/daily_test_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/rating_detail_modal.dart';
import 'package:s11/features/arena/arena_page.dart';
import 'package:s11/features/arena/arena_api.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/study_mode_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/today_tasks_modal.dart';
import 'package:s11/sessions/learning_tools/ui/pages/notepad_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/student_learning_tools_page.dart';
import 'package:s11/sessions/graph_tools/session/jsx_graph_page.dart';
import 'package:s11/sessions/student_dashboard/ui/widgets/activity_badges.dart';
import 'package:s11/sessions/student_dashboard/business/activity_badge_catalog.dart';
import 'package:s11/sessions/student_dashboard/ui/widgets/learning_tools_strip.dart';
import 'package:s11/sessions/student_dashboard/ui/widgets/html_home_dashboard.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/business/repositories/attendance_store.dart';
import 'package:s11/shared/business/repositories/rating_store.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/modal/level_detail_modal.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/business/repositories/social_notification_store.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/course_service.dart';

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
const String _activeCourseStorageKey = 'student.active_course.v1';

const _shadow = BoxShadow(
  blurRadius: 4,
  color: Color(0x33000000),
  offset: Offset(0, 2),
);

const int _ratingEstimateMinSolved = 50;
const double _homeFooterDesktopHeight = 384;
const double _homeFooterSixWeekHeight = 438;

/// 필요한 변수는 현재 모바일 viewport의 공용 바깥 여백이다.
/// 작동 원리: 홈의 인사·학습·현황 섹션에 14px 안쪽 여백을 더해 같은 수직축을 만든다.
double _mobileHomeContentInset(BuildContext context) {
  return studentDensityHorizontalPadding(context) + 14;
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

String? _formatHomeTaskTime(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final time = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
  if (time != null) return '${time[1]!.padLeft(2, '0')}:${time[2]}';
  if (!raw.contains('T')) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
}

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

enum _HomeStudyAction {
  resume,
  courses,
  review,
  problemsets,
  exams,
  textbooks;

  static _HomeStudyAction? fromId(String value) {
    for (final action in values) {
      if (action.name == value) return action;
    }
    return null;
  }
}

class _TodayTaskItem extends TodayTaskEntry {
  const _TodayTaskItem({
    required super.title,
    required super.caption,
    required super.icon,
    super.timeLabel,
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
  const MainStudentPage({super.key, this.username, this.initialScene});
  final String? username;
  final String? initialScene;

  @override
  State<MainStudentPage> createState() => _MainStudentPageState();
}

class _MainStudentPageState extends State<MainStudentPage> {
  final ScrollController _scrollController = ScrollController();
  List<_TodayTaskItem> _todayTeacherTasks = const [];
  List<_TodayTaskItem> _todayPersonalTasks = const [];
  late Future<void> _todayTasksLoadFuture;
  bool _teacherTasksLoading = true;
  bool _personalTasksLoading = true;
  String? _teacherTasksError;
  String? _personalTasksError;
  String? _displayName;
  Key _courseLoaderKey = UniqueKey();
  bool _courseSelectionPending = false;
  bool _initialSceneOpened = false;

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
    unawaited(
      ApiClient.instance
          .fetchAccountSummary()
          .then((summary) {
            ActivityStore.accountSummaryNotifier.value = summary;
          })
          .catchError((_) {}),
    );
    _todayTasksLoadFuture = Future.wait([
      _refreshTeacherTasks(),
      _refreshPersonalTasks(),
    ]).then((_) {});
    if (widget.initialScene?.trim().isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _initialSceneOpened) return;
        _initialSceneOpened = true;
        _openInitialScene(widget.initialScene!.trim());
      });
    }
  }

  /// 검색·딥링크가 지정한 홈 내부 장면을 첫 프레임 뒤에 연다.
  /// 데이터가 없는 경우에도 실제 빈 상태 시트를 보여 주며 샘플 데이터를 만들지 않는다.
  void _openInitialScene(String scene) {
    switch (scene) {
      case 'today-tasks':
        unawaited(
          _showHomeTodayTasks([..._todayTeacherTasks, ..._todayPersonalTasks]),
        );
        return;
      case 'rating-detail':
        unawaited(showRatingDetailModal(context: context));
        return;
      case 'achievements':
        showActivityBadgeDialog(
          context: context,
          snapshot: ActivityStore.notifier.value,
          accountLevel: ActivityStore.accountSummaryNotifier.value?.level ?? 0,
        );
        return;
      case 'activity-history':
        unawaited(Navigator.of(context).pushNamed(AppRoutes.activityHistory));
        return;
      case 'study-mode':
        unawaited(Navigator.of(context).pushNamed(AppRoutes.restrictionMode));
        return;
      case 'course-select':
        unawaited(_handleCourseTap());
        return;
    }
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
    _teacherTasksLoading = true;
    _teacherTasksError = null;
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
            timeLabel: _formatHomeTaskTime(item.assignment.dueDate),
            target: isCourse ? _TodayTaskTarget.course : _TodayTaskTarget.group,
            targetId: isCourse
                ? item.assignment.refId
                : item.assignment.groupId,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _todayTeacherTasks = tasks);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _teacherTasksError = studentFacingApiError(
          error,
          fallback: '교사 지정 과제를 불러오지 못했습니다.',
        ),
      );
    } finally {
      _teacherTasksLoading = false;
    }
  }

  /// 필요한 변수는 서버에 저장된 개인 일정의 날짜와 제목이다.
  /// 작동 원리: 오늘 날짜와 같은 일정만 홈의 알림 카드로 만들고, 선택 시 일정 화면으로 이동시킨다.
  Future<void> _refreshPersonalTasks() async {
    _personalTasksLoading = true;
    _personalTasksError = null;
    try {
      final res = await ApiClient.instance.listMyStudentSchedule();
      final today = _dateOnly(DateTime.now());
      final tasks = (res.data ?? const <StudentScheduleTask>[])
          .where((item) {
            final date = DateTime.tryParse(item.date);
            return date != null && _dateOnly(date) == today;
          })
          .where((item) => item.title.trim().isNotEmpty)
          .map(
            (item) => _TodayTaskItem(
              title: item.title.trim(),
              caption: '내 일정 · 일정에서 보기',
              icon: Icons.event_note_rounded,
              timeLabel: _formatHomeTaskTime(item.startTime),
              target: _TodayTaskTarget.schedule,
            ),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() => _todayPersonalTasks = tasks);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _personalTasksError = studentFacingApiError(
          error,
          fallback: '개인 일정을 불러오지 못했습니다.',
        ),
      );
    } finally {
      _personalTasksLoading = false;
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
    if (_courseSelectionPending) return;
    _courseSelectionPending = true;
    try {
      final selected = await showCurriculumModal(context: context);
      if (!mounted) return;
      if (selected == null) {
        setState(() => _courseLoaderKey = UniqueKey());
        return;
      }
      if (selected.id.trim().isEmpty) {
        throw StateError('선택한 코스의 식별자가 없습니다.');
      }
      await ApiClient.instance.setUserStorage(
        _activeCourseStorageKey,
        selected.id,
      );
      if (!mounted) return;
      setState(() => _courseLoaderKey = UniqueKey());
      await Navigator.of(context).pushNamed(
        Uri(
          path: AppRoutes.courseRuntime,
          queryParameters: {'course_id': selected.id},
        ).toString(),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            studentFacingApiError(
              error,
              fallback: '현재 코스를 저장하지 못했어요. 다시 선택해 주세요.',
            ),
          ),
        ),
      );
    } finally {
      _courseSelectionPending = false;
    }
  }

  /// HTML 홈의 6개 학습 타일을 먼저 요약 시트로 열고, 시트의 단일 CTA에서
  /// 기존 실제 화면으로 이동한다. 큰 영웅 CTA의 이어하기 직행은 유지한다.
  void _handleStudyAction(String id, Course? course, List<Course> courseList) {
    final action = _HomeStudyAction.fromId(id);
    if (action == null) return;
    final title = switch (action) {
      _HomeStudyAction.resume => '이어하기',
      _HomeStudyAction.courses => '코스보기',
      _HomeStudyAction.review => '복습',
      _HomeStudyAction.problemsets => '문제세트',
      _HomeStudyAction.exams => '시험지',
      _HomeStudyAction.textbooks => '교재보기',
    };
    final description = switch (action) {
      _HomeStudyAction.resume =>
        course == null
            ? '이어갈 수 있는 코스가 없습니다. 코스를 먼저 선택해 주세요.'
            : '${course.title}\n마지막 학습 위치에서 이어갑니다.',
      _HomeStudyAction.courses => '수강 중인 코스를 확인하고 새 코스를 찾아보세요.',
      _HomeStudyAction.review => '저장된 오답과 복습 대상을 확인합니다.',
      _HomeStudyAction.problemsets => '책가방에서 보유한 문제세트를 확인합니다.',
      _HomeStudyAction.exams => '책가방에서 보유한 시험지를 확인합니다.',
      _HomeStudyAction.textbooks => '책가방에서 학습할 교재를 선택합니다.',
    };
    final cta = switch (action) {
      _HomeStudyAction.resume => course == null ? '코스 선택하기' : '학습 이어가기',
      _HomeStudyAction.courses => '나의 코스 보기',
      _HomeStudyAction.review => '오답 상세보기',
      _HomeStudyAction.problemsets ||
      _HomeStudyAction.exams ||
      _HomeStudyAction.textbooks => '책가방 열기',
    };
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 2048),
        builder: (sheetContext) {
          final viewport = MediaQuery.sizeOf(sheetContext);
          final mobile = isStudentDensityMobile(sheetContext);
          final maxHeight = math.min(
            mobile ? 650.0 : 720.0,
            viewport.height - (mobile ? 18.0 : 32.0),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                bottom: mobile ? 66 : 0,
                child: GestureDetector(
                  onTap: () => Navigator.of(sheetContext).pop(),
                  child: ColoredBox(color: Colors.black.withValues(alpha: .52)),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: mobile ? 66 : 0),
                  child: SizedBox(
                    width: math.min(viewport.width, 620),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: Material(
                        color: StudentDensityTokens.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                          side: BorderSide(
                            color: StudentDensityTokens.lineStrong,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _HomeStudyActionSheet(
                          key: ValueKey('home-study-sheet-${action.name}'),
                          title: title,
                          description: description,
                          cta: cta,
                          courseList: action == _HomeStudyAction.courses
                              ? courseList
                                    .where((item) => !item.isCompleted)
                                    .take(3)
                                    .toList(growable: false)
                              : null,
                          resumeCourses: action == _HomeStudyAction.resume
                              ? courseList
                                    .where((item) => !item.isCompleted)
                                    .take(3)
                                    .toList(growable: false)
                              : null,
                          onResumeCourse: _resumeCourse,
                          onOpen: () {
                            Navigator.of(sheetContext).pop();
                            switch (action) {
                              case _HomeStudyAction.resume:
                                _resumeCourse(course);
                              case _HomeStudyAction.courses:
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.courses);
                              case _HomeStudyAction.review:
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.wrongAnswers);
                              case _HomeStudyAction.problemsets ||
                                  _HomeStudyAction.exams ||
                                  _HomeStudyAction.textbooks:
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.bookbag);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _resumeCourse(Course? course) {
    if (course == null) {
      unawaited(_handleCourseTap());
      return;
    }
    if (course.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학습할 코스 정보를 확인하지 못했어요. 다시 선택해 주세요.')),
      );
      return;
    }
    unawaited(
      Navigator.of(context).pushNamed(
        Uri(
          path: AppRoutes.courseRuntime,
          queryParameters: {'course_id': course.id},
        ).toString(),
      ),
    );
  }

  /// HTML 홈 대시보드의 카드 목적지를 기존 학생 화면·모달 계약에 연결한다.
  void _handleDashboardAction(String id, List<_TodayTaskItem> todayTasks) {
    switch (id) {
      case 'today':
        unawaited(_showHomeTodayTasks(todayTasks));
        return;
      case 'ovr':
        unawaited(_showHomeOvrSummary());
        return;
      case 'week':
        unawaited(_showHomeWeekSummary());
        return;
      case 'streak':
        unawaited(_showHomeStreakSummary());
        return;
      case 'level':
        final account = ActivityStore.accountSummaryNotifier.value;
        if (account != null) {
          unawaited(_showHomeLevelSummary(account));
        } else {
          _showDashboardNotice('레벨과 포인트', '계정 정보를 불러오는 중입니다.');
        }
        return;
      case 'tutor':
        unawaited(_showHomeTutorSummary());
        return;
      case 'arena':
        unawaited(_showHomeArenaSummary());
        return;
      case 'weakness':
        unawaited(_showHomeWeaknessSummary());
        return;
      case 'achievements':
        unawaited(_showHomeAchievementsSummary());
        return;
      default:
        _showDashboardNotice('마이 대시보드', '연결된 학습 데이터가 없습니다.');
    }
  }

  /// HTML 홈 레벨리티 카드를 요약 시트로 열고 상세 정보를 연결한다.
  Future<T?> _showHomeDashboardOverlay<T>(
    Widget Function(BuildContext context, bool mobile) buildSheet, {
    required String barrierLabel,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, _, _) {
        final mobile = MediaQuery.sizeOf(dialogContext).width <= 720;
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                bottom: mobile ? 66 : 0,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => Navigator.of(dialogContext).pop(false),
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.52),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Material(
                        color: const Color(0xFFFDFDFE),
                        child: SizedBox(
                          width: mobile
                              ? MediaQuery.sizeOf(dialogContext).width
                              : MediaQuery.sizeOf(
                                  dialogContext,
                                ).width.clamp(0, 620),
                          child: buildSheet(dialogContext, mobile),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 레벨리티 요약은 보정되지 않은 내부 수치 대신 준비 상태를 보여준다.
  Future<void> _showHomeOvrSummary() async {
    final openAnalysis = await _showHomeDashboardOverlay<bool>(
      (dialogContext, _) => ValueListenableBuilder(
        valueListenable: RatingStore.notifier,
        builder: (context, rating, _) => HomeOvrSummarySheet(
          onClose: () => Navigator.of(dialogContext).pop(false),
          onOpenAnalysis: () => Navigator.of(dialogContext).pop(true),
        ),
      ),
      barrierLabel: '홈 오버롤 요약 닫기',
    );
    if (openAnalysis == true && mounted) {
      await showRatingDetailModal(context: context);
    }
  }

  /// 주간 학습 카드를 실제 활동 기록 그래프 시트로 열고 전체 기록 이동을 연결한다.
  Future<void> _showHomeWeekSummary() async {
    final openHistory = await _showHomeDashboardOverlay<bool>(
      (dialogContext, _) => ValueListenableBuilder<ActivitySnapshot>(
        valueListenable: ActivityStore.notifier,
        builder: (context, activity, _) => HomeWeekSummarySheet(
          activity: activity,
          onClose: () => Navigator.of(dialogContext).pop(false),
          onOpenHistory: () => Navigator.of(dialogContext).pop(true),
        ),
      ),
      barrierLabel: '홈 주간 학습 닫기',
    );
    if (openHistory == true && mounted) {
      await Navigator.of(context).pushNamed(AppRoutes.activityHistory);
    }
  }

  /// 연속 학습 기록을 요약 시트로 표시하고 HTML의 지표 CTA를 재사용한다.
  Future<void> _showHomeStreakSummary() async {
    final openRating = await _showHomeDashboardOverlay<bool>(
      (dialogContext, _) => ValueListenableBuilder<ActivitySnapshot>(
        valueListenable: ActivityStore.notifier,
        builder: (context, activity, _) => HomeStreakSummarySheet(
          activity: activity,
          onClose: () => Navigator.of(context, rootNavigator: true).pop(false),
          onOpenRating: () =>
              Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ),
      barrierLabel: '홈 연속 학습 닫기',
    );
    if (openRating == true && mounted) {
      await showRatingDetailModal(context: context);
    }
  }

  /// HTML 업적 장면을 실제 활동 기록 요약으로 열고 보관함 CTA를 연결한다.
  Future<void> _showHomeAchievementsSummary() async {
    final openCollection = await _showHomeDashboardOverlay<bool>(
      (dialogContext, _) => ValueListenableBuilder<ActivitySnapshot>(
        valueListenable: ActivityStore.notifier,
        builder: (context, activity, _) => HomeAchievementsSummarySheet(
          activity: activity,
          accountLevel: ActivityStore.accountSummaryNotifier.value?.level ?? 0,
          onClose: () => Navigator.of(dialogContext).pop(false),
          onOpenCollection: () => Navigator.of(dialogContext).pop(true),
        ),
      ),
      barrierLabel: '홈 업적 요약 닫기',
    );
    if (openCollection == true && mounted) {
      showActivityBadgeDialog(
        context: context,
        snapshot: ActivityStore.notifier.value,
        accountLevel: ActivityStore.accountSummaryNotifier.value?.level ?? 0,
      );
    }
  }

  /// HTML의 튜터 제안 시트를 열고, 선택한 질문을 전송 전 입력값으로 전달한다.
  Future<void> _showHomeTutorSummary() async {
    final prompt = await _showHomeDashboardOverlay<String>(
      (dialogContext, _) => HomeTutorSummarySheet(
        onClose: () => Navigator.of(dialogContext).pop(),
        onPrompt: (value) => Navigator.of(dialogContext).pop(value),
        onOpenTutor: () => Navigator.of(dialogContext).pop(''),
      ),
      barrierLabel: '홈 AI 튜터 닫기',
    );
    if (prompt != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ServerChatPage(
            standalone: true,
            initialPrompt: prompt.isEmpty ? null : prompt,
          ),
        ),
      );
    }
  }

  /// HTML 약점 요약 시트를 열고, 실제 오답 태그는 시트에서 조회한다.
  Future<void> _showHomeWeaknessSummary() async {
    final openReview = await _showHomeDashboardOverlay<bool>(
      (dialogContext, _) => HomeWeaknessSummarySheet(
        onClose: () => Navigator.of(dialogContext).pop(false),
        onOpenReview: () => Navigator.of(dialogContext).pop(true),
      ),
      barrierLabel: '홈 약점 태그 닫기',
    );
    if (openReview == true && mounted) {
      await Navigator.of(context).pushNamed(AppRoutes.wrongAnswers);
    }
  }

  /// HTML 대결 요약 시트를 열고 실제 전적을 표시한 뒤 대결장으로 이동한다.
  Future<void> _showHomeArenaSummary() async {
    final enterArena = await _showHomeDashboardOverlay<bool>(
      (dialogContext, _) => HomeArenaSummarySheet(
        onClose: () => Navigator.of(dialogContext).pop(false),
        onEnterArena: () => Navigator.of(dialogContext).pop(true),
      ),
      barrierLabel: '홈 대결 기록 닫기',
    );
    if (enterArena == true && mounted) {
      await Navigator.of(context).pushNamed(AppRoutes.arena);
    }
  }

  /// 레벨 카드는 HTML 레벨/포인트 요약 상태를 표시하고 별도 상세 모달을 우회한다.
  Future<void> _showHomeLevelSummary(AccountSummary account) {
    return _showHomeDashboardOverlay<void>(
      (dialogContext, _) => HomeLevelSummarySheet(
        account: account,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
      barrierLabel: '홈 레벨과 포인트 닫기',
    );
  }

  /// 오늘 카드와 오늘 일정 딥링크를 같은 HTML 요약 시트로 연다.
  Future<void> _showHomeTodayTasks(List<_TodayTaskItem> _) async {
    _TodayTaskItem? selectedTask;
    final selectedAction = await _showHomeDashboardOverlay<int>(
      (dialogContext, _) => StatefulBuilder(
        builder: (context, setSheetState) => FutureBuilder<void>(
          future: _todayTasksLoadFuture,
          builder: (context, snapshot) => HomeTodayTasksSummarySheet(
            tasks: [..._todayTeacherTasks, ..._todayPersonalTasks],
            loading: snapshot.connectionState != ConnectionState.done,
            error: [
              _teacherTasksError,
              _personalTasksError,
            ].whereType<String>().toSet().join('\n'),
            onRetry: () {
              if (_teacherTasksLoading || _personalTasksLoading) return;
              final requests = <Future<void>>[
                if (_teacherTasksError != null) _refreshTeacherTasks(),
                if (_personalTasksError != null) _refreshPersonalTasks(),
              ];
              if (requests.isEmpty) return;
              final nextLoad = Future.wait(requests).then((_) {});
              setSheetState(() {
                _todayTasksLoadFuture = nextLoad;
              });
            },
            onClose: () => Navigator.of(dialogContext).pop(),
            onTaskTap: (task) {
              selectedTask = task as _TodayTaskItem;
              Navigator.of(dialogContext).pop<int>(0);
            },
            onOpenSchedule: () => Navigator.of(dialogContext).pop<int>(-1),
          ),
        ),
      ),
      barrierLabel: '홈 오늘 할 일 닫기',
    );
    if (!mounted) return;
    if (selectedAction == -1) {
      await Navigator.of(context).pushNamed(AppRoutes.schedule);
    } else if (selectedAction == 0 && selectedTask != null) {
      _openTodayTask(selectedTask!);
    }
  }

  void _showDashboardNotice(
    String title,
    String message, {
    String? openLabel,
    VoidCallback? onOpen,
  }) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: StudentDensityTokens.surface,
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: StudentDensityTokens.muted),
              ),
              if (openLabel != null && onOpen != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpen();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: StudentDensityTokens.dark,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(openLabel)],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final wideDesktop =
        MediaQuery.sizeOf(context).width >
        StudentDensityTokens.desktopBreakpoint;
    final todayTasks = [..._todayTeacherTasks, ..._todayPersonalTasks];

    Widget homeScrollFor(Course? course, List<Course> courseList) {
      return SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: HtmlHomeDashboard(
          username: _displayName,
          activeCourse: course,
          todayTaskCount: todayTasks.length,
          onResume: () => _resumeCourse(course),
          onBrowseCourses: () =>
              Navigator.of(context).pushNamed(AppRoutes.courses),
          onReview: () =>
              Navigator.of(context).pushNamed(AppRoutes.wrongAnswers),
          onProblemSets: () =>
              Navigator.of(context).pushNamed(AppRoutes.bookbag),
          onExams: () => Navigator.of(context).pushNamed(AppRoutes.bookbag),
          onTextbooks: () => Navigator.of(context).pushNamed(AppRoutes.bookbag),
          onDashboardAction: (id) => _handleDashboardAction(id, todayTasks),
          onStudyAction: (id) => _handleStudyAction(id, course, courseList),
        ),
      );
    }

    final desktopShell = _CourseLoader(
      key: _courseLoaderKey,
      builder: (course, courseList) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HtmlStudentRail(width: wideDesktop ? 84 : 72),
          Expanded(
            child: Column(
              children: [Expanded(child: homeScrollFor(course, courseList))],
            ),
          ),
          if (wideDesktop)
            _HtmlContextAside(
              nextTaskTitle: todayTasks.isEmpty ? null : todayTasks.first.title,
            ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: StudentDensityTokens.background,
        bottomNavigationBar: mobile
            ? const MobileStudentBottomAppBar(
                activeRoute: AppRoutes.studentDashboard,
              )
            : null,
        body: SafeArea(
          child: mobile
              ? Column(
                  children: [
                    Expanded(
                      child: _CourseLoader(
                        key: _courseLoaderKey,
                        builder: (course, courseList) => SingleChildScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          child: HtmlHomeDashboard(
                            username: _displayName,
                            activeCourse: course,
                            todayTaskCount: todayTasks.length,
                            onResume: () => _resumeCourse(course),
                            onBrowseCourses: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.courses),
                            onReview: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.wrongAnswers),
                            onProblemSets: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.bookbag),
                            onExams: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.bookbag),
                            onTextbooks: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.bookbag),
                            onDashboardAction: (id) =>
                                _handleDashboardAction(id, todayTasks),
                            onStudyAction: (id) =>
                                _handleStudyAction(id, course, courseList),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : desktopShell,
        ),
      ),
    );
  }
}

String _formatHomePointCount(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

/// HTML 홈의 오늘 할 일 패널을 읽기 전용 요약 시트로 표시한다.
class HomeTodayTasksSummarySheet extends StatelessWidget {
  const HomeTodayTasksSummarySheet({
    super.key,
    required this.tasks,
    required this.onClose,
    required this.onTaskTap,
    required this.onOpenSchedule,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final List<TodayTaskEntry> tasks;
  final VoidCallback onClose;
  final ValueChanged<TodayTaskEntry> onTaskTap;
  final VoidCallback onOpenSchedule;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 620, maxHeight: mobile ? 650 : 720),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          mobile ? 12 : 18,
          0,
          mobile ? 12 : 18,
          mobile ? 14 : 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '오늘 할 일',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: '닫기',
                      onPressed: onClose,
                      style: IconButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                          side: BorderSide(color: StudentDensityTokens.line),
                        ),
                      ),
                      icon: const Icon(Icons.close, size: 19),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 18),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '오늘 할 일을 확인하고 있습니다.',
                  key: ValueKey('home-today-loading'),
                ),
              ),
            if (error?.isNotEmpty == true) ...[
              Text(
                error!,
                key: const ValueKey('home-today-error'),
                style: const TextStyle(color: Colors.red),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: loading ? null : onRetry,
                  child: const Text('다시 시도'),
                ),
            ],
            if (tasks.isEmpty && !loading && error?.isNotEmpty != true)
              _HomeTodayTaskRow(
                title: '오늘은 예정된 할 일이 없어요',
                onTap: null,
                isLast: true,
              )
            else if (tasks.isNotEmpty)
              for (var index = 0; index < tasks.length; index++)
                _HomeTodayTaskRow(
                  task: tasks[index],
                  onTap: () => onTaskTap(tasks[index]),
                  isLast: index == tasks.length - 1,
                ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onOpenSchedule,
                style: FilledButton.styleFrom(
                  backgroundColor: StudentDensityTokens.dark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '일정 전체 보기',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
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

class _HomeTodayTaskRow extends StatelessWidget {
  const _HomeTodayTaskRow({
    this.task,
    this.title,
    required this.onTap,
    required this.isLast,
  });
  final TodayTaskEntry? task;
  final String? title;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Material(
    color: StudentDensityTokens.surface,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: StudentDensityTokens.line)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              child: Text(
                task?.timeLabel ?? '',
                style: const TextStyle(
                  color: StudentDensityTokens.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task?.title ?? title ?? '',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null) ...[const SizedBox(width: 10)],
          ],
        ),
      ),
    ),
  );
}

/// HTML 홈의 레벨 카드에서 여는 요약 시트.
class HomeLevelSummarySheet extends StatelessWidget {
  const HomeLevelSummarySheet({
    super.key,
    required this.account,
    required this.onClose,
  });

  final AccountSummary account;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    final level = account.level.clamp(1, LevelDetailModal.maxLevel);
    final isMaxLevel = level >= LevelDetailModal.maxLevel;
    final earned = (account.activityScore - account.currentLevelScore).clamp(
      0,
      1 << 31,
    );
    final remaining = isMaxLevel
        ? 0
        : (account.nextLevelScore - account.activityScore).clamp(0, 1 << 31);
    final range = (account.nextLevelScore - account.currentLevelScore).clamp(
      1,
      1 << 31,
    );
    final progress = isMaxLevel ? 1.0 : account.levelProgress.clamp(0.0, 1.0);
    final nextMilestone = ((level ~/ 5) + 1) * 5;
    final reward = nextMilestone <= LevelDetailModal.maxLevel
        ? 'Lv. $nextMilestone 달성 시 ${LevelDetailModal.coinsForMilestone(nextMilestone)} 코인을 받아요.'
        : '모든 레벨 보상을 달성했어요.';

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 620, maxHeight: mobile ? 650 : 720),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          mobile ? 12 : 18,
          0,
          mobile ? 12 : 18,
          mobile ? 14 : 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '레벨과 포인트',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: '닫기',
                      onPressed: onClose,
                      style: IconButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                          side: BorderSide(color: StudentDensityTokens.line),
                        ),
                      ),
                      icon: const Icon(Icons.close, size: 19),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: StudentDensityTokens.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _HomeLevelValue(label: '현재 레벨', value: 'Lv. $level'),
                  ),
                  Container(
                    width: 1,
                    height: 86,
                    color: StudentDensityTokens.line,
                  ),
                  Expanded(
                    child: _HomeLevelValue(
                      label: '보유 포인트',
                      value: '${_formatHomePointCount(account.totalPoints)} P',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    isMaxLevel ? '최대 레벨에 도달했어요.' : '다음 레벨까지 $remaining XP',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  isMaxLevel ? 'MAX' : '$earned / $range XP',
                  style: const TextStyle(
                    color: StudentDensityTokens.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRect(
              child: SizedBox(
                height: 8,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFFF3F3F5)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        key: const ValueKey('home-level-progress-fill'),
                        widthFactor: progress,
                        child: const SizedBox.expand(
                          child: ColoredBox(color: StudentDensityTokens.dark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(color: StudentDensityTokens.line),
              ),
              child: Text(
                reward,
                style: const TextStyle(
                  color: StudentDensityTokens.muted,
                  fontSize: 11,
                ),
                textScaler: MediaQuery.textScalerOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeLevelValue extends StatelessWidget {
  const _HomeLevelValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 86,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

class HomeOvrSummarySheet extends StatelessWidget {
  const HomeOvrSummarySheet({
    super.key,
    required this.onClose,
    required this.onOpenAnalysis,
  });

  final VoidCallback onClose;
  final VoidCallback onOpenAnalysis;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    final sheet = ConstrainedBox(
      key: const ValueKey('home-ovr-sheet-panel'),
      constraints: BoxConstraints(
        maxWidth: mobile ? double.infinity : 620,
        maxHeight: mobile ? 650 : 720,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          mobile ? 12 : 18,
          0,
          mobile ? 12 : 18,
          mobile ? 14 : 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '나의 레벨리티',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: '닫기',
                      onPressed: onClose,
                      style: IconButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                          side: BorderSide(color: StudentDensityTokens.line),
                        ),
                      ),
                      icon: const Icon(Icons.close, size: 19),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SizedBox(height: mobile ? 8 : 18),
            Text(
              '등급 기준 보정 중',
              style: const TextStyle(
                fontSize: 25,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: mobile ? 33 : 23),
            Container(
              key: const ValueKey('home-ovr-trend-chart'),
              height: 150,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: StudentDensityTokens.line),
                ),
              ),
              child: const _HomeRatingSignalChart(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onOpenAnalysis,
                style: FilledButton.styleFrom(
                  backgroundColor: StudentDensityTokens.dark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '전체 분석 보기',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
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
    if (mobile) return sheet;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: StudentDensityTokens.lineStrong),
      ),
      child: sheet,
    );
  }
}

class _HomeRatingSignalChart extends StatelessWidget {
  const _HomeRatingSignalChart();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<RatingSnapshot>(
    valueListenable: RatingStore.notifier,
    builder: (context, rating, _) {
      final raw = rating.recentAccuracy;
      final accuracy = (raw <= 1 ? raw : raw / 100).clamp(0.0, 1.0);
      final trend = !rating.isLoaded
          ? '학습 지표를 불러오는 중입니다'
          : rating.delta > 0
          ? '최근 학습 결과가 상승 흐름입니다'
          : rating.delta < 0
          ? '최근 학습 결과가 하락 흐름입니다'
          : '최근 학습 결과에 변화가 없습니다';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '최근 정답률',
                  style: TextStyle(
                    color: StudentDensityTokens.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  rating.isLoaded ? '${(accuracy * 100).round()}%' : '—',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: rating.isLoaded ? accuracy : null,
              minHeight: 8,
              backgroundColor: StudentDensityTokens.line,
              valueColor: const AlwaysStoppedAnimation(
                StudentDensityTokens.dark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              trend,
              style: const TextStyle(
                color: StudentDensityTokens.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '등급 경계는 실제 유지율·배정률 검증 후 적용합니다.',
              style: TextStyle(color: StudentDensityTokens.muted, fontSize: 11),
            ),
          ],
        ),
      );
    },
  );
}

class HomeWeekSummarySheet extends StatelessWidget {
  const HomeWeekSummarySheet({
    super.key,
    required this.activity,
    required this.onClose,
    required this.onOpenHistory,
  });

  final ActivitySnapshot activity;
  final VoidCallback onClose;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final days = _homeWeekActivityBars(activity, DateTime.now());
    final activeDays = days.where((day) => day.score > 0).length;
    final totalScore = days.fold<int>(0, (sum, day) => sum + day.score);
    return Container(
      key: const ValueKey('home-week-summary-sheet'),
      constraints: BoxConstraints(
        maxWidth: mobile ? double.infinity : 620,
        maxHeight: mobile ? 650 : 720,
      ),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border.all(color: StudentDensityTokens.lineStrong),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          mobile ? 12 : 18,
          0,
          mobile ? 12 : 18,
          mobile ? 14 : 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: Container(
                  width: 44,
                  height: 4,
                  color: StudentDensityTokens.lineStrong,
                ),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: StudentDensityTokens.line),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '이번 주 학습',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: const ValueKey('home-week-summary-close'),
                      tooltip: '닫기',
                      onPressed: onClose,
                      style: IconButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                          side: BorderSide(color: StudentDensityTokens.line),
                        ),
                      ),
                      icon: const Icon(Icons.close, size: 19),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이번 주 활동점수 ${_formatHomePointCount(totalScore)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$activeDays일 학습 · 일별 활동점수',
                    style: const TextStyle(
                      color: StudentDensityTokens.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _HomeWeekActivityBars(days: days),
                  // The 170px chart already includes the HTML bar's 22px label overflow.
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('home-week-summary-history'),
                      onPressed: onOpenHistory,
                      style: FilledButton.styleFrom(
                        backgroundColor: StudentDensityTokens.dark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '전체 활동 기록',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeArenaSummarySheet extends StatefulWidget {
  const HomeArenaSummarySheet({
    super.key,
    required this.onClose,
    required this.onEnterArena,
  });

  final VoidCallback onClose;
  final VoidCallback onEnterArena;

  @override
  State<HomeArenaSummarySheet> createState() => _HomeArenaSummarySheetState();
}

class _HomeArenaSummarySheetState extends State<HomeArenaSummarySheet> {
  late Future<Map<String, dynamic>> _summary;

  @override
  void initState() {
    super.initState();
    _summary = ArenaApi.instance.summary();
  }

  void _retry() =>
      setState(() => _summary = ArenaApi.instance.summary(forceRefresh: true));

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Container(
      key: const ValueKey('home-arena-summary-sheet'),
      constraints: BoxConstraints(
        maxWidth: mobile ? double.infinity : 620,
        maxHeight: 650,
      ),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border.all(color: StudentDensityTokens.lineStrong),
      ),
      padding: EdgeInsets.fromLTRB(
        mobile ? 12 : 18,
        0,
        mobile ? 12 : 18,
        mobile ? 14 : 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: StudentDensityTokens.line),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '대결 기록',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const ValueKey('home-arena-summary-close'),
                    tooltip: '닫기',
                    onPressed: widget.onClose,
                    style: IconButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                        side: BorderSide(color: StudentDensityTokens.line),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 19),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _summary,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 92,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _HomeWeaknessMessage(
                    message: '대결 기록을 불러오지 못했습니다.',
                    actionLabel: '다시 시도',
                    onAction: _retry,
                  );
                }
                final summary = snapshot.data ?? const <String, dynamic>{};
                final queues = (summary['queues'] as List? ?? const [])
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList(growable: false);
                final profile = queues.cast<Map<String, dynamic>?>().firstWhere(
                  (item) => item?['queue_type'] == 'duel_exam',
                  orElse: () => queues.isEmpty ? null : queues.first,
                );
                return _HomeArenaStats(profile: profile);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              height: 48,
              child: FilledButton(
                key: const ValueKey('home-arena-enter'),
                onPressed: widget.onEnterArena,
                style: FilledButton.styleFrom(
                  backgroundColor: StudentDensityTokens.dark,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        '대결장 입장',
                        style: TextStyle(
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
        ],
      ),
    );
  }
}

class _HomeArenaStats extends StatelessWidget {
  const _HomeArenaStats({required this.profile});

  final Map<String, dynamic>? profile;

  @override
  Widget build(BuildContext context) {
    final hasProfile = profile != null;
    final wins = (profile?['wins'] as num?)?.toInt();
    final losses = (profile?['losses'] as num?)?.toInt();
    final tier = profile?['tier']?.toString();
    final streak = hasProfile
        ? _currentArenaWinStreak(profile!['recent_results'])
        : null;
    final cells = [
      ('전적', hasProfile ? '${wins ?? 0}승 ${losses ?? 0}패' : '—'),
      ('현재 티어', hasProfile ? (tier?.isNotEmpty == true ? tier! : '—') : '—'),
      ('연승', hasProfile ? '$streak' : '—'),
    ];
    return ColoredBox(
      color: StudentDensityTokens.line,
      child: Row(
        children: [
          for (var index = 0; index < cells.length; index++) ...[
            if (index > 0) const SizedBox(width: 1),
            Expanded(
              child: Container(
                key: ValueKey('home-arena-stat-$index'),
                constraints: const BoxConstraints(minHeight: 92),
                padding: const EdgeInsets.all(12),
                color: StudentDensityTokens.surface,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cells[index].$1,
                      style: const TextStyle(
                        fontSize: 9,
                        color: StudentDensityTokens.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        cells[index].$2,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

int _currentArenaWinStreak(Object? recentResults) {
  if (recentResults is! List) return 0;
  var streak = 0;
  for (final result in recentResults.reversed) {
    if (result.toString().toLowerCase() != 'win') break;
    streak++;
  }
  return streak;
}

class HomeWeaknessSummarySheet extends StatefulWidget {
  const HomeWeaknessSummarySheet({
    super.key,
    required this.onClose,
    required this.onOpenReview,
  });

  final VoidCallback onClose;
  final VoidCallback onOpenReview;

  @override
  State<HomeWeaknessSummarySheet> createState() =>
      _HomeWeaknessSummarySheetState();
}

class _HomeWeaknessSummarySheetState extends State<HomeWeaknessSummarySheet> {
  late Future<List<WeaknessTag>> _tags;

  @override
  void initState() {
    super.initState();
    _tags = ApiClient.instance.fetchWeaknessTags();
  }

  void _retry() =>
      setState(() => _tags = ApiClient.instance.fetchWeaknessTags());

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Container(
      key: const ValueKey('home-weakness-summary-sheet'),
      constraints: BoxConstraints(
        maxWidth: mobile ? double.infinity : 620,
        maxHeight: 650,
      ),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border.all(color: StudentDensityTokens.lineStrong),
      ),
      padding: EdgeInsets.fromLTRB(
        mobile ? 12 : 18,
        0,
        mobile ? 12 : 18,
        mobile ? 14 : 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Center(
              child: Container(
                width: 44,
                height: 4,
                color: StudentDensityTokens.lineStrong,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: StudentDensityTokens.line),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '약점 태그',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const ValueKey('home-weakness-summary-close'),
                    tooltip: '닫기',
                    onPressed: widget.onClose,
                    style: IconButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                        side: BorderSide(color: StudentDensityTokens.line),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 19),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: FutureBuilder<List<WeaknessTag>>(
              future: _tags,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 72,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _HomeWeaknessMessage(
                    message: '약점 태그를 불러오지 못했습니다.',
                    actionLabel: '다시 시도',
                    onAction: _retry,
                  );
                }
                final tags = snapshot.data ?? const <WeaknessTag>[];
                if (tags.isEmpty) {
                  return const _HomeWeaknessMessage(
                    message: '현재 복습할 약점 태그가 없습니다.',
                  );
                }
                return Column(
                  children: [
                    for (
                      var index = 0;
                      index < math.min(tags.length, 3);
                      index++
                    )
                      _HomeWeaknessTagRow(
                        tag: tags[index],
                        first: index == 0,
                        last: index == math.min(tags.length, 3) - 1,
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              height: 48,
              child: FilledButton(
                key: const ValueKey('home-weakness-open-review'),
                onPressed: widget.onOpenReview,
                style: FilledButton.styleFrom(
                  backgroundColor: StudentDensityTokens.dark,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        '약점 문제 복습',
                        style: TextStyle(
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
        ],
      ),
    );
  }
}

class _HomeWeaknessTagRow extends StatelessWidget {
  const _HomeWeaknessTagRow({
    required this.tag,
    required this.first,
    required this.last,
  });

  final WeaknessTag tag;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('home-weakness-row-${tag.tag}'),
    constraints: const BoxConstraints(minHeight: 58),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: StudentDensityTokens.surface,
      border: last
          ? null
          : Border(bottom: BorderSide(color: StudentDensityTokens.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tag.tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '최근 오답 ${tag.count}개',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: StudentDensityTokens.muted,
                ),
              ),
            ],
          ),
        ),
        Text(
          first ? '우선' : '복습',
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _HomeWeaknessMessage extends StatelessWidget {
  const _HomeWeaknessMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 72,
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

class HomeTutorSummarySheet extends StatelessWidget {
  const HomeTutorSummarySheet({
    super.key,
    required this.onClose,
    required this.onPrompt,
    required this.onOpenTutor,
  });

  final VoidCallback onClose;
  final ValueChanged<String> onPrompt;
  final VoidCallback onOpenTutor;

  static const _prompts = ['이 개념을 쉽게 설명해 줘', '내 오답 원인을 알려 줘', '비슷한 문제를 추천해 줘'];

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Container(
      key: const ValueKey('home-tutor-summary-sheet'),
      constraints: BoxConstraints(
        maxWidth: mobile ? double.infinity : 620,
        maxHeight: 650,
      ),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border.all(color: StudentDensityTokens.lineStrong),
      ),
      padding: EdgeInsets.fromLTRB(
        mobile ? 12 : 18,
        0,
        mobile ? 12 : 18,
        mobile ? 14 : 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Center(
              child: Container(
                width: 44,
                height: 4,
                color: StudentDensityTokens.lineStrong,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: StudentDensityTokens.line),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'AI 튜터',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const ValueKey('home-tutor-summary-close'),
                    tooltip: '닫기',
                    onPressed: onClose,
                    style: IconButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                        side: BorderSide(color: StudentDensityTokens.line),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 19),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: ColoredBox(
                    color: StudentDensityTokens.dark,
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '지금 배우는 내용으로 질문해 보세요.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < _prompts.length; index++)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: StudentDensityTokens.line),
                ),
              ),
              child: SizedBox(
                height: 44,
                child: TextButton(
                  key: ValueKey('home-tutor-prompt-$index'),
                  onPressed: () => onPrompt(_prompts[index]),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: StudentDensityTokens.ink,
                    backgroundColor: StudentDensityTokens.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: Text(
                    _prompts[index],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              height: 48,
              child: FilledButton(
                key: const ValueKey('home-tutor-open'),
                onPressed: onOpenTutor,
                style: FilledButton.styleFrom(
                  backgroundColor: StudentDensityTokens.dark,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AI 튜터와 대화하기',
                        style: TextStyle(
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
        ],
      ),
    );
  }
}

class HomeAchievementsSummarySheet extends StatelessWidget {
  const HomeAchievementsSummarySheet({
    super.key,
    required this.activity,
    required this.accountLevel,
    required this.onClose,
    required this.onOpenCollection,
  });

  final ActivitySnapshot activity;
  final int accountLevel;
  final VoidCallback onClose;
  final VoidCallback onOpenCollection;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final previews = _homeAchievementPreviews(activity, accountLevel);
    return Container(
      key: const ValueKey('home-achievements-summary-sheet'),
      constraints: BoxConstraints(
        maxWidth: mobile ? double.infinity : 620,
        maxHeight: 650,
      ),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border.all(color: StudentDensityTokens.lineStrong),
      ),
      padding: EdgeInsets.fromLTRB(
        mobile ? 12 : 18,
        0,
        mobile ? 12 : 18,
        mobile ? 14 : 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Center(
              child: Container(
                width: 44,
                height: 4,
                color: StudentDensityTokens.lineStrong,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: StudentDensityTokens.line),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '업적',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const ValueKey('home-achievements-summary-close'),
                    tooltip: '닫기',
                    onPressed: onClose,
                    style: IconButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                        side: BorderSide(color: StudentDensityTokens.line),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 19),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < previews.length; index++)
            _HomeAchievementPreviewRow(
              progress: previews[index],
              shapeIndex: index,
              last: index == previews.length - 1,
            ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const ValueKey('home-achievements-summary-open'),
              onPressed: onOpenCollection,
              style: FilledButton.styleFrom(
                backgroundColor: StudentDensityTokens.dark,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      '업적 보관함 열기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
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

List<ActivityBadgeProgress> _homeAchievementPreviews(
  ActivitySnapshot activity,
  int accountLevel,
) {
  final all = ActivityBadgeCatalog.evaluate(
    activity,
    accountLevel: accountLevel,
  );
  return ['streak', 'solve', 'active_days']
      .map((family) {
        final matches = all
            .where((item) => item.badge.family == family)
            .toList();
        return matches.firstWhere(
          (item) => !item.isEarned,
          orElse: () => matches.last,
        );
      })
      .toList(growable: false);
}

class _HomeAchievementPreviewRow extends StatelessWidget {
  const _HomeAchievementPreviewRow({
    required this.progress,
    required this.shapeIndex,
    required this.last,
  });

  final ActivityBadgeProgress progress;
  final int shapeIndex;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final icon = _HomeAchievementMark(
      shapeIndex: shapeIndex,
      icon: _homeAchievementIcon(progress.badge.family),
    );
    return Container(
      key: ValueKey('home-achievement-row-${progress.badge.family}'),
      constraints: const BoxConstraints(minHeight: 58),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: StudentDensityTokens.line)),
      ),
      child: Row(
        children: [
          SizedBox(width: 34, child: Center(child: icon)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ActivityBadgeCatalog.familyTitleOf(
                          progress.badge.family,
                        ),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${progress.value} / ${progress.badge.threshold}${progress.badge.unit}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: StudentDensityTokens.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRect(
                  child: SizedBox(
                    height: 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(
                          color: StudentDensityTokens.surfaceMuted,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: progress.progress,
                            child: const ColoredBox(
                              color: StudentDensityTokens.dark,
                            ),
                          ),
                        ),
                      ],
                    ),
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

IconData _homeAchievementIcon(String family) => switch (family) {
  'streak' => Icons.calendar_today_outlined,
  'solve' => Icons.edit_outlined,
  _ => Icons.auto_awesome,
};

class _HomeAchievementMark extends StatelessWidget {
  const _HomeAchievementMark({required this.shapeIndex, required this.icon});

  final int shapeIndex;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final background = switch (shapeIndex) {
      0 => Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: StudentDensityTokens.dark,
          shape: BoxShape.circle,
        ),
      ),
      1 => Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 27,
          height: 27,
          color: StudentDensityTokens.dark,
        ),
      ),
      _ => ClipPath(
        clipper: _HomeAchievementHexClipper(),
        child: Container(
          width: 32,
          height: 32,
          color: StudentDensityTokens.dark,
        ),
      ),
    };
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          background,
          Icon(icon, color: Colors.white, size: 16),
        ],
      ),
    );
  }
}

class _HomeAchievementHexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * .25, size.height * .07)
    ..lineTo(size.width * .75, size.height * .07)
    ..lineTo(size.width, size.height * .5)
    ..lineTo(size.width * .75, size.height * .93)
    ..lineTo(size.width * .25, size.height * .93)
    ..lineTo(0, size.height * .5)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class HomeStreakSummarySheet extends StatelessWidget {
  const HomeStreakSummarySheet({
    super.key,
    required this.activity,
    required this.onClose,
    required this.onOpenRating,
  });

  final ActivitySnapshot activity;
  final VoidCallback onClose;
  final VoidCallback onOpenRating;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final streakDays = _activityStreakDays(activity);
    final nextBadge = _nextHomeStreakBadge(activity);
    final progress = nextBadge?.progress ?? 1.0;
    final daysRemaining =
        (nextBadge?.badge.threshold ?? streakDays) - streakDays;
    return Container(
      key: const ValueKey('home-streak-summary-sheet'),
      constraints: BoxConstraints(
        maxWidth: mobile ? double.infinity : 620,
        maxHeight: mobile ? 650 : 720,
      ),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border.all(color: StudentDensityTokens.lineStrong),
      ),
      padding: EdgeInsets.fromLTRB(
        mobile ? 12 : 18,
        0,
        mobile ? 12 : 18,
        mobile ? 14 : 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            key: ValueKey('home-streak-sheet-top-space'),
            height: 16,
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: StudentDensityTokens.line),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '연속 학습',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const ValueKey('home-streak-summary-close'),
                    tooltip: '닫기',
                    onPressed: onClose,
                    style: IconButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                        side: BorderSide(color: StudentDensityTokens.line),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 19),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: StudentDensityTokens.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '🔥',
                    style: TextStyle(
                      fontSize: 32,
                      height: 1,
                      fontFamilyFallback: ['Segoe UI Emoji'],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$streakDays일 연속 학습',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        nextBadge == null
                            ? '연속 학습 뱃지를 모두 달성했어요.'
                            : '다음 뱃지까지 $daysRemaining일',
                        style: const TextStyle(
                          color: StudentDensityTokens.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRect(
                        child: SizedBox(
                          key: const ValueKey('home-streak-progress-track'),
                          height: 4,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const ColoredBox(
                                color: StudentDensityTokens.surfaceMuted,
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: progress.clamp(0.0, 1.0),
                                  heightFactor: 1,
                                  alignment: Alignment.centerLeft,
                                  child: const SizedBox.expand(
                                    child: ColoredBox(
                                      key: ValueKey(
                                        'home-streak-progress-fill',
                                      ),
                                      color: StudentDensityTokens.dark,
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const ValueKey('home-streak-summary-ovr'),
              onPressed: onOpenRating,
              style: FilledButton.styleFrom(
                backgroundColor: StudentDensityTokens.dark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '레벨리티 자세히 보기',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
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

ActivityBadgeProgress? _nextHomeStreakBadge(ActivitySnapshot snapshot) {
  for (final progress in ActivityBadgeCatalog.evaluate(snapshot)) {
    if (progress.badge.family == 'streak' && !progress.isEarned) {
      return progress;
    }
  }
  return null;
}

class _HomeWeekActivityBar {
  const _HomeWeekActivityBar({required this.label, required this.score});

  final String label;
  final int score;
}

List<_HomeWeekActivityBar> _homeWeekActivityBars(
  ActivitySnapshot activity,
  DateTime today,
) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final end = DateTime(today.year, today.month, today.day);
  return List.generate(7, (index) {
    final date = end.subtract(Duration(days: 6 - index));
    final key =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return _HomeWeekActivityBar(
      label: index == 6 ? '오늘' : weekdays[date.weekday - 1],
      score: activity.days[key]?.score ?? 0,
    );
  });
}

class _HomeWeekActivityBars extends StatelessWidget {
  const _HomeWeekActivityBars({required this.days});

  final List<_HomeWeekActivityBar> days;

  @override
  Widget build(BuildContext context) {
    final maxScore = days.fold<int>(0, (max, day) => math.max(max, day.score));
    return SizedBox(
      height: 170,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 21,
            child: Container(height: 1, color: StudentDensityTokens.line),
          ),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final barHeight = maxScore == 0
                          ? 4.0
                          : (day.score / maxScore * 124).clamp(4.0, 124.0);
                      return Stack(
                        children: [
                          Positioned(
                            left: 4,
                            right: 4,
                            bottom: 22,
                            height: barHeight,
                            child: ColoredBox(color: StudentDensityTokens.dark),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: barHeight + 26,
                            height: 10,
                            child: Text(
                              '${day.score}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 12,
                            child: Text(
                              day.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: StudentDensityTokens.muted,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeStudyActionSheet extends StatelessWidget {
  const _HomeStudyActionSheet({
    super.key,
    required this.title,
    required this.description,
    required this.cta,
    required this.onOpen,
    this.courseList,
    this.resumeCourses,
    required this.onResumeCourse,
  });

  final String title;
  final String description;
  final String cta;
  final VoidCallback onOpen;
  final List<Course>? courseList;
  final List<Course>? resumeCourses;
  final ValueChanged<Course> onResumeCourse;

  /// HTML 홈 학습 시트의 제목·설명·단일 이동 CTA를 표시한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 12 : 18,
        0,
        mobile ? 12 : 18,
        mobile ? 14 : 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: StudentDensityTokens.line),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                        side: BorderSide(color: StudentDensityTokens.line),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 19),
                  ),
                ),
              ],
            ),
          ),
          if (courseList != null) ...[
            const SizedBox(height: 18),
            _HomeStudyCourseList(courses: courseList!),
          ] else if (resumeCourses != null) ...[
            const SizedBox(height: 18),
            _HomeStudyResumeList(
              courses: resumeCourses!,
              onOpen: onResumeCourse,
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: StudentDensityTokens.muted,
                height: 1.45,
              ),
            ),
          ],
          if (resumeCourses == null) ...[
            const SizedBox(
              key: ValueKey('home-study-sheet-cta-gap'),
              height: 16,
            ),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: StudentDensityTokens.dark,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(cta)],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeStudyResumeList extends StatelessWidget {
  const _HomeStudyResumeList({required this.courses, required this.onOpen});

  final List<Course> courses;
  final ValueChanged<Course> onOpen;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return Container(
        constraints: const BoxConstraints(minHeight: 188),
        alignment: Alignment.center,
        color: StudentDensityTokens.surface,
        child: const Text(
          '최근 학습 기록이 없습니다.',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: StudentDensityTokens.muted,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < courses.length; index++) ...[
          if (index > 0) Container(height: 1, color: StudentDensityTokens.line),
          _HomeStudyResumeRow(course: courses[index], onTap: onOpen),
        ],
      ],
    );
  }
}

class _HomeStudyResumeRow extends StatelessWidget {
  const _HomeStudyResumeRow({required this.course, required this.onTap});

  final Course course;
  final ValueChanged<Course> onTap;

  @override
  Widget build(BuildContext context) {
    final progress = (course.progress.clamp(0.0, 1.0) * 100).round();
    return Material(
      color: StudentDensityTokens.surface,
      child: InkWell(
        onTap: () => onTap(course),
        child: SizedBox(
          height: 62,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    '$progress%',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: StudentDensityTokens.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeStudyCourseList extends StatelessWidget {
  const _HomeStudyCourseList({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return Container(
        // HTML fixed slot capacity is three 82px rows with 1px dividers.
        // Preserve that layout while showing a truthful empty state.
        constraints: const BoxConstraints(minHeight: 248),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: Alignment.centerLeft,
        color: StudentDensityTokens.surface,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '수강 중인 코스가 없습니다.',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 4),
            Text(
              '새 코스를 찾아보세요.',
              style: TextStyle(fontSize: 8, color: StudentDensityTokens.muted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < courses.length; index++) ...[
          if (index > 0) Container(height: 1, color: StudentDensityTokens.line),
          _HomeStudyCourseRow(course: courses[index]),
        ],
      ],
    );
  }
}

class _HomeStudyCourseRow extends StatelessWidget {
  const _HomeStudyCourseRow({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final progress = (course.progress * 100).round().clamp(0, 100);
    final description = course.description.trim();
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: StudentDensityTokens.surface,
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$progress%',
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '진행 중',
                  style: TextStyle(
                    fontSize: 8,
                    height: 1.375,
                    fontWeight: FontWeight.w800,
                    color: StudentDensityTokens.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                      color: StudentDensityTokens.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseLoader extends StatefulWidget {
  const _CourseLoader({super.key, required this.builder});
  final Widget Function(Course? course, List<Course> courseList) builder;

  @override
  State<_CourseLoader> createState() => _CourseLoaderState();
}

class _CourseLoaderState extends State<_CourseLoader> {
  Course? _course;
  List<Course> _courseList = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final courses = await CourseService.fetchMyCourses();
      String? preferredCourseId;
      try {
        preferredCourseId = await ApiClient.instance.getUserStorage(
          _activeCourseStorageKey,
        );
      } on ApiException {
        // 저장소가 없는 계정/환경은 서버 코스 순서를 그대로 사용한다.
      }
      if (!mounted) return;
      setState(() {
        _courseList = courses;
        // 완료 코스는 다시 활성 코스로 선택하지 않고 검색 화면에서만 미리보기를 제공한다.
        final activeCourses = courses
            .where((course) => !course.isCompleted)
            .toList(growable: false);
        if (activeCourses.isEmpty) {
          _course = null;
        } else {
          final preferred = preferredCourseId?.trim();
          final preferredCourse = preferred == null || preferred.isEmpty
              ? null
              : activeCourses.cast<Course?>().firstWhere(
                  (course) => course?.id == preferred,
                  orElse: () => null,
                );
          _course =
              preferredCourse ??
              activeCourses.firstWhere(
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
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return widget.builder(null, _courseList);
    return widget.builder(_course, _courseList);
  }
}

class _HtmlStudentRail extends StatelessWidget {
  const _HtmlStudentRail({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    Widget item({
      required String label,
      required String route,
      required StudentHtmlIcon navIcon,
      bool active = false,
    }) {
      return Semantics(
        button: true,
        label: label,
        selected: active,
        child: SizedBox(
          width: width - 20,
          height: 44,
          child: InkWell(
            onTap: () {
              if (route == AppRoutes.learningTools) {
                MobileStudentBottomAppBar.openMore(context);
                return;
              }
              Navigator.of(context).pushNamed(route);
            },
            child: Container(
              key: active ? const ValueKey('home-rail-active') : null,
              decoration: BoxDecoration(
                color: active ? StudentDensityTokens.dark : Colors.transparent,
                borderRadius: BorderRadius.zero,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StudentHtmlGlyph(
                    key: ValueKey('student-nav-glyph-${navIcon.name}'),
                    icon: navIcon,
                    size: 17,
                    color: active ? Colors.white : StudentDensityTokens.ink,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : StudentDensityTokens.ink,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
      decoration: const BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border(right: BorderSide(color: StudentDensityTokens.line)),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            color: StudentDensityTokens.dark,
            child: const Text(
              'A',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  item(
                    label: '홈',
                    navIcon: StudentHtmlIcon.home,
                    route: AppRoutes.studentDashboard,
                    active: true,
                  ),
                  const SizedBox(height: 6),
                  item(
                    label: '코스',
                    navIcon: StudentHtmlIcon.courses,
                    route: AppRoutes.courses,
                  ),
                  const SizedBox(height: 6),
                  item(
                    label: '자료실',
                    navIcon: StudentHtmlIcon.market,
                    route: AppRoutes.bookbag,
                  ),
                  const SizedBox(height: 6),
                  item(
                    label: '더보기',
                    navIcon: StudentHtmlIcon.more,
                    route: AppRoutes.learningTools,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            color: StudentDensityTokens.dark,
            child: const Text(
              '학',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HtmlContextAside extends StatelessWidget {
  const _HtmlContextAside({required this.nextTaskTitle});

  final String? nextTaskTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('home-context-aside'),
      width: 244,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: const BoxDecoration(
        color: StudentDensityTokens.surfaceMuted,
        border: Border(left: BorderSide(color: StudentDensityTokens.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HTML aside-focus: 현재 코스가 없을 때만 기본 문구를 보여준다.
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 5),
            child: Row(
              children: [
                Container(
                  key: const ValueKey('home-context-focus-icon'),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: StudentDensityTokens.dark,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nextTaskTitle ?? '오늘의 학습',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(key: ValueKey('home-context-aside-divider'), height: 1),
          const SizedBox(height: 14),
          const _ContextMetric(label: '오늘 집중', value: '—'),
          const SizedBox(height: 14),
          ValueListenableBuilder<ActivitySnapshot>(
            valueListenable: ActivityStore.notifier,
            builder: (context, snapshot, _) => _ContextMetric(
              label: '연속 학습',
              value: '${_activityStreakDays(snapshot)}일',
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ServerChatPage(standalone: true),
                ),
              ),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('튜터에게 묻기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: StudentDensityTokens.dark,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextMetric extends StatelessWidget {
  const _ContextMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('home-context-metric-$label'),
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              letterSpacing: -1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
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

// ignore: unused_element
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
                ? 14
                : mobile
                ? 24
                : 38,
            vertical: portraitMobile
                ? 14
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
                        ? 40
                        : mobile
                        ? 38
                        : 56,
                    height: portraitMobile ? 1.02 : 0.98,
                    fontWeight: FontWeight.w900,
                    letterSpacing: portraitMobile
                        ? -2.2
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
                                return _CircleStat(
                                  percent: 0,
                                  color: const Color(0xFFEF394D),
                                  label: snapshot.isLoaded ? '보정 중' : '--',
                                  subtitle: '레벨리티 동향',
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

// ignore: unused_element
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
    /// 작동 원리: 홈의 세 빠른 실행을 노트 모달·그래프·AI 튜터 화면과 연결한다.
    final tools = LearningToolsStrip(
      onNotepad: () => showStudentToolModal(context, const NotepadPage()),
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
      onTutor: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ServerChatPage(standalone: true),
        ),
      ),
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
            portraitMobile
                ? _mobileHomeContentInset(context)
                : studentDensityHorizontalPadding(context),
            0,
            portraitMobile
                ? _mobileHomeContentInset(context)
                : studentDensityHorizontalPadding(context),
            portraitMobile ? 6 : 14,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: portraitMobile ? 0 : 20,
              vertical: portraitMobile ? 14 : 20,
            ),
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
                  title: portraitMobile ? '학습하기' : null,
                  description: portraitMobile ? '원하는 학습 방식을 선택하세요.' : null,
                  onTap: () => showStudyModeModal(context: context),
                ),
                const SizedBox(height: 12),
                if (portraitMobile)
                  Column(
                    children: [
                      _MobileHomeStatusGroup(
                        courseValue: progressPercent == null
                            ? '코스 선택'
                            : '진행률 $progressPercent%',
                        taskValue: todayTasks.isEmpty
                            ? '할 일 없음'
                            : '${todayTasks.length}개 남음',
                        onCourseTap: onCourseTap,
                        onTodayTasksTap: onTodayTasksTap,
                      ),
                      const SizedBox(height: 24),
                      Material(
                        key: const ValueKey(
                          'student-home-mobile-practical-tools',
                        ),
                        color: Colors.white,
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(24),
                        clipBehavior: Clip.antiAlias,
                        child: toolCard,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      statusCards[0],
                      SizedBox(width: mobile ? 8 : 12),
                      statusCards[1],
                    ],
                  ),
                // 세로 모바일은 위의 실제 도구 그룹을 사용하고, 넓은 화면은 기존 모듈 그리드를 유지한다.
                if (!portraitMobile) ...[
                  const SizedBox(height: 12),
                  moduleGrid,
                ],
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
    elevation: 3,
    shadowColor: Colors.black.withValues(alpha: 0.12),
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
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  /// 필요한 변수는 기능 아이콘·제목·설명과 이동 콜백이다.
  /// 작동 원리: HTML의 118px 기능 카드를 48px 아이콘과 우측 화살표의 3열 구조로 만든다.
  @override
  Widget build(BuildContext context) {
    return StudentDensitySurface(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 118),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: StudentDensityTokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: StudentDensityTokens.line),
                ),
                child: Icon(icon, color: StudentDensityTokens.ink, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StudentDensityTokens.muted,
                        fontSize: 12,
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
            ],
          ),
        ),
      ),
    );
    return child;
  }
}

class _LearnBanner extends StatelessWidget {
  const _LearnBanner({
    this.onTap,
    this.portraitMobile = false,
    this.title,
    this.description,
  });
  final VoidCallback? onTap;
  final bool portraitMobile;
  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Container(
      key: ValueKey(
        portraitMobile
            ? 'student-home-mobile-learn-banner'
            : 'student-home-learn-banner',
      ),
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: portraitMobile
            ? 118
            : mobile
            ? 118
            : 150,
      ),
      decoration: BoxDecoration(
        color: StudentDensityTokens.darkSecondary,
        borderRadius: BorderRadius.circular(portraitMobile ? 24 : 28),
        boxShadow: portraitMobile
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(portraitMobile ? 24 : 28),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: portraitMobile
                  ? 18
                  : mobile
                  ? 20
                  : 28,
              vertical: portraitMobile
                  ? 14
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
                        title ?? (portraitMobile ? '학습 시작' : '학습하기'),
                        style: TextStyle(
                          fontSize: portraitMobile
                              ? 26
                              : mobile
                              ? 26
                              : 38,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      if (description != null || !portraitMobile) ...[
                        const SizedBox(height: 7),
                        Text(
                          description ?? '이어하기 · 코스보기 · 복습 · 문제세트 · 시험지 · 교재보기',
                          maxLines: portraitMobile ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFAFAFB6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: portraitMobile ? 14 : 18),
                Container(
                  width: portraitMobile
                      ? 50
                      : mobile
                      ? 56
                      : 58,
                  height: portraitMobile
                      ? 50
                      : mobile
                      ? 56
                      : 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      portraitMobile ? 16 : 19,
                    ),
                  ),
                  child: Icon(
                    portraitMobile
                        ? Icons.play_arrow_rounded
                        : Icons.play_arrow_rounded,
                    color: StudentDensityTokens.dark,
                    size: portraitMobile ? 28 : 31,
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

// ignore: unused_element
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
    // 필요한 변수는 모바일 여부다.
    // 작동 원리: 모바일은 달력·대결 같은 중복 진입점을 제외하고 레이팅·업적·공지
    // 상태만 부드러운 단일 그룹으로 요약하며, PC 정보 홈은 기존 구성을 유지한다.
    if (mobile) {
      return _MobileHomeInsights(
        onRatingTap: (isEligible) => _handleRatingTap(context, isEligible),
      );
    }
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
                        return ValueListenableBuilder<RatingSnapshot>(
                          valueListenable: RatingStore.notifier,
                          builder: (context, ratingSnapshot, _) {
                            final isEligible =
                                ratingSnapshot.placementCompleted;
                            final ctaText = isEligible
                                ? '레벨리티 자세히 보기'
                                : '레벨테스트 풀러 가기';

                            return _HomeRatingCard(
                              isEligible: isEligible,
                              remainingCount: remainingCount,
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

/// 필요한 변수는 활동·레이팅·계정 상태와 레이팅 상세 이동 함수다.
/// 작동 원리: 모바일 홈에 필요한 상태 정보만 한 개의 무테 Material 그룹으로 묶고,
/// 달력·대결·빠른 도구처럼 `더보기`와 겹치는 기능은 만들지 않는다.
class _MobileHomeInsights extends StatelessWidget {
  const _MobileHomeInsights({required this.onRatingTap});

  final ValueChanged<bool> onRatingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('student-home-mobile-insights'),
      padding: EdgeInsets.fromLTRB(
        _mobileHomeContentInset(context),
        0,
        _mobileHomeContentInset(context),
        24,
      ),
      child: ValueListenableBuilder<ActivitySnapshot>(
        valueListenable: ActivityStore.notifier,
        builder: (context, activity, _) {
          return ValueListenableBuilder<RatingSnapshot>(
            valueListenable: RatingStore.notifier,
            builder: (context, rating, __) {
              final isEligible = rating.placementCompleted;
              return ValueListenableBuilder<AccountSummary?>(
                valueListenable: ActivityStore.accountSummaryNotifier,
                builder: (context, account, ___) {
                  final badges = ActivityBadgeCatalog.evaluate(
                    activity,
                    accountLevel: account?.level ?? 0,
                  );
                  final earned = badges.where((item) => item.isEarned).length;
                  final next = ActivityBadgeCatalog.nextBadges(
                    activity,
                    accountLevel: account?.level ?? 0,
                    limit: 1,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 2, bottom: 12),
                        child: Text(
                          '학습 현황',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                      Material(
                        key: const ValueKey(
                          'student-home-mobile-insights-group',
                        ),
                        color: Colors.white,
                        elevation: 3,
                        shadowColor: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _MobileInsightRow(
                              icon: Icons.insights_rounded,
                              label: '레벨리티',
                              value: rating.isLoaded && isEligible
                                  ? '등급 기준 보정 중'
                                  : '레벨테스트 필요',
                              darkIcon: true,
                              onTap: () => onRatingTap(isEligible),
                            ),
                            _MobileInsightRow(
                              icon: Icons.emoji_events_outlined,
                              label: '업적',
                              value: next.isEmpty
                                  ? '$earned개 달성'
                                  : '$earned개 · ${next.first.badge.title}',
                              onTap: () => showActivityBadgeDialog(
                                context: context,
                                snapshot: activity,
                                accountLevel: account?.level ?? 0,
                              ),
                            ),
                            _MobileInsightRow(
                              icon: Icons.notifications_none_rounded,
                              label: '공지',
                              value: '새 소식 확인',
                              onTap: () => showStudentNotifications(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// 필요한 변수는 상태 아이콘·이름·짧은 값과 이동 콜백이다.
/// 작동 원리: 선으로 구획하지 않고 72px 행의 여백과 잉크 반응만 사용해 단단한 카드
/// 묶음 대신 하나의 부드러운 모바일 설정 그룹처럼 동작한다.
class _MobileInsightRow extends StatelessWidget {
  const _MobileInsightRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.darkIcon = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool darkIcon;

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
              color: darkIcon
                  ? StudentDensityTokens.dark
                  : StudentDensityTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              size: 22,
              color: darkIcon ? Colors.white : StudentDensityTokens.ink,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: StudentDensityTokens.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    ),
  );
}

class _HomeRatingCard extends StatelessWidget {
  const _HomeRatingCard({
    required this.isEligible,
    required this.remainingCount,
    required this.ctaText,
    required this.onTap,
  });

  final bool isEligible;
  final int remainingCount;
  final String ctaText;
  final VoidCallback onTap;

  /// 필요한 변수는 배정 완료 상태와 미완료 문항 수다.
  /// 숫자 OVR 대신 레벨리티 기준 보정 상태를 표시한다.
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
                            '레벨리티',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '등급 기준 보정 중',
                            style: TextStyle(
                              color: StudentDensityTokens.muted,
                              fontSize: 12,
                            ),
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
                    const Expanded(
                      child: Text(
                        '등급·진행률은 보정 데이터 확인 후 표시합니다.',
                        style: TextStyle(
                          color: StudentDensityTokens.muted,
                          fontSize: 12,
                        ),
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
                  child: const Text('레벨리티 자세히 보기'),
                ),
              ] else ...[
                const Text(
                  '나의 레벨리티',
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
                          '레벨테스트까지 $remainingCount문제 남았어요',
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

  /// 레벨리티 등급 경계가 확정되기 전에는 등급을 임의 표시하지 않는다.
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
        '…',
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
    // 홈 카드도 전역 알림 센터와 같은 상세 화면을 사용한다. 그래야 780px
    // 이하에서 고정 폭 데스크톱 대화상자가 아니라 읽기 쉬운 하단 시트가 열린다.
    showStudentNoticeDetail(context, notice);
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
  void _showModal() => showActivityHistoryDetail(context);

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

/// 필요한 변수는 홈의 현재 Navigator 문맥이다.
/// 작동 원리: 공통 780px 이하에서는 전체 일정 기록을 바텀시트로 열고,
/// 넓은 화면은 기존 크기 제한 다이얼로그를 그대로 사용한다.
void showActivityHistoryDetail(BuildContext context) {
  if (isStudentDensityMobile(context)) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Material(
          key: const ValueKey('activity-history-mobile-sheet'),
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: const _ActivityHistorySheet(),
        ),
      ),
    );
    return;
  }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          key: const ValueKey('activity-history-desktop-dialog'),
          width: width,
          height: height,
          child: const _ActivityHistorySheet(),
        ),
      );
    },
  );
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
