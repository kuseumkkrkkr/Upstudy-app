import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arena_api.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

typedef ArenaJoinCallback =
    Future<Map<String, dynamic>> Function(String queueType);

/// 학생 대시보드에서 실시간 대결장을 연다.
Future<void> showArena(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const ArenaPage()));

/// 필요한 변수: 서버의 네 큐 요약.
/// 1v1/2v2 시험·OX 큐와 독립 티어를 한 화면에 표시한다.
class ArenaPage extends StatefulWidget {
  const ArenaPage({super.key, this.initialSummary, this.joinQueue});

  final Map<String, dynamic>? initialSummary;
  final ArenaJoinCallback? joinQueue;

  @override
  State<ArenaPage> createState() => _ArenaPageState();
}

class _ArenaPageState extends State<ArenaPage> {
  Map<String, dynamic>? _summary;
  String? _waitingQueue;
  String? _error;
  Timer? _matchPoller;

  @override
  void initState() {
    super.initState();
    ArenaApi.instance.resultRevision.addListener(_refreshAfterResult);
    _summary = widget.initialSummary;
    if (_summary == null) _load();
  }

  @override
  void dispose() {
    ArenaApi.instance.resultRevision.removeListener(_refreshAfterResult);
    _matchPoller?.cancel();
    super.dispose();
  }

  /// 필요한 변수 없음. 결과 화면이 캐시 무효화를 알리면 뒤쪽 대결장 카드의 레이팅·전적을 즉시 갱신한다.
  void _refreshAfterResult() {
    if (mounted) unawaited(_load());
  }

