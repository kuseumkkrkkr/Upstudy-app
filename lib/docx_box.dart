import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'widgets/app_drawer.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B402B)),
        fontFamily: 'Inter',
      ),
      home: const BookWidget(),
    );
  }
}

class BookWidget extends StatelessWidget {
  const BookWidget({super.key});

  static const Color primaryGreen = Color(0xFF1B402B);
  static const Color brightGreen = Color(0xFF39D276);
  static const Color darkGreen = Color(0xFF134D23);
  static const Color mediumGreen = Color(0xFF25B04C);
  static const Color borderColor = Color(0xFFE0E3E7);
  static const Color bgColor = Color(0xFFF8F8F8);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: bgColor,
        drawer: const AppDrawer(),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Builder(builder: (context) => _buildHeader(context)),
                _buildHeroSection(context),
                _buildBottomSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 상단 헤더 ──────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 90,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.menu_outlined,
              color: primaryGreen,
              size: 36,
            ),
            onPressed: () => toggleAppDrawer(context),
          ),
          const SizedBox(width: 16),
          const Text(
            'AIFlow',
            style: TextStyle(
              color: primaryGreen,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 0,
            ),
          ),
          const Spacer(),
          _navItem('학습터'),
          _navItem(
            '문서고',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BookWidget()),
              );
            },
          ),
          _navItem('친구/소셜'),
          Padding(
            padding: const EdgeInsets.only(right: 32),
            child: _navItem('마켓플레이스'),
          ),
        ],
      ),
    );
  }

  Widget _navItem(String label, {VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: primaryGreen,
          fontSize: 20,
          fontWeight: FontWeight.normal,
        ),
      ),
    ),
  );

  // ── 히어로 배너 ────────────────────────────────────────────────────────────
  Widget _buildHeroSection(BuildContext context) {
    final ImageProvider heroImage = kIsWeb
        ? const NetworkImage('http://localhost:8000/assets/bookshelf.png')
        : const AssetImage('assets/bookshelf.png');
    return Container(
      width: double.infinity,
      height: 550,
      decoration: BoxDecoration(
        image: DecorationImage(
          fit: BoxFit.cover,
          image: heroImage,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 120),
          // 제목 + 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '문서고함',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 40),
                _buildSearchBar(),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // 최근 문서 카드 그리드
          ..._buildRecentRows(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 500,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            color: Color(0x33000000),
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [SizedBox(width: 20), Icon(Icons.search_sharp, size: 28)],
      ),
    );
  }

  List<Widget> _buildRecentRows() {
    final rows = [
      [_recentCard(label: '대학수학능력시험 문제집', sub: '최근 학습 5분전'), _recentCard()],
      [_recentCard(), _recentCard()],
      [_recentCard(), _recentCard()],
    ];
    return rows
        .map(
          (row) => Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [row[0], const SizedBox(width: 40), row[1]],
            ),
          ),
        )
        .toList();
  }

  Widget _recentCard({String? label, String? sub}) {
    return Container(
      width: 380,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: brightGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.book_outlined,
              color: Colors.white,
              size: 36,
            ),
          ),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── 하단 콘텐츠 영역 ───────────────────────────────────────────────────────
  Widget _buildBottomSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽 컬럼
          Expanded(
            child: Column(
              children: [
                _buildSectionCard(
                  title: '시험지',
                  child: Column(
                    children: [
                      _documentItem(
                        color: mediumGreen,
                        icon: Icons.library_books_outlined,
                        title: '2022 대학수학능력시험 대비 문제집',
                        sub: '이수율 78% / 생성일 26.01.19',
                      ),
                      const SizedBox(height: 10),
                      _emptyDocItem(),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                _buildSectionCard(
                  title: '플래시카드',
                  child: Column(
                    children: [
                      _flashcardItem(title: '수열', subtitle: '중간고사 범위'),
                      _flashcardItem(title: 'Title', subtitle: 'Subtitle'),
                      _flashcardItem(title: 'Title', subtitle: 'Subtitle'),
                      _flashcardItem(title: 'Title', subtitle: 'Subtitle'),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                _reportButton(),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // 오른쪽 컬럼
          Expanded(
            child: Column(
              children: [
                _buildSectionCard(
                  title: '교재',
                  child: Column(
                    children: [
                      _documentItem(
                        color: darkGreen,
                        icon: Icons.book_outlined,
                        title: '미적분 보충교재',
                        sub: '이수율 78% / 생성일 26.01.17',
                      ),
                      const SizedBox(height: 10),
                      _emptyDocItem(),
                      const SizedBox(height: 10),
                      _emptyDocItem(),
                      const SizedBox(height: 10),
                      _emptyDocItem(),
                      const SizedBox(height: 10),
                      _emptyDocItem(),
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

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 0, 16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.arrow_forward_ios_sharp, size: 20),
              ),
            ],
          ),
          const Divider(thickness: 2, height: 0),
          Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 8), child: child),
        ],
      ),
    );
  }

  Widget _documentItem({
    required Color color,
    required IconData icon,
    required String title,
    required String sub,
  }) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 120,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyDocItem() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _flashcardItem({required String title, required String subtitle}) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 18,
        color: Colors.grey,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _reportButton() {
    return Container(
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 24),
            child: Text(
              '보고서 보기',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.arrow_forward_ios_sharp, size: 20),
          ),
        ],
      ),
    );
  }
}
