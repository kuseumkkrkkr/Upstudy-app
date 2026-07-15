import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart' as book_page;
import 'package:s11/sessions/textbook/ui/pages/docx_box.dart' as docx;
import 'package:s11/sessions/friend/friend.dart' as friend;
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/course/session/course_pages.dart';
import 'package:s11/sessions/graph_tools/session/jsx_graph_page.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/components/tag_picker_dialog.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/sessions/exam_paper/ui/modals/exam_mode.dart';
import 'package:s11/shared/business/repositories/social_notification_store.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/course_service.dart';

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B402B)),
      scaffoldBackgroundColor: Colors.white,
    ),
    home: const SoWidget(),
  );
}

const _kGreen = Color(0xFF1B402B);
const _kWhite = Colors.white;

double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
  final width = MediaQuery.of(context).size.width;
  final scale = width / 1100;
  if (scale < min) return min;
  if (scale > max) return max;
  return scale;
}

Future<void> openConceptStudy(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final tags = await showTagPickerDialog(context: navigator.context);
  if (tags == null) return;
  if (tags.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('해시태그를 선택해주세요.')));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => book_page.BookWidget(book: buildConceptBook(tags)),
    ),
  );
}

class SoWidget extends StatelessWidget {
  const SoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _kWhite,
        drawer: const AppDrawer(),
        body: SafeArea(
          top: true,
          child: Column(
            children: [
              const StudyCenterNavBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroSection(),
                      _SectionHeader(title: '코스'),
                      _CardRow(
                        cards: [
                          _CardData(
                            icon: Icons.search,
                            title: '코스 찾기',
                            subtitle: '수강중인 코스를 검색합니다',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CourseCatalogPage(),
                                ),
                              );
                            },
                          ),
                          _CardData(
                            icon: Icons.bookmark,
                            title: '북마크',
                            subtitle: '저장한 북마크를 확인합니다',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const book_page.BookmarkListPage(),
                                ),
                              );
                            },
                          ),
                          _CardData(
                            icon: Icons.library_books_outlined,
                            title: '교재함',
                            subtitle: '보유한 교재를 보여줍니다',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const book_page.BookLibraryPage(
                                        libraryTitle: '교재함',
                                        notice: '보유한 교재를 보여줍니다.',
                                        enableDownload: true,
                                      ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _SectionHeader(title: '성장 사례'),
                      _CardRow(
                        cards: [
                          _CardData(
                            icon: Icons.push_pin,
                            title: '약점 보완하기',
                            subtitle: '학습 약점을 보완합니다',
                          ),
                          _CardData(
                            icon: Icons.ads_click_outlined,
                            title: '개념학습하기',
                            subtitle: '개념을 학습할 수 있는 공통교재입니다',
                            onTap: () => openConceptStudy(context),
                          ),
                          _CardData(
                            icon: Icons.content_paste,
                            title: '그래프 그리기',
                            subtitle: '문제를 시각화 합니다',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const JsxGraphPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _SectionHeader(title: '시험 연습'),
                      const SizedBox(height: 20),
                      _ExamBanner(),
                      const SizedBox(height: 10),
                      _CardRow(
                        cards: [
                          _CardData(
                            icon: Icons.adf_scanner_outlined,
                            title: '시험지 코스',
                            subtitle: '시험 유형을 확인합니다',
                          ),
                          _CardData(
                            icon: Icons.folder_open_sharp,
                            title: '분석지 출력',
                            subtitle: '분석지를 출력합니다',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const SizedBox(height: 28),
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

class StudyCenterNavBar extends StatelessWidget {
  const StudyCenterNavBar({super.key, this.onBack});

  /// 필요 변수: [onBack]은 하위 학습 화면에서 이전 화면으로 돌아갈 때 사용한다.
  /// 작동 원리: 콜백이 있으면 메뉴 대신 뒤로가기 버튼을 표시하고, 없으면 기존 메뉴를 유지한다.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Ios26TopBar(
      brandColor: _kGreen,
      onBack: onBack,
      onMenu: onBack == null ? () => toggleAppDrawer(context) : null,
      onTitleTap: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainStudentPage()),
          (route) => false,
        );
      },
      items: [
        const Ios26NavItem(label: '학습터', active: true),
        Ios26NavItem(
          label: '책가방',
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const docx.BookWidget()));
          },
        ),
        Ios26NavItem(
          label: '친구/소셜',
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const friend.SoWidget()));
          },
        ),
        const Ios26NavItem(label: '마켓플레이스'),
      ],
    );
  }
}

