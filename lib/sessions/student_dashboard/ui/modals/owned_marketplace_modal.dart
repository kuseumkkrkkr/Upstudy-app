import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/ios26/ios26_modal.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
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
  String? _openingListingId;

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
  /// 작동 원리는 문제세트 전체를 한 번에 받은 뒤 풀이 화면으로 이동하고,
  /// 대기 중에는 같은 자료를 다시 선택하지 못하게 해 중복 요청을 막는 것이다.
  Future<void> _openItem(Map<String, dynamic> item) async {
    final listingId =
        item['listing_id']?.toString() ?? item['id']?.toString() ?? '';
    if (listingId.isEmpty || _openingListingId != null) {
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    if (widget.kind == 'exam') {
      // 동일한 루트 Navigator로 모달을 닫고 풀이 화면을 push해야 웹에서도
      // 모달 아래의 학습 화면이 잘못 pop되지 않는다.
      navigator.pop(OwnedMarketplaceModalResult.itemOpened);
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
    setState(() => _openingListingId = listingId);
    try {
      final quests = await ApiClient.instance
          .loadMarketplaceProblemSetQuestions(listingId);
      if (!mounted) return;
      if (quests.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('문제를 준비하지 못했습니다. 잠시 후 다시 시도해주세요.')),
        );
        return;
      }
      setState(() => _openingListingId = null);
      navigator.pop(OwnedMarketplaceModalResult.itemOpened);
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문제를 불러오지 못했습니다. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted && _openingListingId == listingId) {
        setState(() => _openingListingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.kind == 'exam' ? '시험지' : '문제세트';
    final mobile = isStudentDensityMobile(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: mobile
          ? null
          : AppBar(
              title: Text('$label 학습하기'),
              automaticallyImplyLeading: false,
              leading: IconButton(
                tooltip: '학습하기로 돌아가기',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (mobile) _buildMobileHeader(label),
            Expanded(child: _buildItems(label, mobile: mobile)),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 현재 자료 유형과 모달 닫기 동작이다.
  /// 작동 원리: 모바일에서 일반 AppBar를 제거하고 레퍼런스처럼 큰 제목·설명·둥근 닫기 버튼을 독립 헤더로 제공한다.
  Widget _buildMobileHeader(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.kind == 'exam' ? 'MY EXAM PAPERS' : 'MY PROBLEM SETS',
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.7,
                  color: Colors.black54,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$label 학습',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '내 학습에 담은 $label를 선택해 바로 이어서 풀어요.',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          tooltip: '학습하기로 돌아가기',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  /// 필요한 변수는 보유 자료 Future·자료 유형·모바일 여부다.
  /// 작동 원리: 로딩·오류·빈 상태를 큰 둥근 카드로 보여 주고 자료가 있으면 64px 이상 터치 가능한 학습 카드 목록으로 만든다.
  Widget _buildItems(String label, {required bool mobile}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          if (!mobile) {
            return const Center(child: Text('보유 자료를 불러오지 못했습니다.'));
          }
          return _OwnedItemsStateCard(
            icon: Icons.cloud_off_rounded,
            title: '보유 자료를 불러오지 못했어요',
            description: '네트워크 연결을 확인한 뒤 다시 열어 주세요.',
            actionLabel: '다시 불러오기',
            onAction: () => setState(
              () => _items = ApiClient.instance.listOwnedMarketplaceItems(),
            ),
          );
        }
        final items = _filteredItems(snapshot.data ?? const []);
        if (items.isEmpty) {
          if (!mobile) {
            return Center(
              child: Text(
                '보유한 $label가 없습니다.\n마켓에서 먼저 담아주세요.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return _OwnedItemsStateCard(
            icon: widget.kind == 'exam'
                ? Icons.description_outlined
                : Icons.view_list_rounded,
            title: '보유한 $label가 없어요',
            description: '마켓에서 학습 자료를 먼저 담아 주세요.',
            actionLabel: '마켓 둘러보기',
            onAction: () {
              final navigator = Navigator.of(context, rootNavigator: true);
              Navigator.of(context).pop();
              navigator.pushNamed('/marketplace');
            },
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            mobile ? 20 : 20,
            mobile ? 4 : 8,
            mobile ? 20 : 20,
            28,
          ),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _buildItemCard(items[index], mobile: mobile),
        );
      },
    );
  }

  /// 필요한 변수는 단일 보유 자료 메타와 현재 화면 폭이다.
  /// 작동 원리: 모바일에서는 아이콘·제목·진행 상태를 큰 흰 카드에 세로 여백을 늘려 표시하고 기존 학습 시작 콜백을 그대로 연결한다.
  Widget _buildItemCard(Map<String, dynamic> item, {required bool mobile}) {
    final completed = item['status']?.toString() == 'completed';
    final itemId =
        item['listing_id']?.toString() ?? item['id']?.toString() ?? '';
    if (!mobile) {
      return ListTile(
        onTap: completed || _openingListingId != null
            ? null
            : () => _openItem(item),
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
          completed ? '이수 완료' : '이어풀기 · ${item['progress_index'] ?? 0}번까지 진행',
          style: TextStyle(
            color: completed ? const Color(0xFF23824A) : Colors.black54,
            fontWeight: completed ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        trailing: _openingListingId == itemId
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : completed
            ? const Text('이수 완료', style: TextStyle(fontWeight: FontWeight.w800))
            : const Icon(Icons.chevron_right_rounded),
      );
    }
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mobile ? 24 : 18),
        side: const BorderSide(color: Color(0xFFE0E0E2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: completed || _openingListingId != null
            ? null
            : () => _openItem(item),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 18 : 16,
            vertical: mobile ? 18 : 12,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: completed
                      ? const Color(0xFFEAF7EF)
                      : const Color(0xFF202022),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  completed ? Icons.check_rounded : Icons.play_arrow_rounded,
                  color: completed ? const Color(0xFF23824A) : Colors.white,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']?.toString() ?? '학습 자료',
                      style: TextStyle(
                        fontSize: mobile ? 17 : 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      completed
                          ? '이수 완료'
                          : '이어풀기 · ${item['progress_index'] ?? 0}번까지 진행',
                      style: TextStyle(
                        color: completed
                            ? const Color(0xFF23824A)
                            : Colors.black54,
                        fontWeight: completed
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_openingListingId == itemId)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnedItemsStateCard extends StatelessWidget {
  const _OwnedItemsStateCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  /// 필요한 변수는 빈·오류 상태 문구와 다음 행동이다.
  /// 작동 원리: 작은 중앙 문구 대신 모바일 앱형 카드에서 이유와 해결 행동을 한눈에 읽게 한다.
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE0E0E2)),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF202022),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.45),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF202022),
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    ),
  );
}
