part of 'package:s11/pages/exam_paper_page.dart';

class _ExamPaperContent extends StatelessWidget {
  const _ExamPaperContent({
    required this.layout,
    required this.pageNumber,
    required this.totalPages,
    this.statusMessage,
  });

  final _PageLayout? layout;
  final int pageNumber;
  final int totalPages;
  final String? statusMessage;

  static const TextStyle _baseStyle = TextStyle(
    fontSize: 13.5,
    height: 1.5,
    fontFamily: 'Batang',
  );
  static const TextStyle _questionNumberStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    fontFamily: 'Batang',
  );
  static const TextStyle _pointsStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    fontFamily: 'Batang',
  );
  static const TextStyle _optionStyle = TextStyle(
    fontSize: 13,
    fontFamily: 'Batang',
  );

  @override
  Widget build(BuildContext context) {
    final isFirstPage = pageNumber <= 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(isFirstPage: isFirstPage),
        const SizedBox(height: 18),
        Expanded(child: _buildContent()),
        const SizedBox(height: 16),
        _buildFooter(pageNumber: pageNumber, totalPages: totalPages),
      ],
    );
  }

  Widget _buildHeader({required bool isFirstPage}) {
    if (!isFirstPage) {
      return Container(
        padding: const EdgeInsets.only(top: _secondaryHeaderHeight),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
        ),
        child: const SizedBox.shrink(),
      );
    }
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _outlinePill('제 2 교시', fontSize: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '2025학년도 대학수학능력시험 문제지',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontFamily: 'Batang',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _outlineBox('가형', fontSize: 22),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '수학 영역',
            style: TextStyle(
              fontSize: 41,
              fontWeight: FontWeight.bold,
              letterSpacing: 14,
              fontFamily: 'Batang',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (statusMessage != null) {
      return Center(
        child: Text(
          statusMessage!,
          style: _baseStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (layout != null) {
      return _buildDynamicContent(layout!);
    }
    return _buildStaticContent();
  }

  Widget _buildDynamicContent(_PageLayout page) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth / 2;
        final rowHeight = constraints.maxHeight / 2;
        return Stack(
          children: [
            ...page.entries.map((entry) {
              final left = entry.column * columnWidth;
              final top = entry.row * rowHeight;
              final height = rowHeight * entry.rowSpan;
              return Positioned(
                left: left,
                top: top,
                width: columnWidth,
                height: height,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: entry.column == 0 ? 0 : 20,
                    right: entry.column == 0 ? 20 : 0,
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _buildExamItemCell(entry.item),
                  ),
                ),
              );
            }),
            Positioned(
              left: constraints.maxWidth / 2,
              top: 0,
              bottom: 0,
              child: Container(width: 1, color: Colors.black),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExamItemCell(ExamItem item) {
    final titleBlocks = parseContentBlocks(item.questTitle);
    final displayTitleBlocks = titleBlocks.isEmpty
        ? [const ContentBlock(type: 'text', content: 'Generating...')]
        : titleBlocks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${item.itemIndex}.',
          style: _questionNumberStyle,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ClipRect(
            child: ContentBlocksView(
              blocks: displayTitleBlocks,
              textStyle: _baseStyle.copyWith(fontSize: 12),
              latexStyle: _baseStyle.copyWith(fontSize: 12),
              spacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTopLeft()),
                      const SizedBox(width: 40),
                      Expanded(child: _problemBlock(_problem3())),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _problemBlock(_problem2())),
                      const SizedBox(width: 40),
                      Expanded(child: _problemBlock(_problem4())),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: constraints.maxWidth / 2,
              top: 0,
              bottom: 0,
              child: Container(width: 1, color: Colors.black),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopLeft() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _problemTypeHeader('5지선다형'),
        const SizedBox(height: 18),
        _problem1(),
      ],
    );
  }

  Widget _problemBlock(Widget child) {
    return Align(alignment: Alignment.topLeft, child: child);
  }

  Widget _problem1() {
    final mathStyle = _mathStyle(13.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _problemLine(
          number: '1.',
          text: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '3√5 × ', style: mathStyle),
                TextSpan(text: '25', style: mathStyle),
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Transform.translate(
                    offset: const Offset(0, -4),
                    child: Text('1/3', style: mathStyle.copyWith(fontSize: 9)),
                  ),
                ),
                const TextSpan(text: '의 값은?'),
              ],
            ),
          ),
          points: '2점',
        ),
        const SizedBox(height: 12),
        _optionsRow(const ['① 2', '② 3', '③ 4', '④ 5', '⑤ 6']),
      ],
    );
  }

  Widget _problem2() {
    final mathStyle = _mathStyle(13.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _problemLine(
          number: '2.',
          text: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '함수 '),
                TextSpan(text: 'f(x) = x', style: mathStyle),
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Transform.translate(
                    offset: const Offset(0, -4),
                    child: Text('3', style: mathStyle.copyWith(fontSize: 9)),
                  ),
                ),
                TextSpan(text: ' - 8x + 7', style: mathStyle),
                const TextSpan(text: '에 대하여 '),
                TextSpan(text: 'lim', style: mathStyle),
                WidgetSpan(
                  alignment: PlaceholderAlignment.bottom,
                  child: Transform.translate(
                    offset: const Offset(0, 4),
                    child: Text('h→0', style: mathStyle.copyWith(fontSize: 9)),
                  ),
                ),
                const TextSpan(text: ' '),
                TextSpan(text: '(f(2+h)-f(2))/h', style: mathStyle),
                const TextSpan(text: '의 값은?'),
              ],
            ),
          ),
          points: '2점',
        ),
        const SizedBox(height: 12),
        _optionsRow(const ['① -1', '② 0', '③ 4', '④ 8', '⑤ 12']),
      ],
    );
  }

  Widget _problem3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _problemLine(
          number: '3.',
          text: const Text('첫째항과 공비가 모두 정수 k인 등비수열 {aₙ}이'),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'a1a2 + a2a3 = 30',
            style: _mathStyle(13.5),
          ),
        ),
        const SizedBox(height: 10),
        _problemLine(
          number: '',
          text: const Text('을 만족시킬 때, k의 값은?'),
          points: '3점',
        ),
        const SizedBox(height: 12),
        _optionsRow(const ['① 1', '② 2', '③ 3', '④ 5', '⑤ 6']),
      ],
    );
  }

  Widget _problem4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _problemLine(
          number: '4.',
          text: const Text('함수 f(x)가 실수 전체의 집합에서 연속일 때 …'),
          points: '3점',
        ),
        const SizedBox(height: 12),
        _optionsRow(const ['① 6', '② 7', '③ 8', '④ 9', '⑤ 10']),
      ],
    );
  }

  Widget _buildFooter({required int pageNumber, required int totalPages}) {
    final safeTotal = totalPages < 1 ? 1 : totalPages;
    final safePage = pageNumber.clamp(1, safeTotal);
    return Align(
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFE0E0E0),
                border: Border(right: BorderSide(color: Colors.black, width: 1)),
              ),
              child: Text('$safePage'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Text('$safeTotal'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _problemTypeHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _problemLine({
    required String number,
    required Widget text,
    String? points,
  }) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 6,
      runSpacing: 4,
      children: [
        if (number.isNotEmpty)
          Text(number, style: _questionNumberStyle),
        DefaultTextStyle.merge(style: _baseStyle, child: text),
        if (points != null && points.isNotEmpty)
          Text('[$points]', style: _pointsStyle),
      ],
    );
  }

  Widget _optionsRow(List<String> options) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: options
          .map((opt) => Text(opt, style: _optionStyle))
          .toList(),
    );
  }

  Widget _outlinePill(String text, {double fontSize = 20}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _outlineBox(String text, {double fontSize = 20}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
    );
  }

  TextStyle _mathStyle(double size) => TextStyle(
    fontFamily: 'Times New Roman',
    fontStyle: FontStyle.italic,
    fontSize: size,
    height: 1.5,
  );
}
