import 'dart:async';

import 'package:flutter/material.dart';
import 'package:s11/features/level_test/level_test_result_page.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

class LevelTestHomePage extends StatefulWidget {
  const LevelTestHomePage({
    super.key,
    this.initialStats,
    this.startNewTest = false,
  });

  final LevelTestPlacementStats? initialStats;
  final bool startNewTest;

  static const routeName = '/level_test';

  @override
  State<LevelTestHomePage> createState() => _LevelTestHomePageState();
}

class _LevelTestHomePageState extends State<LevelTestHomePage> {
  bool _loading = false;
  String? _error;
  LevelTestPlacementStats? _stats;
  LevelTestPlacementResult? _completedResult;
  String? _selectedTrackId;
  String? _selectedForm;

  @override
  void initState() {
    super.initState();
    _stats = widget.initialStats;
    if (_stats == null) unawaited(_loadStats());
    if (!widget.startNewTest) unawaited(_loadStatus());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await ApiClient.instance.fetchLevelTestPlacementStatus();
      if (!mounted) return;
      setState(
        () => _completedResult = status.completed ? status.result : null,
      );
    } catch (_) {
      // 상태 조회 실패는 통계와 안내 화면 렌더링을 막지 않는다.
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await ApiClient.instance.fetchLevelTestPlacementStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // 통계 조회 실패가 시험 시작을 막지는 않는다.
    }
  }

  void _selectTrack(String? trackId) {
    setState(() {
      _selectedTrackId = trackId;
      _selectedForm = null;
    });
  }

  Future<void> _startPlacement() async {
    final trackId = _selectedTrackId;
    final form = _selectedForm;
    if (_loading ||
        _completedResult != null ||
        trackId == null ||
        form == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await ApiClient.instance.startLevelTestPlacement(
        trackId: trackId,
        form: form,
      );
      if (!mounted) return;
      if (session.sessionId.trim().isEmpty) {
        setState(() {
          _loading = false;
          _error = '레벨 테스트 세션을 확인하지 못했어요. 다시 시도해 주세요.';
        });
        return;
      }
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
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LevelTestResultPage(
          placementResult: result,
          onStartAnotherTest: _startAnotherTest,
        ),
      ),
    );
  }

  void _startAnotherTest() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            LevelTestHomePage(initialStats: _stats, startNewTest: true),
      ),
    );
  }

  /// 필요한 변수는 배치 테스트 로딩·오류 상태와 화면 폭이다.
  /// 실제 제출 로직 위에 HTML의 OVR 히어로, 측정 과정, 시작 전 확인 영역을 순서대로 배치한다.
  @override
  Widget build(BuildContext context) {
    if (_completedResult != null) {
      return LevelTestResultPage(
        placementResult: _completedResult,
        onStartAnotherTest: _startAnotherTest,
      );
    }
    final mobile = isStudentDensityMobile(context);
    return StudentHtmlShell(
      key: const ValueKey('level-test-screen'),
      title: '레벨 테스트',
      activeRoute: LevelTestHomePage.routeName,
      // HTML의 level-test shell은 76px 레일만 사용하고 우측 문맥 영역을
      // 숨긴다. 본문 폭은 아래 `_LevelTestEntryPanel`이 직접 제한한다.
      showContextAside: false,
      railWidth: 76,
      mobileBackButton: true,
      onMenu: () => Navigator.of(context).pushNamed('/student/dashboard'),
      onSearch: () => showStudentQuickSearch(context),
      onNotifications: () => showStudentNotifications(context),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: _LevelTestEntryPanel(
              mobile: mobile,
              tracks: _stats?.tracks ?? const <LevelTestAssessmentTrack>[],
              selectedTrackId: _selectedTrackId,
              selectedForm: _selectedForm,
              onTrackChanged: _selectTrack,
              onFormChanged: (form) => setState(() => _selectedForm = form),
              loading: _loading,
              error: _error,
              onStart: _startPlacement,
            ),
          ),
        ),
      ),
    );
  }
}

/// HTML `level-test-entry`를 실제 배치 테스트 시작 계약과 연결한다.
/// 필요한 값은 서버가 제공한 문항 수, 시작 중 여부, 오류와 시작 콜백이다.
class _LevelTestEntryPanel extends StatelessWidget {
  const _LevelTestEntryPanel({
    required this.mobile,
    required this.tracks,
    required this.selectedTrackId,
    required this.selectedForm,
    required this.onTrackChanged,
    required this.onFormChanged,
    required this.loading,
    required this.error,
    required this.onStart,
  });

