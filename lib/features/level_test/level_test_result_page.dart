import 'package:flutter/material.dart';
import 'package:s11/shared/services/api/api_client.dart';

/// 레벨 테스트의 일반 결과와 배치 결과를 같은 학생용 리포트 표면으로 표시한다.
/// 필요한 값은 채점 수치 또는 배치 API 결과이며, 홈 이동은 기존 Navigator 흐름을 그대로 사용한다.
class LevelTestResultPage extends StatelessWidget {
  const LevelTestResultPage({
    super.key,
    this.correctCount = 0,
    this.totalCount = 0,
    this.passed = false,
    this.placementResult,
  });

  final int correctCount;
  final int totalCount;
  final bool passed;
  final LevelTestPlacementResult? placementResult;

  /// 필요한 값은 정답 수와 전체 문항 수다.
  /// 0문항 응답에서도 0으로 안전하게 표시해 결과 화면 렌더링을 보장한다.
  double get _percentage {
    if (totalCount == 0) return 0;
    return (correctCount / totalCount) * 100;
  }

  /// 배치 결과 유무에 따라 기존 두 결과 계약을 하나의 시안형 화면으로 분기한다.
  @override
  Widget build(BuildContext context) {
    final placement = placementResult;
    final report = placement == null
        ? _LevelResultReport.standard(
            correctCount: correctCount,
            totalCount: totalCount,
            passed: passed,
            percentage: _percentage,
          )
        : _LevelResultReport.placement(placement);

    return _LevelResultScaffold(report: report);
  }
}

/// HTML 시안의 결과 리포트 구조를 PC의 2열, 모바일의 단일 열로 전환한다.
/// 결과 데이터는 [_LevelResultReport]로 정규화하여 API·일반 시험 흐름이 같은 위젯을 재사용한다.
class _LevelResultScaffold extends StatelessWidget {
  const _LevelResultScaffold({required this.report});

  final _LevelResultReport report;

  /// 필요한 값은 화면 폭과 결과 요약이다.
  /// 760px 미만에서는 읽기 순서를 유지한 단일 열, 이상에서는 요약과 분석을 분리한 2열로 배치한다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LevelResultTokens.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final horizontal = compact ? 18.0 : 42.0;
            final content = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  compact ? 16 : 28,
                  horizontal,
                  36,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ResultTopBar(compact: compact),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(top: compact ? 22 : 34),
                        child: _ResultBody(report: report, compact: compact),
                      ),
                    ),
                  ],
                ),
              ),
            );
            return Align(alignment: Alignment.topCenter, child: content);
          },
        ),
      ),
    );
  }
}

/// 결과 상단의 제품명과 홈 복귀 동작을 제공한다.
/// 뒤로 가기 대신 기존 결과 흐름과 동일하게 첫 라우트까지 정리해 학습 진입점을 명확히 한다.
class _ResultTopBar extends StatelessWidget {
  const _ResultTopBar({required this.compact});

  final bool compact;

