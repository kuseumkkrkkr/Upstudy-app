import 'dart:async';

import 'package:flutter/material.dart';
import 'package:s11/features/level_test/level_test_result_page.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'package:s11/shared/business/repositories/rating_store.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

class LevelTestHomePage extends StatefulWidget {
  const LevelTestHomePage({super.key, this.initialStats});

  final LevelTestPlacementStats? initialStats;

  static const routeName = '/level_test';

  @override
  State<LevelTestHomePage> createState() => _LevelTestHomePageState();
}

class _LevelTestHomePageState extends State<LevelTestHomePage> {
  bool _loading = false;
  String? _error;
  LevelTestPlacementStats? _stats;

  @override
  void initState() {
    super.initState();
    _stats = widget.initialStats;
    if (_stats == null) unawaited(_loadStats());
  }

  Future<void> _loadStats() async {
    try {
      final stats = await ApiClient.instance.fetchLevelTestPlacementStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // 통계 조회 실패가 시험 시작을 막지는 않는다.
    }
  }

  Future<void> _startPlacement() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await ApiClient.instance.startLevelTestPlacement();
      if (!mounted) return;
      final questions = session.questions;
      if (questions.isEmpty) {
        throw Exception('레벨테스트 문제를 불러오지 못했어요');
      }
      final config = ProblemSolveConfig(
        questionCount: questions.length,
        timeLimitSeconds: session.timeLimitSeconds,
        hashTags: questions.expand((q) => q.hashTags).toSet().toList(),
        gradeImmediately: false,
        minDifficultyTier: 2,
        maxDifficultyTier: 5,
        passRate: 0,
        ratingEnabled: false,
        placementExam: true,
        quests: questions.map((q) => q.quest).toList(),
        onPlacementSubmit:
            ({
              required List<PlacementExamAnswer> answers,
              required int elapsedSeconds,
            }) => _finishPlacement(
              session.sessionId,
              answers: answers,
              elapsedSeconds: elapsedSeconds,
            ),
      );
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BuildpageWidget(config: config)),
      );
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = studentFacingApiError(
          error,
          fallback: '레벨 테스트를 시작하지 못했어요.',
          notFound: '레벨 테스트를 준비 중이에요. 잠시 후 다시 시도해 주세요.',
          unavailable: '레벨 테스트 연결이 잠시 불안정해요. 잠시 후 다시 시도해 주세요.',
        );
      });
    }
  }

  Future<void> _finishPlacement(
    String sessionId, {
    required List<PlacementExamAnswer> answers,
    required int elapsedSeconds,
  }) async {
    final result = await ApiClient.instance.submitLevelTestPlacement(
      sessionId,
      answers: answers
          .map(
            (answer) => <String, dynamic>{
              'item_index': answer.itemIndex,
              'quest_id': answer.questId,
              'user_answer': answer.userAnswer,
              'selected_index': answer.selectedIndex,
            },
          )
          .toList(growable: false),
      elapsedSeconds: elapsedSeconds,
    );
    RatingStore.updateFromRating(result.toUserRating());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LevelTestResultPage(placementResult: result),
      ),
    );
  }

  /// 필요한 변수는 배치 테스트 로딩·오류 상태와 화면 폭이다.
  /// 실제 제출 로직 위에 HTML의 OVR 히어로, 측정 과정, 시작 전 확인 영역을 순서대로 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Scaffold(
      key: const ValueKey('level-test-screen'),
      backgroundColor: StudentDensityTokens.background,
      drawer: mobile ? null : const AppDrawer(),
      bottomNavigationBar: mobile
          ? const MobileStudentBottomAppBar(activeRoute: '/level_test')
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: StudentDensityTokens.dark,
                onMenu: mobile ? null : () => Scaffold.of(context).openDrawer(),
                showLevelIndicator: false,
                showUtilityActions: !mobile,
                hideOnMobile: true,
                items: studentTopNavItems(
                  context,
                  active: StudentTopDestination.learning,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: StudentDensityPage(
                  child: mobile
                      ? _MobilePlacementBody(
                          loading: _loading,
                          error: _error,
                          stats: _stats,
                          onStart: _startPlacement,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _PlacementHero(),
                            const SizedBox(height: 34),
                            const _PlacementIntro(),
                            const SizedBox(height: 18),
                            _PlacementStatistics(stats: _stats),
                            const SizedBox(height: 14),
                            _PlacementReady(
                              loading: _loading,
                              error: _error,
                              onStart: _startPlacement,
                            ),
                            const SizedBox(height: 40),
                          ],
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

/// 필요한 변수는 레벨 테스트 준비 상태·오류·시작 콜백이다.
/// 작동 원리: 모바일에서는 소개용 대형 카드들을 한 개의 시작 카드와 한 개의 과정 목록으로 압축한다.
class _MobilePlacementBody extends StatelessWidget {
  const _MobilePlacementBody({
    required this.loading,
    required this.error,
    required this.stats,
    required this.onStart,
  });

  final bool loading;
  final String? error;
  final LevelTestPlacementStats? stats;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('level-test-mobile-flat'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '레벨 테스트',
        style: TextStyle(
          fontSize: 32,
          letterSpacing: -1.4,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: StudentDensityTokens.dark,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.speed_rounded, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    '25문제로\n첫 OVR을 배정해요',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              '30분 · 자유 이동 · 마지막에 한 번 채점',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: FilledButton(
                key: const ValueKey('level-test-mobile-start'),
                onPressed: loading ? null : onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: StudentDensityTokens.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '레벨 테스트 시작',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 26),
      _PlacementStatistics(stats: stats),
      const SizedBox(height: 32),
    ],
  );
}

class _PlacementHero extends StatelessWidget {
  const _PlacementHero();

  /// 필요한 변수는 화면 폭과 고정 배치 테스트 메타다.
  /// HTML 시안의 밝은 그라데이션 안에 소개 문구·OVR 궤도·25문항 지표를 반응형으로 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(mobile ? 24 : 30),
      child: Container(
        constraints: BoxConstraints(minHeight: mobile ? 230 : 430),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF6F6F8), Color(0xFFE9E9ED)],
            stops: [0, .55, 1],
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 24 : 42,
                mobile ? 24 : 42,
                mobile ? 118 : 330,
                mobile ? 68 : 94,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FIRST STEP · OVR PLACEMENT',
                    style: TextStyle(
                      color: StudentDensityTokens.muted,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '처음 만나는\n나의 실력.',
                    style: TextStyle(
                      color: StudentDensityTokens.ink,
                      fontSize: mobile ? 46 : 70,
                      height: .9,
                      letterSpacing: -3,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '25개의 문제를 마지막에 한 번 채점해\n현재 실력을 나타내는 첫 OVR을 배정합니다.',
                    style: TextStyle(
                      color: StudentDensityTokens.muted,
                      fontSize: mobile ? 11 : 13,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: mobile ? -8 : -80,
              top: mobile ? 50 : 34,
              child: _OvrOrbit(mobile: mobile),
            ),
            Positioned(
              left: mobile ? 14 : null,
              right: mobile ? 14 : 28,
              bottom: mobile ? 10 : 24,
              child: SizedBox(
                width: mobile ? null : 360,
                child: const _PlacementMeta(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OvrOrbit extends StatelessWidget {
  const _OvrOrbit({required this.mobile});

  final bool mobile;

  /// 필요한 변수는 모바일 여부다.
  /// 측정 전 OVR을 두 개의 원형 궤도와 중앙 `--` 값으로 표현한다.
  @override
  Widget build(BuildContext context) => Container(
    width: mobile ? 120 : 360,
    height: mobile ? 120 : 360,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.black26),
    ),
    alignment: Alignment.center,
    child: Container(
      width: mobile ? 94 : 172,
      height: mobile ? 94 : 172,
      decoration: BoxDecoration(
        color: mobile ? Colors.transparent : const Color(0xFF202022),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black38),
        boxShadow: mobile
            ? const []
            : const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'MY OVR',
            style: TextStyle(
              color: mobile ? Colors.black54 : Colors.white54,
              fontSize: 8,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            '--',
            style: TextStyle(
              color: mobile ? StudentDensityTokens.ink : Colors.white,
              fontSize: 34,
              height: .9,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'READY TO MEASURE',
            style: TextStyle(
              color: mobile ? Colors.black38 : Colors.white54,
              fontSize: 6,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PlacementMeta extends StatelessWidget {
  const _PlacementMeta();

  /// 필요한 변수는 문항 수·난이도·결과 유형이다.
  /// 히어로 하단에 반투명 3열 지표를 띄워 테스트 범위를 표시한다.
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Expanded(child: _MetaCell('QUESTIONS', '25')),
      SizedBox(width: 8),
      Expanded(child: _MetaCell('DIFFICULTY', '기초–심화')),
      SizedBox(width: 8),
      Expanded(child: _MetaCell('RESULT', 'OVR')),
    ],
  );
}

class _MetaCell extends StatelessWidget {
  const _MetaCell(this.label, this.value);

  final String label;
  final String value;

  /// 필요한 변수는 지표 이름과 값이다.
  /// 동일 너비의 반투명 셀 안에 작은 영문 이름과 굵은 값을 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .72),
      border: Border.all(color: StudentDensityTokens.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: StudentDensityTokens.muted,
            fontSize: 7,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: StudentDensityTokens.ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _PlacementIntro extends StatelessWidget {
  const _PlacementIntro();

  /// 필요한 변수는 화면 폭이다.
  /// 측정 목적 제목과 설명을 PC 2열, 모바일 단일 열로 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StudentDensityEyebrow('HOW IT WORKS'),
        const SizedBox(height: 10),
        Text(
          '30분 뒤,\n첫 OVR을 배정합니다.',
          style: TextStyle(
            fontSize: mobile ? 34 : 54,
            height: 1,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
    const copy = Text(
      '제한 시간 30분 동안 문항을 자유롭게 오간 뒤 전체 답안을 한 번에 채점해 첫 OVR을 배정합니다.',
      style: TextStyle(
        fontSize: 13,
        height: 1.6,
        color: StudentDensityTokens.muted,
      ),
    );
    if (mobile) return title;
    return Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 40),
        const Expanded(child: copy),
      ],
    );
  }
}

class _PlacementStatistics extends StatelessWidget {
  const _PlacementStatistics({required this.stats});

  final LevelTestPlacementStats? stats;

  static const _fallbackDifficulty = [
    LevelTestDifficultyBand(tier: 2, label: '기초', questionCount: 5),
    LevelTestDifficultyBand(tier: 3, label: '기본', questionCount: 10),
    LevelTestDifficultyBand(tier: 4, label: '응용', questionCount: 7),
    LevelTestDifficultyBand(tier: 5, label: '심화', questionCount: 3),
  ];

  @override
  Widget build(BuildContext context) {
    final difficulty = stats?.difficultyBands.isNotEmpty == true
        ? stats!.difficultyBands
        : _fallbackDifficulty;
    final grades = stats?.gradeBands ?? const <LevelTestGradeBand>[];
    return Column(
      key: const ValueKey('level-test-statistics'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '시험 난이도',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: StudentDensityTokens.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '25문항 난이도 배치',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      for (var index = 0; index < difficulty.length; index++)
                        Expanded(
                          flex: difficulty[index].questionCount,
                          child: ColoredBox(
                            color: [
                              const Color(0xFFD6D6D3),
                              const Color(0xFF9E9E9A),
                              const Color(0xFF5F5F5C),
                              const Color(0xFF191919),
                            ][index.clamp(0, 3).toInt()],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: difficulty
                    .map(
                      (band) => Text(
                        '${band.label} ${band.questionCount}',
                        style: const TextStyle(
                          color: StudentDensityTokens.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '등급대별 실제 결과',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          '제출 완료 데이터 기준 · 표본 3명 이상만 표시',
          style: TextStyle(color: StudentDensityTokens.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('level-test-grade-chart'),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: StudentDensityTokens.line),
          ),
          child: grades.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '아직 표시할 응시자 통계가 충분하지 않아요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: StudentDensityTokens.muted,
                      fontSize: 13,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var index = 0; index < grades.length; index++) ...[
                      _GradeAverageBar(band: grades[index]),
                      if (index != grades.length - 1)
                        const SizedBox(height: 18),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _GradeAverageBar extends StatelessWidget {
  const _GradeAverageBar({required this.band});

  final LevelTestGradeBand band;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              band.grade,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            '평균 ${band.averageCorrect.toStringAsFixed(1)}개 · OVR ${band.averageOvr.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      const SizedBox(height: 9),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: (band.averageCorrect / 25).clamp(0.0, 1.0),
          minHeight: 9,
          color: StudentDensityTokens.dark,
          backgroundColor: StudentDensityTokens.surfaceMuted,
        ),
      ),
    ],
  );
}

class _PlacementReady extends StatelessWidget {
  const _PlacementReady({
    required this.loading,
    required this.error,
    required this.onStart,
  });

  final bool loading;
  final String? error;
  final VoidCallback onStart;

  /// 필요한 변수는 API 준비 상태·오류·시작 콜백과 화면 폭이다.
  /// 준비 체크와 실제 시작 행동을 흑백 2열 또는 모바일 세로 카드로 표시한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final copy = Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          StudentDensityEyebrow('BEFORE YOU START'),
          SizedBox(height: 10),
          Text(
            '준비되었나요?',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 16),
          _ReadyCheck('25문항 · 제한 시간 30분'),
          _ReadyCheck('빈 답 허용 · 이전/다음 자유 이동'),
          _ReadyCheck('마지막 제출에서 한 번만 채점'),
        ],
      ),
    );
    final action = Container(
      color: StudentDensityTokens.dark,
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const StudentDensityEyebrow('YOUR BASELINE', color: Colors.white54),
          const SizedBox(height: 12),
          const Text(
            '첫 번째\n기준점을 만들 시간',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: loading ? null : onStart,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: StudentDensityTokens.ink,
              minimumSize: const Size.fromHeight(48),
            ),
            child: loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '레벨 테스트 시작 →',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          ],
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        color: Colors.white,
        child: mobile
            ? Column(children: [copy, action])
            : Row(
                children: [
                  Expanded(child: copy),
                  Expanded(child: action),
                ],
              ),
      ),
    );
  }
}

class _ReadyCheck extends StatelessWidget {
  const _ReadyCheck(this.label);

  final String label;

  /// 필요한 변수는 시작 전 확인 문구다.
  /// 체크 아이콘과 안내 문구를 한 행으로 표시한다.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        const Icon(Icons.check_circle, size: 17),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
