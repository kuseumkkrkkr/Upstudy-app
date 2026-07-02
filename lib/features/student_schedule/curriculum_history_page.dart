import 'package:flutter/material.dart';
import 'package:s11/shared/theme/app_colors.dart';

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
        return AppColors.primaryLight;
      case '실패':
        return AppColors.error;
      case '재분배':
        return Colors.orange;
      default:
        return Colors.grey;
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '커리큘럼 이력',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chip bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = filter == _selectedFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.grey.shade200,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final oldStatus = item['oldStatus']!;
                final newStatus = item['newStatus']!;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      item['title']!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Text(
                            item['date']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              oldStatus,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Colors.black45,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(newStatus)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              newStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(newStatus),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