  /// 필요한 값은 현재 Navigator다.
  /// 모든 시험 결과 진입 경로에서 동일한 홈 복귀 계약을 유지한다.
  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'AIFLOW',
          style: TextStyle(
            fontSize: 15,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w900,
            color: _LevelResultTokens.ink,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'LEVEL REPORT',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: _LevelResultTokens.muted,
          ),
        ),
        const Spacer(),
        OutlinedButton.icon(
          key: const ValueKey('level-result-home-button'),
          onPressed: () => _goHome(context),
          icon: const Icon(Icons.home_outlined, size: 18),
          label: Text(compact ? '홈' : '학습 홈으로'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _LevelResultTokens.ink,
            minimumSize: Size(0, compact ? 42 : 46),
            side: const BorderSide(color: _LevelResultTokens.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

/// 결과 카드·태그 분석·다음 행동을 시안의 읽기 순서로 조합한다.
/// PC와 모바일 모두 같은 데이터이지만 폭에 따라 레이아웃만 달라져 분석 정보가 누락되지 않는다.
class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.report, required this.compact});

  final _LevelResultReport report;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final overview = _ResultOverview(report: report, compact: compact);
    final analysis = _ResultAnalysis(report: report, compact: compact);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          report.isPlacement ? 'PLACEMENT COMPLETE' : 'TEST COMPLETE',
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w900,
            color: _LevelResultTokens.muted,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          report.isPlacement ? '나의 학습 기준점이\n완성됐어요.' : '이번 테스트를\n완료했어요.',
          style: TextStyle(
            fontSize: compact ? 36 : 54,
            height: .98,
            letterSpacing: -2.2,
            fontWeight: FontWeight.w900,
            color: _LevelResultTokens.ink,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          report.description,
          style: TextStyle(
            fontSize: compact ? 14 : 16,
            height: 1.55,
            color: _LevelResultTokens.muted,
          ),
        ),
        SizedBox(height: compact ? 24 : 34),
        if (compact) ...[
          overview,
          const SizedBox(height: 14),
          analysis,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: overview),
              const SizedBox(width: 18),
              Expanded(flex: 5, child: analysis),
            ],
          ),
        SizedBox(height: compact ? 18 : 24),
        _NextStepCard(report: report, compact: compact),
      ],
    );
  }
}

/// OVR 또는 정답률을 가장 큰 숫자로 표시하고 시험 계약의 부가 수치를 같은 카드에 묶는다.
/// 텍스트 크기는 좁은 화면에서만 줄여 390px에서도 줄바꿈이나 오버플로를 막는다.
class _ResultOverview extends StatelessWidget {
  const _ResultOverview({required this.report, required this.compact});

  final _LevelResultReport report;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('level-result-overview'),
      padding: EdgeInsets.all(compact ? 22 : 30),
      decoration: _LevelResultTokens.cardDecoration(dark: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'MY OVR',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.7,
                ),
              ),
              const Spacer(),
              _StatusPill(label: report.statusLabel),
            ],
          ),
          SizedBox(height: compact ? 28 : 38),
          Text(
            report.primaryValue,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 68 : 96,
              height: .8,
              letterSpacing: -5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            report.primaryCaption,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 26),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                label: report.firstMetricLabel,
                value: report.firstMetricValue,
              ),
              _Metric(
                label: report.secondMetricLabel,
                value: report.secondMetricValue,
              ),
              _Metric(label: '분석 상태', value: report.analysisState),
            ],
          ),
        ],
      ),
    );
  }
}

/// 강점·보완 태그와 신뢰도를 가벼운 흑백 카드로 표시한다.
/// API가 빈 목록을 내려도 안내 문구를 보이게 해 결과 화면의 정보 밀도를 안정적으로 유지한다.
class _ResultAnalysis extends StatelessWidget {
  const _ResultAnalysis({required this.report, required this.compact});

  final _LevelResultReport report;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('level-result-analysis'),
      padding: EdgeInsets.all(compact ? 20 : 26),
      decoration: _LevelResultTokens.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESULT SUMMARY',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w900,
              color: _LevelResultTokens.muted,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            report.isPlacement ? 'OVR 배정 결과' : '다음 학습을 위한 분석',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 22),
          if (report.isPlacement) ...[
            _ResultFact(
              label: report.firstMetricLabel,
              value: report.firstMetricValue,
            ),
            const SizedBox(height: 14),
            _ResultFact(
              label: report.secondMetricLabel,
              value: report.secondMetricValue,
            ),
          ] else ...[
            _TagGroup(title: '강점 태그', tags: report.strongTags, positive: true),
            const SizedBox(height: 18),
            _TagGroup(title: '보완 태그', tags: report.weakTags),
          ],
          const SizedBox(height: 22),
          const Divider(height: 1, color: _LevelResultTokens.line),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  report.confidenceCopy,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: _LevelResultTokens.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultFact extends StatelessWidget {
  const _ResultFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F3F1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: _LevelResultTokens.muted)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

