import 'package:flutter/material.dart';
import 'package:s11/shared/theme/app_colors.dart';

/// 오답 노트 목록 페이지.
///
/// 두 개의 탭(취약 태그, 습관 분석)을 제공하며,
/// 각 탭에서 mock 항목을 목록으로 보여준다.
class WrongAnswerListPage extends StatefulWidget {
  const WrongAnswerListPage({super.key});

  static const routeName = '/wrong_answers';

  @override
  State<WrongAnswerListPage> createState() => _WrongAnswerListPageState();
}

class _WrongAnswerListPageState extends State<WrongAnswerListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<Map<String, String>> _weaknessItems = const [
    {'title': '함수의 극한', 'tag': '#극한 #함수'},
    {'title': '미분법', 'tag': '#미분 #도함수'},
    {'title': '적분의 활용', 'tag': '#적분 #넓이'},
  ];

  final List<Map<String, String>> _habitItems = const [
    {'title': '부호 실수', 'tag': '#계산실수 #부호'},
    {'title': '약분 누락', 'tag': '#약분 #분수'},
    {'title': '공식 외우기', 'tag': '#공식 #암기'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRedirectDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('재풀이 안내'),
        content: const Text(
          '실제 재풀이는 WrongAnswerReviewWidget을 통해\nBuildpageWidget(문제해결기)로 연결됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, String>> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title']!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['tag']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed: _showRedirectDialog,
                  child: const Text('다시 풀기'),
                ),
              ],
            ),
          ),
        );
      },
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
          '오답 노트',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryLight,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '오답노트'),
            Tab(text: '습관 분석'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_weaknessItems),
          _buildList(_habitItems),
        ],
      ),
    );
  }
}
