import 'package:flutter/material.dart';

import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

/// 커리큘럼 수행 이력 페이지.
///
/// 날짜, 미션 제목, 상태 변경(old → new)을 목록으로 보여주며,
/// 상단 필터 칩으로 전체/성공/실패/재분배를 필터링할 수 있다.
class CurriculumHistoryPage extends StatefulWidget {
  const CurriculumHistoryPage({super.key});

  static const routeName = '/schedule/history';

  @override
  State<CurriculumHistoryPage> createState() => _CurriculumHistoryPageState();
}

class _CurriculumHistoryPageState extends State<CurriculumHistoryPage> {
  String _selectedFilter = '전체';

  final List<String> _filters = const ['전체', '성공', '실패', '재분배'];

  final List<Map<String, String>> _historyItems = const [
    {
      'date': '2026-05-19',
      'title': '수학 미분법 개념 정리',
      'oldStatus': '진행 중',
      'newStatus': '성공',
    },
    {
      'date': '2026-05-18',
      'title': '영어 독해 연습 (3지문)',
      'oldStatus': '진행 중',
      'newStatus': '실패',
    },
    {
      'date': '2026-05-17',
      'title': '과학 실험 보고서 작성',
      'oldStatus': '대기',
      'newStatus': '재분배',
    },
    {
      'date': '2026-05-16',
      'title': '국어 문법 요약 정리',
      'oldStatus': '진행 중',
      'newStatus': '성공',
    },
    {
      'date': '2026-05-15',
      'title': '사회 지도 분석 학습',
      'oldStatus': '대기',
      'newStatus': '성공',
    },
    {
      'date': '2026-05-14',
      'title': '수학 적분의 활용',
      'oldStatus': '진행 중',
      'newStatus': '재분배',
    },
    {
      'date': '2026-05-13',
      'title': '영어 어휘 암기 50개',
      'oldStatus': '대기',
      'newStatus': '실패',
    },
  ];

  Color _statusColor(String status) {
    switch (status) {
      case '성공':
        return const Color(0xFF1E8E5A);
      case '실패':
        return const Color(0xFFC24141);
      case '재분배':
        return const Color(0xFFB46B12);
      default:
        return StudentDensityTokens.muted;
    }
  }

  List<Map<String, String>> get _filteredItems {
    if (_selectedFilter == '전체') return _historyItems;
    return _historyItems
        .where((item) => item['newStatus'] == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: StudentDensityTokens.dark,
                showLevelIndicator: false,
                showUtilityActions: true,
                onMenu: () => toggleAppDrawer(context),
                onTitleTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/student/dashboard',
                  (route) => false,
                ),
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
                      const StudentDensityPageHeader(
                        eyebrow: 'LEARNING HISTORY',
                        title: '커리큘럼 이력',
                        description: '완료, 실패, 재분배된 학습 항목을 날짜순으로 확인하세요.',
                        showMobileDescription: true,
                      ),
                      SizedBox(height: mobile ? 20 : 28),
                      StudentDensitySurface(
                        padding: EdgeInsets.all(mobile ? 14 : 18),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _filters
                              .map((filter) {
                                final isSelected = filter == _selectedFilter;
                                return ChoiceChip(
                                  key: ValueKey(
                                    'curriculum-history-filter-$filter',
                                  ),
                                  label: Text(filter),
                                  selected: isSelected,
                                  selectedColor: StudentDensityTokens.dark,
                                  backgroundColor:
                                      StudentDensityTokens.surfaceMuted,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : StudentDensityTokens.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                  side: BorderSide(
                                    color: isSelected
                                        ? StudentDensityTokens.dark
                                        : StudentDensityTokens.line,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _selectedFilter = filter),
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                      SizedBox(height: mobile ? 14 : 20),
                      for (final item in _filteredItems) ...[
                        _CurriculumHistoryCard(
                          item: item,
                          statusColor: _statusColor(item['newStatus']!),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 32),
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

class _CurriculumHistoryCard extends StatelessWidget {
  const _CurriculumHistoryCard({required this.item, required this.statusColor});

  final Map<String, String> item;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final oldStatus = item['oldStatus']!;
    final newStatus = item['newStatus']!;
    return StudentDensitySurface(
      padding: EdgeInsets.all(mobile ? 17 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.history_rounded, color: statusColor, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']!,
                  style: const TextStyle(
                    color: StudentDensityTokens.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Text(
                      item['date']!,
                      style: const TextStyle(
                        color: StudentDensityTokens.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _HistoryStatusPill(label: oldStatus),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: StudentDensityTokens.muted,
                    ),
                    _HistoryStatusPill(label: newStatus, color: statusColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryStatusPill extends StatelessWidget {
  const _HistoryStatusPill({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? StudentDensityTokens.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: color == null ? .10 : .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