  /// 필요한 변수 없음. 레이팅 요약을 서버에서 다시 읽는다.
  Future<void> _load() async {
    try {
      final value = await ArenaApi.instance.summary();
      if (mounted) setState(() => _summary = value);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  /// 필요한 변수: 선택한 큐 ID.
  /// 작동 원리: 실제 매치가 없으면 서버가 발급한 연습 경기로 즉시 들어가고, 없을 때만 기존 폴링을 사용한다.
  Future<void> _join(String queueType) async {
    setState(() {
      _waitingQueue = queueType;
      _error = null;
    });
    try {
      final result =
          await (widget.joinQueue?.call(queueType) ??
              ArenaApi.instance.join(queueType));
      if (!mounted) return;
      final matchId = result['match_id']?.toString();
      final practiceMatchId = result['practice_match_id']?.toString();
      final entryMatchId = matchId?.isNotEmpty == true
          ? matchId
          : practiceMatchId;
      if (entryMatchId != null && entryMatchId.isNotEmpty) {
        await _openMatch(entryMatchId);
      } else {
        _scheduleMatchPoll(queueType);
      }
    } catch (error) {
      if (mounted) {
        _matchPoller?.cancel();
        setState(() {
          _waitingQueue = null;
          _error = error.toString();
        });
      }
    }
  }

  /// 필요한 변수: 참가한 큐 ID.
  /// 작동 원리: 이전 요청과 겹치지 않는 단발 타이머로 기존 서버 매칭 결과를 2초마다 확인한다.
  void _scheduleMatchPoll(String queueType) {
    _matchPoller?.cancel();
    _matchPoller = Timer(const Duration(seconds: 2), () async {
      if (!mounted || _waitingQueue != queueType) return;
      try {
        final summary = await ArenaApi.instance.summary(forceRefresh: true);
        final active = summary['active_match_id']?.toString();
        if (active != null && active.isNotEmpty && mounted) {
          await _openMatch(active);
          return;
        }
      } catch (error) {
        if (mounted) setState(() => _error = error.toString());
      }
      if (mounted && _waitingQueue == queueType) _scheduleMatchPoll(queueType);
    });
  }

  /// 필요한 변수 없음. 현재 매칭 대기를 서버와 화면에서 함께 취소한다.
  Future<void> _cancel() async {
    final queueType = _waitingQueue;
    _matchPoller?.cancel();
    try {
      await ArenaApi.instance.cancel();
      if (mounted) {
        setState(() {
          _waitingQueue = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
        if (queueType != null && _waitingQueue == queueType) {
          _scheduleMatchPoll(queueType);
        }
      }
    }
  }

  /// 필요한 변수는 선택한 모바일 큐의 유형·예상 대기 시간·문항 수다.
  /// 작동 원리는 실제 서버 매칭 전에 참조형 바텀시트로 조건을 다시 보여
  /// 실수로 대결에 참가하는 것을 막고 최종 버튼에서만 참가 요청을 보낸다.
  Future<void> _confirmMobileJoin(Map<String, dynamic> queue) async {
    final queueType = queue['queue_type']?.toString() ?? '';
    if (queueType.isEmpty) {
      return;
    }
    final waitSeconds = (queue['estimated_wait_seconds'] as num? ?? 0).round();
    final questionCount = (queue['question_count'] as num? ?? 10).round();
    final durationMinutes = (queue['duration_minutes'] as num? ?? 20).round();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('arena-mobile-confirm-sheet'),
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 36,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D6D8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '대결 시작',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '매칭을 시작하면 상대를 찾는 동안 이 화면을 유지합니다.',
                style: TextStyle(
                  color: Color(0xFF68686E),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF171719),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.sports_mma_rounded,
                        color: Colors.black,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1v1 문제풀이',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$questionCount문항 · $durationMinutes분'
                            '${waitSeconds > 0 ? ' · 약 $waitSeconds초 대기' : ''}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '실전 대결 결과는 티어와 레이팅에 반영될 수 있습니다.',
                  style: TextStyle(
                    color: Color(0xFF55555A),
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  key: const ValueKey('arena-mobile-confirm-join'),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF202022),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: const Text(
                    '매칭 시작',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      color: Color(0xFF67676C),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await _join(queueType);
    }
  }

  /// 필요한 변수: 성립된 경기 ID. 대기 상태를 정리하고 매치 성립 안내를 거쳐 경기 화면을 연다.
  Future<void> _openMatch(String matchId) async {
    _matchPoller?.cancel();
    if (!mounted) return;
    setState(() {
      _waitingQueue = null;
    });
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ArenaReadyPage(matchId: matchId)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1000;
    final mobile = width <= StudentDensityTokens.mobileBreakpoint;
    final queues = List<Map<String, dynamic>>.from(
      (_summary?['queues'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final profile = Map<String, dynamic>.from(
      _summary?['profile'] as Map? ??
          (queues.isEmpty ? const {} : queues.first),
    );
    final rating = (profile['rating'] as num? ?? 1500).round();
    final wins = (profile['wins'] as num? ?? 0).round();
    final losses = (profile['losses'] as num? ?? 0).round();
    final draws = (profile['draws'] as num? ?? 0).round();
    final tier = profile['tier']?.toString() ?? 'E';
    final recentResults = List<String>.from(
      profile['recent_results'] as List? ?? const [],
    );
    final resumableMatchId =
        (_summary?['active_match_id'] ?? _summary?['active_practice_match_id'])
            ?.toString();
    final total = math.max(1, wins + losses + draws);
    final winRate = wins / total * 100;
    // 시험 대결용 1v1·2v2 큐를 함께 보여 주어 선택 영역의 빈 공간을 없앤다.
    final visibleQueues = queues
        .where(
          (queue) =>
              queue['queue_type'] == 'duel_exam' ||
              queue['queue_type'] == 'team_exam',
        )
        .toList(growable: false);
    // 모바일은 현재 참가 가능한 모드만 첫 화면에 둔다.
    // 준비 중인 2v2 카드와 전적 정보가 실제 1v1 입장 버튼을 화면 아래로 밀지 않게 한다.
    final joinableQueues = visibleQueues
        .where((queue) => queue['coming_soon'] != true)
        .toList(growable: false);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      drawer: mobile ? null : const AppDrawer(),
      bottomNavigationBar: mobile
          ? const MobileStudentBottomAppBar(activeRoute: '/arena')
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: Colors.black,
                showLevelIndicator: false,
                showUtilityActions: !mobile,
                onMenu: mobile ? null : () => toggleAppDrawer(context),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    desktop ? 40 : 14,
                    24,
                    desktop ? 40 : 14,
                    40,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1380),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (desktop)
                              _ArenaHero(
                                tier: tier,
                                rating: rating,
                                wins: wins,
                                losses: losses,
                                draws: draws,
                                winRate: winRate,
                                desktop: true,
                                recentResults: recentResults,
                                onTierTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ArenaRankingPage(
                                      queueType:
                                          profile['queue_type']?.toString() ??
                                          'duel_exam',
                                    ),
                                  ),
                                ),
                              )
                            else
                              const _ArenaMobileHeader(),
                            if (resumableMatchId != null &&
                                resumableMatchId.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: _ResumeMatchBanner(
                                  onResume: () => _openMatch(resumableMatchId),
                                ),
                              ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            SizedBox(height: desktop ? 56 : 28),
                            if (desktop) ...[
                              const _ArenaMatchHeader(),
                              const SizedBox(height: 20),
                            ],
                            if (_summary == null)
                              const Center(child: CircularProgressIndicator())
                            else if (desktop)
                              GridView.count(
                                key: const ValueKey('arena-desktop-queue-grid'),
                                crossAxisCount: 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 1.7,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  for (
                                    var index = 0;
                                    index < visibleQueues.length;
                                    index++
                                  )
                                    _QueueCard(
                                      data: visibleQueues[index],
                                      desktop: true,
                                      // 1v1은 어둡게 강조하고 2v2는 밝게 반전한다.
                                      featured:
                                          visibleQueues[index]['queue_type'] ==
                                          'duel_exam',
                                      waiting:
                                          _waitingQueue ==
                                          visibleQueues[index]['queue_type'],
                                      disabled:
                                          visibleQueues[index]['coming_soon'] ==
                                              true ||
                                          (_waitingQueue != null &&
                                              _waitingQueue !=
                                                  visibleQueues[index]['queue_type']),
                                      onJoin: () => _join(
                                        visibleQueues[index]['queue_type']
                                            .toString(),
                                      ),
                                      onCancel: _cancel,
                                    ),
                                ],
                              )
                            else
                              Column(
                                key: const ValueKey('arena-mobile-queue-list'),
                                children: [
                                  for (final queue in joinableQueues)
                                    _ArenaMobileEntryCard(
                                      data: queue,
                                      waiting:
                                          _waitingQueue == queue['queue_type'],
                                      disabled:
                                          _waitingQueue != null &&
                                          _waitingQueue != queue['queue_type'],
                                      onJoin: () => _confirmMobileJoin(queue),
                                      onCancel: _cancel,
                                    ),
                                  if (joinableQueues.isEmpty)
                                    const _ArenaUnavailableCard(),
                                ],
                              ),
                            const SizedBox(height: 20),
                            _ArenaRules(desktop: desktop),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 필요한 변수 없음.
/// 작동 원리: 세로 화면에서는 전적·티어 같은 보조 정보를 생략하고,
/// 사용자가 대결을 시작할 수 있는 목적을 첫 화면에서 명확히 전달한다.
class _ArenaMobileHeader extends StatelessWidget {
  const _ArenaMobileHeader();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'REAL-TIME MATCH',
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.6,
          color: Colors.black54,
          fontWeight: FontWeight.w900,
        ),
      ),
      SizedBox(height: 10),
      Text(
        '대결장',
        style: TextStyle(
          fontSize: 34,
          letterSpacing: -1.8,
          fontWeight: FontWeight.w900,
        ),
      ),
      SizedBox(height: 6),
      Text(
        '같은 10문항으로 실력을 겨뤄보세요.',
        style: TextStyle(fontSize: 14, color: Colors.black54),
      ),
    ],
  );
}

/// 필요한 변수: 참가 가능한 큐, 대기 상태와 참가·취소 콜백.
/// 작동 원리: 모바일 세로폭에서 버튼을 카드 전체 폭으로 분리해
/// 작은 가로 Row의 눌림 영역·오버플로우 때문에 대결장에 들어가지 못하는 일을 막는다.
class _ArenaMobileEntryCard extends StatelessWidget {
  const _ArenaMobileEntryCard({
    required this.data,
    required this.waiting,
    required this.disabled,
    required this.onJoin,
    required this.onCancel,
  });

  final Map<String, dynamic> data;
  final bool waiting;
  final bool disabled;
  final VoidCallback onJoin;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final waitSeconds = (data['estimated_wait_seconds'] as num? ?? 0).round();
    return Container(
      key: const ValueKey('arena-mobile-entry-card'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF171719),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1V1 RANKED MATCH',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '1v1 문제풀이',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              letterSpacing: -1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '10문항 · 20분${waitSeconds > 0 ? ' · 약 $waitSeconds초 대기' : ''}',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              key: const ValueKey('arena-mobile-join-button'),
              onPressed: disabled ? null : (waiting ? onCancel : onJoin),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                waiting ? '매칭 취소' : '대결 시작',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 필요한 변수 없음.
/// 작동 원리: 서버가 활성 큐를 반환하지 못한 경우에도 빈 화면 대신 재시도 안내를 제공한다.
class _ArenaUnavailableCard extends StatelessWidget {
  const _ArenaUnavailableCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE1E1E3)),
    ),
    child: const Text(
      '지금은 참가 가능한 대결이 없습니다. 잠시 후 다시 확인해 주세요.',
      style: TextStyle(color: Colors.black54),
    ),
  );
}

class _ArenaHero extends StatelessWidget {
  const _ArenaHero({
    required this.tier,
    required this.rating,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
    required this.desktop,
    required this.recentResults,
    required this.onTierTap,
  });

  final String tier;
  final int rating;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;
  final bool desktop;
  final List<String> recentResults;
  final VoidCallback onTierTap;

