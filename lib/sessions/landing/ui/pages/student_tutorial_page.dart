import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/app/router.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

/// HTML 학생 튜토리얼의 한 단계에 필요한 표시 정보다.
@immutable
class StudentTutorialStep {
  const StudentTutorialStep({
    required this.id,
    required this.number,
    required this.title,
    required this.shortTitle,
    required this.description,
    required this.actionLabel,
    required this.icon,
    required this.instruction,
  });

  final String id;
  final String number;
  final String title;
  final String shortTitle;
  final String description;
  final String actionLabel;
  final IconData icon;
  final String instruction;
}

/// 지정 HTML의 5개 튜토리얼 단계다. 샘플 문구는 안내 화면에만 사용한다.
const studentTutorialSteps = <StudentTutorialStep>[
  StudentTutorialStep(
    id: 'home',
    number: '01',
    title: '오늘 학습 시작하기',
    shortTitle: '홈',
    description: '홈에서 오늘 할 일과 진행 중인 코스를 확인하고, 이어 학습하기를 누르세요.',
    actionLabel: '이어 학습하기',
    icon: Icons.home_outlined,
    instruction: '홈에서 진행 중인 코스를 찾습니다.',
  ),
  StudentTutorialStep(
    id: 'course',
    number: '02',
    title: '코스에서 단원 고르기',
    shortTitle: '코스',
    description: '코스 화면에서 현재 단원과 남은 학습량을 확인한 뒤 이어갈 단원을 선택하세요.',
    actionLabel: '현재 단원 열기',
    icon: Icons.route_outlined,
    instruction: '현재 표시가 있는 단원을 찾습니다.',
  ),
  StudentTutorialStep(
    id: 'solve',
    number: '03',
    title: '문제 풀고 해설 확인하기',
    shortTitle: '풀이',
    description: '문제를 읽고 풀이 탭에 과정을 적으세요. 제출 후에는 해설 탭에서 핵심 순서를 확인할 수 있어요.',
    actionLabel: '풀이 작성하기',
    icon: Icons.edit_outlined,
    instruction: '문제를 읽고 풀이 탭을 누릅니다.',
  ),
  StudentTutorialStep(
    id: 'book',
    number: '04',
    title: '교재 이어 읽기',
    shortTitle: '책가방',
    description: '책가방에 저장된 교재를 열고 목차나 페이지 버튼으로 필요한 개념을 이어 읽으세요.',
    actionLabel: '다음 페이지',
    icon: Icons.menu_book_outlined,
    instruction: '교재를 열고 현재 위치를 확인합니다.',
  ),
  StudentTutorialStep(
    id: 'tutor',
    number: '05',
    title: '막히면 AI 튜터에게 묻기',
    shortTitle: '튜터',
    description: '풀이 중 막힌 지점을 짧게 적으면 AI 튜터가 다음에 확인할 개념과 풀이 방향을 안내해요.',
    actionLabel: '질문 보내기',
    icon: Icons.auto_awesome_outlined,
    instruction: '막힌 내용을 한 문장으로 적습니다.',
  ),
];

/// HTML `about` 화면에 대응하는 학생용 튜토리얼 페이지다.
class StudentTutorialPage extends StatefulWidget {
  const StudentTutorialPage({super.key});

  static const routeName = '/landing/about';

  @override
  State<StudentTutorialPage> createState() => _StudentTutorialPageState();
}

class _StudentTutorialPageState extends State<StudentTutorialPage> {
  static const _storageKey = 'student.atlas.tutorial.v1';

  int _current = 0;
  final Set<String> _practiced = <String>{};
  bool _loaded = false;

  StudentTutorialStep get _step => studentTutorialSteps[_current];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  /// 로컬 튜토리얼 위치와 실습 완료 목록만 복원한다.
  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt('$_storageKey.current') ?? 0;
      final practiced =
          prefs.getStringList('$_storageKey.practiced') ?? const [];
      if (!mounted) return;
      setState(() {
        _current = current.clamp(0, studentTutorialSteps.length - 1);
        _practiced
          ..clear()
          ..addAll(practiced.where(_isKnownStep));
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  bool _isKnownStep(String id) =>
      studentTutorialSteps.any((step) => step.id == id);

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_storageKey.current', _current);
      await prefs.setStringList('$_storageKey.practiced', _practiced.toList());
    } catch (_) {
      // 튜토리얼 진행은 로컬 저장 실패만으로 막지 않는다.
    }
  }

