import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/ios26/ios26_modal.dart';
import 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

enum OwnedMarketplaceModalResult { itemOpened }

/// 필요한 변수는 현재 학습 모달의 자료 유형이다.
/// 작동 원리는 문제세트·시험지별 보유 자료만 조회하고, 실제 학습 시작 여부를
/// 호출자에게 반환해 뒤로가기일 때만 이전 학습 모달을 복원하게 하는 것이다.
Future<OwnedMarketplaceModalResult?> showOwnedMarketplaceModal({
  required BuildContext context,
  required String kind,
}) {
  return showIos26Modal<OwnedMarketplaceModalResult>(
    context: context,
    maxWidth: 720,
    maxHeight: 640,
    mobileFullScreen: true,
    child: _OwnedMarketplaceModal(kind: kind),
  );
}

class _OwnedMarketplaceModal extends StatefulWidget {
  const _OwnedMarketplaceModal({required this.kind});

  final String kind;

  @override
  State<_OwnedMarketplaceModal> createState() => _OwnedMarketplaceModalState();
}

class _OwnedMarketplaceModalState extends State<_OwnedMarketplaceModal> {
  late Future<List<Map<String, dynamic>>> _items;

  @override
  void initState() {
    super.initState();
    _items = ApiClient.instance.listOwnedMarketplaceItems();
  }

  /// 필요한 변수는 API 보유 목록과 선택 유형이다.
  /// 작동 원리는 서버 정렬을 유지하면서 현재 모달 유형만 좁히고 완료 자료를 마지막에 남기는 것이다.
  List<Map<String, dynamic>> _filteredItems(List<Map<String, dynamic>> items) {
    final filtered = items
        .where((item) => item['kind']?.toString() == widget.kind)
        .toList(growable: false);
    filtered.sort((a, b) {
      final aCompleted = a['status']?.toString() == 'completed';
      final bCompleted = b['status']?.toString() == 'completed';
      return (aCompleted ? 1 : 0).compareTo(bCompleted ? 1 : 0);
    });
    return filtered;
  }

  /// 필요한 변수는 선택한 보유 자료의 메타데이터다.
  /// 작동 원리는 유형에 맞는 풀이 화면으로 이동하고 문제세트는 완료 콜백으로 이수 상태를 저장하는 것이다.
  Future<void> _openItem(Map<String, dynamic> item) async {
    final listingId =
        item['listing_id']?.toString() ?? item['id']?.toString() ?? '';
    final navigator = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop(OwnedMarketplaceModalResult.itemOpened);
    if (widget.kind == 'exam') {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ExamPaperPage(
            examId: item['asset_id']?.toString().isNotEmpty == true
                ? item['asset_id'].toString()
                : listingId,
            expectedQuestionCount: int.tryParse(
              item['item_count']?.toString() ?? '',
            ),
            marketplaceListingId: listingId,
          ),
        ),
      );
      return;
    }
    final rawIds = item['problem_ids'];
    final ids = rawIds is List
        ? rawIds.map((id) => id.toString()).where((id) => id.isNotEmpty)
        : const Iterable<String>.empty();
    final quests = <Map<String, dynamic>>[];
    for (final id in ids) {
      try {
        final result = await ApiClient.instance.searchQuests(
          questId: id,
          pageSize: 1,
        );
        if (result.isNotEmpty) quests.add(result.first);
      } catch (_) {
        // 한 문제 조회 실패가 전체 보유 자료의 선택을 막지 않게 한다.
      }
    }
    if (quests.isEmpty) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => BuildpageWidget(
          config: ProblemSolveConfig(
            questionCount: quests.length,
            quests: quests,
            ratingEnabled: false,
            onComplete:
                ({
                  required correctCount,
                  required totalCount,
                  required passed,
                  elapsedSeconds,
                }) async {
                  await ApiClient.instance.updateMarketplaceProgress(
                    listingId: listingId,
                    progressIndex: totalCount,
                    completed: passed,
                  );
                },
            onProblemGraded:
                ({
                  required itemIndex,
                  required quest,
                  required isCorrect,
                  required stepCorrectness,
                  selectedIndex,
                  elapsedSeconds,
                }) async {
                  await ApiClient.instance.updateMarketplaceProgress(
                    listingId: listingId,
                    progressIndex: itemIndex + 1,
                    completed: false,
                  );
                },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.kind == 'exam' ? '시험지' : '문제세트';
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FA),
      appBar: AppBar(
        title: Text('$label 학습하기'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: '학습하기로 돌아가기',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('보유 자료를 불러오지 못했습니다.'));
          }
          final items = _filteredItems(snapshot.data ?? const []);
          if (items.isEmpty) {
            return Center(
              child: Text(
                '보유한 $label가 없습니다.\n마켓에서 먼저 담아주세요.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final completed = item['status']?.toString() == 'completed';
              return ListTile(
                onTap: completed ? null : () => _openItem(item),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE0E0E2)),
                ),
                leading: Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : Icons.play_circle_fill_rounded,
                  color: completed ? const Color(0xFF23824A) : Colors.black,
                ),
                title: Text(
                  item['title']?.toString() ?? '학습 자료',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  completed
                      ? '이수 완료'
                      : '이어풀기 · ${item['progress_index'] ?? 0}번까지 진행',
                  style: TextStyle(
                    color: completed ? const Color(0xFF23824A) : Colors.black54,
                    fontWeight: completed ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                trailing: completed
                    ? const Text(
                        '이수 완료',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      )
                    : const Icon(Icons.chevron_right_rounded),
              );
            },
          );
        },
      ),
    );
  }
}
