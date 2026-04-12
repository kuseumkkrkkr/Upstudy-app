import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:s11/models/concept_tag.dart';
import 'package:s11/services/api_client.dart';

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
  late final Map<String, String> _tagLabelMap = {
    for (final tag in _allTags) _normalize(tag): tag,
  };
  bool _loadingRatings = true;
  Map<String, TagRating> _tagRatings = {};

  @override
  void initState() {
    super.initState();
    _loadTagRatings();
  }

  Future<void> _loadTagRatings() async {
    try {
      final tags = await ApiClient.instance.fetchTagRatings();
      final map = <String, TagRating>{};
      for (final item in tags) {
        final key = _normalize(item.tag);
        if (key.isEmpty) continue;
        map[key] = _normalizeTagRating(item);
      }
      if (!mounted) return;
      setState(() {
        _tagRatings = map;
        _loadingRatings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRatings = false);
    }
  }

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

  String _labelForTag(String tag) {
    final key = _normalize(tag);
    final label = _tagLabelMap[key];
    if (label != null && label.isNotEmpty) {
      return label;
    }
    if (tag.trim().startsWith('#')) {
      return tag.trim();
    }
    return '#${tag.trim()}';
  }

  List<String> _flattenTagsUnder(ConceptTag tag) {
    final result = <String>[];
    void visit(ConceptTag current) {
      result.add(current.displayName);
      for (final child in current.children) {
        visit(child);
      }
    }
    visit(tag);
    return result;
  }

  List<_TagDelta> _buildRising() {
    final items = _tagRatings.values.where((item) => item.delta > 0).toList()
      ..sort((a, b) => b.delta.compareTo(a.delta));
    return items
        .take(5)
        .map(
          (item) => _TagDelta(
            label: _labelForTag(item.tag),
            delta: _visibleDelta(item.rating, item.delta),
          ),
        )
        .toList();
  }

  List<_TagDelta> _buildFalling() {
    final items = _tagRatings.values.where((item) => item.delta < 0).toList()
      ..sort((a, b) => a.delta.compareTo(b.delta));
    return items
        .take(5)
        .map(
          (item) => _TagDelta(
            label: _labelForTag(item.tag),
            delta: _visibleDelta(item.rating, item.delta),
          ),
        )
        .toList();
  }

  List<_TagScore> _buildStrong() {
    final items = _tagRatings.values.toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return items
        .take(5)
        .map((item) => _TagScore(label: _labelForTag(item.tag), score: item.rating))
        .toList();
  }

  List<_TagScore> _buildWeak() {
    final items = _tagRatings.values.toList()
      ..sort((a, b) => a.rating.compareTo(b.rating));
    return items
        .take(5)
        .map((item) => _TagScore(label: _labelForTag(item.tag), score: item.rating))
        .toList();
  }

  List<_RadarStat> _buildRadarStats() {
    if (_tagRatings.isEmpty) {
      return [];
    }
    final stats = <_RadarStat>[];
    final roots = conceptTagData.take(4).toList();
    for (final root in roots) {
      final tags = _flattenTagsUnder(root)
          .map((tag) => _normalize(tag))
          .where((tag) => tag.isNotEmpty)
          .toList();
      final ratings = tags
          .map((tag) => _tagRatings[tag]?.rating)
          .whereType<double>()
          .toList();
      final ovrs = ratings.map(_tagOvrValue).toList();
      final avg = ovrs.isEmpty
          ? 0.0
          : ovrs.reduce((a, b) => a + b) / ovrs.length;
      stats.add(
        _RadarStat(
          label: root.displayName.replaceAll('#', ''),
          score: avg,
        ),
      );
    }
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final rising = _buildRising();
    final falling = _buildFalling();
    final strong = _buildStrong();
    final weak = _buildWeak();
    final radarStats = _buildRadarStats();

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
                                  tagRatings: _tagRatings,
                                  isLoading: _loadingRatings,
                                  onChanged: () => setState(() {}),
                                )
                              : _OverviewBody(
                                  scale: scale,
                                  onSearchTap: _enterSearchMode,
                                  rising: rising,
                                  falling: falling,
                                  strong: strong,
                                  weak: weak,
                                  radarStats: radarStats,
                                  isLoading: _loadingRatings,
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
    required this.rising,
    required this.falling,
    required this.strong,
    required this.weak,
    required this.radarStats,
    required this.isLoading,
  });

  final double scale;
  final VoidCallback onSearchTap;
  final List<_TagDelta> rising;
  final List<_TagDelta> falling;
  final List<_TagScore> strong;
  final List<_TagScore> weak;
  final List<_RadarStat> radarStats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 920;

    if (isCompact) {
      return SingleChildScrollView(
        child: Column(
          children: [
            _TagDeltaCard(
              scale: scale,
              rising: rising,
              falling: falling,
              strong: strong,
              weak: weak,
              isLoading: isLoading,
            ),
            SizedBox(height: 16 * scale),
            _OverviewActions(scale: scale, onSearchTap: onSearchTap),
            SizedBox(height: 16 * scale),
            _OvrRadarCard(
              scale: scale,
              stats: radarStats,
              isLoading: isLoading,
            ),
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
                    Expanded(
                      child: _TagDeltaCard(
                        scale: scale,
                        rising: rising,
                        falling: falling,
                        strong: strong,
                        weak: weak,
                        isLoading: isLoading,
                      ),
                    ),
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
              Expanded(
                child: _OvrRadarCard(
                  scale: scale,
                  stats: radarStats,
                  isLoading: isLoading,
                ),
              ),
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
    required this.tagRatings,
    required this.isLoading,
    required this.onChanged,
  });

  final double scale;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> selectedTags;
  final List<String> suggestions;
  final Map<String, TagRating> tagRatings;
  final bool isLoading;
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
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : suggestions.isEmpty
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
                          final key = _normalize(tag);
                          final rating = tagRatings[key]?.rating;
                          return ListTile(
                            title: Text(tag),
                            trailing: rating == null
                                ? const SizedBox(width: 40, height: 40)
                                : _TagRatingProgressBar(
                                    rating: rating,
                                    size: 36 * scale,
                                    strokeWidth: 4 * scale,
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
  const _TagDeltaCard({
    required this.scale,
    required this.rising,
    required this.falling,
    required this.strong,
    required this.weak,
    required this.isLoading,
  });

  final double scale;
  final List<_TagDelta> rising;
  final List<_TagDelta> falling;
  final List<_TagScore> strong;
  final List<_TagScore> weak;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final content = isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
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
          );

    return _CardShell(
      scale: scale,
      title: '급상승/급하락 태그',
      child: content,
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
        if (items.isEmpty)
          Text(
            'No data',
            style: TextStyle(fontSize: 12 * scale, color: Colors.black54),
          )
        else
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
                    item.delta > 0
                        ? '+${item.delta.toStringAsFixed(1)}'
                        : item.delta.toStringAsFixed(1),
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
        if (items.isEmpty)
          Text(
            'No data',
            style: TextStyle(fontSize: 12 * scale, color: Colors.black54),
          )
        else
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
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _OvrRadarCard extends StatelessWidget {
  const _OvrRadarCard({
    required this.scale,
    required this.stats,
    required this.isLoading,
  });

  final double scale;
  final List<_RadarStat> stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final data = isLoading ? const <_RadarStat>[] : stats;

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
              maxValue: _tagOvrMax,
            ),
          ),
        );

        return _CardShell(
          scale: scale,
          title: '과목별 OVR 레이더 차트',
          expandChild: canExpand,
          child: Center(
            child: isLoading
                ? const CircularProgressIndicator()
                : data.isEmpty
                    ? const Text('No data')
                    : canExpand
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
  final double delta;
}

class _TagScore {
  const _TagScore({required this.label, required this.score});
  final String label;
  final double score;
}

class _RadarStat {
  const _RadarStat({required this.label, required this.score});

  final String label;
  final double score;

  double get ovr => score;
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

const double _tagRatingFloor = 1200;
const double _tagDisplayMax = 32767;
const double _tagOvrDivider = 128;
const double _tagOvrMax = _tagDisplayMax / _tagOvrDivider;

double _normalizedTagRatingValue(double rating) {
  return math.max(rating, _tagRatingFloor);
}

TagRating _normalizeTagRating(TagRating item) {
  return TagRating(
    tag: item.tag,
    rating: _normalizedTagRatingValue(item.rating),
    delta: item.delta,
    attempts: item.attempts,
  );
}

double _tagDisplayValue(double rating) {
  return (_normalizedTagRatingValue(rating) - _tagRatingFloor)
      .clamp(0, _tagDisplayMax)
      .toDouble();
}

double _tagOvrValue(double rating) {
  return _tagDisplayValue(rating) / _tagOvrDivider;
}

double _visibleDelta(double rating, double delta) {
  final current = _tagOvrValue(rating);
  final previous = _tagOvrValue(rating - delta);
  return current - previous;
}

class _TagRatingProgressBar extends StatefulWidget {
  const _TagRatingProgressBar({
    required this.rating,
    required this.size,
    required this.strokeWidth,
  });

  final double rating;
  final double size;
  final double strokeWidth;

  @override
  State<_TagRatingProgressBar> createState() => _TagRatingProgressBarState();
}

class _TagRatingProgressBarState extends State<_TagRatingProgressBar> {
  bool _showBubble = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    _timer?.cancel();
    setState(() => _showBubble = true);
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _showBubble = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final display = _tagDisplayValue(widget.rating);
    final progress = (display / _tagDisplayMax).clamp(0.0, 1.0);
    final ovrText = _tagOvrValue(widget.rating).toStringAsFixed(1);
    final bubble = AnimatedOpacity(
      opacity: _showBubble ? 1 : 0,
      duration: const Duration(milliseconds: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          ovrText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return GestureDetector(
      onTap: _handleTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: -(widget.size),
            child: bubble,
          ),
          Container(
            width: 50,
            height: widget.strokeWidth * 1.3,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(widget.strokeWidth * 1.3),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B402B),
                  borderRadius: BorderRadius.circular(widget.strokeWidth * 1.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