  /// 필요한 변수는 티어·레이팅·승패무·승률이다.
  /// 작동 원리는 HTML의 랭크 소개와 검은 프로필 카드를 한 덩어리로 구성해 첫 화면 정보 밀도를 고정하는 것이다.
  @override
  Widget build(BuildContext context) {
    final nextTierRating = ((rating ~/ 300) + 1) * 300;
    final progress = (rating % 300) / 300;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'RANKED MATCH',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.6,
            color: Colors.black54,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: desktop ? 38 : 44),
        Text(
          '실력으로 증명하는\n20분.',
          style: TextStyle(
            fontSize: desktop ? 58 : 42,
            height: .98,
            letterSpacing: desktop ? -3.1 : -2.2,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: desktop ? 30 : 46),
        const Text(
          '시험 대결은 객관식 5문항과 숫자 단답형 5문항, OX 대결은 10문항으로 진행됩니다.',
          style: TextStyle(fontSize: 15, height: 1.8, color: Colors.black54),
        ),
        const SizedBox(height: 34),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$tier TIER까지', style: const TextStyle(fontSize: 11)),
            Text(
              '${math.max(0, nextTierRating - rating)}점',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 7,
          borderRadius: BorderRadius.circular(99),
          color: Colors.black,
          backgroundColor: const Color(0xFFE8E8EB),
        ),
        const SizedBox(height: 8),
        Text(
          '현재 $rating · 다음 티어 $nextTierRating',
          style: const TextStyle(fontSize: 10, color: Colors.black45),
        ),
      ],
    );
    final profile = _ArenaProfileCard(
      tier: tier,
      rating: rating,
      wins: wins,
      losses: losses,
      draws: draws,
      winRate: winRate,
      recentResults: recentResults,
      onTierTap: onTierTap,
    );
    return Container(
      key: ValueKey(
        desktop ? 'arena-desktop-overview' : 'arena-mobile-overview',
      ),
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: copy),
                const SizedBox(width: 30),
                SizedBox(width: 400, child: profile),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 34), profile],
            ),
    );
  }
}

/// 필요한 변수 없음.
/// 작동 원리: 1v1·2v2 큐가 동시에 배치됨을 안내해 두 카드의 관계를 명확히 한다.
class _ArenaMatchHeader extends StatelessWidget {
  const _ArenaMatchHeader();

  @override
  Widget build(BuildContext context) {
    final copy = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHOOSE YOUR MATCH',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.8,
            color: Colors.black54,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 12),
        Text(
          '대결 방식 선택',
          style: TextStyle(
            fontSize: 38,
            letterSpacing: -1.8,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '1v1과 2v2의 레이팅·전적은 각각 독립적으로 기록됩니다.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
    return copy;
  }
}

/// 필요한 변수: 데스크톱 여부.
/// 작동 원리: 공정성 규칙을 PC 4열·모바일 2열로 재배치해 큐 진입 전 동일 조건을 비교하게 한다.
class _ArenaRules extends StatelessWidget {
  const _ArenaRules({required this.desktop});
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    const rules = [
      ('01', '동일 문항', '모든 참가자가 같은 문제를 풉니다.'),
      ('02', '20분 제한', '서버 시간을 기준으로 동시에 종료됩니다.'),
      ('03', '재시도 제한', '남은 횟수가 모두에게 표시됩니다.'),
      ('04', '채팅 파쇄', '팀 채팅은 경기 종료 즉시 삭제됩니다.'),
    ];
    return Container(
      padding: EdgeInsets.all(desktop ? 34 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: desktop
          ? Row(
              children: [
                const Expanded(child: _ArenaRulesTitle()),
                const SizedBox(width: 28),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      for (final rule in rules)
                        Expanded(child: _ArenaRule(rule: rule)),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ArenaRulesTitle(),
                const SizedBox(height: 22),
                GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.25,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [for (final rule in rules) _ArenaRule(rule: rule)],
                ),
              ],
            ),
    );
  }
}

class _ArenaRulesTitle extends StatelessWidget {
  const _ArenaRulesTitle();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'FAIR PLAY PROTOCOL',
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 1.4,
          color: Colors.black54,
          fontWeight: FontWeight.w900,
        ),
      ),
      SizedBox(height: 10),
      Text(
        '모두에게 같은 조건',
        style: TextStyle(
          fontSize: 26,
          height: 1.05,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _ArenaRule extends StatelessWidget {
  const _ArenaRule({required this.rule});
  final (String, String, String) rule;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rule.$1,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.black45,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          rule.$2,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          rule.$3,
          style: const TextStyle(
            fontSize: 9,
            height: 1.4,
            color: Colors.black54,
          ),
        ),
      ],
    ),
  );
}

class _ArenaProfileCard extends StatelessWidget {
  const _ArenaProfileCard({
    required this.tier,
    required this.rating,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
    required this.recentResults,
    required this.onTierTap,
  });

  final String tier;
  final int rating;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;
  final List<String> recentResults;
  final VoidCallback onTierTap;

  /// 필요한 변수는 개인 아레나 전적이다.
  /// 작동 원리는 티어 배지·점수·네 통계·최근 전적을 HTML의 어두운 프로필 카드 안에 배치하는 것이다.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF171719), Color(0xFF3B3B40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'MY ARENA PROFILE',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 8,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Semantics(
                button: true,
                label: '대결장 랭킹 열기',
                child: InkWell(
                  onTap: onTierTap,
                  borderRadius: BorderRadius.circular(40),
                  child: TierBadge(tier: tier, size: 80),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatArenaRating(rating),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$tier TIER · 티어를 눌러 랭킹 보기',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          Row(
            children: [
              _ArenaStat(value: '$wins', label: '승'),
              _ArenaStat(value: '$losses', label: '패'),
              _ArenaStat(value: '$draws', label: '무'),
              _ArenaStat(value: '${winRate.toStringAsFixed(1)}%', label: '승률'),
            ],
          ),
          const Divider(color: Colors.white12),
          Row(
            children: [
              const Text(
                '최근 전적',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              const Spacer(),
              if (recentResults.isEmpty)
                const Text(
                  '아직 경기 전적이 없습니다.',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                )
              else
                for (final result in recentResults.reversed.take(5))
                  Container(
                    width: 25,
                    height: 25,
                    margin: const EdgeInsets.only(left: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: result == 'win' ? Colors.white : Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      result == 'win'
                          ? '승'
                          : result == 'loss'
                          ? '패'
                          : '무',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: result == 'win' ? Colors.black : Colors.white54,
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 필요한 변수는 정수 레이팅이다.
/// 작동 원리는 HTML 프로필의 천 단위 구분 형식으로 점수를 변환하는 것이다.
String _formatArenaRating(int rating) {
  if (rating.abs() < 1000) return '$rating';
  final prefix = rating ~/ 1000;
  final suffix = (rating.abs() % 1000).toString().padLeft(3, '0');
  return '$prefix,$suffix';
}

class _ArenaStat extends StatelessWidget {
  const _ArenaStat({required this.value, required this.label});
  final String value;
  final String label;

  /// 필요한 변수는 통계 값과 레이블이다.
  /// 작동 원리는 네 지표를 같은 너비로 나눠 카드의 비교 리듬을 유지하는 것이다.
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    ),
  );
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.data,
    required this.waiting,
    required this.disabled,
    required this.onJoin,
    required this.onCancel,
    this.desktop = false,
    this.featured = false,
  });
  final Map<String, dynamic> data;
  final bool waiting;
  final bool disabled;
  final VoidCallback onJoin;
  final VoidCallback onCancel;
  final bool desktop;
  final bool featured;

  String get _label =>
      const {
        'duel_exam': '1v1 문제풀이',
        'team_exam': '2v2 문제풀이',
      }[data['queue_type']] ??
      '대결';

  @override
  Widget build(BuildContext context) {
    final comingSoon = data['coming_soon'] == true;
    final tier = data['tier']?.toString() ?? 'C';
    final foreground = featured ? Colors.white : Colors.black;
    final muted = featured ? Colors.white54 : Colors.black54;
    if (desktop) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: featured ? const Color(0xFF171719) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: featured ? const Color(0xFF171719) : const Color(0xFFE1E1E3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: featured ? Colors.white : const Color(0xFFF4F4F6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TierBadge(tier: tier, size: 42),
                ),
                const Spacer(),
                Text(
                  comingSoon ? '● COMING SOON' : '● LIVE QUEUE',
                  style: TextStyle(
                    fontSize: 9,
                    color: muted,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              _label,
              style: TextStyle(
                fontSize: 28,
                letterSpacing: -1.2,
                color: foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _queueDescription,
              style: TextStyle(fontSize: 11, height: 1.5, color: muted),
            ),
            const Spacer(),
            Row(
              children: [
                _QueueStat(
                  label: '예상 대기',
                  value: '${data['estimated_wait_seconds'] ?? 0}초',
                  color: foreground,
                ),
                const SizedBox(width: 30),
                _QueueStat(
                  label: '내 전적',
                  value: '${data['wins'] ?? 0}승 ${data['losses'] ?? 0}패',
                  color: foreground,
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: disabled ? null : (waiting ? onCancel : onJoin),
                style: FilledButton.styleFrom(
                  backgroundColor: featured ? Colors.white : Colors.black,
                  foregroundColor: featured ? Colors.black : Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  comingSoon ? '준비 중' : (waiting ? '매칭 취소' : '매칭 시작  →'),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: featured ? const Color(0xFF171719) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: featured ? const Color(0xFF171719) : const Color(0xFFE1E1E3),
        ),
      ),
      child: Row(
        children: [
          TierBadge(tier: tier, size: 62),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$tier 티어 · ${(data['rating'] as num? ?? 1500).toStringAsFixed(0)}점',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                Text(
                  '${data['wins'] ?? 0}승 ${data['losses'] ?? 0}패 ${data['draws'] ?? 0}무 · 예상 ${data['estimated_wait_seconds'] ?? 0}초',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: featured ? Colors.white : Colors.black,
              foregroundColor: featured ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: disabled ? null : (waiting ? onCancel : onJoin),
            child: Text(comingSoon ? '준비 중' : (waiting ? '취소' : '매칭')),
          ),
        ],
      ),
    );
  }

  String get _queueDescription =>
      const {
        'duel_exam': '객관식 5 + 숫자 단답형 5 · 제한 시간 20분',
        'team_exam': '팀 합산 문제풀이 모드는 준비 중입니다.',
      }[data['queue_type']] ??
      '같은 조건에서 실력을 겨룹니다.';
}

class _QueueStat extends StatelessWidget {
  const _QueueStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 9, color: color.withValues(alpha: .5)),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

/// 필요한 변수: A~E 티어와 크기.
/// CustomPainter 벡터 도형으로 단계별 재질과 광원 효과를 그린다.
class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.tier, this.size = 64});
  final String tier;
  final double size;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(size),
      painter: _TierBadgePainter(tier),
    ),
  );
}

