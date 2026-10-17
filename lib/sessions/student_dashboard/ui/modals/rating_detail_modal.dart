import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s11/shared/data/models/concept_tag.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

const _ink = Color(0xFF09090B),
    _muted = Color(0xFF71717A),
    _surface = Color(0xFFFDFDFE),
    _line = Color(0xFFD8D8DC);

/// 기존 서명을 유지하고 HTML과 같은 독립페이지를 연다. 서버에 쓰지 않는다.
Future<T?> showRatingDetailModal<T>({
  required BuildContext context,
  Map<String, TagRating>? initialRatings,
}) => Navigator.of(context).push<T>(
  MaterialPageRoute<T>(
    settings: const RouteSettings(name: '/rating-detail'),
    builder: (_) => RatingDetailPage(initialRatings: initialRatings),
  ),
);

/// 직접 생성 호출자의 호환 위젯. mobileSheet는 과거 인자이며 독립페이지를 표시한다.
class RatingDetailModal extends StatelessWidget {
  const RatingDetailModal({
    super.key,
    this.initialRatings,
    this.mobileSheet = false,
  });
  final Map<String, TagRating>? initialRatings;
  final bool mobileSheet;
  @override
  Widget build(BuildContext context) =>
      RatingDetailPage(initialRatings: initialRatings);
}

/// 실제 학습 데이터를 읽고 숫자 OVR 대신 레벨리티 상태를 보여주는 목적지.
class RatingDetailPage extends StatefulWidget {
  const RatingDetailPage({super.key, this.initialRatings});
  final Map<String, TagRating>? initialRatings;
  @override
  State<RatingDetailPage> createState() => _RatingDetailPageState();
}

class _RatingDetailPageState extends State<RatingDetailPage> {
  UserRating? _rating;
  List<_Area> _areas = const [];
  bool _loading = true, _tagsLoading = true;
  String? _error, _tagError;
  final _focus = List.generate(4, (_) => FocusNode());
  @override
  void initState() {
    super.initState();
    _loadUser();
    final initial = widget.initialRatings;
    if (initial == null) {
      _loadTags();
    } else {
      _areas = _areasFrom(initial.values);
      _tagsLoading = false;
    }
  }

