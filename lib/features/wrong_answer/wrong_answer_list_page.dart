import 'package:flutter/material.dart';

import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

/// HTML 시안의 오늘 복습 우선순위와 약점 요약을 제공하는 화면이다.
class WrongAnswerListPage extends StatefulWidget {
  const WrongAnswerListPage({super.key});

  static const routeName = '/wrong_answers';

  /// 필요한 변수는 필터와 재풀이 상태다.
  /// 화면 내부에서 선택 필터를 유지할 State를 생성한다.
  @override
  State<WrongAnswerListPage> createState() => _WrongAnswerListPageState();
}

class _WrongAnswerListPageState extends State<WrongAnswerListPage> {
  String _filter = '전체 8';

  static const _items = <_ReviewItem>[
    _ReviewItem(
      number: '01',
      title: '두 직선의 교점 구하기',
      source: '수학Ⅱ 실전 시험 · 오늘',
      reason: '식의 이항 과정에서 부호를 반대로 바꿨어요.',
      tags: ['#식정리', '#교점'],
      attempts: '2회 틀림',
    ),
    _ReviewItem(
      number: '02',
      title: '일차함수의 기울기 판단',
      source: '함수의 시작 코스 · 어제',
      reason: 'Δy와 Δx의 순서를 바꾸는 실수가 반복됐어요.',
      tags: ['#기울기', '#좌표해석'],
      attempts: '3회 틀림',
    ),
    _ReviewItem(
      number: '03',
      title: '그래프의 평행이동',
      source: '일일 테스트 · 7월 12일',
      reason: '이동 방향은 맞았지만 상수항 계산을 놓쳤어요.',
      tags: ['#평행이동'],
      attempts: '1회 틀림',
    ),
    _ReviewItem(
      number: '04',
      title: '함숫값 계산',
      source: '함수의 시작 코스 · 7월 11일',
      reason: '복습에서 연속 두 번 정답을 맞혀 완료됐어요.',
      tags: ['#대입'],
      attempts: '복습 완료',
      done: true,
    ),
  ];