/// 결과 뒤의 다음 학습 행동을 기존 홈 라우팅으로 연결한다.
/// 라우트 계약을 새로 만들지 않고 첫 라우트 복귀로 기존 대시보드 진입점을 보존한다.
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.report, required this.compact});

  final _LevelResultReport report;
  final bool compact;

  /// 필요한 값은 현재 Navigator다.
  /// 기존 결과 화면의 홈 버튼과 같은 popUntil 동작으로 라우팅 회귀를 막는다.
  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 20 : 26),
      decoration: _LevelResultTokens.cardDecoration(),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _content(context, stacked: true),
            )
          : Row(children: _content(context, stacked: false)),
    );
  }

  /// 필요한 값은 화면 폭과 홈 이동 콜백이다.
  /// 모바일에서는 설명과 버튼을 세로로, PC에서는 같은 행의 명확한 CTA로 구성한다.
  List<Widget> _content(BuildContext context, {required bool stacked}) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEXT STEP',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w900,
            color: _LevelResultTokens.muted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          report.nextTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          report.nextDescription,
          style: const TextStyle(fontSize: 13, color: _LevelResultTokens.muted),
        ),
      ],
    );
    final button = FilledButton.icon(
      key: const ValueKey('level-result-next-button'),
      onPressed: () => _goHome(context),
      icon: const Icon(Icons.arrow_forward_rounded),
      label: const Text('학습 홈에서 이어가기'),
      style: FilledButton.styleFrom(
        backgroundColor: _LevelResultTokens.ink,
        foregroundColor: Colors.white,
        minimumSize: Size(0, compact ? 50 : 52),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    if (stacked) return [copy, const SizedBox(height: 18), button];
    return [Expanded(child: copy), const SizedBox(width: 20), button];
  }
}

/// 흑백 결과 화면에 필요한 상태·태그·보조 문구를 두 API 계약에서 계산한다.
/// 서버 값은 그대로 보존하고 표현만 이 모델에서 통일해 UI 분기를 간결하게 유지한다.
class _LevelResultReport {
  const _LevelResultReport._({
    required this.isPlacement,
    required this.primaryValue,
    required this.primaryCaption,
    required this.statusLabel,
    required this.firstMetricLabel,
    required this.firstMetricValue,
    required this.secondMetricLabel,
    required this.secondMetricValue,
    required this.analysisState,
    required this.description,
    required this.confidenceCopy,
    required this.strongTags,
    required this.weakTags,
    required this.nextTitle,
    required this.nextDescription,
  });

  factory _LevelResultReport.standard({
    required int correctCount,
    required int totalCount,
    required bool passed,
    required double percentage,
  }) {
    return _LevelResultReport._(
      isPlacement: false,
      primaryValue: '${percentage.toStringAsFixed(0)}%',
      primaryCaption: '$correctCount / $totalCount 문항 정답',
      statusLabel: passed ? 'PASS' : 'REVIEW',
      firstMetricLabel: '정답률',
      firstMetricValue: '${percentage.toStringAsFixed(1)}%',
      secondMetricLabel: '결과',
      secondMetricValue: passed ? '통과' : '복습 추천',
      analysisState: '완료',
      description: passed
          ? '현재 단원의 핵심 개념을 안정적으로 이해하고 있어요.'
          : '틀린 문항을 복습하면 다음 학습을 더 단단하게 시작할 수 있어요.',
      confidenceCopy: '시험 결과가 저장되었습니다. 다음 학습에서 부족한 개념을 다시 확인할 수 있어요.',
      strongTags: const [],
      weakTags: const [],
      nextTitle: passed ? '다음 학습으로 넘어갈 준비가 됐어요.' : '복습부터 차근차근 이어가 볼까요?',
      nextDescription: '학습 홈에서 코스와 복습 과제를 확인하세요.',
    );
  }

