import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';

Future<T?> showDailyTestModal<T>({
  required BuildContext context,
  String? courseId,
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
            Center(child: DailyTestModal(courseId: courseId)),
          ],
        ),
      );
    },
  );
}

class DailyTestModal extends StatefulWidget {
  const DailyTestModal({super.key, this.courseId});

  final String? courseId;

  @override
  State<DailyTestModal> createState() => _DailyTestModalState();
}

class _DailyTestModalState extends State<DailyTestModal> {
  DailyQuestBundle? _bundle;
  String? _error;
  bool _loading = true;
  String? _claimingQuestId;
  int? _rewardBurstPoints;

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    final items = bundle?.items ?? const <DailyQuestItem>[];
    final completed = items.where((item) => item.status == 'completed').length;
    final total = items.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final percentLabel = '${(progress * 100).round()}%';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SizedBox(
        width: 1040,
        height: 560,
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
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, size: 28),
                ),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(bottom: 4),
                  child: Text('일일 퀘스트', style: TextStyle(fontSize: 24)),
                ),
              ),
            ],
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!)))
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 0, 34, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '완료율 $percentLabel',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xCCE6E6E6),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF45BF63),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('오늘의 퀘스트가 없습니다.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 28),
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

  @override
  Widget build(BuildContext context) {
    final progressText =
        '${item.progress.clamp(0, item.target)}/${item.target}';
    final statusLabel = _completed
        ? item.rewardClaimed
              ? '수령 완료'
              : '완료'
        : '진행 중';
    final statusColor = _completed
        ? const Color(0xFF2E9853)
        : const Color(0xFF9A9A9A);

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            _completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 10),
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
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.difficultyLabel} · $progressText · $statusLabel',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
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
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFF5DA676),
                  size: 18,
                ),
                Text(
                  '${item.rewardPoints}',
                  style: const TextStyle(
                    color: Color(0xFF5DA676),
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
                    color: _claimable ? Colors.black : Colors.black38,
                  ),
            onPressed: _claimable && !claiming ? onClaim : null,
          ),
        ],
      ),
    );
  }
}