  void _moveTo(int index) {
    final next = index.clamp(0, studentTutorialSteps.length - 1);
    if (next == _current) return;
    setState(() => _current = next);
    _saveState();
  }

  void _practice() {
    if (_practiced.add(_step.id)) {
      setState(() {});
      _saveState();
    }
  }

  void _finish() {
    _saveState();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.studentDashboard, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: StudentDensityTokens.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth <= StudentDensityTokens.mobileBreakpoint;
            return Column(
              children: [
                _TutorialTopBar(compact: compact),
                Expanded(
                  child: _TutorialLayout(
                    compact: compact,
                    current: _current,
                    step: _step,
                    practiced: _practiced,
                    onStep: _moveTo,
                    onPractice: _practice,
                    onPrevious: () => _moveTo(_current - 1),
                    onNext: () => _moveTo(_current + 1),
                    onFinish: _finish,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TutorialLayout extends StatelessWidget {
  const _TutorialLayout({
    required this.compact,
    required this.current,
    required this.step,
    required this.practiced,
    required this.onStep,
    required this.onPractice,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  final bool compact;
  final int current;
  final StudentTutorialStep step;
  final Set<String> practiced;
  final ValueChanged<int> onStep;
  final VoidCallback onPractice;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final steps = _TutorialSteps(
      compact: compact,
      current: current,
      practiced: practiced,
      onStep: onStep,
    );
    final stage = Expanded(
      child: _TutorialStage(
        step: step,
        compact: compact,
        practiced: practiced.contains(step.id),
        onPractice: onPractice,
      ),
    );
    final footer = _TutorialActions(
      current: current,
      compact: compact,
      onPrevious: onPrevious,
      onNext: onNext,
      onFinish: onFinish,
    );

    if (compact) {
      return Column(
        children: [
          SizedBox(height: 64, child: steps),
          stage,
          footer,
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 230, child: steps),
              stage,
            ],
          ),
        ),
        footer,
      ],
    );
  }
}

class _TutorialTopBar extends StatelessWidget {
  const _TutorialTopBar({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    height: 62,
    color: StudentDensityTokens.surface,
    padding: EdgeInsets.only(left: compact ? 10 : 10, right: compact ? 10 : 22),
    child: Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: OutlinedButton(
            key: const ValueKey('tutorial-back'),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(
                  context,
                ).pushReplacementNamed(AppRoutes.studentDashboard);
              }
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: StudentDensityTokens.ink,
              side: const BorderSide(color: StudentDensityTokens.line),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Icon(Icons.arrow_back, size: 19),
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          '튜토리얼',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const Spacer(),
        _TutorialTopAction(
          icon: Icons.search,
          label: '검색',
          onTap: () => showStudentQuickSearch(context),
        ),
        const SizedBox(width: 8),
        _TutorialTopAction(
          icon: Icons.notifications_none,
          label: '알림',
          onTap: () => showStudentNotifications(context),
        ),
      ],
    ),
  );
}

class _TutorialTopAction extends StatelessWidget {
  const _TutorialTopAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: SizedBox(
      width: 48,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: StudentDensityTokens.ink,
          side: const BorderSide(color: StudentDensityTokens.line),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Icon(icon, size: 19),
      ),
    ),
  );
}

class _TutorialProgress extends StatelessWidget {
  const _TutorialProgress({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final value = (current + 1) / studentTutorialSteps.length;
    return Semantics(
      label: '튜토리얼 진행률',
      value: '${current + 1} / ${studentTutorialSteps.length}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SizedBox(
              height: 5,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: StudentDensityTokens.surfaceMuted,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: const ColoredBox(color: StudentDensityTokens.dark),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${current + 1} / ${studentTutorialSteps.length}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _TutorialSteps extends StatelessWidget {
  const _TutorialSteps({
    required this.compact,
    required this.current,
    required this.practiced,
    required this.onStep,
  });

  final bool compact;
  final int current;
  final Set<String> practiced;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final list = ListView.builder(
      scrollDirection: compact ? Axis.horizontal : Axis.vertical,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 10,
        vertical: compact ? 6 : 14,
      ),
      itemCount: studentTutorialSteps.length,
      itemBuilder: (context, index) {
        final item = studentTutorialSteps[index];
        final active = index == current;
        return SizedBox(
          width: compact ? 74 : double.infinity,
          height: compact ? 52 : 58,
          child: Semantics(
            button: true,
            selected: active,
            label: '${item.number} ${item.shortTitle}',
            child: InkWell(
              key: ValueKey('tutorial-step-${item.id}'),
              onTap: () => onStep(index),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
                decoration: BoxDecoration(
                  color: active
                      ? StudentDensityTokens.surfaceMuted
                      : StudentDensityTokens.surface,
                  border: Border(
                    left: compact
                        ? BorderSide.none
                        : BorderSide(
                            color: active
                                ? StudentDensityTokens.dark
                                : Colors.transparent,
                            width: 3,
                          ),
                    bottom: compact
                        ? BorderSide(
                            color: active
                                ? StudentDensityTokens.dark
                                : Colors.transparent,
                            width: 2,
                          )
                        : BorderSide.none,
                  ),
                ),
                child: compact
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.icon, size: 19),
                          const SizedBox(height: 2),
                          Text(
                            item.shortTitle,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: active
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              item.number,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: StudentDensityTokens.muted,
                              ),
                            ),
                          ),
                          Icon(item.icon, size: 19),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              item.shortTitle,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Icon(
                            practiced.contains(item.id)
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 17,
                            color: practiced.contains(item.id)
                                ? StudentDensityTokens.dark
                                : StudentDensityTokens.line,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border(
          right: BorderSide(color: StudentDensityTokens.line),
          bottom: BorderSide(color: StudentDensityTokens.line),
        ),
      ),
      child: list,
    );
  }
}

class _TutorialStage extends StatelessWidget {
  const _TutorialStage({
    required this.step,
    required this.compact,
    required this.practiced,
    required this.onPractice,
  });

  final StudentTutorialStep step;
  final bool compact;
  final bool practiced;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'STEP ${step.number}',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: StudentDensityTokens.muted,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          step.title,
          style: TextStyle(
            fontSize: compact ? 26 : 40,
            fontWeight: FontWeight.w900,
            height: 1.04,
          ),
        ),
        SizedBox(height: compact ? 10 : 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            step.description,
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              height: 1.7,
              color: StudentDensityTokens.muted,
            ),
          ),
        ),
        SizedBox(height: compact ? 16 : 24),
        if (!compact) ...[
          _InstructionRow(number: '1', text: step.instruction),
          const _InstructionRow(number: '2', text: '오른쪽 예시에서 강조된 버튼을 눌러보세요.'),
        ],
      ],
    );
    final demo = _TutorialDemo(
      compact: compact,
      step: step,
      practiced: practiced,
      onPractice: onPractice,
    );
    final content = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, demo],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 10, child: copy),
              const SizedBox(width: 50),
              Expanded(flex: 22, child: demo),
            ],
          );
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        compact ? (MediaQuery.sizeOf(context).width <= 390 ? 12 : 16) : 38,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 420 : 600),
        child: Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(0, compact ? 0 : 42),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 54),
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: StudentDensityTokens.line)),
    ),
    child: Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          color: StudentDensityTokens.dark,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _TutorialDemo extends StatelessWidget {
  const _TutorialDemo({
    required this.compact,
    required this.step,
    required this.practiced,
    required this.onPractice,
  });

  final StudentTutorialStep step;
  final bool compact;
  final bool practiced;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: compact ? 312 : 394,
        padding: EdgeInsets.all(compact ? 10 : 22),
        decoration: const BoxDecoration(
          color: Color(0xFFE9EAED),
          border: Border.fromBorderSide(
            BorderSide(color: StudentDensityTokens.line),
          ),
        ),
        child: _DemoContent(
          compact: compact,
          step: step,
          onPractice: onPractice,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        practiced ? '확인했어요. 다음 단계로 이동하세요.' : '강조된 버튼을 직접 눌러보세요.',
        key: const ValueKey('tutorial-demo-status'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: StudentDensityTokens.muted,
        ),
      ),
    ],
  );
}