  factory _LevelResultReport.placement(LevelTestPlacementResult result) {
    final confidence = (result.confidence * 100).round();
    final correctCount = (result.recentAccuracy * 25).round();
    return _LevelResultReport._(
      isPlacement: true,
      primaryValue: result.ovr > 0 ? result.ovr.toStringAsFixed(1) : '--',
      primaryCaption: '레벨 테스트로 배정된 첫 OVR',
      statusLabel: 'MEASURED',
      firstMetricLabel: '정답 수',
      firstMetricValue: '$correctCount / 25',
      secondMetricLabel: '제한 시간',
      secondMetricValue: '30분',
      analysisState: 'OVR 배정',
      description: '25문항의 전체 답안을 한 번에 채점해 첫 OVR을 배정했습니다.',
      confidenceCopy: '측정 신뢰도 $confidence% · 이 시험 결과는 첫 OVR 배정에 사용됩니다.',
      strongTags: const [],
      weakTags: const [],
      nextTitle: '첫 OVR 배정이 완료됐어요.',
      nextDescription: '학습 홈으로 돌아가 원하는 학습을 시작하세요.',
    );
  }

  final bool isPlacement;
  final String primaryValue;
  final String primaryCaption;
  final String statusLabel;
  final String firstMetricLabel;
  final String firstMetricValue;
  final String secondMetricLabel;
  final String secondMetricValue;
  final String analysisState;
  final String description;
  final String confidenceCopy;
  final List<Map<String, dynamic>> strongTags;
  final List<Map<String, dynamic>> weakTags;
  final String nextTitle;
  final String nextDescription;
}

/// 태그 평점 목록을 간결한 흑백 배지로 표현한다.
/// 태그 값이 없거나 형식이 달라도 안전한 텍스트로 변환해 서버 응답 오류가 화면을 막지 않게 한다.
class _TagGroup extends StatelessWidget {
  const _TagGroup({
    required this.title,
    required this.tags,
    this.positive = false,
  });

  final String title;
  final List<Map<String, dynamic>> tags;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 9),
        if (tags.isEmpty)
          const Text(
            '아직 충분한 분석 태그가 없습니다.',
            style: TextStyle(fontSize: 13, color: _LevelResultTokens.muted),
          )
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: tags
                .take(5)
                .map((tag) {
                  final label = (tag['tag'] ?? '학습 태그').toString();
                  final rating = (tag['rating'] as num?)?.toDouble();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: positive
                          ? _LevelResultTokens.ink
                          : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      rating == null
                          ? '#$label'
                          : '#$label ${rating.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: positive ? Colors.white : _LevelResultTokens.ink,
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
      ],
    );
  }
}

/// 요약 카드의 보조 지표를 일정한 최소 폭으로 표시한다.
/// Wrap을 사용해 390px에서도 지표가 잘리지 않고 다음 줄로 자연스럽게 이동한다.
class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 결과 상태를 대비 높은 작은 배지로 제공한다.
/// PASS·REVIEW·MEASURED 값을 고정 폭 없이 보여줘 상태 문자열 변경에도 대응한다.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: _LevelResultTokens.ink,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    );
  }
}

/// 시안의 흑백 표면·여백을 한 곳에서 관리한다.
/// 결과 전용 토큰만 두어 기존 전역 테마나 다른 학생 화면에 영향을 주지 않는다.
abstract final class _LevelResultTokens {
  static const canvas = Color(0xFFF5F5F3);
  static const ink = Color(0xFF171717);
  static const muted = Color(0xFF6C6C6C);
  static const line = Color(0xFFD9D9D5);

  /// 필요한 값은 어두운 요약 여부다.
  /// 밝고 어두운 카드 모두 같은 모서리와 테두리 규칙을 사용해 HTML 시안의 표면 밀도를 맞춘다.
  static BoxDecoration cardDecoration({bool dark = false}) {
    return BoxDecoration(
      color: dark ? ink : Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: dark ? ink : line),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? .08 : .035),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