  final bool mobile;
  final List<LevelTestAssessmentTrack> tracks;
  final String? selectedTrackId;
  final String? selectedForm;
  final ValueChanged<String?> onTrackChanged;
  final ValueChanged<String?> onFormChanged;
  final bool loading;
  final String? error;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final side = mobile ? 18.0 : 38.0;
    final top = mobile ? 26.0 : 34.0;
    final trackIndex = tracks.indexWhere(
      (track) => track.id == selectedTrackId,
    );
    final selectedTrack = trackIndex < 0 ? null : tracks[trackIndex];
    final formIndex =
        selectedTrack?.forms.indexWhere((form) => form.id == selectedForm) ??
        -1;
    final selectedAssessmentForm = formIndex < 0
        ? null
        : selectedTrack!.forms[formIndex];
    final selectedQuestionCount = selectedAssessmentForm?.questionCount ?? 0;
    return Container(
      key: const ValueKey('level-test-entry'),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surface,
        border: mobile
            ? const Border(bottom: BorderSide(color: StudentDensityTokens.ink))
            : Border.all(color: StudentDensityTokens.ink),
      ),
      padding: EdgeInsets.fromLTRB(side, top, side, mobile ? 26 : 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: mobile ? 24 : 28,
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '01',
                    style: TextStyle(
                      color: StudentDensityTokens.ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: mobile ? 1.0 : 1.2,
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
                      '레벨 테스트',
                      style: TextStyle(
                        color: StudentDensityTokens.ink,
                        fontSize: mobile ? 25 : 28,
                        height: 1.4,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.35,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      '현재 학습 위치를 측정하는 기준점 진단입니다.',
                      style: TextStyle(
                        color: StudentDensityTokens.muted,
                        fontSize: 11,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: mobile ? 22 : 26),
          DropdownButtonFormField<String>(
            key: const ValueKey('level-test-track-picker'),
            initialValue: selectedTrackId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '학년·과목 선택',
              border: OutlineInputBorder(borderRadius: BorderRadius.zero),
            ),
            items: tracks
                .map(
                  (track) => DropdownMenuItem(
                    value: track.id,
                    child: Text(track.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: loading ? null : onTrackChanged,
          ),
          const SizedBox(height: 16),
          Text(
            '문항 유형',
            style: TextStyle(
              fontSize: mobile ? 14 : 15,
              fontWeight: FontWeight.w900,
              color: StudentDensityTokens.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                (selectedTrack?.forms ?? const <LevelTestAssessmentForm>[])
                    .map(
                      (form) => ChoiceChip(
                        key: ValueKey('level-test-form-${form.id}'),
                        label: Text('${form.id}형 · ${form.questionCount}문항'),
                        selected: selectedForm == form.id,
                        onSelected: loading
                            ? null
                            : (selected) =>
                                  onFormChanged(selected ? form.id : null),
                      ),
                    )
                    .toList(growable: false),
          ),
          if (selectedAssessmentForm != null) ...[
            const SizedBox(height: 8),
            Text(
              selectedAssessmentForm.label,
              style: const TextStyle(
                color: StudentDensityTokens.muted,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _LevelTestMetaRow(
            questionCount: selectedQuestionCount,
            mobile: mobile,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Align(
              alignment: mobile ? Alignment.center : Alignment.centerRight,
              child: SizedBox(
                width: mobile ? double.infinity : 176,
                height: 50,
                child: FilledButton(
                  key: const ValueKey('level-test-entry-start'),
                  onPressed:
                      loading ||
                          selectedTrack == null ||
                          selectedAssessmentForm == null
                      ? null
                      : onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: StudentDensityTokens.ink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: StudentDensityTokens.muted,
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '테스트 시작',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              textAlign: mobile ? TextAlign.center : TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelTestMetaRow extends StatelessWidget {
  const _LevelTestMetaRow({required this.questionCount, required this.mobile});

  final int questionCount;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final cells = <({String label, String value})>[
      (label: '문항', value: questionCount == 0 ? '선택' : '$questionCount'),
      (label: '제한 시간', value: '60분'),
      (label: '채점', value: '제출 후'),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: StudentDensityTokens.line),
          bottom: BorderSide(color: StudentDensityTokens.line),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < cells.length; index++)
            Expanded(
              child: Container(
                constraints: BoxConstraints(minHeight: mobile ? 70 : 78),
                padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 8 : 14,
                  vertical: mobile ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  border: index == cells.length - 1
                      ? null
                      : const Border(
                          right: BorderSide(color: StudentDensityTokens.line),
                        ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cells[index].label,
                      style: const TextStyle(
                        color: StudentDensityTokens.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      cells[index].value,
                      style: TextStyle(
                        color: StudentDensityTokens.ink,
                        fontSize: mobile ? 16 : 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
                    '25문제로\n현재 실력을 확인해요',
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
              '60분 · 자유 이동 · 마지막에 한 번 채점',
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
                    'FIRST STEP · LEVEL DIAGNOSTIC',
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
                    '문제은행에서 25문항을 뽑아 마지막에 한 번 채점하고\n정답률과 단원별 결과를 보여드립니다.',
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
            '진단 상태',
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
            '제출 후 결과 제공',
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
      Expanded(child: _MetaCell('RESULT', '진단 결과')),
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
          '60분 동안 풀고,\n결과를 확인합니다.',
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
      '문항을 자유롭게 오가며 풀 수 있고, 제출하면 정답 수와 난이도·태그별 결과를 확인할 수 있습니다.',
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

  @override
  Widget build(BuildContext context) {
    final difficulty =
        stats?.difficultyBands ?? const <LevelTestDifficultyBand>[];
    return Column(
      key: const ValueKey('level-test-statistics'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '문항 구성',
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
              Text(
                '문제은행 ${stats?.poolCount ?? 0}문항 · 평가 ${stats?.questionCount ?? 25}문항',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              if (difficulty.isNotEmpty)
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
                              color:
                                  [
                                    const Color(0xFFD6D6D3),
                                    const Color(0xFF9E9E9A),
                                    const Color(0xFF5F5F5C),
                                    const Color(0xFF191919),
                                    const Color(0xFF000000),
                                  ][(difficulty[index].tier - 1)
                                      .clamp(0, 4)
                                      .toInt()],
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
                        '${band.label} ${band.questionCount}문항',
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
      ],
    );
  }
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
          _ReadyCheck('빈 답 허용 · 이전/다음 자유 이동'),
          _ReadyCheck('마지막 제출에서 서버가 한 번 채점'),
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
          const StudentDensityEyebrow('YOUR DIAGNOSTIC', color: Colors.white54),
          const SizedBox(height: 12),
          const Text(
            '현재 실력을\n확인할 시간',
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
