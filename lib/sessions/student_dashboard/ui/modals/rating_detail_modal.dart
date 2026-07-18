import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/concept_tag.dart';
import 'package:s11/shared/services/api/api_client.dart';

// 필요 변수: 현재 context. 작동 원리: 반투명 블러 배경 위에 레이팅 상세 모달을 표시한다.
Future<T?> showRatingDetailModal<T>({
  required BuildContext context,
  Map<String, TagRating>? initialRatings,
}) {
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
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
            Center(child: RatingDetailModal(initialRatings: initialRatings)),
          ],
        ),
      );
    },
  );
}

class RatingDetailModal extends StatefulWidget {
  const RatingDetailModal({super.key, this.initialRatings});

  final Map<String, TagRating>? initialRatings;

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
    final initialRatings = widget.initialRatings;
    if (initialRatings == null) {
      _loadTagRatings();
    } else {
      _tagRatings = initialRatings.map(
        (key, value) => MapEntry(_normalize(key), _normalizeTagRating(value)),
      );
      _loadingRatings = false;
    }
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

  /// 필요한 변수는 상승·하락·강점·약점 태그와 현재 로딩 상태다.
  /// 작동 원리는 현재 레이팅 데이터를 HTML 학습 보고서 모달의 요약·강점·보완 카드로 변환한다.
  void _openReport() {
    final rising = _buildRising();
    final falling = _buildFalling();
    final strong = _buildStrong();
    final weak = _buildWeak();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학습 레이팅 보고서'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'RATING REPORT',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: Colors.black54,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _ReportSection(
                  title: '상승 개념',
                  values: rising
                      .map(
                        (item) =>
                            '${item.label}  +${item.delta.toStringAsFixed(1)}',
                      )
                      .toList(),
                ),
                _ReportSection(
                  title: '보완 개념',
                  values: falling
                      .map(
                        (item) =>
                            '${item.label}  ${item.delta.toStringAsFixed(1)}',
                      )
                      .toList(),
                ),
                _ReportSection(
                  title: '현재 강점',
                  values: strong
                      .map(
                        (item) =>
                            '${item.label}  ${item.score.toStringAsFixed(1)}',
                      )
                      .toList(),
                ),
                _ReportSection(
                  title: '우선 복습',
                  values: weak
                      .map(
                        (item) =>
                            '${item.label}  ${item.score.toStringAsFixed(1)}',
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 전체 검색 문자열이다.
  /// 작동 원리: 마지막 해시태그 뒤의 작성 중인 단어만 검색어로 사용하고, 공백으로 확정된 태그는 검색 조건에서 제외한다.
  String _currentQuery(String text) {
    if (text.isNotEmpty && RegExp(r'\s$').hasMatch(text)) return '';
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

  /// 필요한 변수는 현재 검색어·전체 개념 태그·사용자 레이팅이다.
  /// 작동 원리: 검색 전에는 실제 풀이 이력이 많은 개념을 먼저, 검색 중에는 완전 일치와 접두어 일치를 우선 노출한다.
  List<String> _filteredTags() {
    final query = _normalize(_currentQuery(_searchController.text));
    if (query.isEmpty) {
      final ratedTags = _tagRatings.values.toList()
        ..sort((a, b) {
          final attempts = b.attempts.compareTo(a.attempts);
          return attempts != 0 ? attempts : b.rating.compareTo(a.rating);
        });
      final visible = <String>[];
      final seen = <String>{};
      for (final rating in ratedTags) {
        final label = _labelForTag(rating.tag);
        if (seen.add(_normalize(label))) visible.add(label);
      }
      for (final tag in _allTags) {
        if (seen.add(_normalize(tag))) visible.add(tag);
      }
      return visible;
    }
    final matches = _allTags
        .where((tag) => _normalize(tag).contains(query))
        .toList();
    matches.sort((a, b) {
      final aValue = _normalize(a);
      final bValue = _normalize(b);
      final aRank = aValue == query
          ? 0
          : aValue.startsWith(query)
          ? 1
          : 2;
      final bRank = bValue == query
          ? 0
          : bValue.startsWith(query)
          ? 1
          : 2;
      final rank = aRank.compareTo(bRank);
      return rank != 0 ? rank : aValue.length.compareTo(bValue.length);
    });
    return matches;
  }

  /// 필요한 변수는 사용자가 누른 태그와 현재 입력 문자열이다.
  /// 작동 원리: 작성 중인 마지막 검색어를 선택 태그로 교체하고 다음 검색을 바로 입력할 수 있게 공백을 붙인다.
  void _selectSearchTag(String tag) {
    final normalizedTag = tag.startsWith('#') ? tag : '#$tag';
    final text = _searchController.text;
    final lastHash = text.lastIndexOf('#');
    final prefix = lastHash >= 0 ? text.substring(0, lastHash) : '';
    final nextText =
        '${prefix.trimRight()}${prefix.trim().isEmpty ? '' : ' '}$normalizedTag ';
    _searchController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
    setState(() {});
    _searchFocusNode.requestFocus();
  }

  /// 필요한 변수는 제거할 태그와 현재 입력 문자열이다.
  /// 작동 원리: 선택 칩과 일치하는 해시태그 토큰만 제거하고 나머지 검색 조건은 유지한다.
  void _removeSearchTag(String tag) {
    final target = _normalize(tag);
    final remaining = _selectedTags(
      _searchController.text,
    ).where((item) => _normalize(item) != target);
    final nextText = remaining.isEmpty ? '' : '${remaining.join(' ')} ';
    _searchController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
    setState(() {});
    _searchFocusNode.requestFocus();
  }

  /// 필요한 변수는 검색 컨트롤러다.
  /// 작동 원리: 입력과 선택 태그를 한 번에 비우고 추천 개념 목록으로 복귀한다.
  void _clearSearch() {
    _searchController.clear();
    setState(() {});
    _searchFocusNode.requestFocus();
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
        .map(
          (item) =>
              _TagScore(label: _labelForTag(item.tag), score: item.rating),
        )
        .toList();
  }

  List<_TagScore> _buildWeak() {
    final items = _tagRatings.values.toList()
      ..sort((a, b) => a.rating.compareTo(b.rating));
    return items
        .take(5)
        .map(
          (item) =>
              _TagScore(label: _labelForTag(item.tag), score: item.rating),
        )
        .toList();
  }

  List<_RadarStat> _buildRadarStats() {
    if (_tagRatings.isEmpty) {
      return [];
    }
    final stats = <_RadarStat>[];
    final roots = conceptTagData.take(4).toList();
    for (final root in roots) {
      final tags = _flattenTagsUnder(
        root,
      ).map((tag) => _normalize(tag)).where((tag) => tag.isNotEmpty).toList();
      final ratings = tags
          .map((tag) => _tagRatings[tag]?.rating)
          .whereType<double>()
          .toList();
      final ovrs = ratings.map(_tagOvrValue).toList();
      final avg = ovrs.isEmpty
          ? 0.0
          : ovrs.reduce((a, b) => a + b) / ovrs.length;
      stats.add(
        _RadarStat(label: root.displayName.replaceAll('#', ''), score: avg),
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
        const baseWidth = 1120.0;
        const baseHeight = 760.0;
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
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(28 * scale),
                    border: Border.all(color: const Color(0xFFD8D8DC)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 42,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _ModalHeader(
                        scale: scale,
                        isSearchMode: _isSearchMode,
                        onClose: _handleClose,
                      ),
                      Divider(
                        height: 1 * scale,
                        color: const Color(0xFFD8D8DC),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(20 * scale),
                          child: _isSearchMode
                              ? _SearchBody(
                                  scale: scale,
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  selectedTags: _selectedTags(
                                    _searchController.text,
                                  ),
                                  suggestions: _filteredTags(),
                                  tagRatings: _tagRatings,
                                  isLoading: _loadingRatings,
                                  onChanged: () => setState(() {}),
                                  onTagTap: _selectSearchTag,
                                  onTagRemoved: _removeSearchTag,
                                  onClear: _clearSearch,
                                  quickTags: conceptTagData
                                      .take(6)
                                      .map((tag) => tag.displayName)
                                      .toList(),
                                )
                              : _OverviewBody(
                                  scale: scale,
                                  onSearchTap: _enterSearchMode,
                                  onReportTap: _openReport,
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
      padding: EdgeInsets.fromLTRB(
        28 * scale,
        22 * scale,
        24 * scale,
        20 * scale,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSearchMode ? 'CONCEPT SEARCH' : 'OVR DETAIL',
                  style: TextStyle(
                    color: const Color(0xFF77777F),
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                SizedBox(height: 7 * scale),
                Text(
                  isSearchMode ? '세부 해시태그 검색' : '레이팅 상세',
                  style: TextStyle(
                    fontSize: 30 * scale,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                if (!isSearchMode) ...[
                  SizedBox(height: 5 * scale),
                  Text(
                    '현재 실력과 개념별 변화를 한눈에 확인하세요.',
                    style: TextStyle(
                      color: const Color(0xFF77777F),
                      fontSize: 12 * scale,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Material(
            color: Colors.white,
            shape: const CircleBorder(
              side: BorderSide(color: Color(0xFFD8D8DC)),
            ),
            child: IconButton(
              tooltip: isSearchMode ? '뒤로가기' : '닫기',
              icon: Text(
                isSearchMode ? '←' : '×',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24 * scale,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.scale,
    required this.onSearchTap,
    required this.onReportTap,
    required this.rising,
    required this.falling,
    required this.strong,
    required this.weak,
    required this.radarStats,
    required this.isLoading,
  });

  final double scale;
  final VoidCallback onSearchTap;
  final VoidCallback onReportTap;
  final List<_TagDelta> rising;
  final List<_TagDelta> falling;
  final List<_TagScore> strong;
  final List<_TagScore> weak;
  final List<_RadarStat> radarStats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 920;
    final radarAverage = radarStats.isEmpty
        ? 0.0
        : radarStats.map((item) => item.ovr).reduce((a, b) => a + b) /
              radarStats.length;
    final solvedConcepts = strong.length + weak.length;
    final tier = radarAverage >= 22
        ? 'A'
        : radarAverage >= 17
        ? 'B'
        : radarAverage >= 12
        ? 'C'
        : '-';
    final summary = _RatingSummaryStrip(
      scale: scale,
      ovr: radarAverage,
      solvedConcepts: solvedConcepts,
      tier: tier,
      isLoading: isLoading,
    );

    if (isCompact) {
      return SingleChildScrollView(
        child: Column(
          children: [
            summary,
            SizedBox(height: 12 * scale),
            _TagDeltaCard(
              scale: scale,
              rising: rising,
              falling: falling,
              strong: strong,
              weak: weak,
              isLoading: isLoading,
            ),
            SizedBox(height: 16 * scale),
            _OverviewActions(
              scale: scale,
              onSearchTap: onSearchTap,
              onReportTap: onReportTap,
            ),
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
          child: Column(
            children: [
              summary,
              SizedBox(height: 12 * scale),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 9,
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
                          SizedBox(height: 10 * scale),
                          Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  scale: scale,
                                  label: '세부 해시태그 검색',
                                  onTap: onSearchTap,
                                ),
                              ),
                              SizedBox(width: 8 * scale),
                              Expanded(
                                child: _ActionButton(
                                  scale: scale,
                                  label: '보고서 보기',
                                  onTap: onReportTap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    Expanded(
                      flex: 11,
                      child: _OvrRadarCard(
                        scale: scale,
                        stats: radarStats,
                        isLoading: isLoading,
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
}

class _RatingSummaryStrip extends StatelessWidget {
  const _RatingSummaryStrip({
    required this.scale,
    required this.ovr,
    required this.solvedConcepts,
    required this.tier,
    required this.isLoading,
  });

  final double scale;
  final double ovr;
  final int solvedConcepts;
  final String tier;
  final bool isLoading;

  /// 필요한 변수는 평균 OVR·분석 개념 수·티어다.
  /// 작동 원리: HTML의 3칸 요약표처럼 첫 지표를 반전하고 나머지를 동일 시각 위계로 연결한다.
  @override
  Widget build(BuildContext context) {
    final values = <({String label, String value, String detail, bool dark})>[
      (
        label: '현재 OVR',
        value: isLoading || ovr == 0 ? '--' : ovr.toStringAsFixed(1),
        detail: '최근 30일 개념 평균',
        dark: true,
      ),
      (
        label: '분석 개념',
        value: isLoading ? '--' : '$solvedConcepts',
        detail: '레이팅 신뢰 구간',
        dark: false,
      ),
      (
        label: '현재 티어',
        value: isLoading ? '--' : tier,
        detail: '다음 티어까지 진행 중',
        dark: false,
      ),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(22 * scale),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD8D8DC)),
          borderRadius: BorderRadius.circular(22 * scale),
        ),
        child: Row(
          children: [
            for (var index = 0; index < values.length; index++)
              Expanded(
                child: Container(
                  constraints: BoxConstraints(minHeight: 104 * scale),
                  padding: EdgeInsets.all(18 * scale),
                  decoration: BoxDecoration(
                    color: values[index].dark
                        ? const Color(0xFF111113)
                        : Colors.white,
                    border: index == 0
                        ? null
                        : const Border(
                            left: BorderSide(color: Color(0xFFD8D8DC)),
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        values[index].label,
                        style: TextStyle(
                          color: values[index].dark
                              ? Colors.white60
                              : const Color(0xFF77777F),
                          fontSize: 10 * scale,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                      Text(
                        values[index].value,
                        style: TextStyle(
                          color: values[index].dark
                              ? Colors.white
                              : const Color(0xFF111113),
                          fontSize: 29 * scale,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                      Text(
                        values[index].detail,
                        style: TextStyle(
                          color: values[index].dark
                              ? Colors.white54
                              : const Color(0xFF77777F),
                          fontSize: 9 * scale,
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

class _OverviewActions extends StatelessWidget {
  const _OverviewActions({
    required this.scale,
    required this.onSearchTap,
    required this.onReportTap,
  });

  final double scale;
  final VoidCallback onSearchTap;
  final VoidCallback onReportTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionButton(scale: scale, label: '세부 해시태그 검색', onTap: onSearchTap),
        SizedBox(height: 12 * scale),
        _ActionButton(scale: scale, label: '보고서 보기', onTap: onReportTap),
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
    required this.onTagTap,
    required this.onTagRemoved,
    required this.onClear,
    required this.quickTags,
  });

  final double scale;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> selectedTags;
  final List<String> suggestions;
  final Map<String, TagRating> tagRatings;
  final bool isLoading;
  final VoidCallback onChanged;
  final ValueChanged<String> onTagTap;
  final ValueChanged<String> onTagRemoved;
  final VoidCallback onClear;
  final List<String> quickTags;

  /// 필요한 변수는 검색 입력·선택 태그·검색 결과·레이팅 데이터다.
  /// 작동 원리: 검색 도구와 결과 영역을 분리하고, 넓은 화면에서는 결과 카드를 2열로 배치해 탐색 밀도를 높인다.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ConceptSearchPanel(
              scale: scale,
              controller: controller,
              focusNode: focusNode,
              selectedTags: selectedTags,
              quickTags: quickTags,
              onChanged: onChanged,
              onTagTap: onTagTap,
              onTagRemoved: onTagRemoved,
              onClear: onClear,
            ),
            SizedBox(height: 14 * scale),
            Row(
              children: [
                Text(
                  controller.text.trim().isEmpty ? '추천 개념' : '검색 결과',
                  style: TextStyle(
                    color: const Color(0xFF111113),
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
                SizedBox(width: 8 * scale),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scale,
                    vertical: 4 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9E9EC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${suggestions.length}개',
                    style: TextStyle(
                      color: const Color(0xFF5F5F66),
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'OVR · 최근 변화 · 풀이 수',
                  style: TextStyle(
                    color: const Color(0xFF85858C),
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 9 * scale),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : suggestions.isEmpty
                  ? _EmptySearchResult(scale: scale)
                  : GridView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: useGrid ? 2 : 1,
                        mainAxisExtent: 108 * scale,
                        crossAxisSpacing: 10 * scale,
                        mainAxisSpacing: 10 * scale,
                      ),
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final tag = suggestions[index];
                        return _ConceptResultCard(
                          scale: scale,
                          tag: tag,
                          rating: tagRatings[_normalize(tag)],
                          isSelected: selectedTags.any(
                            (item) => _normalize(item) == _normalize(tag),
                          ),
                          onTap: () => onTagTap(tag),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ConceptSearchPanel extends StatelessWidget {
  const _ConceptSearchPanel({
    required this.scale,
    required this.controller,
    required this.focusNode,
    required this.selectedTags,
    required this.quickTags,
    required this.onChanged,
    required this.onTagTap,
    required this.onTagRemoved,
    required this.onClear,
  });

  final double scale;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> selectedTags;
  final List<String> quickTags;
  final VoidCallback onChanged;
  final ValueChanged<String> onTagTap;
  final ValueChanged<String> onTagRemoved;
  final VoidCallback onClear;

  /// 필요한 변수는 입력 컨트롤러·빠른 탐색 태그·현재 선택 태그다.
  /// 작동 원리: 한 카드 안에서 검색, 추천 진입, 선택 조건 해제를 연속적으로 처리한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(14 * scale),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18 * scale),
      border: Border.all(color: const Color(0xFFD8D8DC)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 48 * scale,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F6),
            borderRadius: BorderRadius.circular(12 * scale),
            border: Border.all(color: const Color(0xFFE0E0E4)),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 1,
            textInputAction: TextInputAction.search,
            onChanged: (_) => onChanged(),
            style: TextStyle(fontSize: 15 * scale, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: '개념명 검색 · 예: 함수, 도함수, 다항식',
              hintStyle: TextStyle(
                color: const Color(0xFF99999F),
                fontSize: 13 * scale,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 21 * scale,
                color: const Color(0xFF111113),
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '검색 초기화',
                      onPressed: onClear,
                      icon: Icon(Icons.close_rounded, size: 18 * scale),
                    ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14 * scale),
            ),
          ),
        ),
        SizedBox(height: 10 * scale),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 7 * scale,
          runSpacing: 7 * scale,
          children: [
            Text(
              selectedTags.isEmpty ? '빠른 탐색' : '선택한 태그',
              style: TextStyle(
                color: const Color(0xFF77777F),
                fontSize: 10 * scale,
                fontWeight: FontWeight.w800,
              ),
            ),
            for (final tag in selectedTags.isEmpty ? quickTags : selectedTags)
              _SearchTagChip(
                scale: scale,
                label: tag,
                isSelected: selectedTags.isNotEmpty,
                onTap: () =>
                    selectedTags.isEmpty ? onTagTap(tag) : onTagRemoved(tag),
              ),
            if (selectedTags.isNotEmpty)
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF77777F),
                  padding: EdgeInsets.symmetric(horizontal: 5 * scale),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '전체 해제',
                  style: TextStyle(
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _SearchTagChip extends StatelessWidget {
  const _SearchTagChip({
    required this.scale,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final double scale;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// 필요한 변수는 태그명·선택 상태·탭 동작이다.
  /// 작동 원리: 추천 태그는 밝게, 선택 태그는 반전해 검색 조건의 상태를 즉시 구분한다.
  @override
  Widget build(BuildContext context) => Material(
    color: isSelected ? const Color(0xFF111113) : const Color(0xFFF4F4F6),
    borderRadius: BorderRadius.circular(30),
    child: InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 6 * scale,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF333337),
                fontSize: 10 * scale,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 4 * scale),
              Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 12 * scale,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ConceptResultCard extends StatelessWidget {
  const _ConceptResultCard({
    required this.scale,
    required this.tag,
    required this.rating,
    required this.isSelected,
    required this.onTap,
  });

  final double scale;
  final String tag;
  final TagRating? rating;
  final bool isSelected;
  final VoidCallback onTap;

  /// 필요한 변수는 개념 태그·레이팅·선택 상태다.
  /// 작동 원리: 태그명, OVR, 최근 변화, 풀이 수를 한 카드에 정렬하고 카드 전체를 선택 영역으로 사용한다.
  @override
  Widget build(BuildContext context) {
    final value = rating;
    final ovr = value == null ? null : _tagOvrValue(value.rating);
    final delta = value == null
        ? null
        : _visibleDelta(value.rating, value.delta);
    final progress = ovr == null ? 0.0 : (ovr / 25).clamp(0.0, 1.0);
    final deltaText = delta == null
        ? '기록 없음'
        : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}';

    return Material(
      color: isSelected ? const Color(0xFF111113) : Colors.white,
      borderRadius: BorderRadius.circular(16 * scale),
      child: InkWell(
        borderRadius: BorderRadius.circular(16 * scale),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(14 * scale),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16 * scale),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF111113)
                  : const Color(0xFFD8D8DC),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28 * scale,
                    height: 28 * scale,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: .12)
                          : const Color(0xFFF0F0F2),
                      borderRadius: BorderRadius.circular(8 * scale),
                    ),
                    child: Text(
                      '#',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF111113),
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: 9 * scale),
                  Expanded(
                    child: Text(
                      tag.replaceFirst('#', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF111113),
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.2,
                      ),
                    ),
                  ),
                  Text(
                    ovr?.toStringAsFixed(1) ?? '--',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF111113),
                      fontSize: 19 * scale,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 4 * scale),
                  Text(
                    'OVR',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white54
                          : const Color(0xFF85858C),
                      fontSize: 8 * scale,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    deltaText,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white70
                          : const Color(0xFF55555B),
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    ' 최근 변화',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white38
                          : const Color(0xFF929299),
                      fontSize: 9 * scale,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    value == null ? '아직 풀이 기록 없음' : '${value.attempts}회 풀이',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white54
                          : const Color(0xFF77777F),
                      fontSize: 9 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8 * scale),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3 * scale,
                  color: isSelected ? Colors.white : const Color(0xFF111113),
                  backgroundColor: isSelected
                      ? Colors.white.withValues(alpha: .18)
                      : const Color(0xFFE9E9EC),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult({required this.scale});

  final double scale;

  /// 필요한 변수는 화면 배율이다.
  /// 작동 원리: 결과가 없을 때 원인과 다음 입력 행동을 함께 안내해 검색 흐름이 끊기지 않게 한다.
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off_rounded, size: 34 * scale, color: Colors.black26),
        SizedBox(height: 10 * scale),
        Text(
          '일치하는 개념이 없습니다',
          style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 5 * scale),
        Text(
          '# 없이 핵심 단어만 입력해 보세요.',
          style: TextStyle(fontSize: 11 * scale, color: Colors.black45),
        ),
      ],
    ),
  );
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
        : GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.62,
            children: [
              _RatingMetricTile(
                scale: scale,
                label: '상승',
                tag: rising.isEmpty ? '아직 데이터 없음' : rising.first.label,
                value: rising.isEmpty
                    ? '--'
                    : '+${rising.first.delta.toStringAsFixed(1)}',
                progress: rising.isEmpty ? 0 : .82,
              ),
              _RatingMetricTile(
                scale: scale,
                label: '하락',
                tag: falling.isEmpty ? '아직 데이터 없음' : falling.first.label,
                value: falling.isEmpty
                    ? '--'
                    : falling.first.delta.toStringAsFixed(1),
                progress: falling.isEmpty ? 0 : .28,
              ),
              _RatingMetricTile(
                scale: scale,
                label: '강점',
                tag: strong.isEmpty ? '아직 데이터 없음' : strong.first.label,
                value: strong.isEmpty
                    ? '--'
                    : _tagOvrValue(strong.first.score).toStringAsFixed(1),
                progress: strong.isEmpty
                    ? 0
                    : (_tagOvrValue(strong.first.score) / 25).clamp(0, 1),
              ),
              _RatingMetricTile(
                scale: scale,
                label: '보완',
                tag: weak.isEmpty ? '아직 데이터 없음' : weak.first.label,
                value: weak.isEmpty
                    ? '--'
                    : _tagOvrValue(weak.first.score).toStringAsFixed(1),
                progress: weak.isEmpty
                    ? 0
                    : (_tagOvrValue(weak.first.score) / 25).clamp(0, 1),
              ),
            ],
          );

    return _CardShell(scale: scale, title: '개념 변화', child: content);
  }
}

class _RatingMetricTile extends StatelessWidget {
  const _RatingMetricTile({
    required this.scale,
    required this.label,
    required this.tag,
    required this.value,
    required this.progress,
  });

  final double scale;
  final String label;
  final String tag;
  final String value;
  final double progress;

  /// 필요한 변수는 지표 종류·태그·값·상대 진행률이다.
  /// 작동 원리: HTML 태그 2×2 그리드를 얇은 테두리와 하단 진행선으로 재현한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(15 * scale),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFD8D8DC)),
    ),
    child: Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF77777F),
                fontSize: 9 * scale,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 7 * scale),
            Text(
              tag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 15 * scale,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Positioned(
          left: -15 * scale,
          right: -15 * scale,
          bottom: -15 * scale,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3 * scale,
            color: const Color(0xFF111113),
            backgroundColor: Colors.transparent,
          ),
        ),
      ],
    ),
  );
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
              lineColor: const Color(0xFF111113),
              fillColor: const Color(0x24111113),
              labelColor: const Color(0xFF27272A),
              maxValue: 25,
            ),
          ),
        );

        return Container(
          padding: EdgeInsets.all(20 * scale),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24 * scale),
            border: Border.all(color: const Color(0xFFD8D8DC)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 24,
                color: Color(0x10000000),
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SUBJECT BALANCE',
                          style: TextStyle(
                            color: const Color(0xFF77777F),
                            fontSize: 9 * scale,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(height: 6 * scale),
                        Text(
                          '과목별 OVR 레이더 차트',
                          style: TextStyle(
                            fontSize: 18 * scale,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * scale,
                      vertical: 7 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD8D8DC)),
                    ),
                    child: Text(
                      'MAX 25.0',
                      style: TextStyle(
                        color: const Color(0xFF77777F),
                        fontSize: 9 * scale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10 * scale),
              if (canExpand)
                Expanded(
                  child: Center(
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : data.isEmpty
                        ? const Text('아직 분석할 레이팅이 없어요.')
                        : chart,
                  ),
                )
              else
                Center(
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : data.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Text('아직 분석할 레이팅이 없어요.'),
                        )
                      : SizedBox(height: 300 * scale, child: chart),
                ),
            ],
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
  });

  final double scale;
  final String title;
  final Widget child;

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
            style: TextStyle(fontSize: 15 * scale, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 14 * scale),
          child,
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

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.values});
  final String title;
  final List<String> values;

  /// 필요한 변수는 보고서 구역 제목과 태그 값 목록이다.
  /// 작동 원리는 빈 데이터와 실제 레이팅 데이터를 같은 흑백 보고서 카드로 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F7),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        if (values.isEmpty)
          const Text(
            '아직 분석할 기록이 없습니다.',
            style: TextStyle(color: Colors.black45),
          )
        else
          for (final value in values)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(value),
            ),
      ],
    ),
  );
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
    final radius = math.min(size.width, size.height) * 0.31;
    final count = data.length;
    final angleStep = (math.pi * 2) / count;
    final scaleMax = maxValue <= 0 ? 1 : maxValue;

    final gridPaint = Paint()
      ..color = const Color(0x2409090B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = const Color(0x3309090B)
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

      final levelPainter = TextPainter(
        text: TextSpan(
          text: (scaleMax * level / gridCount).toStringAsFixed(1),
          style: const TextStyle(
            color: Color(0xFF9A9AA1),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      levelPainter.paint(
        canvas,
        Offset(center.dx + 5, center.dy - r - levelPainter.height / 2),
      );
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
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, linePaint);

    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + angleStep * i;
      final valueRatio = (data[i].ovr / scaleMax).clamp(0.0, 1.0);
      final r = radius * valueRatio;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      canvas.drawCircle(point, 5, pointPaint);
      canvas.drawCircle(point, 5, pointBorderPaint);
    }

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + angleStep * i;
      final labelOffset = Offset(
        center.dx + (radius + 34) * math.cos(angle),
        center.dy + (radius + 34) * math.sin(angle),
      );
      final textPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${data[i].label}\n',
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: data[i].ovr.toStringAsFixed(1),
              style: const TextStyle(
                color: Color(0xFF77777F),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.fillColor != fillColor;
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
          Positioned(left: -(widget.size), child: bubble),
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
