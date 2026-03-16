import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'book_page.dart' as book_page;
import 'docx_box.dart' as docx;
import 'friend.dart' as friend;
import 'package:s11/mainstudent.dart';
import 'pages/course_pages.dart';
import 'widgets/app_drawer.dart';

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

const _navStyle = TextStyle(
  color: _kGreen,
  fontSize: 30,
  fontWeight: FontWeight.normal,
);

double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
  final width = MediaQuery.of(context).size.width;
  final scale = width / 1100;
  if (scale < min) return min;
  if (scale > max) return max;
  return scale;
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StudyCenterNavBar(),
                _HeroBanner(),
                _SectionHeader(title: '커리큘럼'),
                const Divider(thickness: 2, height: 2),
                _CardRow(
                  cards: [
                    _CardData(
                      icon: Icons.search,
                      title: '커리큘럼 찾기',
                      subtitle: '수강중인 커리큘럼을 검색합니다',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CourseCatalogPage(),
                          ),
                        );
                      },
                    ),
                    _CardData(
                      icon: Icons.architecture_sharp,
                      title: '커리큘럼 만들기',
                      subtitle: '나에게 맞는 커리큘럼을 생성합니다',
                    ),
                    _CardData(
                      icon: Icons.library_books,
                      title: '교재 만들기',
                      subtitle: '맞춤형 교재를 만듭니다',
                    ),
                  ],
                ),
                _CardRow(
                  cards: [
                    _CardData(
                      icon: Icons.bookmark,
                      title: '북마크',
                      subtitle: '저장한 북마크를 확인합니다',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const book_page.BookmarkListPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SectionHeader(title: '성장 사례'),
                const Divider(thickness: 2, height: 2),
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
                    ),
                    _CardData(
                      icon: Icons.content_paste,
                      title: '빈출 유형',
                      subtitle: '빈출 유형 문제 풀이',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SectionHeader(title: '시험 연습'),
                const Divider(thickness: 2, height: 2),
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
                _SectionHeader(title: '분석'),
                const Divider(thickness: 2, height: 2),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudyCenterNavBar extends StatelessWidget {
  const StudyCenterNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return Container(
      width: double.infinity,
      height: 72 * scale,
      color: _kWhite,
      child: Row(
        children: [
          SizedBox(width: 16 * scale),
          IconButton(
            iconSize: 28 * scale,
            icon: const Icon(Icons.menu_outlined, color: _kGreen),
            onPressed: () => toggleAppDrawer(context),
          ),
          SizedBox(width: 12 * scale),
          SizedBox(width: 12 * scale),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainStudentPage()),
                (route) => false,
              );
            },
            child: Text(
              'AIFlow',
              style: TextStyle(
                color: _kGreen,
                fontSize: 36 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 120 * scale),
          Expanded(
            child: Container(
              color: _kWhite,
              height: 72 * scale,
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final label in ['학습터', '문서고', '친구/소셜', '마켓플레이스'])
                      Padding(
                        padding: EdgeInsets.only(
                          right: label == '마켓플레이스' ? 24 * scale : 0,
                        ),
                        child: GestureDetector(
                          onTap: label == '친구/소셜'
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const friend.SoWidget(),
                                    ),
                                  );
                                }
                              : label == '문서고'
                                  ? () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const docx.BookWidget(),
                                        ),
                                      );
                                    }
                                  : null,
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: 12 * scale),
                            child: Text(
                              label,
                              style: _navStyle.copyWith(fontSize: 16 * scale),
                            ),
                          ),
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

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return SizedBox(
      width: double.infinity,
      height: 755 * scale,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1543248939-4296e1fea89b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwyfHxib29rc2hlbGZ8ZW58MHx8fHwxNzcyMzUzMjA5fDA&ixlib=rb-4.1.0&q=80&w=1080',
            fit: BoxFit.cover,
          ),
          Container(color: const Color(0xBB000000)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'AIFlow 학습터',
                style: GoogleFonts.inter(
                  color: _kWhite,
                  fontSize: 120 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '학습 도구를 사용할 수 있습니다',
                style: GoogleFonts.inter(
                  color: const Color(0xFFE7E7E7),
                  fontSize: 28 * scale,
                ),
              ),
            ],
          ),
        ],
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
      height: 80 * scale,
      color: Colors.white,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 30 * scale, bottom: 5 * scale),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 36 * scale,
          fontWeight: FontWeight.w600,
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
    final widgets = <Widget>[];
    for (final card in cards) {
      widgets.add(Expanded(child: _MenuCard(data: card)));
    }
    for (int i = cards.length; i < 3; i++) {
      widgets.add(const Expanded(child: SizedBox()));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(30 * scale, 10 * scale, 30 * scale, 0),
      child: Row(
        children: widgets
            .expand(
              (w) => [w, if (w != widgets.last) SizedBox(width: 30 * scale)],
            )
            .toList(),
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
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(16 * scale),
      child: Container(
        height: 150 * scale,
        decoration: BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.circular(16 * scale),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4,
              color: Color(0x33000000),
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 20 * scale),
                    child: Icon(data.icon, size: 60 * scale),
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
                            fontSize: 32 * scale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          data.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 14 * scale),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 16 * scale),
              child: Icon(Icons.arrow_forward_ios, size: 24 * scale),
            ),
          ],
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
      padding: EdgeInsets.symmetric(horizontal: 30 * scale),
      child: Container(
        width: double.infinity,
        height: 180 * scale,
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.circular(16 * scale),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4,
              color: Color(0x33000000),
              offset: Offset(0, 2),
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
                onPressed: () {},
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
