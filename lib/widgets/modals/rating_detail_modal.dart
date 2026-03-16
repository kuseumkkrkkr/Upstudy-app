import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:s11/models/concept_tag.dart';

Future<T?> showRatingDetailModal<T>({required BuildContext context}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            const Center(child: RatingDetailModal()),
          ],
        ),
      );
    },
  );
}

class RatingDetailModal extends StatefulWidget {
  const RatingDetailModal({super.key});

  @override
  State<RatingDetailModal> createState() => _RatingDetailModalState();
}

class _RatingDetailModalState extends State<RatingDetailModal> {
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final List<String> _allTags = _flattenConceptTags(conceptTagData);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _enterSearchMode() {
    setState(() => _isSearchMode = true);
    Future.microtask(() => _searchFocusNode.requestFocus());
  }

  void _exitSearchMode() {
    setState(() => _isSearchMode = false);
  }

  void _handleClose() {
    if (_isSearchMode) {
      _exitSearchMode();
    } else {
      Navigator.of(context).pop();
    }
  }

  String _currentQuery(String text) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) return '';
    final lastHash = trimmed.lastIndexOf('#');
    if (lastHash == -1) return trimmed;
    return trimmed.substring(lastHash + 1);
  }

  List<String> _selectedTags(String text) {
    final matches = RegExp(r'#([^#\s]+)').allMatches(text);
    final seen = <String>{};
    final result = <String>[];
    for (final match in matches) {
      final value = '#${match.group(1)}';
      if (seen.add(value)) {
        result.add(value);
      }
    }
    return result;
  }

  List<String> _filteredTags() {
    final query = _normalize(_currentQuery(_searchController.text));
    if (query.isEmpty) {
      return _allTags;
    }
    return _allTags
        .where((tag) => _normalize(tag).contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 1200.0;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 720.0;
        const baseWidth = 1200.0;
        const baseHeight = 680.0;
        final width = math.min(baseWidth, maxW * 0.96);
        final height = math.min(baseHeight, maxH * 0.96);
        final scale = (width / baseWidth).clamp(0.6, 1.0);

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              top: true,
              child: Center(
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20 * scale),
                  ),
                  child: Column(
                    children: [
                      _ModalHeader(
                        scale: scale,
                        isSearchMode: _isSearchMode,
                        onClose: _handleClose,
                      ),
                      Divider(height: 1 * scale),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(20 * scale),
                          child: _isSearchMode
                              ? _SearchBody(
                                  scale: scale,
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  selectedTags:
                                      _selectedTags(_searchController.text),
                                  suggestions: _filteredTags(),
                                  onChanged: () => setState(() {}),
                                )
                              : _OverviewBody(
                                  scale: scale,
                                  onSearchTap: _enterSearchMode,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({
    required this.scale,
    required this.isSearchMode,
    required this.onClose,
  });

  final double scale;
  final bool isSearchMode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16 * scale,
        right: 24 * scale,
        top: 8 * scale,
        bottom: 8 * scale,
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: 30 * scale,
            icon: Icon(
              isSearchMode ? Icons.arrow_back : Icons.close,
              color: Colors.black,
            ),
            onPressed: onClose,
          ),
          SizedBox(width: 8 * scale),
          Text(
            isSearchMode ? '세부 해시태그 검색' : '레이팅 상세',
            style: TextStyle(
              fontSize: 22 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.scale,
    required this.onSearchTap,
  });

  final double scale;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 920;

    if (isCompact) {
      return SingleChildScrollView(
        child: Column(
          children: [
            _TagDeltaCard(scale: scale),
            SizedBox(height: 16 * scale),
            _OverviewActions(scale: scale, onSearchTap: onSearchTap),
            SizedBox(height: 16 * scale),
            _OvrRadarCard(scale: scale),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 520.0 * scale;
        return SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _TagDeltaCard(scale: scale)),
                    SizedBox(height: 12 * scale),
                    _ActionButton(
                      scale: scale,
                      label: '세부 해시태그 검색',
                      onTap: onSearchTap,
                    ),
                    SizedBox(height: 12 * scale),
                    _ActionButton(
                      scale: scale,
                      label: '보고서 보기',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16 * scale),
              Expanded(child: _OvrRadarCard(scale: scale)),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewActions extends StatelessWidget {
  const _OverviewActions({
    required this.scale,
    required this.onSearchTap,
  });

  final double scale;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionButton(
          scale: scale,
          label: '세부 해시태그 검색',
          onTap: onSearchTap,
        ),
        SizedBox(height: 12 * scale),
        _ActionButton(
          scale: scale,
          label: '보고서 보기',
          onTap: () {},
        ),
      ],
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.scale,
    required this.controller,
    required this.focusNode,
    required this.selectedTags,
    required this.suggestions,
    required this.onChanged,
  });

  final double scale;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> selectedTags;
  final List<String> suggestions;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '해시태그를 입력하면 해당 개념의 점수를 조회합니다. #을 추가하면 새로운 해시태그로 인식됩니다.',
          style: TextStyle(
            fontSize: 12 * scale,
            color: Colors.black54,
          ),
        ),
        SizedBox(height: 10 * scale),
        TextField(
          controller: controller,
          focusNode: focusNode,
          minLines: 1,
          maxLines: 3,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            hintText: '#함수 #도함수',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 12 * scale,
            ),
          ),
        ),
        if (selectedTags.isNotEmpty) ...[
          SizedBox(height: 12 * scale),
          Wrap(
            spacing: 8 * scale,
            runSpacing: 8 * scale,
            children: selectedTags
                .map(
                  (tag) => Chip(
                    label: Text(tag),
                    backgroundColor: const Color(0xFFEFF5F0),
                  ),
                )
                .toList(),
          ),
        ],
        SizedBox(height: 16 * scale),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: suggestions.isEmpty
                ? Center(
                    child: Text(
                      '검색 결과가 없습니다.',
                      style: TextStyle(
                        fontSize: 14 * scale,
                        color: Colors.black54,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1 * scale),
                    itemBuilder: (context, index) {
                      final tag = suggestions[index];
                      final ovr = _mockOvrForTag(tag);
                      return ListTile(
                        title: Text(tag),
                        trailing: Text(
                          'OVR ${ovr.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1B402B),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _TagDeltaCard extends StatelessWidget {
  const _TagDeltaCard({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final rising = const [
      _TagDelta(label: '#함수', delta: 48),
      _TagDelta(label: '#지수', delta: 36),
      _TagDelta(label: '#수열', delta: 29),
      _TagDelta(label: '#도형', delta: 24),
      _TagDelta(label: '#미분', delta: 18),
    ];
    final falling = const [
      _TagDelta(label: '#기하', delta: -22),
      _TagDelta(label: '#확률', delta: -18),
      _TagDelta(label: '#벡터', delta: -12),
      _TagDelta(label: '#삼각함수', delta: -10),
      _TagDelta(label: '#로그', delta: -8),
    ];
    final strong = const [
      _TagScore(label: '#수열', score: 224.3),
      _TagScore(label: '#지수', score: 218.7),
      _TagScore(label: '#함수', score: 212.9),
      _TagScore(label: '#도형', score: 206.4),
      _TagScore(label: '#미분', score: 201.2),
    ];
    final weak = const [
      _TagScore(label: '#확률', score: 128.5),
      _TagScore(label: '#기하', score: 134.2),
      _TagScore(label: '#벡터', score: 139.1),
      _TagScore(label: '#삼각함수', score: 142.6),
      _TagScore(label: '#로그', score: 149.3),
    ];

    return _CardShell(
      scale: scale,
      title: '급상승/급하락 태그',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TagDeltaColumn(
                  scale: scale,
                  title: '급상승 TOP5',
                  items: rising,
                  highlight: const Color(0xFF1B402B),
                ),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: _TagDeltaColumn(
                  scale: scale,
                  title: '급하락 TOP5',
                  items: falling,
                  highlight: const Color(0xFFB44747),
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TagScoreColumn(
                  scale: scale,
                  title: '잘 푸는 개념 TOP5',
                  items: strong,
                  highlight: const Color(0xFF1B402B),
                ),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: _TagScoreColumn(
                  scale: scale,
                  title: '잘 못 푸는 개념 TOP5',
                  items: weak,
                  highlight: const Color(0xFFB44747),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagDeltaColumn extends StatelessWidget {
  const _TagDeltaColumn({
    required this.scale,
    required this.title,
    required this.items,
    required this.highlight,
  });

  final double scale;
  final String title;
  final List<_TagDelta> items;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12 * scale),
        ...items.map(
          (item) => Padding(
            padding: EdgeInsets.only(bottom: 10 * scale),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(fontSize: 13 * scale),
                  ),
                ),
                Text(
                  item.delta > 0 ? '+${item.delta}' : '${item.delta}',
                  style: TextStyle(
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w700,
                    color: highlight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TagScoreColumn extends StatelessWidget {
  const _TagScoreColumn({
    required this.scale,
    required this.title,
    required this.items,
    required this.highlight,
  });

  final double scale;
  final String title;
  final List<_TagScore> items;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12 * scale),
        ...items.map(
          (item) => Padding(
            padding: EdgeInsets.only(bottom: 10 * scale),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(fontSize: 13 * scale),
                  ),
                ),
                Text(
                  item.score.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w700,
                    color: highlight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OvrRadarCard extends StatelessWidget {
  const _OvrRadarCard({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    const data = [
      _RadarStat(label: '공통수학1', rawScore: 28670),
      _RadarStat(label: '공통수학2', rawScore: 27420),
      _RadarStat(label: '대수', rawScore: 29110),
      _RadarStat(label: '기하', rawScore: 26240),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final canExpand = constraints.maxHeight.isFinite;
        final chart = AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            painter: _RadarChartPainter(
              data: data,
              gridCount: 4,
              lineColor: const Color(0xFF1B402B),
              fillColor: const Color(0x331B402B),
              labelColor: Colors.black87,
              maxValue: 256,
            ),
          ),
        );

        return _CardShell(
          scale: scale,
          title: '과목별 OVR 레이더 차트',
          expandChild: canExpand,
          child: Center(
            child: canExpand
                ? chart
                : SizedBox(
                    height: 260 * scale,
                    child: chart,
                  ),
          ),
        );
      },
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.scale,
    required this.title,
    required this.child,
    this.expandChild = false,
  });

  final double scale;
  final String title;
  final Widget child;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            color: Color(0x22000000),
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 14 * scale),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.scale,
    required this.label,
    required this.onTap,
  });

  final double scale;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * scale),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            color: Color(0x22000000),
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14 * scale),
        child: InkWell(
          borderRadius: BorderRadius.circular(14 * scale),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14 * scale),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B402B),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagDelta {
  const _TagDelta({required this.label, required this.delta});
  final String label;
  final int delta;
}

class _TagScore {
  const _TagScore({required this.label, required this.score});
  final String label;
  final double score;
}

class _RadarStat {
  const _RadarStat({required this.label, required this.rawScore});

  final String label;
  final int rawScore;

  double get ovr => rawScore / 128.0;
}

class _RadarChartPainter extends CustomPainter {
  _RadarChartPainter({
    required this.data,
    required this.gridCount,
    required this.lineColor,
    required this.fillColor,
    required this.labelColor,
    required this.maxValue,
  });

  final List<_RadarStat> data;
  final int gridCount;
  final Color lineColor;
  final Color fillColor;
  final Color labelColor;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;
    final count = data.length;
    final angleStep = (math.pi * 2) / count;
    final scaleMax = maxValue <= 0 ? 1 : maxValue;

    final gridPaint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var level = 1; level <= gridCount; level++) {
      final r = radius * (level / gridCount);
      final path = Path();
      for (var i = 0; i < count; i++) {
        final angle = -math.pi / 2 + angleStep * i;
        final point = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + angleStep * i;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, point, axisPaint);
    }

    final dataPath = Path();
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + angleStep * i;
      final valueRatio = (data[i].ovr / scaleMax).clamp(0.0, 1.0);
      final r = radius * valueRatio;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, linePaint);

    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + angleStep * i;
      final valueRatio = (data[i].ovr / scaleMax).clamp(0.0, 1.0);
      final r = radius * valueRatio;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      canvas.drawCircle(point, 3.5, pointPaint);
    }

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + angleStep * i;
      final labelOffset = Offset(
        center.dx + (radius + 20) * math.cos(angle),
        center.dy + (radius + 20) * math.sin(angle),
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${data[i].label}\n${data[i].ovr.toStringAsFixed(1)}',
          style: TextStyle(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius);
      final offset = Offset(
        labelOffset.dx - textPainter.width / 2,
        labelOffset.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

List<String> _flattenConceptTags(List<ConceptTag> tags) {
  final result = <String>[];
  final seen = <String>{};

  void visit(ConceptTag tag) {
    final value = tag.displayName.trim();
    if (value.isNotEmpty && seen.add(value)) {
      result.add(value);
    }
    for (final child in tag.children) {
      visit(child);
    }
  }

  for (final tag in tags) {
    visit(tag);
  }

  return result;
}

String _normalize(String value) {
  return value.replaceAll('#', '').toLowerCase().trim();
}

double _mockOvrForTag(String tag) {
  var sum = 0;
  for (final unit in tag.codeUnits) {
    sum = (sum + unit) % 32768;
  }
  return sum / 128.0;
}