class _HeroSection extends StatefulWidget {
  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  late final Future<_StudyCenterOverview> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _loadOverview();
  }

  /// 필요 변수: 현재 날짜, 내 수강 과제, 수강 코스, 친구 요청 목록이다.
  /// 작동 원리: 화면 진입 시 한 번만 서버 상태를 조회해 히어로의 요약 수치를 만들고 소셜 알림 저장소를 갱신한다.
  Future<_StudyCenterOverview> _loadOverview() async {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    var todayTaskCount = 0;
    var activeCourseCount = 0;
    var pendingSocialCount = 0;

    try {
      final result = await ApiClient.instance.listMyAssignments();
      todayTaskCount = (result.data ?? const <StudentAssignmentTask>[]).where((
        task,
      ) {
        final due = DateTime.tryParse(task.assignment.dueDate ?? '');
        final status = task.submission.status.toLowerCase();
        final isFinished = status == 'submitted' || status == 'completed';
        return due != null &&
            DateTime(due.year, due.month, due.day) == todayKey &&
            !isFinished;
      }).length;
    } catch (_) {
      // 과제 API를 사용할 수 없으면 0건으로 표시해 화면 진입을 막지 않는다.
    }

    try {
      final courses = await CourseService.fetchMyCourses();
      activeCourseCount = courses
          .where(
            (course) =>
                !course.isDemo &&
                course.progress < 1 &&
                course.status?.toLowerCase() != 'completed',
          )
          .length;
    } catch (_) {
      // 코스 조회 실패 시 다른 요약 정보는 정상적으로 표시한다.
    }

    try {
      final requests = await ApiClient.instance.listFriendRequests();
      pendingSocialCount = requests
          .where((request) => request.status.toLowerCase() == 'pending')
          .length;
      SocialNotificationStore.update(friendRequests: pendingSocialCount);
    } catch (_) {
      // 기존 소셜 알림 값은 유지한다.
    }

    return _StudyCenterOverview(
      todayTaskCount: todayTaskCount,
      activeCourseCount: activeCourseCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16 * scale, 12 * scale, 16 * scale, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16 * scale),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: FutureBuilder<_StudyCenterOverview>(
          future: _overviewFuture,
          builder: (context, snapshot) {
            final overview = snapshot.data ?? _StudyCenterOverview.empty();
            return Column(
              children: [
                _HeroBanner(),
                _QuickOverviewRow(overview: overview),
                _QuickActionRow(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StudyCenterOverview {
  const _StudyCenterOverview({
    required this.todayTaskCount,
    required this.activeCourseCount,
  });

  final int todayTaskCount;
  final int activeCourseCount;

  factory _StudyCenterOverview.empty() =>
      const _StudyCenterOverview(todayTaskCount: 0, activeCourseCount: 0);
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(18 * scale, 16 * scale, 18 * scale, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학습터',
                  style: GoogleFonts.inter(
                    color: _kGreen,
                    fontSize: 30 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6 * scale),
                Text(
                  '학습 도구, 코스, 소셜을 같은 흐름으로 이어 빠르게 학습합니다.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF2F4138),
                    fontSize: 14 * scale,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 46 * scale,
            height: 46 * scale,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              color: _kGreen,
              size: 24 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickOverviewRow extends StatelessWidget {
  const _QuickOverviewRow({required this.overview});

  final _StudyCenterOverview overview;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(18 * scale, 18 * scale, 18 * scale, 0),
      child: Row(
        children: [
          Expanded(
            child: _OverviewChip(
              title: '오늘 할 일',
              value: '${overview.todayTaskCount}개',
              icon: Icons.checklist_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _OverviewChip(
              title: '진행 코스',
              value: '${overview.activeCourseCount}개',
              icon: Icons.route_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ValueListenableBuilder<SocialNotificationSnapshot>(
              valueListenable: SocialNotificationStore.notifier,
              builder: (context, social, _) {
                final count =
                    social.unreadMessages +
                    social.friendRequests +
                    social.friendRemovals;
                return _OverviewChip(
                  title: '소셜 알림',
                  value: '$count건',
                  icon: Icons.notifications_active_rounded,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Ios26FrostedCard(
      radius: 14 * scale,
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
      child: SizedBox(
        height: 64 * scale,
        child: Row(
          children: [
            Icon(icon, color: _kGreen, size: 22 * scale),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12 * scale,
                      color: const Color(0xFF5A665E),
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w700,
                      color: _kGreen,
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

class _QuickActionRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18 * scale,
        10 * scale,
        18 * scale,
        16 * scale,
      ),
      child: Wrap(
        spacing: 10 * scale,
        runSpacing: 10 * scale,
        children: [
          _QuickActionButton(
            icon: Icons.search_rounded,
            label: '코스 찾기',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CourseCatalogPage()),
            ),
          ),
          _QuickActionButton(
            icon: Icons.folder_copy_outlined,
            label: '책가방',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const docx.BookWidget())),
          ),
          _QuickActionButton(
            icon: Icons.groups_rounded,
            label: '친구/소셜',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const friend.SoWidget())),
          ),
          _QuickActionButton(
            icon: Icons.edit_note_rounded,
            label: '개념학습',
            onTap: () => openConceptStudy(context),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return _InteractiveTile(
      onTap: onTap,
      builder: (pressed, hovered) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 10 * scale,
        ),
        decoration: BoxDecoration(
          color: hovered ? Colors.white : Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x26000000)),
          boxShadow: hovered
              ? const [
                  BoxShadow(
                    blurRadius: 12,
                    color: Color(0x12000000),
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17 * scale, color: _kGreen),
            SizedBox(width: 8 * scale),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13 * scale,
                color: _kGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractiveTile extends StatefulWidget {
  const _InteractiveTile({required this.builder, required this.onTap});

  final Widget Function(bool pressed, bool hovered) builder;
  final VoidCallback onTap;

  @override
  State<_InteractiveTile> createState() => _InteractiveTileState();
}

class _InteractiveTileState extends State<_InteractiveTile> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.985 : (_hovered ? 1.01 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          child: widget.builder(_pressed, _hovered),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Container(
      width: double.infinity,
      height: 52 * scale,
      color: Colors.white,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(
        left: 24 * scale,
        bottom: 4 * scale,
        top: 10 * scale,
      ),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 19 * scale,
          fontWeight: FontWeight.w700,
          color: _kGreen,
        ),
      ),
    );
  }
}

class _CardData {
  const _CardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.cards});
  final List<_CardData> cards;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final gap = 10 * scale;
    final count = cards.length.clamp(1, 3).toInt();

    return Padding(
      padding: EdgeInsets.fromLTRB(16 * scale, 8 * scale, 16 * scale, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = count == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - gap * (count - 1)) / count;
          final children = <Widget>[];

          for (int i = 0; i < count; i++) {
            final card = _MenuCard(data: cards[i]);
            children.add(SizedBox(width: cardWidth, child: card));
            if (i != count - 1) {
              children.add(SizedBox(width: gap));
            }
          }

          return Row(children: children);
        },
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.data});
  final _CardData data;

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 220),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, (1 - t) * 8),
        child: Opacity(opacity: t, child: child),
      ),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(18 * scale),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 132 * scale,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14 * scale),
            boxShadow: const [
              BoxShadow(
                blurRadius: 14,
                color: Color(0x1F000000),
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      margin: EdgeInsets.only(left: 16 * scale),
                      width: 44 * scale,
                      height: 44 * scale,
                      decoration: BoxDecoration(
                        color: _kGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12 * scale),
                      ),
                      child: Icon(data.icon, size: 24 * scale, color: _kGreen),
                    ),
                    SizedBox(width: 12 * scale),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 17 * scale,
                              color: _kGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2 * scale),
                          Text(
                            data.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13 * scale,
                              color: const Color(0xFF536056),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.only(right: 14 * scale),
                width: 28 * scale,
                height: 28 * scale,
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18 * scale,
                  color: _kGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      child: Container(
        width: double.infinity,
        height: 180 * scale,
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.circular(14 * scale),
          boxShadow: const [
            BoxShadow(
              blurRadius: 14,
              color: Color(0x1F000000),
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 30 * scale),
                    child: Icon(
                      Icons.grade,
                      color: const Color(0xFFFFD600),
                      size: 60 * scale,
                    ),
                  ),
                  SizedBox(width: 12 * scale),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '시험 즉시 생성',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: _kWhite,
                            fontSize: 48 * scale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '학습 내역 기반으로 시험지를 즉시 생성합니다',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: _kWhite,
                            fontSize: 18 * scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 60 * scale),
              child: TextButton(
                onPressed: () => startExamFlow(context),
                style: TextButton.styleFrom(
                  backgroundColor: _kWhite,
                  foregroundColor: _kGreen,
                  minimumSize: Size(150 * scale, 60 * scale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24 * scale),
                  ),
                ),
                child: Text(
                  '시험코스가기',
                  style: GoogleFonts.interTight(
                    fontSize: 28 * scale,
                    color: _kGreen,
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