class _DemoContent extends StatelessWidget {
  const _DemoContent({
    required this.compact,
    required this.step,
    required this.onPractice,
  });

  final bool compact;
  final StudentTutorialStep step;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final barTitle = switch (step.id) {
      'home' => '오늘 학습',
      'course' => '미적분 핵심 완성',
      'solve' => '문제 03',
      'book' => '접선의 기울기',
      _ => 'AI 튜터',
    };
    final barDetail = switch (step.id) {
      'home' => '화요일 · 3개 예정',
      'course' => '4단원',
      'solve' => '풀이',
      'book' => '02 / 05',
      _ => '질문',
    };
    final focusTitle = switch (step.id) {
      'home' => '미적분 핵심 완성',
      'course' => '4.2 접선의 방정식',
      'solve' => 'f(x)=x²−2x+1의 접선 기울기를 구하세요.',
      'book' => '접선의 기울기',
      _ => '어느 부분에서 막혔나요?',
    };
    final focusDetail = switch (step.id) {
      'home' => '4단원 · 도함수 · 68%',
      'course' => '4.2 접선의 방정식',
      'solve' => '풀이를 여기에 작성하세요',
      'book' => '점 P(a, f(a))에서 접선의 기울기는 f′(a)입니다.',
      _ => '접선의 기울기를 어디에 대입해야 하는지 모르겠어요.',
    };
    final cardPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 24)
        : const EdgeInsets.all(28);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 44,
          color: StudentDensityTokens.surface,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Text(
                barTitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                barDetail,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: StudentDensityTokens.muted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 20 : 38),
        Align(
          alignment: Alignment.center,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: cardPadding,
            color: StudentDensityTokens.dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '진행 중인 코스',
                  style: TextStyle(
                    color: Color(0xFFB8BAC0),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  focusTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  focusDetail,
                  style: const TextStyle(
                    color: Color(0xFFC8C9CE),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 18),
                const SizedBox(
                  height: 5,
                  child: LinearProgressIndicator(
                    value: .68,
                    backgroundColor: Color(0x44FFFFFF),
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: compact ? 18 : 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    key: ValueKey('tutorial-practice-${step.id}'),
                    onPressed: onPractice,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: StudentDensityTokens.dark,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.actionLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward, size: 17),
                      ],
                    ),
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

class _TutorialActions extends StatelessWidget {
  const _TutorialActions({
    required this.current,
    required this.compact,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  final int current;
  final bool compact;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final last = current == studentTutorialSteps.length - 1;
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 20,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border(top: BorderSide(color: StudentDensityTokens.line)),
      ),
      child: compact
          ? Row(
              children: [
                SizedBox(
                  width: 48,
                  child: OutlinedButton(
                    key: const ValueKey('tutorial-previous'),
                    onPressed: current == 0 ? null : onPrevious,
                    style: _buttonStyle(compact: true),
                    child: const Text('이전'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 10, child: _TutorialProgress(current: current)),
                const SizedBox(width: 8),
                Expanded(flex: 14, child: _nextButton(last, compact: true)),
              ],
            )
          : Row(
              children: [
                OutlinedButton(
                  key: const ValueKey('tutorial-previous'),
                  onPressed: current == 0 ? null : onPrevious,
                  style: _buttonStyle(),
                  child: const Text('이전'),
                ),
                const SizedBox(width: 18),
                const Spacer(),
                SizedBox(
                  width: 240,
                  child: _TutorialProgress(current: current),
                ),
                const SizedBox(width: 18),
                const Spacer(),
                _nextButton(last),
              ],
            ),
    );
  }

  Widget _nextButton(bool last, {bool compact = false}) => FilledButton(
    key: ValueKey(last ? 'tutorial-finish' : 'tutorial-next'),
    onPressed: last ? onFinish : onNext,
    style: _primaryStyle(compact: compact),
    child: Text(last ? '튜토리얼 마치기' : '다음'),
  );

  ButtonStyle _buttonStyle({bool compact = false}) => OutlinedButton.styleFrom(
    minimumSize: Size(compact ? 48 : 72, 48),
    padding: compact ? EdgeInsets.zero : null,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    side: const BorderSide(color: StudentDensityTokens.line),
  );

  ButtonStyle _primaryStyle({bool compact = false}) => FilledButton.styleFrom(
    minimumSize: Size(compact ? 0 : 120, 48),
    backgroundColor: StudentDensityTokens.dark,
    foregroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  );
}
