import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';

/// 필요한 변수는 화면 context·활성 코스 ID·선택적 감사용 초기 데이터다.
/// 작동 원리는 실제 퀘스트 API 상태를 HTML 세로 액션 패널 안에 열고 배경을 블러 처리하는 것이다.
Future<T?> showDailyTestModal<T>({
  required BuildContext context,
  String? courseId,
  DailyQuestBundle? initialBundle,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
            Center(
              child: DailyTestModal(
                courseId: courseId,
                initialBundle: initialBundle,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class DailyTestModal extends StatefulWidget {
  const DailyTestModal({super.key, this.courseId, this.initialBundle});

  final String? courseId;
  final DailyQuestBundle? initialBundle;

  @override
  State<DailyTestModal> createState() => _DailyTestModalState();
}

class _DailyTestModalState extends State<DailyTestModal> {
  DailyQuestBundle? _bundle;
  String? _error;
  bool _loading = true;
  String? _claimingQuestId;
  int? _rewardBurstPoints;

  /// 필요한 변수는 선택적 초기 번들과 코스 ID다.
  /// 작동 원리는 초기 데이터가 있으면 즉시 표시하고 없으면 활성 코스의 일일 퀘스트를 한 번 조회하는 것이다.
  @override
  void initState() {
    super.initState();
    final initialBundle = widget.initialBundle;
    if (initialBundle != null) {
      _bundle = initialBundle;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final courseId = widget.courseId?.trim();
    if (courseId == null || courseId.isEmpty) {
      setState(() {
        _loading = false;
        _error = '활성 코스가 없습니다.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await ApiClient.instance.fetchDailyQuestBundle(
        courseId: courseId,
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '일일 퀘스트를 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _claim(DailyQuestItem item) async {
    final courseId = widget.courseId?.trim();
    if (courseId == null || courseId.isEmpty) return;
    setState(() => _claimingQuestId = item.id);
    try {
      final bundle = await ApiClient.instance.completeDailyQuestBundle(
        courseId: courseId,
        questId: item.id,
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _claimingQuestId = null;
        _rewardBurstPoints = bundle.account.grantedPoints > 0
            ? bundle.account.grantedPoints
            : null;
      });
      if (bundle.account.grantedPoints > 0) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _rewardBurstPoints = null);
        });
      }
      final granted = bundle.account.grantedPoints;
      final message = granted > 0
          ? '$granted P 획득'
          : bundle.account.dailyCapReached
          ? '오늘 획득 한도에 도달했습니다.'
          : '서버 검증이 필요한 퀘스트입니다.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _claimingQuestId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('보상 수령 실패')));
    }
  }

  /// 필요한 변수는 퀘스트 목록·완료율·현재 화면 크기다.
  /// 작동 원리는 최대 720px 세로 패널 안에 보상 상태와 목록을 반응형으로 표시하는 것이다.
  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    final items = bundle?.items ?? const <DailyQuestItem>[];
    final completed = items.where((item) => item.status == 'completed').length;
    final total = items.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final percentLabel = '${(progress * 100).round()}%';

    final size = MediaQuery.sizeOf(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SizedBox(
        width: size.width > 760 ? 720 : size.width * .94,
        height: size.height * .9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: _buildPanel(items, percentLabel, progress)),
            if (_rewardBurstPoints != null)
              _RewardBurst(points: _rewardBurstPoints!),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 일일 퀘스트 목록·완료율 문구·진행값이다.
  /// 작동 원리는 HTML 헤더와 설명, 검정 진행 막대, 실제 보상 행을 위에서 아래로 구성하는 것이다.
  Widget _buildPanel(
    List<DailyQuestItem> items,
    String percentLabel,
    double progress,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 18, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAILY QUEST',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '일일 테스트',
                        style: TextStyle(
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!)))
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '현재 코스에서 오늘 풀 수 있는 테스트입니다.',
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '완료율 $percentLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE6E6E8),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('오늘의 퀘스트가 없습니다.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _DailyQuestRow(
                          item: items[index],
                          claiming: _claimingQuestId == items[index].id,
                          onClaim: () => _claim(items[index]),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardBurst extends StatelessWidget {
  const _RewardBurst({required this.points});

  final int points;

  /// 필요한 변수는 지급된 포인트와 애니메이션 진행값이다.
  /// 작동 원리는 보상 수령 직후 포인트 문구를 위로 이동시키며 서서히 숨기는 것이다.
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      builder: (context, value, child) {
        final dy = -28 * value;
        final opacity = value < 0.75 ? 1.0 : (1.0 - value) * 4;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1B402B),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          '+${points}P',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DailyQuestRow extends StatelessWidget {
  const _DailyQuestRow({
    required this.item,
    required this.claiming,
    required this.onClaim,
  });

  final DailyQuestItem item;
  final bool claiming;
  final VoidCallback onClaim;

  bool get _completed => item.status == 'completed';
  bool get _claimable => item.claimable || (_completed && !item.rewardClaimed);

  /// 필요한 변수는 퀘스트 상태·보상 수령 중 여부·수령 콜백이다.
  /// 작동 원리는 진행 중 항목만 검정으로 강조하고 완료·대기 항목은 흰색 행으로 구분하는 것이다.
  @override
  Widget build(BuildContext context) {
    final progressText =
        '${item.progress.clamp(0, item.target)}/${item.target}';
    final statusLabel = _completed
        ? item.rewardClaimed
              ? '수령 완료'
              : '완료'
        : '진행 중';
    final active = !_completed && item.progress > 0;

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? Colors.black : const Color(0xFFDCDCE0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.white : const Color(0xFFF4F4F6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDCDCE0)),
            ),
            child: Icon(
              _completed ? Icons.check_rounded : Icons.article_outlined,
              color: Colors.black,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ).copyWith(color: active ? Colors.white : Colors.black),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.difficultyLabel} · $progressText · $statusLabel',
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (_claimable) ...[
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                shape: BoxShape.circle,
              ),
            ),
          ],
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  color: active ? Colors.white70 : Colors.black45,
                  size: 18,
                ),
                Text(
                  '${item.rewardPoints}',
                  style: TextStyle(
                    color: active ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: _claimable ? '보상 수령' : statusLabel,
            icon: claiming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    item.rewardClaimed
                        ? Icons.verified_rounded
                        : Icons.redeem_rounded,
                    color: active
                        ? Colors.white
                        : _claimable
                        ? Colors.black
                        : Colors.black38,
                  ),
            onPressed: _claimable && !claiming ? onClaim : null,
          ),
        ],
      ),
    );
  }
}