  @override
  void dispose() {
    for (final node in _focus) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rating = await ApiClient.instance.fetchUserRating();
      if (!mounted) return;
      setState(() {
        _rating = rating;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '학습지표를 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }

  Future<void> _loadTags() async {
    setState(() {
      _tagsLoading = true;
      _tagError = null;
    });
    try {
      final tags = await ApiClient.instance.fetchTagRatings();
      if (!mounted) return;
      setState(() {
        _areas = _areasFrom(tags);
        _tagsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tagError = '태그 레이팅을 불러오지 못했습니다.';
        _tagsLoading = false;
      });
    }
  }

  /// 시트 닫기/Escape 이후 호출 버튼의 키보드 포커스를 복구한다.
  void _open(int index) {
    const scenes = ['tags', 'attendance', 'recent', 'method'];
    const titles = ['태그별 레이팅', '학습 성실도', '최근 반영', 'OVR 기준'];
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .48),
      builder: (dialogContext) => _RatingSheet(
        scene: scenes[index],
        title: titles[index],
        content: index == 0
            ? _Tags(
                areas: _areas,
                loading: _tagsLoading,
                error: _tagError,
                onRetry: () async {
                  Navigator.of(dialogContext).pop();
                  await _loadTags();
                  if (mounted) _open(index);
                },
              )
            : index == 3
            ? const _Method()
            : _Status(
                message: index == 1
                    ? '최근 30일 활동점수 데이터가 제공되지 않습니다.'
                    : '레이팅 변경 시각과 반영 내역 데이터가 제공되지 않습니다.',
              ),
      ),
    ).whenComplete(() {
      if (mounted) _focus[index].requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    return StudentHtmlShell(
      key: const ValueKey('rating-detail-page'),
      title: '레벨리티',
      railWidth: 76,
      mobileBackButton: true,
      onMenu: () {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
      child: ColoredBox(
        color: _surface,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: mobile
                    ? double.infinity
                    : math.min(760, MediaQuery.sizeOf(context).width - 112),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  0,
                  mobile ? 0 : 22,
                  0,
                  mobile ? 28 : 48,
                ),
                child: Column(
                  children: [
                    _Hero(
                      rating: _rating,
                      areas: _areas,
                      mobile: mobile,
                      loading: _loading,
                      error: _error,
                      onRetry: _loadUser,
                    ),
                    ...List.generate(4, (index) {
                      const titles = [
                        '부족·강점 클러스터',
                        '학습 성실도',
                        '최근 반영',
                        '레벨리티 기준',
                      ];
                      final subtitles = [
                        '${_areas.length}개 학습 클러스터의 최근 동향',
                        '최근 30일 활동점수 보기',
                        '풀이 결과가 반영된 기록',
                        '유지율·배정률 기준 확인',
                      ];
                      const scenes = ['tags', 'attendance', 'recent', 'method'];
                      return Container(
                        key: ValueKey('rating-action-${scenes[index]}'),
                        decoration: BoxDecoration(
                          border: index == 3
                              ? null
                              : const Border(
                                  bottom: BorderSide(color: Color(0x1A09090B)),
                                ),
                        ),
                        child: TextButton(
                          focusNode: _focus[index],
                          onPressed: () => _open(index),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.standard,
                            foregroundColor: _ink,
                            minimumSize: Size.fromHeight(
                              (mobile ? 74.0 : 78.0) - (index == 3 ? 0 : 1),
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: const RoundedRectangleBorder(),
                            padding: EdgeInsets.symmetric(
                              horizontal: mobile ? 18 : 34,
                              vertical: 14,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      titles[index],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      subtitles[index],
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                            ],
                          ),
                        ),
                      );
                    }),
                    _LevelityBands(levelity: _rating?.levelity, mobile: mobile),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
                      child: Text(
                        'OVR 숫자는 내부 계산에만 사용합니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.rating,
    required this.areas,
    required this.mobile,
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  final UserRating? rating;
  final List<_Area> areas;
  final bool mobile, loading;
  final String? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final strongest = areas.isEmpty
        ? null
        : areas.reduce((a, b) => a.attempts >= b.attempts ? a : b);
    final trend = rating == null ? '기록 없음' : _trendLabel(rating!.ovrDelta);
    final levelity = rating?.levelity;
    final percentile = levelity?.percentile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          key: const ValueKey('rating-portal-heading'),
          padding: mobile
              ? const EdgeInsets.fromLTRB(18, 24, 18, 18)
              : const EdgeInsets.fromLTRB(34, 28, 34, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: mobile ? 24 : 28,
                child: const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text(
                    '01',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              SizedBox(width: mobile ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '나의 레벨리티',
                      style: TextStyle(
                        fontSize: mobile ? 25 : 28,
                        fontWeight: FontWeight.w700,
                        height: mobile ? 36 / 25 : 40 / 28,
                        letterSpacing: (mobile ? 25 : 28) * -.05,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      '현재 학습 구간과 최근 동향',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (error != null)
          _Status(message: error!, onRetry: onRetry)
        else
          Padding(
            key: const ValueKey('rating-portal-core'),
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? 18 : 34,
              vertical: mobile ? 22 : 24,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trendWidth = mobile
                    ? 110.0
                    : math.max(180, (constraints.maxWidth - 28) * .82 / 1.82);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 7),
                          Text(
                            levelity?.tier ??
                                (levelity == null
                                    ? '정보 대기'
                                    : levelity.available
                                    ? '배정 전'
                                    : '확인 필요'),
                            key: const ValueKey('rating-levelity'),
                            style: TextStyle(
                              fontSize: mobile
                                  ? (levelity?.tier == null ? 22 : 30)
                                  : (levelity?.tier == null ? 30 : 44),
                              height: .78,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loading
                                ? '학습 기록 확인 중'
                                : levelity == null
                                ? '개인 급간 정보가 아직 제공되지 않습니다'
                                : levelity.available == false
                                ? '급간 집계를 불러오지 못했습니다'
                                : percentile == null
                                ? '풀이 기록을 쌓으면 등급이 배정됩니다'
                                : '전체 상위 ${(100 - percentile).round()}% · 다음 급간 ${levelity.progress?.toStringAsFixed(0) ?? '최고'}%',
                            style: TextStyle(
                              color: _muted,
                              fontSize: mobile ? 8 : 10,
                              fontWeight: FontWeight.w800,
                              height: mobile ? 11 / 8 : 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: mobile ? 18 : 28),
                    SizedBox(
                      width: trendWidth.toDouble(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  '최근 동향',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                loading ? '…' : trend,
                                style: TextStyle(
                                  fontSize: mobile ? 14 : 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: mobile ? 42 : 56,
                            child: _AccuracySignal(
                              rating: rating,
                              loading: loading,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        Container(
          key: const ValueKey('rating-portal-meta'),
          constraints: BoxConstraints(minHeight: mobile ? 40 : 43),
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 18 : 34,
            vertical: mobile ? 12 : 13,
          ),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x1A09090B))),
          ),
          child: Wrap(
            spacing: mobile ? 12 : 18,
            runSpacing: 6,
            children: [
              Text(
                '레벨리티 급간  ${levelity?.tier ?? '미배정'}',
                style: TextStyle(color: _muted, fontSize: mobile ? 9 : 10),
              ),
              Text(
                '학습 클러스터  ${strongest == null ? '기록 없음' : strongest.name}',
                style: TextStyle(fontSize: mobile ? 9 : 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _levelityPolicyFallback = <LevelityBand>[
  LevelityBand(
    tier: 'Prime+',
    allocation: 3.97,
    retention: 97.5,
    up: 0,
    down: 2.5,
  ),
  LevelityBand(
    tier: 'Prime 0',
    allocation: 8.85,
    retention: 67,
    up: 23.5,
    down: 9.4,
  ),
  LevelityBand(
    tier: 'Powerful+',
    allocation: 12.85,
    retention: 66.9,
    up: 21,
    down: 12.1,
  ),
  LevelityBand(
    tier: 'Powerful 0',
    allocation: 15.92,
    retention: 69.7,
    up: 18.1,
    down: 12.1,
  ),
  LevelityBand(
    tier: 'Insane+',
    allocation: 17.25,
    retention: 70,
    up: 16.1,
    down: 13.9,
  ),
  LevelityBand(
    tier: 'Insane 0',
    allocation: 14.82,
    retention: 66.9,
    up: 15.4,
    down: 17.7,
  ),
  LevelityBand(
    tier: 'Plain+',
    allocation: 13.15,
    retention: 70.8,
    up: 10.1,
    down: 19,
  ),
  LevelityBand(
    tier: 'Plain 0',
    allocation: 9.93,
    retention: 74.2,
    up: 4.7,
    down: 21.1,
  ),
  LevelityBand(
    tier: 'Cheer Up',
    allocation: 3.27,
    retention: 100,
    up: 0,
    down: 0,
  ),
];

class _LevelityBands extends StatelessWidget {
  const _LevelityBands({required this.levelity, required this.mobile});

  final UserLevelity? levelity;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final bands = levelity?.bands.isNotEmpty == true
        ? levelity!.bands
        : _levelityPolicyFallback;
    final status = levelity == null
        ? '개인 급간 정보가 아직 제공되지 않습니다.'
        : !levelity!.available
        ? '개인 급간을 불러오지 못했습니다. 정책표만 표시합니다.'
        : levelity!.tier == null
        ? '아직 활동 기록이 없어 개인 급간이 배정되지 않았습니다.'
        : '';

    return Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 18 : 34, 0, mobile ? 18 : 34, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '급간 배정 · 30문항 전이 경향',
            style: TextStyle(
              fontSize: mobile ? 14 : 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          if (status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                status,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ),
          if ((levelity?.cohortSize ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '활동 기록 ${levelity!.cohortSize}명 기준 · OVR 숫자는 표시하지 않음',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ),
          for (var index = 0; index < bands.length; index++)
            _LevelityBandCard(
              band: bands[index],
              index: index,
              selected: levelity?.tier == bands[index].tier,
              mobile: mobile,
            ),
        ],
      ),
    );
  }
}

class _LevelityBandCard extends StatelessWidget {
  const _LevelityBandCard({
    required this.band,
    required this.index,
    required this.selected,
    required this.mobile,
  });

  final LevelityBand band;
  final int index;
  final bool selected;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final color = _levelityBandColor(index);
    return Container(
      key: ValueKey('levelity-band-${band.tier}'),
      margin: const EdgeInsets.only(bottom: 7),
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 11 : 14,
        vertical: mobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        border: Border(
          left: BorderSide(color: color, width: selected ? 5 : 3),
          top: BorderSide(color: color.withValues(alpha: .32)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  band.tier,
                  style: TextStyle(
                    color: color,
                    fontSize: mobile ? 14 : 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '배정 ${band.allocation.toStringAsFixed(2)}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '유지 ${band.retention.toStringAsFixed(1)}%  ·  상승 ${band.up.toStringAsFixed(1)}%  ·  하락 ${band.down.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: mobile ? 10 : 12,
              color: _muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _levelityBandColor(int index) => const [
  Color(0xFF141414),
  Color(0xFF7D3357),
  Color(0xFF173D85),
  Color(0xFF00675D),
  Color(0xFF4F5C18),
  Color(0xFF986315),
  Color(0xFF96512A),
  Color(0xFF59616B),
  Color(0xFF355E47),
][index.clamp(0, 8)];

class _AccuracySignal extends StatelessWidget {
  const _AccuracySignal({required this.rating, required this.loading});

  final UserRating? rating;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final value = rating?.recentAccuracy ?? 0;
    final normalized = (value <= 1 ? value : value / 100).clamp(0.0, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loading
              ? '최근 정답률 불러오는 중'
              : rating == null
              ? '최근 정답률 기록 없음'
              : '최근 정답률 ${(normalized * 100).round()}%',
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: loading
              ? null
              : rating == null
              ? 0
              : normalized,
          minHeight: 5,
          backgroundColor: _line,
          valueColor: const AlwaysStoppedAnimation(_ink),
        ),
      ],
    );
  }
}

class _RatingSheet extends StatelessWidget {
  const _RatingSheet({
    required this.scene,
    required this.title,
    required this.content,
  });
  final String scene, title;
  final Widget content;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context), mobile = size.width <= 720;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop();
              return null;
            },
          ),
        },
        child: Dialog(
          alignment: Alignment.bottomCenter,
          insetPadding: mobile ? EdgeInsets.zero : const EdgeInsets.all(18),
          backgroundColor: _surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: const RoundedRectangleBorder(),
          child: Container(
            key: ValueKey('rating-sheet-$scene'),
            width: mobile
                ? size.width
                : (scene == 'attendance' || scene == 'recent' ? 620 : 520),
            constraints: BoxConstraints(
              maxHeight: mobile
                  ? size.height * .86
                  : math.min(720, (size.height - 36) * .92),
            ),
            decoration: BoxDecoration(
              border: mobile
                  ? const Border(top: BorderSide(color: _ink))
                  : Border.all(color: _ink),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (scene != 'method')
                                const Text(
                                  'LEARNING INDEX',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.12,
                                  ),
                                ),
                              if (scene != 'method') const SizedBox(height: 4),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.of(context).pop(),
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          icon: const Text('×', style: TextStyle(fontSize: 24)),
                        ),
                      ],
                    ),
                  ),
                  content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tags extends StatelessWidget {
  const _Tags({
    required this.areas,
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  final List<_Area> areas;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) return _Status(message: error!, onRetry: onRetry);
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    return Padding(
      padding: mobile
          ? const EdgeInsets.fromLTRB(14, 12, 14, 18)
          : const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Semantics(
              label: areas.isEmpty
                  ? '태그별 풀이 기록이 없습니다.'
                  : '학습 클러스터 ${areas.map((a) => a.name).join(', ')}',
              image: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  areas.isEmpty
                      ? '아직 풀이 기록이 없습니다.'
                      : '숫자 레이팅은 공개하지 않습니다. 아래 클러스터를 선택해 세부 태그를 확인하세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: mobile ? 12 : 13),
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x1A09090B))),
            ),
            child: Column(
              children: areas
                  .map((area) => _TagClusterTile(area: area))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Method extends StatelessWidget {
  const _Method();
  @override
  Widget build(BuildContext context) {
    const items = [
      ('개념별 풀이 결과', '정답 여부와 풀이 단계를 함께 분석합니다.'),
      ('유지와 변화', '최근 유지율·배정률을 검증해 등급을 산정합니다.'),
      ('수치 비공개', '내부 계산값 대신 등급과 다음 구간 진행률을 공개합니다.'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          items.length,
          (i) => Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E2E4))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].$1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        items[i].$2,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.5,
                          color: _muted,
                        ),
                      ),
                    ],
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

class _Status extends StatelessWidget {
  const _Status({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: const TextStyle(fontSize: 12, color: _muted)),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ),
  );
}

class _Area {
  const _Area(this.name, this.delta, this.attempts, this.tags);
  final String name;
  final double delta;
  final int attempts;
  final List<String> tags;
}

class _TagClusterTile extends StatelessWidget {
  const _TagClusterTile({required this.area});
  final _Area area;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: ValueKey('rating-area-${area.name}'),
    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    title: Text(area.name, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(
      '${area.attempts}회 풀이 · ${_trendLabel(area.delta)}',
      style: const TextStyle(color: _muted, fontSize: 12),
    ),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: area.tags.map((tag) => Chip(label: Text(tag))).toList(),
        ),
      ),
    ],
  );
}

String _normalize(String value) =>
    value.replaceAll('#', '').toLowerCase().trim();

String _trendLabel(double value) => value > 0
    ? '상승'
    : value < 0
    ? '하락'
    : '유지';

/// 점수값은 노출하지 않고 학습 동향과 표본 수만 클러스터 단위로 묶는다.
List<_Area> _areasFrom(Iterable<TagRating> tags) {
  final ratings = {
    for (final rating in tags.where((rating) => rating.attempts > 0))
      _normalize(rating.tag): rating,
  };
  final result = <_Area>[];
  for (final root in conceptTagData.take(4)) {
    final keys = <String>{};
    void visit(ConceptTag tag) {
      keys
        ..add(_normalize(tag.name))
        ..add(_normalize(tag.displayName));
      for (final child in tag.children) {
        visit(child);
      }
    }

    visit(root);
    final values = keys
        .map((key) => ratings[key])
        .whereType<TagRating>()
        .toList();
    if (values.isEmpty) continue;
    final attempts = values.fold<int>(0, (sum, value) => sum + value.attempts);
    final delta =
        values.fold<double>(
          0,
          (sum, value) => sum + value.delta * value.attempts,
        ) /
        attempts;
    final details = values.map((value) => value.tag).toSet().toList()..sort();
    result.add(
      _Area(root.displayName.replaceAll('#', ''), delta, attempts, details),
    );
  }
  return result;
}