  /// 필요한 변수는 현재 화면 문맥과 선택 문제다.
  /// 실제 문제 세션 연결 전까지 해설·재풀이 목적을 명확한 안내 대화상자로 전달한다.
  void _showReviewAction(String action, _ReviewItem? item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action),
        content: Text(
          item == null
              ? '우선순위가 높은 복습 문제부터 문제 풀이 세션으로 연결합니다.'
              : '${item.title}\n문제 풀이 세션에서 $action 기능을 이어갑니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 선택한 필터 이름이다.
  /// 완료 필터만 완료 문항으로 제한하고 나머지는 우선순위 목록을 유지한다.
  List<_ReviewItem> get _visibleItems {
    if (_filter == '완료 2') return _items.where((item) => item.done).toList();
    if (_filter == '반복 오답 3') {
      return _items
          .where(
            (item) =>
                item.attempts.startsWith('2') || item.attempts.startsWith('3'),
          )
          .toList();
    }
    return _items;
  }

  /// 필요한 변수는 현재 필터·화면 폭·복습 항목이다.
  /// 공용 셸 아래에 HTML의 페이지 헤더, 검은 복습 히어로, 목록과 약점 카드를 순서대로 배치한다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('wrong-answers-screen'),
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: StudentDensityTokens.dark,
                onMenu: () => Scaffold.of(context).openDrawer(),
                showLevelIndicator: false,
                items: studentTopNavItems(
                  context,
                  active: StudentTopDestination.learning,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: StudentDensityPage(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ReviewHeading(
                        onStart: () => _showReviewAction('맞춤 복습 시작', null),
                      ),
                      const SizedBox(height: 16),
                      _ReviewHero(
                        onStart: () => _showReviewAction('6문제 이어서 풀기', null),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final mobile = constraints.maxWidth <= 780;
                          final list = _ReviewList(
                            items: _visibleItems,
                            filter: _filter,
                            onFilter: (value) =>
                                setState(() => _filter = value),
                            onAction: _showReviewAction,
                          );
                          const side = _WeakPoints();
                          if (mobile) {
                            return Column(
                              children: [
                                list,
                                const SizedBox(height: 14),
                                side,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: list),
                              const SizedBox(width: 14),
                              const Expanded(flex: 3, child: side),
                            ],
                          );
                        },
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

class _ReviewHeading extends StatelessWidget {
  const _ReviewHeading({required this.onStart});

  final VoidCallback onStart;

  /// 필요한 변수는 맞춤 복습 시작 콜백과 화면 폭이다.
  /// 모바일은 전체 폭 버튼, PC는 제목 우측 버튼을 사용한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    const copy = StudentDensityPageHeader(
      eyebrow: 'REVIEW',
      title: '복습',
      description: '틀린 문제를 쌓아두지 않고, 지금 다시 풀 문제부터 차례로 끝냅니다.',
    );
    final button = FilledButton(
      onPressed: onStart,
      style: FilledButton.styleFrom(
        backgroundColor: StudentDensityTokens.dark,
        minimumSize: Size(mobile ? double.infinity : 112, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Text(
        '맞춤 복습 시작',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [copy, const SizedBox(height: 16), button],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(child: copy),
        button,
      ],
    );
  }
}

class _ReviewHero extends StatelessWidget {
  const _ReviewHero({required this.onStart});

  final VoidCallback onStart;

  /// 필요한 변수는 복습 시작 콜백과 화면 폭이다.
  /// 오늘 분량·완료 링·주간 지표를 검은 단일 카드 안에 HTML 비율로 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(mobile ? 24 : 28),
      child: Container(
        color: const Color(0xFF1F1F20),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 22 : 34,
                mobile ? 22 : 30,
                mobile ? 18 : 28,
                mobile ? 18 : 24,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const StudentDensityEyebrow(
                          'TODAY’S REVIEW',
                          color: Colors.white54,
                        ),
                        SizedBox(height: mobile ? 26 : 40),
                        Text(
                          '오늘은 6문제만\n다시 보면 돼요.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: mobile ? 34 : 52,
                            height: .92,
                            letterSpacing: -2.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (!mobile) ...[
                          const SizedBox(height: 36),
                          const Text(
                            '최근 오답과 반복해서 놓친 개념을 우선순위로 정리했습니다.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: onStart,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: StudentDensityTokens.ink,
                          ),
                          child: const Text(
                            '6문제 이어서 풀기',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _ReviewRing(),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            const Row(
              children: [
                Expanded(child: _HeroMetric('이번 주 복습', '18문제')),
                Expanded(child: _HeroMetric('다시 맞힌 비율', '76%')),
                Expanded(child: _HeroMetric('가장 약한 개념', '기울기')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRing extends StatelessWidget {
  const _ReviewRing();

  /// 필요한 변수는 오늘 완료 수 2/8이다.
  /// 원형 진행 테두리 안에 완료 수를 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    width: isStudentDensityMobile(context) ? 82 : 108,
    height: isStudentDensityMobile(context) ? 82 : 108,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white24, width: 8),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '2',
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            height: .9,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text('/ 8 완료', style: TextStyle(color: Colors.white60, fontSize: 8)),
      ],
    ),
  );
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric(this.label, this.value);

  final String label;
  final String value;

  /// 필요한 변수는 히어로 하단 지표 이름과 값이다.
  /// 동일한 3열 셀에 작은 이름과 굵은 값을 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Colors.white12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({
    required this.items,
    required this.filter,
    required this.onFilter,
    required this.onAction,
  });

  final List<_ReviewItem> items;
  final String filter;
  final ValueChanged<String> onFilter;
  final void Function(String, _ReviewItem?) onAction;

  /// 필요한 변수는 복습 목록·선택 필터·행동 콜백이다.
  /// HTML 필터 막대와 우선순위 행을 하나의 흰 카드로 표시한다.
  @override
  Widget build(BuildContext context) {
    const filters = ['전체 8', '최근 오답 5', '반복 오답 3', '완료 2'];
    return StudentDensitySurface(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in filters)
                ChoiceChip(
                  label: Text(value),
                  selected: filter == value,
                  onSelected: (_) => onFilter(value),
                  selectedColor: StudentDensityTokens.dark,
                  labelStyle: TextStyle(
                    color: filter == value
                        ? Colors.white
                        : StudentDensityTokens.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide.none,
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () {}, child: const Text('최신순 ↕')),
          const Divider(height: 28),
          for (var index = 0; index < items.length; index++) ...[
            _ReviewRow(item: items[index], onAction: onAction),
            if (index != items.length - 1) const Divider(height: 28),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.item, required this.onAction});

  final _ReviewItem item;
  final void Function(String, _ReviewItem?) onAction;

  /// 필요한 변수는 복습 문제 메타와 행동 콜백이다.
  /// 모바일은 행동을 아래 2열, PC는 우측에 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 58,
          decoration: BoxDecoration(
            color: StudentDensityTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.number,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                item.done ? '완료' : '복습',
                style: const TextStyle(
                  fontSize: 8,
                  color: StudentDensityTokens.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudentDensityEyebrow(item.source),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.attempts,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.reason,
                style: const TextStyle(
                  fontSize: 11,
                  color: StudentDensityTokens.muted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [for (final tag in item.tags) _Tag(tag)],
              ),
            ],
          ),
        ),
        if (!mobile) ...[
          const SizedBox(width: 10),
          _ReviewActions(item: item, onAction: onAction),
        ],
      ],
    );
    if (!mobile) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        const SizedBox(height: 14),
        _ReviewActions(item: item, onAction: onAction),
      ],
    );
  }
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({required this.item, required this.onAction});

  final _ReviewItem item;
  final void Function(String, _ReviewItem?) onAction;

  /// 필요한 변수는 복습 항목·완료 상태·행동 콜백이다.
  /// 해설과 재풀이를 동일 폭 흑백 버튼으로 표시한다.
  @override
  Widget build(BuildContext context) {
    final solution = OutlinedButton(
      onPressed: () => onAction('해설 보기', item),
      child: const Text('해설 보기'),
    );
    final retry = FilledButton(
      onPressed: () => onAction(item.done ? '한 번 더 풀기' : '다시 풀기', item),
      style: FilledButton.styleFrom(backgroundColor: StudentDensityTokens.dark),
      child: Text(item.done ? '한 번 더 풀기' : '다시 풀기'),
    );
    if (isStudentDensityMobile(context)) {
      return Row(
        children: [
          Expanded(child: solution),
          const SizedBox(width: 6),
          Expanded(child: retry),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [solution, const SizedBox(width: 6), retry],
    );
  }
}

class _WeakPoints extends StatelessWidget {
  const _WeakPoints();

  /// 필요한 변수는 세 약점 이름과 비율이다.
  /// 데스크톱 우측 카드와 모바일 하단 카드에 진행 막대를 표시한다.
  @override
  Widget build(BuildContext context) => StudentDensitySurface(
    radius: 28,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        StudentDensityEyebrow('WEAK POINTS'),
        SizedBox(height: 12),
        Text(
          '먼저 볼 개념',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        Divider(height: 28),
        _WeakSkill('기울기와 변화량', 42),
        _WeakSkill('식 정리', 31),
        _WeakSkill('좌표 해석', 27),
      ],
    ),
  );
}

class _WeakSkill extends StatelessWidget {
  const _WeakSkill(this.label, this.percent);

  final String label;
  final int percent;

  /// 필요한 변수는 약점 이름과 비율이다.
  /// 이름·퍼센트·검은 진행 막대를 세로로 표시한다.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: percent / 100,
          minHeight: 6,
          color: StudentDensityTokens.dark,
          backgroundColor: StudentDensityTokens.line,
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  /// 필요한 변수는 복습 태그 문구다.
  /// 문제 행의 연회색 소형 태그로 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: StudentDensityTokens.surfaceMuted,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 8, color: StudentDensityTokens.muted),
    ),
  );
}

class _ReviewItem {
  const _ReviewItem({
    required this.number,
    required this.title,
    required this.source,
    required this.reason,
    required this.tags,
    required this.attempts,
    this.done = false,
  });

  final String number;
  final String title;
  final String source;
  final String reason;
  final List<String> tags;
  final String attempts;
  final bool done;
}
