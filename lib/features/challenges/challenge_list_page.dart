import 'package:flutter/material.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/theme/app_colors.dart';

class ChallengeListPage extends StatefulWidget {
  const ChallengeListPage({super.key});

  static const routeName = '/challenges';

  @override
  State<ChallengeListPage> createState() => _ChallengeListPageState();
}

class _ChallengeListPageState extends State<ChallengeListPage> {
  bool _loading = true;
  String? _error;
  String? _courseId;
  List<DailyQuestItem> _dailyItems = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final courses = await CourseService.fetchMyCourses();
      final firstId = courses.isNotEmpty ? courses.first.id : null;
      if (firstId == null || firstId.trim().isEmpty) {
        setState(() {
          _loading = false;
          _error = '등록된 코스가 없어 일일 퀘스트를 불러올 수 없습니다.';
        });
        return;
      }
      final daily = await ApiClient.instance.fetchDailyQuests(
        courseId: firstId,
      );
      setState(() {
        _courseId = firstId;
        _dailyItems = daily;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '일일 퀘스트를 불러오지 못했습니다: $e';
      });
    }
  }

  Future<void> _completeQuest(String questId) async {
    final courseId = _courseId;
    if (courseId == null || courseId.isEmpty) return;
    try {
      final updated = await ApiClient.instance.completeDailyQuest(
        courseId: courseId,
        questId: questId,
      );
      if (!mounted) return;
      setState(() => _dailyItems = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('완료 처리 실패: $e')));
    }
  }

  Color _statusColor(String status) {
    return status == 'completed' ? Colors.green : Colors.orange;
  }

  String _statusLabel(String status) {
    return status == 'completed' ? '완료' : '진행 중';
  }

  Widget _buildDailyList() {
    if (_dailyItems.isEmpty) {
      return const Center(child: Text('오늘의 일일 퀘스트가 없습니다.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _dailyItems.length,
        itemBuilder: (context, index) {
          final item = _dailyItems[index];
          final done = item.status == 'completed';
          final claimable = item.claimable || (done && !item.rewardClaimed);
          final progressText = '${item.progress}/${item.target}';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '일일',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.difficultyLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(
                            item.status,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusLabel(item.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(item.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (item.description.isNotEmpty) ...[
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    '타입: ${item.questType}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '진행도: $progressText',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '보상: ${item.rewardPoints}P',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FilledButton.tonal(
                          onPressed: claimable
                              ? () => _completeQuest(item.id)
                              : null,
                          child: Text(
                            item.rewardClaimed
                                ? '수령 완료'
                                : done
                                ? '보상 수령'
                                : '진행 중',
                          ),
                        ),
                        if (claimable)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '일일 퀘스트',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _buildDailyList(),
    );
  }
}
