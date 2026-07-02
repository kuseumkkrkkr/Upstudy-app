import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/shared/data/models/course_module_config.dart';

/// CurriculumGroupWidget — standalone group launcher UI for curriculum sub-missions.
///
/// Displays a list of curriculum items (sub-missions) that the student can tap
/// to launch individually. Each item maps to a mission type handled by the
/// course learning page's mission tap handler.
class CurriculumGroupWidget extends StatefulWidget {
  const CurriculumGroupWidget({super.key, required this.config, this.onComplete});

  final CurriculumGroupConfig config;
  final void Function({required int correctCount, required int totalCount, required bool passed, int? elapsedSeconds})? onComplete;

  @override
  State<CurriculumGroupWidget> createState() => _CurriculumGroupWidgetState();
}

class _CurriculumGroupWidgetState extends State<CurriculumGroupWidget> {
  final Set<int> _completedItems = <int>{};

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final items = config.items;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B402B),
        foregroundColor: Colors.white,
        title: Text(
          config.title.isNotEmpty ? config.title : '커리큘럼 그룹',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: items.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isCompleted = _completedItems.contains(index);
                return _buildItemCard(
                  context,
                  index: index,
                  item: item,
                  isCompleted: isCompleted,
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            '등록된 학습 항목이 없습니다',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context, {
    required int index,
    required CurriculumItemConfig item,
    required bool isCompleted,
  }) {
    final icon = _iconForMissionType(item.missionType);
    final label = _labelForMissionType(item.missionType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            color: Color(0x1A000000),
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1B402B).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isCompleted ? const Color(0xFF45BF63) : const Color(0xFF1B402B),
          ),
        ),
        title: Text(
          item.title.isNotEmpty ? item.title : '학습 항목 ${index + 1}',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B402B),
          ),
        ),
        subtitle: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
        trailing: isCompleted
            ? const Icon(Icons.check_circle, color: Color(0xFF45BF63))
            : const Icon(Icons.chevron_right, color: Colors.black38),
        onTap: isCompleted
            ? null
            : () {
                // Mark as completed for UI feedback
                setState(() => _completedItems.add(index));
                // Notify parent via onComplete callback
                widget.onComplete?.call(
                  correctCount: _completedItems.length,
                  totalCount: widget.config.items.length,
                  passed: _completedItems.length >= widget.config.items.length,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item.title} 학습을 시작합니다'),
                  ),
                );
              },
      ),
    );
  }

  IconData _iconForMissionType(String type) {
    switch (type) {
      case 'textbook_view':
        return Icons.menu_book;
      case 'problem_solve':
        return Icons.edit_note;
      case 'exam_solve':
        return Icons.assignment;
      case 'wrong_answer_review':
        return Icons.replay;
      case 'challenge_group':
        return Icons.emoji_events;
      case 'level_test':
        return Icons.trending_up;
      default:
        return Icons.school;
    }
  }

  String _labelForMissionType(String type) {
    switch (type) {
      case 'textbook_view':
        return '교재 열람';
      case 'problem_solve':
        return '문제 풀이';
      case 'exam_solve':
        return '시험 풀이';
      case 'wrong_answer_review':
        return '오답 복습';
      case 'challenge_group':
        return '도전 학습';
      case 'level_test':
        return '레벨 테스트';
      default:
        return '학습';
    }
  }
}
