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
  const LevelTestHomePage({super.key});

  static const routeName = '/level_test';

  @override
  State<LevelTestHomePage> createState() => _LevelTestHomePageState();
}

class _LevelTestHomePageState extends State<LevelTestHomePage> {
  bool _loading = false;
  String? _error;

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
      final byIndex = {
        for (final question in questions) question.itemIndex: question,
      };
      final config = ProblemSolveConfig(
        questionCount: questions.length,
        timeLimitSeconds: session.timeLimitSeconds,
        hashTags: questions.expand((q) => q.hashTags).toSet().toList(),
        gradeImmediately: true,
        minDifficultyTier: 2,
        maxDifficultyTier: 5,
        passRate: 1,
        ratingEnabled: false,
        quests: questions.map((q) => q.quest).toList(),
        onProblemGraded:
            ({
              required int itemIndex,
              required Map<String, dynamic>? quest,
              required bool isCorrect,
              required List<Map<String, dynamic>> stepCorrectness,
              int? selectedIndex,
              int? elapsedSeconds,
            }) async {
              final question = byIndex[itemIndex];
              final questId = question?.questId ?? _questIdOf(quest);
              if (questId.isEmpty) return;
              await ApiClient.instance.submitLevelTestPlacementAnswer(
                sessionId: session.sessionId,
                itemIndex: itemIndex,
                questId: questId,
                isCorrect: isCorrect,
                answerTime: elapsedSeconds,
                stepCorrectness: stepCorrectness,
                tags: question?.hashTags ?? _tagsOf(quest),
              );
            },
        onComplete:
            ({
              required int correctCount,
              required int totalCount,
              required bool passed,
              int? elapsedSeconds,
            }) {
              _finishPlacement(session.sessionId);
            },
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BuildpageWidget(config: config)),
      );
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

  Future<void> _finishPlacement(String sessionId) async {
    try {
      final result = await ApiClient.instance.submitLevelTestPlacement(
        sessionId,
      );
      RatingStore.updateFromRating(result.toUserRating());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LevelTestResultPage(placementResult: result),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            studentFacingApiError(
              error,
              fallback: '결과를 저장하지 못했어요.',
              unavailable: '결과 저장 연결이 잠시 불안정해요. 잠시 후 다시 시도해 주세요.',
            ),
          ),
        ),
      );
    }
  }

  String _questIdOf(Map<String, dynamic>? quest) {
    final header = quest?['header'];
    if (header is Map) return (header['quest_id'] ?? '').toString();
    return '';
  }

  List<String> _tagsOf(Map<String, dynamic>? quest) {
    final info = quest?['info'];
    if (info is! Map) return const <String>[];
    return (info['hash_tag'] as List<dynamic>? ?? const [])
        .map((tag) => tag.toString())
        .toList();
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
                          onStart: _startPlacement,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _PlacementHero(),
                            const SizedBox(height: 34),
                            const _PlacementIntro(),
                            const SizedBox(height: 18),
                            const _PlacementProcess(),
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
    required this.onStart,
  });

  final bool loading;
  final String? error;
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
                    '25문제로\n실력을 확인해요',
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
              '약 60분 · 자동 저장 · OVR 분석',
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
                        '테스트 시작',
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
      const Text(
        '진행 방식',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          children: [
            _MobilePlacementStep(
              icon: Icons.quiz_outlined,
              title: '문제 풀기',
              subtitle: '주요 개념 25문항',
            ),
            _MobilePlacementStep(
              icon: Icons.insights_outlined,
              title: '풀이 분석',
              subtitle: '정오답과 풀이 시간 확인',
            ),
            _MobilePlacementStep(
              icon: Icons.route_outlined,
              title: '학습 추천',
              subtitle: 'OVR과 다음 코스 제공',
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
    ],
  );
}

/// 필요한 변수는 단계 아이콘·제목·짧은 설명이다.
/// 작동 원리: 과정 설명을 카드 세 개 대신 한 그룹 안의 큰 Material 목록 행으로 표시한다.
class _MobilePlacementStep extends StatelessWidget {
  const _MobilePlacementStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: StudentDensityTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: StudentDensityTokens.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
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
                    '25개의 문제로 지금의 학습 위치를 찾습니다.\n첫 OVR은 앞으로의 코스와 난이도를 결정합니다.',
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
      Expanded(child: _MetaCell('DIFFICULTY', '중상–상')),
      SizedBox(width: 8),
      Expanded(child: _MetaCell('RESULT', 'OVR + 태그')),
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
          mobile ? '점수가 아니라,\n학습의 출발점을 찾습니다.' : '점수가 아니라,\n학습의 출발점을 찾습니\n다.',
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
      '모든 답은 개념 태그와 풀이 시간으로 함께 분석됩니다. 맞힌 개수만 세지 않고 어떤 영역에서 빠르고 정확한지 확인합니다.',
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

class _PlacementProcess extends StatelessWidget {
  const _PlacementProcess();

  /// 필요한 변수는 화면 폭과 세 측정 단계다.
  /// 모바일은 세로, PC는 3열 카드로 배치 테스트 과정을 표시한다.
  @override
  Widget build(BuildContext context) {
    const cards = [
      _ProcessCard('01', '25', '폭넓게 확인', '선별된 25문항으로 주요 개념을 고르게 확인합니다.'),
      _ProcessCard('02', '⌁', '풀이 패턴 분석', '정오답, 풀이 시간과 사고 흐름을 문항마다 누적합니다.'),
      _ProcessCard('03', 'OVR', '첫 기준점 생성', '첫 OVR과 신뢰도, 강한 태그와 보완 태그를 제공합니다.'),
    ];
    if (isStudentDensityMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cards[0],
          const SizedBox(height: 10),
          cards[1],
          const SizedBox(height: 10),
          cards[2],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 10),
        Expanded(child: cards[1]),
        const SizedBox(width: 10),
        Expanded(child: cards[2]),
      ],
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard(this.number, this.mark, this.title, this.copy);

  final String number;
  final String mark;
  final String title;
  final String copy;

  /// 필요한 변수는 단계 번호·표식·제목·설명이다.
  /// 흰 카드 안에 큰 측정 표식과 설명을 동일한 최소 높이로 표시한다.
  @override
  Widget build(BuildContext context) => StudentDensitySurface(
    radius: 24,
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 9,
            color: StudentDensityTokens.muted,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          mark,
          style: const TextStyle(
            fontSize: 42,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          copy,
          style: const TextStyle(
            fontSize: 11,
            height: 1.5,
            color: StudentDensityTokens.muted,
          ),
        ),
      ],
    ),
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
          _ReadyCheck('25문항 · 제한 시간 60분'),
          _ReadyCheck('중간 진행 자동 저장'),
          _ReadyCheck('정답은 제출 후 분석'),
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