class _TierBadgePainter extends CustomPainter {
  const _TierBadgePainter(this.tier);
  final String tier;
  @override
  void paint(Canvas canvas, Size size) {
    final colors =
        <String, List<Color>>{
          'E': [const Color(0xff555d66), const Color(0xffaab1b8)],
          'D': [const Color(0xff77411f), const Color(0xffd6924f)],
          'C': [const Color(0xff8e9aa6), const Color(0xffdcecff)],
          'B': [const Color(0xffa86d00), const Color(0xffffdc65)],
          'A': [const Color(0xff571064), const Color(0xffffd65a)],
        }[tier] ??
        [Colors.grey, Colors.white];
    final center = size.center(Offset.zero);
    if (tier == 'A' || tier == 'B') {
      canvas.drawCircle(
        center,
        size.width * .46,
        Paint()
          ..color = colors.last.withValues(alpha: .18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    final path = Path()
      ..moveTo(size.width * .5, size.height * .06)
      ..lineTo(size.width * .88, size.height * .22)
      ..lineTo(size.width * .80, size.height * .70)
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .98,
        size.width * .20,
        size.height * .70,
      )
      ..lineTo(size.width * .12, size.height * .22)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: colors,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .055
        ..color = colors.last,
    );
    final text = TextPainter(
      text: TextSpan(
        text: tier,
        style: TextStyle(
          color: Colors.white,
          fontSize: size.width * .44,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(blurRadius: 5, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TierBadgePainter oldDelegate) =>
      oldDelegate.tier != tier;
}

/// 필요한 변수: 서버가 발급한 경기 ID.
/// 남은 시간, 동일 문항, 문자열 입력, 팀 점수와 2v2 채팅을 제공한다.
/// 필요한 변수: 재개하거나 새로 성립한 경기 ID.
/// 작동 원리: 경기 상태를 한 번 확인해 상대·규칙을 보여준 뒤 3초 후 풀이 화면으로 전환한다.
class ArenaReadyPage extends StatefulWidget {
  const ArenaReadyPage({super.key, required this.matchId});
  final String matchId;

  @override
  State<ArenaReadyPage> createState() => _ArenaReadyPageState();
}

class _ArenaReadyPageState extends State<ArenaReadyPage> {
  Map<String, dynamic>? _state;
  int _countdown = 3;
  int _cancelRemaining = 3;
  Timer? _timer;
  Timer? _statePoller;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statePoller?.cancel();
    super.dispose();
  }

  /// 필요한 변수: 현재 연습 경기 ID와 서버 취소 결과.
  /// 작동 원리: 3초 준비 구간의 연습 경기와 실제 사용자 큐를 함께 취소하고
  /// 실전 매칭이 이미 성립했다면 해당 경기 화면으로 이동한다.
  Future<void> _cancelWaiting() async {
    try {
      final result = await ArenaApi.instance.cancel();
      if (!mounted) return;
      final activeMatchId = result['active_match_id']?.toString();
      if (result['cancelled'] != true &&
          activeMatchId != null &&
          activeMatchId.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('경기가 이미 시작되어 취소할 수 없습니다.')),
        );
        return;
      }
      if (result['cancelled'] != true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('매칭 취소 가능 시간이 지났습니다.')));
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('매칭 상태가 바뀌었습니다. 잠시 후 다시 확인해 주세요.')),
        );
      }
    }
  }

  /// 필요한 변수: 경기 ID. 서버 상태를 읽은 뒤 화면에 진입 카운트다운을 시작한다.
  Future<void> _prepare() async {
    try {
      final state = await ArenaApi.instance.matchState(widget.matchId);
      if (!mounted) return;
      if (state['finished'] == true) {
        final result = await ArenaApi.instance.matchResult(widget.matchId);
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                ArenaResultPage(matchId: widget.matchId, initialResult: result),
          ),
        );
        return;
      }
      setState(() => _state = state);
      final practice = state['practice'] == true;
      _countdown = practice ? 5 : 3;
      if (practice) _pollForHumanMatch();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_countdown <= 1) {
          timer.cancel();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ArenaMatchPage(matchId: widget.matchId),
            ),
          );
        } else {
          setState(() {
            _countdown--;
            if (_cancelRemaining > 0) _cancelRemaining--;
          });
        }
      });
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// 필요한 변수: 연습 경기 ID. 5초 대기 중 실제 상대 경기로 교체되었는지 1초마다 확인한다.
  void _pollForHumanMatch() {
    _statePoller?.cancel();
    _statePoller = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      try {
        final state = await ArenaApi.instance.matchState(widget.matchId);
        if (state['finished'] == true) {
          _statePoller?.cancel();
          _timer?.cancel();
          final result = await ArenaApi.instance.matchResult(widget.matchId);
          if (mounted) {
            await Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => ArenaResultPage(
                  matchId: widget.matchId,
                  initialResult: result,
                ),
              ),
            );
          }
          return;
        }
        final replacement = state['replacement_match_id']?.toString();
        if (replacement != null &&
            replacement.isNotEmpty &&
            replacement != widget.matchId) {
          _statePoller?.cancel();
          _timer?.cancel();
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => ArenaReadyPage(matchId: replacement),
              ),
            );
          }
        }
      } catch (_) {
        // 일시적 폴링 실패는 다음 주기에 재시도한다.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final practice = _state?['practice'] == true;
    final participants = _state?['participants'] as List? ?? const [];
    Map<String, dynamic>? opponent;
    for (final raw in participants) {
      if (raw is Map && raw['team'] != _state?['team']) {
        opponent = Map<String, dynamic>.from(raw);
        break;
      }
    }
    return Scaffold(
      backgroundColor: const Color(0xFF171719),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'MATCH FOUND',
                  style: TextStyle(
                    color: Colors.white54,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  practice ? '연습 상대와 준비 완료' : '상대가 매칭되었습니다',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const TierBadge(tier: 'E', size: 72),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TierBadge(
                      tier: practice
                          ? (_state?['bot_tier']?.toString() ?? 'C')
                          : 'E',
                      size: 72,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  practice
                      ? '5초 동안 실제 상대를 찾고, 봇전 승리 시 +${(_state?['bot_win_rating_reward'] as num? ?? 20).round()} 레이팅을 받습니다.'
                      : '동일한 10문항으로 승부합니다.',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (opponent != null && !practice) ...[
                  const SizedBox(height: 8),
                  Text(
                    '상대 ${opponent['user_id']}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 32),
                Text(
                  '$_countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => ArenaMatchPage(matchId: widget.matchId),
                    ),
                  ),
                  child: const Text(
                    '바로 시작',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                if (_cancelRemaining > 0)
                  TextButton.icon(
                    onPressed: _cancelWaiting,
                    icon: const Icon(Icons.close, color: Colors.white70),
                    label: Text(
                      '매칭 취소 ($_cancelRemaining)',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 필요한 변수: 재개할 경기 콜백. 진행 중인 실전·봇전을 홈에서 다시 열 수 있게 표시한다.
class _ResumeMatchBanner extends StatelessWidget {
  const _ResumeMatchBanner({required this.onResume});
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF171719),
    borderRadius: BorderRadius.circular(18),
    child: ListTile(
      leading: const Icon(Icons.play_circle_fill, color: Colors.white),
      title: const Text(
        '진행 중인 경기가 있습니다',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
      subtitle: const Text(
        '실수로 나간 경기로 돌아갈 수 있습니다.',
        style: TextStyle(color: Colors.white54),
      ),
      trailing: FilledButton(onPressed: onResume, child: const Text('경기 계속하기')),
    ),
  );
}

/// 필요한 변수: 선택한 큐. 실제 참가자 레이팅만 서버에서 읽어 티어 선택의 랭킹 화면을 제공한다.
class ArenaRankingPage extends StatefulWidget {
  const ArenaRankingPage({super.key, required this.queueType});
  final String queueType;

  @override
  State<ArenaRankingPage> createState() => _ArenaRankingPageState();
}

class _ArenaRankingPageState extends State<ArenaRankingPage> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 필요한 변수: 선택 큐. 캐시된 랭킹을 불러와 봇 없이 사용자만 표시한다.
  Future<void> _load() async {
    final value = await ArenaApi.instance.rankings(widget.queueType);
    if (mounted) setState(() => _data = value);
  }

  @override
  Widget build(BuildContext context) {
    final items = _data?['items'] as List? ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('대결장 랭킹')),
      body: _data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, index) {
                final item = Map<String, dynamic>.from(items[index] as Map);
                return ListTile(
                  leading: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  title: Text(item['user_id']?.toString() ?? ''),
                  subtitle: Text(
                    '${item['wins'] ?? 0}승 ${item['losses'] ?? 0}패 ${item['draws'] ?? 0}무',
                  ),
                  trailing: Text(
                    _formatArenaRating(
                      (item['rating'] as num? ?? 1500).round(),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                );
              },
            ),
    );
  }
}

class ArenaMatchPage extends StatefulWidget {
  const ArenaMatchPage({super.key, required this.matchId});
  final String matchId;
  @override
  State<ArenaMatchPage> createState() => _ArenaMatchPageState();
}

class _ArenaMatchPageState extends State<ArenaMatchPage> {
  Map<String, dynamic>? _state;
  int _index = 0;
  int _remaining = 1200;
  final _answer = TextEditingController();
  final _chat = TextEditingController();
  Timer? _timer;
  Timer? _fallbackPoller;
  ArenaSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  String? _feedback;
  bool _switchingMatch = false;
  bool _submitting = false;
  bool _showingResult = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fallbackPoller?.cancel();
    _socketSubscription?.cancel();
    _socket?.close();
    _answer.dispose();
    _chat.dispose();
    super.dispose();
  }

  /// 필요한 변수는 경기 ID와 인증 토큰이다.
  /// WebSocket 상태 이벤트를 화면에 반영하고 연결 실패 때만 REST 조회로 복구한다.
  Future<void> _connect() async {
    try {
      final socket = await ArenaApi.instance.connect(matchId: widget.matchId);
      if (!mounted) {
        await socket.close();
        return;
      }
      _socket = socket;
      _socketSubscription = socket.events.listen(
        _handleSocketEvent,
        onError: (_) => _startFallbackPolling(),
        onDone: _startFallbackPolling,
      );
    } catch (_) {
      await _load();
      _startFallbackPolling();
    }
  }

  /// 필요한 변수 없음.
  /// 작동 원리: WebSocket 장애 때만 단발 REST 조회를 2초 간격으로 이어 실제 경기 교체를 놓치지 않는다.
  void _startFallbackPolling() {
    _fallbackPoller?.cancel();
    _fallbackPoller = Timer(const Duration(seconds: 2), () async {
      if (!mounted || _switchingMatch || _showingResult) return;
      try {
        await _load();
      } catch (error) {
        if (mounted) setState(() => _feedback = error.toString());
      }
      if (mounted && !_switchingMatch && !_showingResult) {
        _startFallbackPolling();
      }
    });
  }

  /// 필요한 변수는 최신 경기 상태다.
  /// 작동 원리는 서버가 반환한 제출 완료 문항을 건너뛰고 아직 풀지 않은 첫 문항만 화면에 고정하는 것이다.
  void _applyMatchState(Map<String, dynamic> value) {
    final questions = value['questions'] as List? ?? const [];
    final submitted = (value['submitted_question_ids'] as List? ?? const [])
        .map((item) => item.toString())
        .toSet();
    var nextIndex = questions.length;
    for (var index = 0; index < questions.length; index++) {
      final question = questions[index];
      if (question is Map && !submitted.contains(question['id']?.toString())) {
        nextIndex = index;
        break;
      }
    }
    setState(() {
      _state = value;
      _remaining = (value['remaining_seconds'] as num?)?.toInt() ?? 0;
      _index = nextIndex;
      _submitting = false;
    });
  }

  /// 필요한 변수는 선택적으로 WebSocket이 전달한 종료 결과다.
  /// 작동 원리는 모든 타이머·소켓을 닫고 결과를 한 번만 조회한 뒤 현재 경기 화면을 분석 화면으로 즉시 교체하는 것이다.
  Future<void> _openResult([Map<String, dynamic>? initialResult]) async {
    if (_showingResult || !mounted) return;
    _showingResult = true;
    _timer?.cancel();
    _fallbackPoller?.cancel();
    await _socketSubscription?.cancel();
    await _socket?.close();
    try {
      final result =
          initialResult ?? await ArenaApi.instance.matchResult(widget.matchId);
      if (initialResult != null) {
        await ArenaApi.instance.invalidateSummary();
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              ArenaResultPage(matchId: widget.matchId, initialResult: result),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showingResult = false;
      setState(() => _feedback = '경기는 종료됐지만 결과를 불러오지 못했습니다: $error');
      _startFallbackPolling();
    }
  }

  /// 필요한 변수는 서버 이벤트 유형과 data 본문이다.
  /// 경기 상태·답안 결과·종료를 각각 기존 화면 상태와 피드백으로 연결한다.
  void _handleSocketEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['type']?.toString();
    final rawData = event['data'];
    if (type == 'match_state' && rawData is Map) {
      final value = Map<String, dynamic>.from(rawData);
      final replacementMatchId = value['replacement_match_id']?.toString();
      if (replacementMatchId != null &&
          replacementMatchId.isNotEmpty &&
          replacementMatchId != widget.matchId) {
        unawaited(_replaceWithHumanMatch(replacementMatchId));
        return;
      }
      _applyMatchState(value);
      if (value['finished'] == true) {
        unawaited(_openResult());
      } else {
        _startLocalTimer();
      }
    } else if (type == 'answer_result' && rawData is Map) {
      final result = Map<String, dynamic>.from(rawData);
      setState(() {
        _feedback = result['correct'] == true ? '정답입니다!' : '오답입니다.';
        _submitting = false;
        _index++;
        _answer.clear();
      });
      if (result['finished'] == true) unawaited(_openResult());
    } else if (type == 'match_finished' && rawData is Map) {
      unawaited(_openResult(Map<String, dynamic>.from(rawData)));
    } else if (type == 'error') {
      setState(() {
        _submitting = false;
        _feedback = event['message']?.toString();
      });
    }
  }

  /// 필요한 변수는 현재 남은 시간이다. 서버 상태 사이 구간만 1초 단위로 보간한다.
  void _startLocalTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _showingResult) return;
      if (_remaining > 0) {
        setState(() => _remaining--);
        if (_remaining == 0) unawaited(_load());
      }
    });
  }

  Future<void> _load() async {
    final value = await ArenaApi.instance.matchState(widget.matchId);
    if (!mounted) return;
    final replacementMatchId = value['replacement_match_id']?.toString();
    if (replacementMatchId != null &&
        replacementMatchId.isNotEmpty &&
        replacementMatchId != widget.matchId) {
      await _replaceWithHumanMatch(replacementMatchId);
      return;
    }
    _applyMatchState(value);
    if (value['finished'] == true) {
      await _openResult();
    } else {
      _startLocalTimer();
    }
  }

  /// 필요한 변수: 서버가 성립시킨 실제 사용자 경기 ID.
  /// 작동 원리: 연습 소켓과 타이머를 먼저 닫고 현재 라우트를 동일한 실전 경기 화면으로 교체한다.
  Future<void> _replaceWithHumanMatch(String matchId) async {
    if (_switchingMatch || !mounted) return;
    _switchingMatch = true;
    _timer?.cancel();
    _fallbackPoller?.cancel();
    await _socketSubscription?.cancel();
    await _socket?.close();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ArenaMatchPage(matchId: matchId)),
    );
  }

  /// 필요한 변수: 사용자가 입력하거나 선택한 답안.
  /// 작동 원리: 소켓이 연결된 경우 단일 프레임으로 보내고, 장애 복구 중에는 REST로 동일한 멱등 제출을 수행한다.
  Future<void> _submit(String answer) async {
    if (_submitting || _showingResult || answer.trim().isEmpty) return;
    final questions = _state?['questions'] as List? ?? const [];
    if (questions.isEmpty || _index >= questions.length) return;
    final question = Map<String, dynamic>.from(questions[_index] as Map);
    setState(() => _submitting = true);
    try {
      final socket = _socket;
      if (socket != null) {
        socket.send({
          'type': 'submit_answer',
          'question_id': question['id'].toString(),
          'answer': answer,
          'idempotency_key':
              '${DateTime.now().microsecondsSinceEpoch}-${question['id']}',
        });
        return;
      }
      final result = await ArenaApi.instance.submit(
        widget.matchId,
        question['id'].toString(),
        answer,
      );
      if (!mounted) return;
      setState(() {
        _feedback = result['correct'] == true ? '정답입니다!' : '오답입니다.';
        _submitting = false;
        _answer.clear();
      });
      if (result['finished'] == true) {
        await _openResult();
      } else {
        await _load();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _feedback = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final questions = _state!['questions'] as List? ?? const [];
    if (questions.isEmpty) {
      return const Scaffold(body: Center(child: Text('경기 문항을 불러오지 못했습니다.')));
    }
    final allAnswered = _index >= questions.length;
    final submittedCount =
        (_state!['submitted_question_ids'] as List? ?? const []).length;
    final progressCount = math.max(
      submittedCount,
      math.min(_index, questions.length),
    );
    final canSubmit = !allAnswered && !_submitting && !_showingResult;
    final question = Map<String, dynamic>.from(
      questions[math.min(_index, questions.length - 1)] as Map,
    );
    final choices = question['choices'] as List? ?? const [];
    final teamMode = _state!['queue_type'].toString().startsWith('team_');
    final practice = _state!['practice'] == true;
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final scores = Map<String, dynamic>.from(
      _state!['scores'] as Map? ?? const {},
    );
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF4F4F6),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: true,
          title: Text(
            '${(_remaining ~/ 60).toString().padLeft(2, '0')}:${(_remaining % 60).toString().padLeft(2, '0')} · ${math.min(_index + 1, questions.length)}/${questions.length}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            if (teamMode && !desktop)
              IconButton(
                tooltip: '팀 채팅',
                onPressed: _showTeamChat,
                icon: const Icon(Icons.forum_outlined),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1380),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                desktop ? 28 : 14,
                8,
                desktop ? 28 : 14,
                20,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE1E1E3)),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          _ArenaScoreBoard(
                            scores: scores,
                            team: (_state!['team'] as num? ?? 0).toInt(),
                            practice: practice,
                            botTier: _state!['bot_tier']?.toString(),
                            botWinReward:
                                (_state!['bot_win_rating_reward'] as num? ?? 20)
                                    .round(),
                            botActivity: _state!['bot_activity'] as Map?,
                          ),
                          const SizedBox(height: 20),
                          if (allAnswered) ...[
                            const _ArenaWaitingForResult(),
                            const SizedBox(height: 18),
                          ],
                          Text(
                            question['tags']?.toString() ?? '',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ContentBlocksView(
                            blocks: parseTextWithLatex(
                              question['prompt'].toString(),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                            latexStyle: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                            ),
                            spacing: 12,
                            // 서버가 보존한 수식 블록을 문제 문장 안에서 자연스럽게 이어 그린다.
                            inline: true,
                          ),
                          const SizedBox(height: 20),
                          if (choices.isNotEmpty)
                            ...choices.map((raw) {
                              final value = Map<String, dynamic>.from(
                                raw as Map,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: OutlinedButton(
                                  onPressed: canSubmit
                                      ? () => _submit(value['id'].toString())
                                      : null,
                                  child: ContentBlocksView(
                                    blocks: parseTextWithLatex(
                                      value['label'].toString(),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    latexStyle: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          if (choices.isEmpty)
                            TextField(
                              controller: _answer,
                              enabled: canSubmit,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\-.]'),
                                ),
                              ],
                              autocorrect: false,
                              enableSuggestions: false,
                              onSubmitted: _submit,
                              decoration: const InputDecoration(
                                labelText: '숫자 정답 직접 입력',
                                helperText: '정수 또는 소수를 키보드로 입력하세요.',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          if (choices.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: FilledButton(
                                onPressed: canSubmit
                                    ? () => _submit(_answer.text)
                                    : null,
                                child: Text(_submitting ? '제출 중…' : '제출'),
                              ),
                            ),
                          if (_feedback != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(_feedback!),
                            ),
                          const SizedBox(height: 18),
                          LinearProgressIndicator(
                            value: questions.isEmpty
                                ? 0
                                : progressCount / questions.length,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$progressCount/${questions.length} 제출 완료 · 제출한 문제로 돌아갈 수 없습니다.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF6E6E73),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (teamMode && desktop) ...[
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 300,
                      child: _TeamChat(
                        matchId: widget.matchId,
                        messages: _state!['chat'] as List? ?? const [],
                        controller: _chat,
                        onSent: _load,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 필요한 변수: 현재 팀 경기 상태와 채팅 컨트롤러.
  /// 작동 원리: 좁은 화면에서는 문제 영역을 보존하고 팀 채팅을 하단 시트로 분리한다.
  Future<void> _showTeamChat() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: _TeamChat(
        matchId: widget.matchId,
        messages: _state?['chat'] as List? ?? const [],
        controller: _chat,
        onSent: _load,
      ),
    ),
  );
}

/// 필요한 변수: 종료 경기 ID와 선택적으로 이미 수신한 결과.
/// 작동 원리: 승패·레이팅 변동을 먼저 보여 주고 같은 화면 아래에 문항별 제출·정답 분석을 이어서 표시한다.
class ArenaResultPage extends StatefulWidget {
  const ArenaResultPage({super.key, required this.matchId, this.initialResult});

  final String matchId;
  final Map<String, dynamic>? initialResult;

  @override
  State<ArenaResultPage> createState() => _ArenaResultPageState();
}

class _ArenaResultPageState extends State<ArenaResultPage> {
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    if (_result == null) unawaited(_load());
  }

  /// 필요한 변수는 종료 경기 ID다.
  /// 작동 원리는 참가자 전용 결과 API를 캐시 없이 읽고 실패 시 재시도 가능한 오류를 보존하는 것이다.
  Future<void> _load() async {
    try {
      final value = await ArenaApi.instance.matchResult(widget.matchId);
      if (mounted) {
        setState(() {
          _result = value;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  /// 필요한 변수는 결과 참가자 목록과 현재 사용자 ID다.
  /// 작동 원리는 viewer ID를 우선하고 없으면 봇이 아닌 참가자를 선택해 내 레이팅 결과를 찾는 것이다.
  Map<String, dynamic> _myParticipant(Map<String, dynamic> result) {
    final viewerId = result['viewer_user_id']?.toString();
    final participants = result['participants'] as List? ?? const [];
    for (final raw in participants) {
      if (raw is Map && raw['user_id']?.toString() == viewerId) {
        return Map<String, dynamic>.from(raw);
      }
    }
    for (final raw in participants) {
      if (raw is Map && raw['is_bot'] != true) {
        return Map<String, dynamic>.from(raw);
      }
    }
    return const <String, dynamic>{};
  }

  /// 필요한 변수는 로드된 종료 결과다.
  /// 작동 원리는 승패 요약과 문항 분석을 하나의 스크롤 화면으로 반응형 배치하는 것이다.
  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('경기 결과')),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('결과 다시 불러오기'),
                ),
        ),
      );
    }
    final mine = _myParticipant(result);
    final viewerTeam =
        (result['viewer_team'] as num?)?.toInt() ??
        (mine['team'] as num?)?.toInt() ??
        0;
    final analysis = result['analysis'] as List? ?? const [];
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text('경기 종료'),
        backgroundColor: const Color(0xFFF4F4F6),
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ArenaResultSummary(result: result, mine: mine),
                    const SizedBox(height: 20),
                    Text(
                      '문항별 결과 분석',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '제출한 답안은 한 번만 판정되며, 미제출 문항도 함께 표시됩니다.',
                      style: TextStyle(color: Color(0xFF6E6E73)),
                    ),
                    const SizedBox(height: 14),
                    for (final raw in analysis)
                      if (raw is Map)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ArenaAnalysisCard(
                            item: Map<String, dynamic>.from(raw),
                            viewerTeam: viewerTeam,
                          ),
                        ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.sports_esports),
                      label: const Text('대결장으로 돌아가기'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 필요한 변수: 전체 결과와 현재 사용자 참가 결과.
/// 작동 원리는 종료 사유·승패·점수·레이팅 증감을 한 카드에서 즉시 인지할 수 있게 조합하는 것이다.
class _ArenaResultSummary extends StatelessWidget {
  const _ArenaResultSummary({required this.result, required this.mine});

  final Map<String, dynamic> result;
  final Map<String, dynamic> mine;

  /// 필요한 변수는 내 전적·레이팅과 양 팀 점수다. 종료 핵심 정보를 어두운 결과 카드로 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final record = mine['record']?.toString() ?? 'draw';
    final title = record == 'win'
        ? '승리'
        : record == 'loss'
        ? '패배'
        : '무승부';
    final color = record == 'win'
        ? const Color(0xFF55D98A)
        : record == 'loss'
        ? const Color(0xFFFF8A8A)
        : Colors.white70;
    final delta = (mine['rating_delta'] as num? ?? 0).round();
    final team = (mine['team'] as num? ?? 0).toInt();
    final scores = Map<String, dynamic>.from(
      result['scores'] as Map? ?? const {},
    );
    final myScore = Map<String, dynamic>.from(
      scores['$team'] as Map? ?? const {},
    );
    final opponentScore = Map<String, dynamic>.from(
      scores['${1 - team}'] as Map? ?? const {},
    );
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF171719),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            result['practice'] == true ? 'BOT MATCH RESULT' : 'MATCH RESULT',
            style: const TextStyle(
              color: Colors.white54,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _arenaFinishReasonLabel(result['finish_reason']?.toString()),
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ArenaScore(
                label: '나',
                score: (myScore['correct'] as num? ?? 0).toInt(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text('VS', style: TextStyle(color: Colors.white38)),
              ),
              _ArenaScore(
                label: result['practice'] == true ? '봇' : '상대',
                score: (opponentScore['correct'] as num? ?? 0).toInt(),
              ),
            ],
          ),
          const Divider(height: 32, color: Colors.white12),
          Text(
            '${delta >= 0 ? '+' : ''}$delta 레이팅',
            style: TextStyle(
              color: delta > 0
                  ? const Color(0xFF7FE1A1)
                  : delta < 0
                  ? const Color(0xFFFF9A9A)
                  : Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(mine['rating_before'] as num? ?? 1500).round()} → ${(mine['rating_after'] as num? ?? 1500).round()}',
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

/// 필요한 변수: 한 문항의 종료 분석과 현재 팀 번호.
/// 작동 원리는 수식 문제·내 답·정답·정오답 상태를 한 카드에서 비교하게 만드는 것이다.
class _ArenaAnalysisCard extends StatelessWidget {
  const _ArenaAnalysisCard({required this.item, required this.viewerTeam});

  final Map<String, dynamic> item;
  final int viewerTeam;

  /// 필요한 변수는 현재 팀의 제출 답안과 공개된 정답이다. 정오답 색상과 수식 본문을 함께 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final answers = Map<String, dynamic>.from(
      item['team_answers'] as Map? ?? const {},
    );
    final rawAnswer = answers['$viewerTeam'];
    final answer = rawAnswer is Map
        ? Map<String, dynamic>.from(rawAnswer)
        : null;
    final correct = answer?['correct'] == true;
    final statusColor = answer == null
        ? const Color(0xFF8E8E93)
        : correct
        ? const Color(0xFF17883E)
        : const Color(0xFFC62828);
    final status = answer == null
        ? '미제출'
        : correct
        ? '정답'
        : '오답';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E1E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item['position'] ?? '-'}번',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ContentBlocksView(
            blocks: parseTextWithLatex(item['prompt']?.toString() ?? ''),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            latexStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _ArenaRenderedAnswerLine(
            label: '내 답',
            value: answer?['answer_label']?.toString() ?? '제출하지 않음',
            color: statusColor,
          ),
          const SizedBox(height: 5),
          _ArenaRenderedAnswerLine(
            label: '정답',
            value: item['correct_answer_label']?.toString() ?? '-',
          ),
        ],
      ),
    );
  }
}

/// 필요한 변수: 답안 종류 라벨·수식 포함 값·선택 색상.
/// 작동 원리는 결과 분석의 답안도 문제 본문과 같은 인라인 수식 렌더러로 표시하는 것이다.
class _ArenaRenderedAnswerLine extends StatelessWidget {
  const _ArenaRenderedAnswerLine({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  /// 필요한 변수는 라벨과 수식 포함 답안 값이다. 라벨 옆 남은 폭에서 인라인 수식을 자동 줄바꿈한다.
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label: ',
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
      Expanded(
        child: ContentBlocksView(
          blocks: parseTextWithLatex(value),
          textStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
          latexStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

/// 필요한 변수: 서버 종료 사유 코드.
/// 작동 원리는 내부 코드를 학생이 이해할 수 있는 즉시 종료 설명으로 변환하는 것이다.
String _arenaFinishReasonLabel(String? reason) => switch (reason) {
  'anti_cheat_speed' => '비정상적인 초고속 제출이 감지되어 종료됐습니다.',
  'inactive_forfeit' => '상대 이탈로 몰수 종료됐습니다.',
  'time_expired' => '경기 시간이 종료됐습니다.',
  'all_questions_answered' => '한쪽이 모든 문항을 제출해 종료됐습니다.',
  'decisive_lead' => '남은 문항으로 역전할 수 없어 조기 종료됐습니다.',
  _ => '최종 점수로 경기가 종료됐습니다.',
};

/// 필요한 변수 없음.
/// 작동 원리는 모든 답안을 제출한 짧은 전환 구간에 추가 입력을 막고 서버 결과 확정을 안내하는 것이다.
class _ArenaWaitingForResult extends StatelessWidget {
  const _ArenaWaitingForResult();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F7FF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            '모든 답안을 제출했습니다. 경기 결과를 확정하고 있습니다.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

/// 필요한 변수: 서버 팀 점수·연습 여부·봇 티어·최근 봇 응답.
/// 작동 원리: 실제 경기와 같은 점수판을 사용하고 연습 중에는 사람 매칭 상태와 봇 정오답을 함께 표시한다.
class _ArenaScoreBoard extends StatelessWidget {
  const _ArenaScoreBoard({
    required this.scores,
    required this.team,
    required this.practice,
    required this.botTier,
    required this.botWinReward,
    required this.botActivity,
  });

  final Map<String, dynamic> scores;
  final int team;
  final bool practice;
  final String? botTier;
  final int botWinReward;
  final Map? botActivity;

  @override
  Widget build(BuildContext context) {
    final mine = Map<String, dynamic>.from(scores['$team'] as Map? ?? const {});
    final opponent = Map<String, dynamic>.from(
      scores['${1 - team}'] as Map? ?? const {},
    );
    final activity = botActivity == null
        ? '봇이 첫 답안을 푸는 중입니다.'
        : '${botActivity!['question_number']}번 · ${botActivity!['correct'] == true ? '정답' : '오답'}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171719),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          if (practice) ...[
            Row(
              children: [
                const Icon(Icons.sync, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${botTier ?? 'C'} 티어 봇전 · 승리 +$botWinReward 레이팅',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  activity,
                  style: TextStyle(
                    color: botActivity?['correct'] == false
                        ? const Color(0xFFFF9A9A)
                        : const Color(0xFF7FE1A1),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ArenaScore(
                label: '나',
                score: (mine['correct'] as num? ?? 0).toInt(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text('VS', style: TextStyle(color: Colors.white38)),
              ),
              _ArenaScore(
                label: practice ? '연습 봇' : '상대 팀',
                score: (opponent['correct'] as num? ?? 0).toInt(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArenaScore extends StatelessWidget {
  const _ArenaScore({required this.label, required this.score});

  final String label;
  final int score;

  /// 필요한 변수: 팀 이름과 정답 수.
  /// 작동 원리: 서버가 집계한 점수를 동일한 폭으로 표시해 실전과 연습의 점수 구조를 통일한다.
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 4),
      Text(
        '$score',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _TeamChat extends StatelessWidget {
  const _TeamChat({
    required this.matchId,
    required this.messages,
    required this.controller,
    required this.onSent,
  });
  final String matchId;
  final List messages;
  final TextEditingController controller;
  final Future<void> Function() onSent;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            '팀 채팅 · 종료 시 파쇄',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: ListView(
            children: messages
                .map(
                  (e) => ListTile(
                    dense: true,
                    title: Text((e as Map)['message'].toString()),
                  ),
                )
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: controller,
            onSubmitted: (_) async {
              final text = controller.text;
              controller.clear();
              await ArenaApi.instance.chat(matchId, text);
              await onSent();
            },
            decoration: const InputDecoration(hintText: '팀원과 토의하기'),
          ),
        ),
      ],
    ),
  );
}
