import 'package:flutter/material.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/theme/app_colors.dart';
import 'package:s11/shared/ui/modal/modal_shell.dart';

/// 계정 레벨의 진행 상태와 보상 규칙을 표시하는 공통 모달입니다.
class LevelDetailModal extends StatelessWidget {
  const LevelDetailModal({super.key, required this.account});

  /// 서버에서 계산한 현재 경험치, 레벨 기준 점수, 보유 코인 정보입니다.
  final AccountSummary account;

  static const int maxLevel = 256;

  /// [account]의 레벨 정보를 모달로 표시합니다.
  /// 서버가 제공한 누적 경험치 기준을 사용해 클라이언트와 서버의 수치를 일치시킵니다.
  static Future<void> show(BuildContext context, AccountSummary account) {
    return ModalShell.show<void>(
      context,
      child: LevelDetailModal(account: account),
    );
  }

  /// 다음 레벨까지 남은 경험치를 계산합니다.
  /// 최대 레벨에서는 더 이상 필요한 경험치가 없으므로 0을 반환합니다.
  int get _remainingExperience {
    if (_level >= maxLevel) return 0;
    return (account.nextLevelScore - account.activityScore).clamp(0, 1 << 31);
  }

  /// 서버 값이 비정상적으로 커도 화면에서는 최대 레벨 256을 유지합니다.
  int get _level => account.level.clamp(1, maxLevel);

  /// 현재 레벨 구간에서 획득한 경험치를 계산합니다.
  int get _earnedExperience =>
      (account.activityScore - account.currentLevelScore).clamp(0, 1 << 31);

  /// 5레벨 단위 보상액을 계산합니다.
  /// [milestoneLevel]은 5의 배수이며, 보상은 5레벨마다 10코인씩 점진적으로 증가합니다.
  static int coinsForMilestone(int milestoneLevel) {
    final group = (milestoneLevel ~/ 5).clamp(1, maxLevel ~/ 5);
    return group * 10;
  }

  @override
  Widget build(BuildContext context) {
    final isMaxLevel = _level >= maxLevel;
    final nextMilestone = ((_level ~/ 5) + 1) * 5;
    final milestoneText = nextMilestone <= maxLevel
        ? '레벨 $nextMilestone 달성 시 ${coinsForMilestone(nextMilestone)}코인'
        : '모든 레벨 보상을 달성했어요';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '레벨 상세',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '닫기',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Lv. $_level${isMaxLevel ? ' · 최대 레벨' : ''}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: isMaxLevel ? 1 : account.levelProgress,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFEAF0E7),
                  valueColor: const AlwaysStoppedAnimation(AppColors.success),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isMaxLevel
                    ? '최대 레벨에 도달했어요.'
                    : '다음 레벨까지 $_remainingExperience 경험치 남음',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (!isMaxLevel) ...[
                const SizedBox(height: 4),
                Text(
                  '현재 구간: $_earnedExperience / ${account.nextLevelScore - account.currentLevelScore} 경험치',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7DE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: Color(0xFFD59B19),
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        milestoneText,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '레벨은 최대 256까지이며, 레벨이 오를수록 다음 레벨에 필요한 경험치가 늘어납니다. 5의 배수 레벨마다 코인을 받고, 보상 코인도 5레벨 단위로 10코인씩 증가합니다.',
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
