import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arena_api.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';
import 'package:s11/app/router.dart';

typedef ArenaJoinCallback =
    Future<Map<String, dynamic>> Function(String queueType);
typedef ArenaSummaryCallback = Future<Map<String, dynamic>> Function();

/// 학생 대시보드에서 실시간 대결장을 연다.
Future<void> showArena(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const ArenaPage()));

/// 필요한 변수: 서버의 네 큐 요약.
/// 1v1/2v2 시험·OX 큐와 독립 티어를 한 화면에 표시한다.
class ArenaPage extends StatefulWidget {
  const ArenaPage({
    super.key,
    this.initialSummary,
    this.joinQueue,
    this.loadSummary,
  });

  final Map<String, dynamic>? initialSummary;
  final ArenaJoinCallback? joinQueue;
  final ArenaSummaryCallback? loadSummary;

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
    if (mounted) setState(() => _error = null);
    try {
      final value =
          await (widget.loadSummary?.call() ?? ArenaApi.instance.summary());
      if (mounted) {
        setState(() {
          _summary = value;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          // 로딩 실패도 완료 상태로 전환해 진행 표시기가 무한히 남지 않게 한다.
          _summary = const <String, dynamic>{
            'queues': <Map<String, dynamic>>[],
          };
          _error = studentFacingApiError(
            error,
            fallback: '대결 정보를 불러오지 못했어요.',
            notFound: '대결 기능을 준비하고 있어요.',
          );
        });
      }
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
          _error = studentFacingApiError(error, fallback: '매칭을 시작하지 못했어요.');
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
        if (mounted) {
          setState(
            () => _error = studentFacingApiError(
              error,
              fallback: '매칭 상태를 확인하지 못했어요.',
            ),
          );
        }
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
        setState(
          () => _error = studentFacingApiError(
            error,
            fallback: '매칭 취소를 완료하지 못했어요.',
          ),
        );
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
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '대결 참가 확인 닫기',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, _) {
        final mobile = MediaQuery.sizeOf(dialogContext).width <= 720;
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(false),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: const ColoredBox(color: Color(0x8A09090B)),
              ),
            ),
            Align(
              alignment: mobile ? Alignment.bottomCenter : Alignment.center,
              child: Padding(
                padding: mobile ? EdgeInsets.zero : const EdgeInsets.all(20),
                child: _ArenaJoinConfirmationDialog(
                  mobile: mobile,
                  waitSeconds: waitSeconds,
                  questionCount: questionCount,
                  durationMinutes: durationMinutes,
                  onCancel: () => Navigator.of(dialogContext).pop(false),
                  onConfirm: () => Navigator.of(dialogContext).pop(true),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
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
    final queues = List<Map<String, dynamic>>.from(
      (_summary?['queues'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final profile = Map<String, dynamic>.from(
      _summary?['profile'] as Map? ??
          (queues.isEmpty ? const {} : queues.first),
    );
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
    return StudentHtmlShell(
      title: '대결장',
      activeRoute: AppRoutes.studentDashboard,
      showContextAside: false,
      mobileBackButton: true,
      onMenu: () =>
          Navigator.of(context).pushReplacementNamed('/student/dashboard'),
      child: RefreshIndicator(
        onRefresh: _load,
        child: ColoredBox(
          color: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1380),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ArenaIdentityStrip(
                        tier: tier,
                        wins: wins,
                        losses: losses,
                        draws: draws,
                        recentResults: recentResults,
                        onRanking: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ArenaRankingPage(
                              queueType:
                                  profile['queue_type']?.toString() ??
                                  'duel_exam',
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: desktop ? 38 : 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (resumableMatchId != null &&
                                resumableMatchId.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: _ResumeMatchBanner(
                                  onResume: () => _openMatch(resumableMatchId),
                                ),
                              ),
                            if (_error != null && _summary != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _ArenaErrorBanner(
                                  message: _error!,
                                  onRetry: _load,
                                ),
                              ),
                            SizedBox(height: desktop ? 26 : 7),
                            const _ArenaMatchHeader(),
                            SizedBox(height: desktop ? 16 : 16),
                            if (_summary == null)
                              const Center(child: CircularProgressIndicator())
                            else
                              Column(
                                key: ValueKey(
                                  desktop
                                      ? 'arena-queue-list'
                                      : 'arena-mobile-queue-list',
                                ),
                                children: [
                                  for (
                                    var index = 0;
                                    index < visibleQueues.length;
                                    index++
                                  )
                                    Padding(
                                      padding: EdgeInsets.only(
                                        bottom:
                                            index == visibleQueues.length - 1
                                            ? 0
                                            : 8,
                                      ),
                                      child: _ArenaMobileEntryCard(
                                        data: visibleQueues[index],
                                        waiting:
                                            _waitingQueue ==
                                            visibleQueues[index]['queue_type'],
                                        disabled:
                                            visibleQueues[index]['coming_soon'] ==
                                                true ||
                                            _waitingQueue != null &&
                                                _waitingQueue !=
                                                    visibleQueues[index]['queue_type'],
                                        onJoin: () => _confirmMobileJoin(
                                          visibleQueues[index],
                                        ),
                                        onCancel: _cancel,
                                      ),
                                    ),
                                  if (visibleQueues.isEmpty)
                                    _ArenaUnavailableCard(onRetry: _load),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 필요한 변수: 서버에서 받은 티어·전적·최근 결과와 랭킹 이동 콜백.
/// 작동 원리: HTML의 상단 컴팩트 기록 띠를 모바일과 데스크톱에서 동일한 정보 순서로 보여준다.
class _ArenaJoinConfirmationDialog extends StatelessWidget {
  const _ArenaJoinConfirmationDialog({
    required this.mobile,
    required this.waitSeconds,
    required this.questionCount,
    required this.durationMinutes,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool mobile;
  final int waitSeconds;
  final int questionCount;
  final int durationMinutes;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('예상 대기', waitSeconds > 0 ? '약 $waitSeconds초' : '바로 시작'),
      ('문항 수', '$questionCount문항'),
      ('제한 시간', '$durationMinutes분'),
    ];
    final maxHeight = math.max(
      0.0,
      math.min(640.0, MediaQuery.sizeOf(context).height - 24),
    );

    return Material(
      color: Colors.transparent,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: '1v1 대결 참가 확인',
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: mobile ? 291 : 0,
            maxWidth: mobile ? double.infinity : 470,
            maxHeight: mobile ? maxHeight : double.infinity,
          ),
          child: Container(
            key: const ValueKey('arena-mobile-confirm-sheet'),
            width: mobile ? double.infinity : 470,
            padding: EdgeInsets.fromLTRB(
              mobile ? 16 : 22,
              mobile ? 12 : 22,
              mobile ? 16 : 22,
              mobile ? 18 : 22,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: mobile
                  ? const Border(top: BorderSide(color: Color(0xFF09090B)))
                  : Border.all(color: const Color(0xFF09090B)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3309090B),
                  blurRadius: 80,
                  offset: Offset(0, 24),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mobile) ...[
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        color: const Color(0xFFD6D6D8),
                      ),
                    ),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1v1 문제풀이',
                              style: TextStyle(
                                color: Color(0xFF71717A),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              '매칭을 시작할까요?',
                              style: TextStyle(
                                fontSize: mobile ? 21 : 24,
                                height: 1.1,
                                letterSpacing: -1.05,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Semantics(
                        button: true,
                        label: '닫기',
                        child: InkWell(
                          onTap: onCancel,
                          child: Container(
                            key: const ValueKey('arena-confirm-close'),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0x1A09090B),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.close, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    margin: EdgeInsets.only(top: mobile ? 16 : 20, bottom: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0x1A09090B)),
                        bottom: BorderSide(color: Color(0x1A09090B)),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (var index = 0; index < metrics.length; index++)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: index == metrics.length - 1
                                    ? null
                                    : const Border(
                                        right: BorderSide(
                                          color: Color(0x1A09090B),
                                        ),
                                      ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    metrics[index].$1,
                                    style: const TextStyle(
                                      color: Color(0xFF71717A),
                                      fontSize: 9,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    metrics[index].$2,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: Color(0xFF71717A),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '참가 요청은 중복 처리되지 않으며, 매칭 전에는 언제든 취소할 수 있습니다.',
                          style: TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 10,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: mobile ? 25 : 22),
                  Row(
                    children: [
                      if (mobile)
                        Expanded(
                          child: _ArenaConfirmCancelButton(onPressed: onCancel),
                        )
                      else
                        SizedBox(
                          width: 150,
                          child: _ArenaConfirmCancelButton(onPressed: onCancel),
                        ),
                      const SizedBox(width: 8),
                      if (mobile)
                        Expanded(
                          child: _ArenaConfirmJoinButton(onPressed: onConfirm),
                        )
                      else
                        SizedBox(
                          width: 150,
                          child: _ArenaConfirmJoinButton(onPressed: onConfirm),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArenaConfirmCancelButton extends StatelessWidget {
  const _ArenaConfirmCancelButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: const BorderSide(color: Color(0xFF09090B)),
        shape: const RoundedRectangleBorder(),
        textStyle: const TextStyle(
          fontFamily: 'Noto Sans KR',
          fontWeight: FontWeight.w900,
        ),
      ),
      child: const Text('취소', style: TextStyle(fontFamily: 'Noto Sans KR')),
    ),
  );
}

class _ArenaConfirmJoinButton extends StatelessWidget {
  const _ArenaConfirmJoinButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: FilledButton(
      key: const ValueKey('arena-mobile-confirm-join'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF09090B),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(),
        textStyle: const TextStyle(
          fontFamily: 'Noto Sans KR',
          fontWeight: FontWeight.w900,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('상대 찾기', style: TextStyle(fontFamily: 'Noto Sans KR')),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 16),
        ],
      ),
    ),
  );
}

class _ArenaIdentityStrip extends StatelessWidget {
  const _ArenaIdentityStrip({
    required this.tier,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.recentResults,
    required this.onRanking,
  });

  final String tier;
  final int wins;
  final int losses;
  final int draws;
  final List<String> recentResults;
  final VoidCallback onRanking;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final results = recentResults.reversed.take(5).toList();
    final streak = _arenaWinStreak(recentResults);
    return Container(
      key: const ValueKey('arena-identity-strip'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(mobile ? 14 : 38, 12, mobile ? 14 : 38, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5E7))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: mobile ? 54 : 70,
                height: mobile ? 54 : 70,
                color: const Color(0xFF09090B),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'TIER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      tier,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: mobile ? 20 : 24,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: mobile ? 12 : 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '현재 기록',
                      style: TextStyle(color: Color(0xFF71717A), fontSize: 9),
                    ),
                    Text(
                      '$wins승 $losses패 $draws무',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '승률 ${_arenaWinRate(wins, losses, draws)}% · 최근 $streak연승',
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              if (!mobile) ...[
                const Text(
                  '최근 대결',
                  style: TextStyle(color: Color(0xFF71717A), fontSize: 9),
                ),
                const SizedBox(width: 8),
                ...results.map((result) => _ArenaRecentResult(result: result)),
                const SizedBox(width: 16),
              ],
              if (mobile)
                OutlinedButton.icon(
                  onPressed: onRanking,
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text(
                    '전체 랭킹 보기',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 54),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: onRanking,
                  icon: const Text(
                    '전체 랭킹 보기',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                  label: const Icon(Icons.arrow_forward, size: 14),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(132, 48),
                    shape: const RoundedRectangleBorder(
                      side: BorderSide(color: Color(0xFFE5E5E7)),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
            ],
          ),
          if (mobile)
            Padding(
              padding: const EdgeInsets.only(left: 66, top: 8, bottom: 12),
              child: Row(
                children: [
                  const Text(
                    '최근 대결',
                    style: TextStyle(color: Color(0xFF71717A), fontSize: 9),
                  ),
                  const SizedBox(width: 8),
                  ...results.map(
                    (result) => _ArenaRecentResult(result: result),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ArenaRecentResult extends StatelessWidget {
  const _ArenaRecentResult({required this.result});
  final String result;

  @override
  Widget build(BuildContext context) {
    final won = result == 'win';
    final drawn = result == 'draw';
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(left: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: won ? Colors.black : Colors.white,
        border: Border.all(color: const Color(0xFFE5E5E7)),
      ),
      child: Text(
        won
            ? '승'
            : drawn
            ? '무'
            : '패',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: won ? Colors.white : const Color(0xFF71717A),
        ),
      ),
    );
  }
}

int _arenaWinStreak(List<String> results) {
  var streak = 0;
  for (final result in results.reversed) {
    if (result != 'win') break;
    streak++;
  }
  return streak;
}

String _arenaWinRate(int wins, int losses, int draws) {
  final total = wins + losses + draws;
  return total == 0 ? '0' : (wins / total * 100).round().toString();
}

/// 필요한 변수 없음.
/// 작동 원리: 세로 화면에서는 영문 라벨·긴 설명·전적을 생략하고 기능명만 크게 표시한다.
// ignore: unused_element
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
      SizedBox(height: 8),
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
    final comingSoon = data['coming_soon'] == true;
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final description = data['queue_type'] == 'team_exam'
        ? '팀 점수 · 실시간 메시지'
        : '10문항 · 제한 20분 · 같은 티어 우선';
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          comingSoon ? '준비 중' : '지금 참여 가능',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          data['queue_type'] == 'team_exam' ? '팀 문제풀이' : '1v1 문제풀이',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(color: Color(0xFF71717A), fontSize: 10),
        ),
      ],
    );
    final icon = Container(
      width: mobile ? 54 : 62,
      height: mobile ? 54 : 62,
      alignment: Alignment.center,
      color: comingSoon ? Colors.white : const Color(0xFF09090B),
      child: Text(
        data['queue_type'] == 'team_exam' ? '2:2' : '1:1',
        style: TextStyle(
          color: comingSoon ? const Color(0xFF71717A) : Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    final action = comingSoon
        ? const Text(
            '참가 불가',
            style: TextStyle(
              color: Color(0xFF71717A),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          )
        : const Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: Colors.black,
          );
    return Semantics(
      button: !comingSoon,
      enabled: !disabled,
      label: waiting ? '매칭 취소' : '대결 시작',
      child: InkWell(
        key: comingSoon ? null : const ValueKey('arena-mobile-join-button'),
        onTap: disabled ? null : (waiting ? onCancel : onJoin),
        child: Container(
          key: const ValueKey('arena-mobile-entry-card'),
          constraints: BoxConstraints(minHeight: mobile ? 123 : 108),
          padding: EdgeInsets.fromLTRB(
            mobile ? 13 : 16,
            mobile ? 14 : 16,
            mobile ? 12 : 16,
            mobile ? 14 : 16,
          ),
          decoration: BoxDecoration(
            color: comingSoon ? const Color(0xFFF4F4F6) : Colors.white,
            border: Border.all(
              color: comingSoon
                  ? const Color(0xFFD8D8DB)
                  : const Color(0xFF202022),
            ),
          ),
          child: mobile
              ? Column(
                  children: [
                    Row(
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(child: copy),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const SizedBox(width: 66),
                        Text(
                          comingSoon ? '현재 상태' : '예상 대기',
                          style: const TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 9,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          comingSoon
                              ? '참가 불가'
                              : waiting
                              ? '매칭 취소'
                              : '약 ${data['estimated_wait_seconds'] ?? 20}초',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!comingSoon) action,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    icon,
                    const SizedBox(width: 16),
                    Expanded(child: copy),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          comingSoon ? '현재 상태' : '예상 대기',
                          style: const TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          comingSoon
                              ? '참가 불가'
                              : waiting
                              ? '상대 찾는 중'
                              : '약 ${data['estimated_wait_seconds'] ?? 20}초',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (!comingSoon) ...[const SizedBox(width: 8), action],
                  ],
                ),
        ),
      ),
    );
  }
}

/// 필요한 변수 없음.
/// 작동 원리: 서버가 활성 큐를 반환하지 못하면 테두리 없는 빈 상태와 큰 재시도 버튼을 제공한다.
class _ArenaUnavailableCard extends StatelessWidget {
  const _ArenaUnavailableCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.sports_mma_rounded, size: 30),
        const SizedBox(height: 14),
        const Text(
          '참가 가능한 대결이 없어요',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        const Text(
          '잠시 후 다시 확인하거나 새로고침해 주세요.',
          style: TextStyle(color: Colors.black54, fontSize: 15),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            key: const ValueKey('arena-mobile-retry-button'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              '다시 확인',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF0F0F2),
              foregroundColor: Colors.black,
              elevation: 0,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 필요한 변수: 학생용 오류 문구와 재시도 콜백.
/// 작동 원리: 원시 서버 예외 대신 대비가 충분한 안내와 즉시 복구 동작을 함께 제공한다.
class _ArenaErrorBanner extends StatelessWidget {
  const _ArenaErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0EE),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE8AAA3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFF9A3027)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Color(0xFF76251F),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: '다시 시도',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF76251F)),
        ),
      ],
    ),
  );
}

// ignore: unused_element
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
        SizedBox(height: 0),
        Text(
          '참가할 대결',
          style: TextStyle(
            fontSize: 22,
            letterSpacing: -.8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
    return copy;
  }
}

/// 필요한 변수: 데스크톱 여부.
/// 작동 원리: 공정성 규칙을 PC 4열·모바일 2열로 재배치해 큐 진입 전 동일 조건을 비교하게 한다.
// ignore: unused_element
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

// ignore: unused_element
class _QueueCard extends StatelessWidget {
  // ignore: unused_element_parameter
  const _QueueCard({
    required this.data,
    required this.waiting,
    required this.disabled,
    required this.onJoin,
    required this.onCancel,
    // ignore: unused_element_parameter
    this.desktop = false,
    // ignore: unused_element_parameter
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
  bool _loading = true;
  bool _cancelling = false;
  bool _leaving = false;
  bool _polling = false;
  bool _preparing = false;
  String? _error;
  DateTime? _startDeadline;
  DateTime? _cancelDeadline;

  void _leaveReady() {
    if (_loading || _cancelling || _leaving) return;
    if (_state == null) {
      Navigator.of(context).maybePop();
    } else if (_cancelDeadline?.isAfter(DateTime.now()) == true) {
      _cancelWaiting();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('취소 가능 시간이 지났습니다.')));
    }
  }

  void _startMatch() {
    if (!mounted || _loading || _cancelling || _leaving || _state == null)
      return;
    _leaving = true;
    _timer?.cancel();
    _statePoller?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ArenaMatchPage(matchId: widget.matchId),
      ),
    );
  }

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
    if (_loading ||
        _cancelling ||
        _leaving ||
        _cancelDeadline?.isAfter(DateTime.now()) != true)
      return;
    setState(() => _cancelling = true);
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
      _leaving = true;
      _timer?.cancel();
      _statePoller?.cancel();
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('매칭 상태가 바뀌었습니다. 잠시 후 다시 확인해 주세요.')),
        );
      }
    } finally {
      if (mounted && !_leaving) setState(() => _cancelling = false);
    }
  }

  /// 필요한 변수: 경기 ID. 서버 상태를 읽은 뒤 화면에 진입 카운트다운을 시작한다.
  Future<void> _prepare() async {
    if (_preparing || _leaving) return;
    _preparing = true;
    _timer?.cancel();
    _statePoller?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await ArenaApi.instance.matchState(widget.matchId);
      if (!mounted || _leaving) return;
      if (state['finished'] == true) {
        final result = await ArenaApi.instance.matchResult(widget.matchId);
        if (!mounted || _leaving) return;
        _leaving = true;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                ArenaResultPage(matchId: widget.matchId, initialResult: result),
          ),
        );
        return;
      }
      setState(() {
        _state = state;
        _loading = false;
        _cancelRemaining = 3;
      });
      final practice = state['practice'] == true;
      _countdown = practice ? 5 : 3;
      _startDeadline = DateTime.now().add(Duration(seconds: _countdown));
      _cancelDeadline = DateTime.now().add(const Duration(seconds: 3));
      if (practice) _pollForHumanMatch();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _leaving) return;
        final now = DateTime.now();
        setState(() {
          _countdown =
              ((_startDeadline!.difference(now).inMilliseconds / 1000).ceil())
                  .clamp(0, 5);
          _cancelRemaining =
              ((_cancelDeadline!.difference(now).inMilliseconds / 1000).ceil())
                  .clamp(0, 3);
        });
        if (_countdown == 0 && !_cancelling && !_loading) {
          timer.cancel();
          _startMatch();
        }
      });
    } catch (_) {
      if (mounted && !_leaving)
        setState(() {
          _loading = false;
          _error = '경기 준비 상태를 불러오지 못했습니다.';
        });
    } finally {
      _preparing = false;
    }
  }

  /// 필요한 변수: 연습 경기 ID. 5초 대기 중 실제 상대 경기로 교체되었는지 1초마다 확인한다.
  void _pollForHumanMatch() {
    _statePoller?.cancel();
    _statePoller = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || _leaving || _polling || _cancelling) return;
      _polling = true;
      try {
        final state = await ArenaApi.instance.matchState(widget.matchId);
        if (!mounted || _leaving || _cancelling) return;
        if (state['finished'] == true) {
          _statePoller?.cancel();
          _timer?.cancel();
          setState(() => _loading = true);
          final result = await ArenaApi.instance.matchResult(widget.matchId);
          if (mounted && !_leaving) {
            _leaving = true;
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
            _leaving = true;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => ArenaReadyPage(matchId: replacement),
              ),
            );
          }
        }
      } catch (_) {
        if (mounted && !_leaving && _loading)
          setState(() {
            _loading = false;
            _error = '경기 결과를 불러오지 못했습니다.';
          });
      } finally {
        _polling = false;
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
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    final questions = _state?['questions'];
    final count = questions is List && questions.isNotEmpty
        ? questions.length
        : null;
    return StudentHtmlShell(
      title: '대결 준비',
      railWidth: 76,
      mobileBackButton: true,
      activeRoute: AppRoutes.studentDashboard,
      onMenu: _leaveReady,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _leaveReady,
        },
        child: Focus(
          autofocus: true,
          child: ColoredBox(
            color: const Color(0xFFFDFDFE),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Semantics(liveRegion: true, child: Text(_error!)),
                          TextButton(
                            onPressed: _prepare,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF09090B)),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _player(
                              mobile,
                              true,
                              'YOU',
                              '나',
                              '티어 확인 불가',
                            ),
                          ),
                          Container(
                            width: mobile ? 76 : 150,
                            decoration: const BoxDecoration(
                              border: Border.symmetric(
                                vertical: BorderSide(color: Color(0x1909090B)),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  '시작까지',
                                  style: TextStyle(
                                    fontSize: 9,
                                    height: 12.8 / 9,
                                    letterSpacing: 1.26,
                                    color: Color(0xFF71717A),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _loading || _error != null
                                        ? '—'
                                        : '$_countdown',
                                    style: TextStyle(
                                      fontSize: mobile ? 42 : 58,
                                      height: 1,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: (mobile ? 42 : 58) * -.08,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'VS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    height: 1.44,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _player(
                              mobile,
                              false,
                              'OPPONENT',
                              practice
                                  ? '연습 상대'
                                  : (opponent?['nickname']?.toString() ?? '상대'),
                              practice && _state?['bot_tier'] != null
                                  ? '${_state!['bot_tier']} · 연습 경기'
                                  : '티어 · 승률 확인 불가',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _rules(mobile, count),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!mobile) const Spacer(),
                      _action(
                        mobile,
                        '매칭 나가기',
                        false,
                        !_loading &&
                                !_cancelling &&
                                _cancelRemaining > 0 &&
                                !_leaving
                            ? _cancelWaiting
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _action(
                        mobile,
                        '바로 시작',
                        true,
                        !_loading && _error == null && !_cancelling && !_leaving
                            ? _startMatch
                            : null,
                      ),
                    ],
                  ),
                  if (_cancelRemaining <= 0)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        '취소 가능 시간이 지났습니다.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _player(
    bool mobile,
    bool mine,
    String label,
    String name,
    String detail,
  ) => Container(
    constraints: BoxConstraints(minHeight: mobile ? 144 : 190),
    padding: EdgeInsets.symmetric(
      horizontal: mobile ? 8 : 24,
      vertical: mobile ? 16 : 24,
    ),
    color: mine ? const Color(0xFF09090B) : const Color(0xFFFDFDFE),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF71717A),
            fontSize: 9,
            height: 12 / 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.26,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: mine ? Colors.white : const Color(0xFF09090B),
            fontSize: mobile
                ? 20
                : (MediaQuery.sizeOf(context).width * .03).clamp(24, 38),
            fontWeight: FontWeight.w700,
            letterSpacing:
                (mobile
                    ? 20
                    : (MediaQuery.sizeOf(context).width * .03).clamp(24, 38)) *
                -.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF71717A), fontSize: 10),
        ),
      ],
    ),
  );

  Widget _rules(bool mobile, int? count) {
    final narrow = MediaQuery.sizeOf(context).width <= 820;
    final header = Padding(
      padding: narrow
          ? const EdgeInsets.only(bottom: 16)
          : const EdgeInsets.fromLTRB(0, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '대결 규칙',
            style: TextStyle(fontSize: 10, color: Color(0xFF71717A)),
          ),
          SizedBox(height: 5),
          Text(
            '공정한 실시간 풀이',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    final rows = [
      [
        '01',
        count == null ? '문항 수 확인 불가' : '같은 ${count}문항',
        '서버가 제공한 같은 문항을 같은 순서로 풉니다.',
      ],
      ['02', '제출 즉시 점수 반영', '제출한 문항은 다시 돌아갈 수 없습니다.'],
      ['03', '상대 정답은 비공개', '상대의 제출 진도와 점수만 공유합니다.'],
    ];
    final items = rows
        .map(
          (r) => Container(
            constraints: BoxConstraints(minHeight: mobile ? 58 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                right: !mobile && r[0] != '03'
                    ? const BorderSide(color: Color(0x1909090B))
                    : BorderSide.none,
                bottom: mobile && r[0] != '03'
                    ? const BorderSide(color: Color(0x1909090B))
                    : BorderSide.none,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    r[0],
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF71717A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r[1],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        r[2],
                        style: const TextStyle(
                          fontSize: 9,
                          height: 1.45,
                          color: Color(0xFF71717A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
    final list = Container(
      padding: EdgeInsets.only(top: narrow ? 14 : 0),
      decoration: BoxDecoration(
        border: narrow
            ? const Border(top: BorderSide(color: Color(0x1909090B)))
            : const Border(left: BorderSide(color: Color(0x1909090B))),
      ),
      child: mobile
          ? Column(children: items)
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: items.map((w) => Expanded(child: w)).toList(),
              ),
            ),
    );
    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 20),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x1909090B)),
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, list],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 210, child: header),
                Expanded(child: list),
              ],
            ),
    );
  }

  Widget _action(bool mobile, String label, bool primary, VoidCallback? tap) {
    final button = OutlinedButton(
      onPressed: tap,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.standard,
        minimumSize: const Size(150, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        backgroundColor: primary
            ? const Color(0xFF09090B)
            : const Color(0xFFFDFDFE),
        foregroundColor: primary ? Colors.white : const Color(0xFF09090B),
        shape: const RoundedRectangleBorder(),
        side: const BorderSide(color: Color(0xFF09090B)),
        textStyle: TextStyle(
          fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label)),
          if (primary) ...[
            const SizedBox(width: 18),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ],
      ),
    );
    return mobile ? Expanded(child: button) : button;
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
  final _search = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _loadingMore = false;
  String? _pageError;
  int _nextOffset = 0;
  String _scope = 'all';
  Timer? _searchDebounce;
  int _queryGeneration = 0;
  String? _viewerId;
  bool _authenticationRequired = false;

  void _restartRankingQuery({bool debounce = false}) {
    _searchDebounce?.cancel();
    _queryGeneration++;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _pageError = null;
      _nextOffset = 0;
    });
    if (_rankScroll.hasClients) _rankScroll.jumpTo(0);
    if (debounce)
      _searchDebounce = Timer(
        const Duration(milliseconds: 300),
        () => unawaited(_load()),
      );
    else
      unawaited(_load());
  }

  final _rankScroll = ScrollController();
  final _rankViewport = GlobalKey();
  final _mybarFlow = GlobalKey();
  final _headerFlow = GlobalKey();
  final _mybarOverlay = GlobalKey();
  final _headerOverlay = GlobalKey();
  bool _mybarPinned = false;
  bool _headerPinned = false;
  bool _rankMeasureQueued = false;
  double _mybarHeight = 84;
  double _headerHeight = 42;
  double _stickyLeft = 0;
  double _stickyWidth = 0;
  double _headerStickyTop = 84;

  void _measureRankSticky() {
    if (_rankMeasureQueued || !mounted) return;
    _rankMeasureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rankMeasureQueued = false;
      if (!mounted) return;
      final viewport = _rankViewport.currentContext?.findRenderObject();
      final mine = _mybarFlow.currentContext?.findRenderObject();
      final header = _headerFlow.currentContext?.findRenderObject();
      if (viewport is! RenderBox ||
          mine is! RenderBox ||
          header is! RenderBox ||
          !mine.hasSize ||
          !header.hasSize)
        return;
      final viewportOrigin = viewport.localToGlobal(Offset.zero);
      final mineOrigin = mine.localToGlobal(Offset.zero);
      final headerOrigin = header.localToGlobal(Offset.zero);
      final visibleMine = _mybarPinned
          ? _mybarOverlay.currentContext?.findRenderObject()
          : mine;
      final visibleHeader = _headerPinned
          ? _headerOverlay.currentContext?.findRenderObject()
          : header;
      final mineHeight = visibleMine is RenderBox && visibleMine.hasSize
          ? visibleMine.size.height
          : mine.size.height;
      final headerHeight = visibleHeader is RenderBox && visibleHeader.hasSize
          ? visibleHeader.size.height
          : header.size.height;
      final rawTop = MediaQuery.sizeOf(context).width <= 720 ? 116.0 : 84.0;
      final top = MediaQuery.textScalerOf(context).scale(18) / 18 > 1.3
          ? math.max(rawTop, mineHeight)
          : rawTop;
      final minePinned = mineOrigin.dy < viewportOrigin.dy;
      final headerPinned = headerOrigin.dy < viewportOrigin.dy + top;
      final left = mineOrigin.dx - viewportOrigin.dx;
      if (_mybarPinned != minePinned ||
          _headerPinned != headerPinned ||
          (_stickyLeft - left).abs() > .1 ||
          (_stickyWidth - mine.size.width).abs() > .1 ||
          (_mybarHeight - mineHeight).abs() > .1 ||
          (_headerHeight - headerHeight).abs() > .1 ||
          (_headerStickyTop - top).abs() > .1) {
        setState(() {
          _mybarHeight = mineHeight;
          _headerHeight = headerHeight;
          _mybarPinned = minePinned;
          _headerPinned = headerPinned;
          _stickyLeft = left;
          _stickyWidth = mine.size.width;
          _headerStickyTop = top;
        });
      }
    });
  }

  bool get _knownMetadata {
    final value = _data;
    return value != null &&
        value['total'] is int &&
        value['total'] >= 0 &&
        value['viewer_user_id'] is String &&
        (value['viewer_user_id'] as String).isNotEmpty &&
        value['has_more'] is bool &&
        value['limit'] is int &&
        value['limit'] >= 1 &&
        value['limit'] <= 100 &&
        value['offset'] is int &&
        value['offset'] >= 0;
  }

  Map? get _myProfile {
    final value = _data?['my_profile'];
    return _knownMetadata &&
            value is Map &&
            value['user_id'] == _data?['viewer_user_id']
        ? value
        : null;
  }

  String get _myRank {
    if (!_knownMetadata) return '미확인';
    final rank = _data?['my_rank'];
    if (rank == null) return '순위 없음';
    return rank is int && rank > 0 ? '$rank' : '미확인';
  }

  @override
  void initState() {
    super.initState();
    _rankScroll.addListener(_measureRankSticky);
    _load();
  }

  /// 선택 큐의 실제 최신 페이지를 조회한다. 추가 페이지 실패 시 이미 읽은 목록은 보존한다.
  Future<void> _load({bool append = false}) async {
    if (append && (_loading || _loadingMore)) return;
    final generation = append ? _queryGeneration : ++_queryGeneration;
    final query = _search.text.trim();
    final scope = _scope;
    final previous = _data;
    final oldItems = previous?['items'] as List? ?? const [];
    final offset = append ? _nextOffset : 0;
    setState(() {
      _authenticationRequired = false;
      if (append) {
        _loadingMore = true;
        _pageError = null;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      await ApiClient.instance.requireToken();
      final value = await ArenaApi.instance.rankings(
        widget.queueType,
        offset: offset,
        query: query,
        scope: scope,
        forceRefresh: true,
      );
      if (!mounted || generation != _queryGeneration) return;
      if (value['query'] != query || value['scope'] != scope)
        throw const FormatException('랭킹 검색 조건의 응답을 확인하지 못했습니다.');
      if (value['items'] is! List) {
        throw const FormatException('랭킹 목록을 확인하지 못했습니다.');
      }
      final pageItems = value['items'] as List;
      if (pageItems.length > 100 ||
          (value.containsKey('queue_type') &&
              value['queue_type'] != widget.queueType)) {
        throw const FormatException('랭킹 페이지 범위를 확인하지 못했습니다.');
      }
      {
        final total = value['total'];
        if (total is! int ||
            total < 0 ||
            value['offset'] != offset ||
            value['limit'] != 100 ||
            value['has_more'] is! bool ||
            value['has_more'] != (offset + pageItems.length < total) ||
            value['viewer_user_id'] is! String ||
            (value['viewer_user_id'] as String).isEmpty) {
          throw const FormatException('전체 랭킹 정보를 확인하지 못했습니다.');
        }
        if (_viewerId != null && value['viewer_user_id'] != _viewerId)
          throw const FormatException('랭킹 계정의 응답을 확인하지 못했습니다.');
      }
      if (append) {
        if (value['viewer_user_id'] != previous?['viewer_user_id'] ||
            value['offset'] != offset ||
            value['items'] is! List) {
          throw const FormatException('랭킹 페이지의 계정 또는 범위를 확인하지 못했습니다.');
        }
        final newItems = value['items'] as List;
        if (newItems.isEmpty && value['has_more'] == true) {
          throw const FormatException('다음 랭킹 페이지가 비어 있습니다.');
        }
        final owners = oldItems
            .whereType<Map>()
            .map((e) => e['user_id'])
            .toSet();
        setState(
          () => _data = {
            ...value,
            'items': [
              ...oldItems,
              ...newItems.where(
                (e) => e is Map && !owners.contains(e['user_id']),
              ),
            ],
          },
        );
        _nextOffset = offset + newItems.length;
      } else {
        setState(() => _data = value);
        _nextOffset = (value['items'] as List? ?? const []).length;
      }
      final viewer = value['viewer_user_id'];
      if (viewer is String) _viewerId ??= viewer;
    } catch (error) {
      if (mounted && generation == _queryGeneration) {
        setState(() {
          if (error is ApiException && error.statusCode == 401) {
            _authenticationRequired = true;
            _data = null;
            _pageError = null;
            _nextOffset = 0;
            _error = studentFacingApiError(error, fallback: '로그인을 확인해 주세요.');
          } else {
            append
                ? _pageError = studentFacingApiError(
                    error,
                    fallback: '다음 랭킹을 불러오지 못했어요.',
                  )
                : _error = studentFacingApiError(
                    error,
                    fallback: '랭킹을 불러오지 못했어요.',
                  );
          }
        });
      }
    } finally {
      if (mounted && generation == _queryGeneration)
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _rankScroll.dispose();
    _search.dispose();
    super.dispose();
  }

  String _metricValue(String label) {
    if (label == '내 순위') {
      final rank = int.tryParse(_myRank);
      return rank == null ? _myRank : '${_formatArenaRating(rank)}위';
    }
    final profile = _myProfile;
    if (profile == null) return '미확인';
    if (label == '티어 점수')
      return profile['rating'] is num
          ? _formatArenaRating((profile['rating'] as num).round())
          : '미확인';
    final wins = profile['wins'],
        losses = profile['losses'],
        draws = profile['draws'];
    if (wins is! int ||
        losses is! int ||
        draws is! int ||
        wins < 0 ||
        losses < 0 ||
        draws < 0)
      return '미확인';
    if (label == '누적 전적') return '$wins승 $losses패 $draws무';
    final total = wins + losses + draws;
    return total == 0 ? '경기 없음' : '${(wins * 100 / total).toStringAsFixed(1)}%';
  }

  Widget _metric(
    String label,
    bool mobile, {
    bool lastColumn = false,
    bool lastRow = true,
  }) => Container(
    constraints: BoxConstraints(minHeight: mobile ? 58 : 82),
    padding: EdgeInsets.symmetric(
      horizontal: mobile ? 11 : 18,
      vertical: mobile ? 8 : 13,
    ),
    decoration: BoxDecoration(
      border: Border(
        right: lastColumn
            ? BorderSide.none
            : const BorderSide(color: Color(0x1909090B)),
        bottom: lastRow
            ? BorderSide.none
            : const BorderSide(color: Color(0x1909090B)),
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF71717A)),
        ),
        const SizedBox(height: 4),
        Text(
          _metricValue(label),
          key: ValueKey('arena-ranking-metric-$label'),
          style: TextStyle(
            fontSize: mobile ? 14 : 18,
            fontWeight: FontWeight.w700,
            letterSpacing: (mobile ? 14 : 18) * -.035,
          ),
        ),
      ],
    ),
  );

  Widget _mybar(bool mobile, {bool margin = true}) => Container(
    key: const ValueKey('arena-ranking-mybar'),
    margin: EdgeInsets.only(top: margin ? 12 : 0),
    decoration: BoxDecoration(
      color: const Color(0xFFFDFDFE),
      border: Border.all(color: const Color(0xFF09090B)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1209090B),
          offset: Offset(0, 6),
          blurRadius: 20,
        ),
      ],
    ),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: mobile ? 58 : 64,
            constraints: BoxConstraints(minHeight: mobile ? 116 : 82),
            color: const Color(0xFF09090B),
            alignment: Alignment.center,
            child: Text(
              const {'A', 'B', 'C', 'D', 'E'}.contains(_myProfile?['tier'])
                  ? _myProfile!['tier'] as String
                  : '—',
              key: const ValueKey('arena-ranking-tier-value'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -.72,
              ),
            ),
          ),
          Expanded(
            child: mobile
                ? Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _metric('내 순위', true, lastRow: false),
                            ),
                            Expanded(
                              child: _metric('티어 점수', true, lastRow: false),
                            ),
                          ],
                        ),
                      ),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _metric('누적 전적', true)),
                            Expanded(
                              child: _metric('승률', true, lastColumn: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final label in ['내 순위', '티어 점수', '누적 전적', '승률'])
                        Expanded(
                          child: _metric(
                            label,
                            false,
                            lastColumn: label == '승률',
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _toolbar(int? count, bool mobile, bool inline) {
    final tabs = Row(
      children: [
        for (var index = 0; index < 3; index++) ...[
          if (index > 0) const SizedBox(width: 4),
          if (mobile)
            Expanded(child: _rankingTab(['전체', '내 티어', '친구'][index]))
          else
            SizedBox(
              width: 86,
              child: _rankingTab(['전체', '내 티어', '친구'][index]),
            ),
        ],
      ],
    );
    final countLabel = Text(
      count == null ? '—명' : '$count명',
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 10, color: Color(0xFF71717A)),
    );
    final search = Container(
      key: const ValueKey('arena-ranking-search-box'),
      height: 50,
      padding: const EdgeInsets.only(left: 13),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x1909090B)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            child: StudentHtmlGlyph(
              icon: StudentHtmlIcon.pageSearch,
              size: 18,
              color: Color(0xFF09090B),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              key: const ValueKey('arena-ranking-search'),
              controller: _search,
              maxLength: 80,
              onChanged: (_) => _restartRankingQuery(debounce: true),
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: '참가자 검색',
                counterText: '',
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (_search.text.isNotEmpty)
            IconButton(
              tooltip: '검색어 지우기',
              onPressed: () {
                _search.clear();
                _restartRankingQuery();
              },
              icon: const StudentHtmlGlyph(
                icon: StudentHtmlIcon.close,
                size: 17,
                color: Color(0xFF09090B),
              ),
            ),
        ],
      ),
    );
    return Container(
      key: const ValueKey('arena-ranking-toolbar'),
      margin: const EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(mobile ? 8 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFE),
        border: Border.all(color: const Color(0x1909090B)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (inline) {
            final searchWidth = math.min(360.0, constraints.maxWidth - 328);
            // CSS grid auto columns share the extra width after intrinsic 266/42.
            final leftWidth =
                (constraints.maxWidth - searchWidth - 20 + 266 - 42) / 2;
            return Row(
              children: [
                SizedBox(width: leftWidth, child: tabs),
                const SizedBox(width: 10),
                SizedBox(width: searchWidth, child: search),
                const SizedBox(width: 10),
                Expanded(child: countLabel),
              ],
            );
          }
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: tabs),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 42),
                    child: countLabel,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              search,
            ],
          );
        },
      ),
    );
  }

  Widget _rankingTab(String label) => Tooltip(
    message: label,
    child: TextButton(
      key: ValueKey('arena-ranking-filter-$label'),
      onPressed: () {
        _scope = {'전체': 'all', '내 티어': 'my_tier', '친구': 'friends'}[label]!;
        _restartRankingQuery();
      },
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const RoundedRectangleBorder(),
        backgroundColor:
            _scope == {'전체': 'all', '내 티어': 'my_tier', '친구': 'friends'}[label]
            ? const Color(0xFF09090B)
            : Colors.transparent,
        foregroundColor:
            _scope == {'전체': 'all', '내 티어': 'my_tier', '친구': 'friends'}[label]
            ? Colors.white
            : const Color(0xFF71717A),
        disabledForegroundColor: const Color(0xFF71717A),
        textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      child: Text(label),
    ),
  );

  Widget _tableRow(
    Map<String, dynamic>? item,
    int index,
    bool mobile, {
    bool first = false,
    bool last = false,
  }) {
    final header = item == null;
    final hasName =
        item?['name'] is String && (item!['name'] as String).trim().isNotEmpty;
    final name = hasName ? (item!['name'] as String).trim() : '표시 이름 미등록';
    final mine =
        !header &&
        _knownMetadata &&
        item['user_id'] == _data?['viewer_user_id'];
    final rating = item?['rating'];
    final validRecord =
        !header &&
        [
          'wins',
          'losses',
          'draws',
        ].every((key) => item![key] is int && item[key] >= 0);
    final games = validRecord
        ? (item!['wins'] + item['losses'] + item['draws']) as int
        : 0;
    final record = validRecord
        ? '${item!['wins']}승 ${item['losses']}패 ${item['draws']}무'
        : '—';
    final percent = validRecord
        ? (games == 0
              ? '경기 없음'
              : '${(item!['wins'] * 100 / games).toStringAsFixed(1)}%')
        : '—';
    final tier = item?['tier'] is String && (item!['tier'] as String).isNotEmpty
        ? item['tier'] as String
        : '—';
    final change = item?['rating_change'];
    Widget text(
      String value,
      double size, {
      Color color = const Color(0xFF09090B),
      FontWeight weight = FontWeight.w700,
      double? spacing,
    }) => Text(
      value,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: spacing,
      ),
    );
    final headerNames = ['순위', '참가자', '티어', '점수', '전적 · 승률', '변화'];
    final user = Row(
      children: [
        Container(
          key: ValueKey('arena-ranking-avatar-${item?['user_id']}'),
          width: mobile ? 32 : 36,
          height: mobile ? 32 : 36,
          alignment: Alignment.center,
          color: const Color(0xFF09090B),
          child: text(
            hasName ? String.fromCharCode(name.runes.first) : '—',
            10,
            color: Colors.white,
            weight: FontWeight.w900,
          ),
        ),
        SizedBox(width: mobile ? 7 : 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!mobile && item?['friend'] == true) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0x1909090B)),
                  ),
                  child: text(
                    '친구',
                    8,
                    color: const Color(0xFF71717A),
                    weight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final cells = header
        ? headerNames
              .map(
                (name) => text(
                  name,
                  9,
                  color: const Color(0xFF71717A),
                  weight: FontWeight.w900,
                ),
              )
              .toList()
        : <Widget>[
            text(
              item['rank'] is int && item['rank'] > 0
                  ? '${item['rank']}'
                  : '미확인',
              16,
              spacing: -.48,
            ),
            user,
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                key: ValueKey('arena-ranking-tier-${item['user_id']}'),
                constraints: const BoxConstraints(minWidth: 38),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x1909090B)),
                ),
                child: text(tier, 9, weight: FontWeight.w900),
              ),
            ),
            text(rating is num ? _formatArenaRating(rating.round()) : '—', 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(child: text(record, 11)),
                const SizedBox(width: 8),
                text(
                  percent,
                  9,
                  color: const Color(0xFF71717A),
                  weight: FontWeight.w400,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: text(
                change is num ? '${change >= 0 ? '+' : ''}$change' : '—',
                10,
                weight: FontWeight.w900,
              ),
            ),
          ];
    return Container(
      key: header
          ? const ValueKey('arena-ranking-table-header')
          : ValueKey('arena-ranking-row-${item['user_id']}'),
      constraints: BoxConstraints(minHeight: header ? 42 : 68),
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 10 : 18,
        vertical: header ? 0 : 9,
      ),
      decoration: BoxDecoration(
        color: header || mine
            ? const Color(0xFFF3F3F5)
            : const Color(0xFFFDFDFE),
        border: Border(
          left: const BorderSide(color: Color(0x1909090B)),
          right: const BorderSide(color: Color(0x1909090B)),
          top: !header && first
              ? BorderSide.none
              : const BorderSide(color: Color(0x1909090B)),
          bottom: header || last
              ? const BorderSide(color: Color(0x1909090B))
              : BorderSide.none,
        ),
      ),
      foregroundDecoration: mine
          ? const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFF09090B), width: 4),
              ),
            )
          : null,
      child: Row(
        children: [
          for (var i = 0; i < (mobile ? 4 : 6); i++)
            if (i == 1)
              Expanded(child: cells[i])
            else
              SizedBox(
                width: mobile
                    ? <double>[42, 0, 48, 68][i]
                    : <double>[64, 0, 70, 100, 130, 70][i],
                child: cells[i],
              ),
        ],
      ),
    );
  }

  /// Fetch another page only after a user scroll ends near the list bottom.
  Widget _rankingScroll({
    required EdgeInsets padding,
    required Widget child,
    required bool mobile,
  }) => NotificationListener<ScrollNotification>(
    onNotification: (event) {
      if (event is ScrollEndNotification &&
          event.depth == 0 &&
          event.metrics.axis == Axis.vertical &&
          event.metrics.extentAfter < 160 &&
          _knownMetadata &&
          _data?['has_more'] == true &&
          !_loading &&
          !_loadingMore &&
          _pageError == null) {
        unawaited(_load(append: true));
      }
      return false;
    },
    child: SizedBox.expand(
      key: _rankViewport,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(
            1180.0,
            math.max(0.0, constraints.maxWidth - padding.horizontal),
          );
          final left = (constraints.maxWidth - width) / 2;
          return Stack(
            children: [
              SingleChildScrollView(
                key: const ValueKey('arena-ranking-scroll'),
                controller: _rankScroll,
                padding: padding,
                child: child,
              ),
              if (_headerPinned && _stickyWidth > 0)
                Positioned(
                  top: _headerStickyTop,
                  left: left,
                  width: width,
                  child: KeyedSubtree(
                    key: _headerOverlay,
                    child: _tableRow(null, 0, mobile),
                  ),
                ),
              if (_mybarPinned && _stickyWidth > 0)
                Positioned(
                  top: 0,
                  left: left,
                  width: width,
                  child: KeyedSubtree(
                    key: _mybarOverlay,
                    child: _mybar(mobile, margin: false),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    _measureRankSticky();
    final mobile = viewportWidth <= 720;
    final padding = viewportWidth <= 720
        ? 13.0
        : (viewportWidth * .024).clamp(18.0, 34.0);
    final items = (_data?['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final query = _search.text.trim();
    final indexed = items.asMap().entries.toList();
    final known = !_loading && _error == null && _data != null;
    int? visibleCount;
    if (known && _knownMetadata) {
      visibleCount = _data!['total'] as int;
    }
    return StudentHtmlShell(
      title: '아레나 랭킹',
      activeRoute: AppRoutes.studentDashboard,
      railWidth: 76,
      mobileBackButton: true,
      onMenu: () => Navigator.of(context).maybePop(),
      child: ColoredBox(
        color: const Color(0xFFF0F0F2),
        child: _rankingScroll(
          mobile: mobile,
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    constraints: BoxConstraints(minHeight: mobile ? 62 : 72),
                    padding: EdgeInsets.fromLTRB(2, 4, 2, mobile ? 12 : 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x1909090B)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '시즌 정보 미제공',
                                style: TextStyle(
                                  fontSize: 9,
                                  height: 17.6 / 9,
                                  letterSpacing: 1.26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF71717A),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '전체 랭킹',
                                style: TextStyle(
                                  fontSize: mobile
                                      ? 28
                                      : (viewportWidth * .034).clamp(
                                          29.0,
                                          42.0,
                                        ),
                                  height: 1,
                                  letterSpacing:
                                      -.055 *
                                      (mobile
                                          ? 28
                                          : (viewportWidth * .034).clamp(
                                              29.0,
                                              42.0,
                                            )),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: mobile ? 116 : 132,
                          ),
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.arena),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(mobile ? 116 : 132, 48),
                              visualDensity: VisualDensity.standard,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: const RoundedRectangleBorder(),
                              foregroundColor: const Color(0xFF09090B),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              side: const BorderSide(color: Color(0xFF09090B)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '대결 참가',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(width: 18),
                                StudentHtmlGlyph(
                                  icon: StudentHtmlIcon.arrow,
                                  size: 16,
                                  color: Color(0xFF09090B),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      key: _mybarFlow,
                      width: double.infinity,
                      child: _mybarPinned
                          ? SizedBox(height: _mybarHeight)
                          : _mybar(mobile, margin: false),
                    ),
                  ),
                  _toolbar(visibleCount, mobile, viewportWidth > 820),
                  const SizedBox(height: 8),
                  SizedBox(
                    key: _headerFlow,
                    width: double.infinity,
                    child: _headerPinned
                        ? SizedBox(height: _headerHeight)
                        : _tableRow(null, 0, mobile),
                  ),
                  if (_loading)
                    const SizedBox(
                      height: 150,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: _authenticationRequired
                                  ? () => Navigator.of(
                                      context,
                                    ).pushNamed(AppRoutes.login)
                                  : _load,
                              child: Text(
                                _authenticationRequired ? '로그인하기' : '다시 시도',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (indexed.isEmpty)
                    SizedBox(
                      height: 150,
                      child: Center(
                        child: Text(
                          query.isNotEmpty
                              ? '검색 결과가 없습니다.'
                              : '현재 서버에서 제공된 랭킹 데이터가 없습니다.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF71717A),
                          ),
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < indexed.length; i++)
                      _tableRow(
                        indexed[i].value,
                        indexed[i].key,
                        mobile,
                        first: i == 0,
                        last: i == indexed.length - 1,
                      ),
                  if (_loadingMore)
                    Semantics(
                      liveRegion: true,
                      child: const Text(
                        '랭킹을 불러오는 중…',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF71717A),
                        ),
                      ),
                    ),
                  if (_pageError != null)
                    Column(
                      children: [
                        Text(
                          _pageError!,
                          key: const ValueKey('arena-ranking-page-error'),
                        ),
                        OutlinedButton(
                          key: const ValueKey('arena-ranking-page-retry'),
                          onPressed: _loadingMore
                              ? null
                              : () => _load(append: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF09090B),
                            shape: const RoundedRectangleBorder(),
                            minimumSize: const Size(0, 48),
                            visualDensity: VisualDensity.standard,
                          ),
                          child: const Text('다음 페이지 다시 시도'),
                        ),
                      ],
                    ),
                  Semantics(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '${_knownMetadata ? '현재 조건의 총 ${_data!["total"]}명 중 ${items.length}명 불러옴.' : '전체 인원·내 순위는 서버 응답에서 확인하지 못했습니다.'} 시즌·점수 변화 정보는 미제공입니다.',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF71717A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ArenaMatchPage extends StatefulWidget {
  const ArenaMatchPage({super.key, required this.matchId, this.openSocket});
  final String matchId;

  /// 실시간 이벤트 테스트에서만 주입한다. 배포 앱은 Vercel REST API만 사용한다.
  final Future<ArenaSocket> Function()? openSocket;
  @override
  State<ArenaMatchPage> createState() => _ArenaMatchPageState();
}

class _ArenaMatchPageState extends State<ArenaMatchPage> {
  Map<String, dynamic>? _state;
  int _index = 0;
  int _remaining = 1200;
  final _answer = TextEditingController();
  Timer? _timer;
  Timer? _fallbackPoller;
  ArenaSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  String? _feedback;
  bool _switchingMatch = false;
  bool _submitting = false;
  bool _showingResult = false;
  bool _loadingState = false;
  bool _replaying = false;
  bool _answerAcknowledged = false;
  String? _selectedChoice;
  String? _pendingQuestionId;
  String? _pendingAnswer;
  String? _pendingKey;
  String? _loadError;
  Timer? _ackTimer;
  final Set<String> _acknowledgedIds = {};
  DateTime? _remainingDeadline;
  final _matchScroll = ScrollController();
  final _matchViewport = GlobalKey();
  final _footerAnchor = GlobalKey();
  final _questionAnchor = GlobalKey();
  double _footerTranslation = 0;
  bool _stickyMeasureQueued = false;

  void _scheduleStickyMeasure() {
    if (_stickyMeasureQueued || !mounted) return;
    _stickyMeasureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stickyMeasureQueued = false;
      if (!mounted) return;
      final viewport = _matchViewport.currentContext?.findRenderObject();
      final footer = _footerAnchor.currentContext?.findRenderObject();
      final panel = _questionAnchor.currentContext?.findRenderObject();
      if (viewport is! RenderBox ||
          footer is! RenderBox ||
          panel is! RenderBox ||
          !viewport.hasSize ||
          !footer.hasSize ||
          !panel.hasSize)
        return;
      final viewportBottom =
          viewport.localToGlobal(Offset.zero).dy + viewport.size.height;
      // RenderTransform의 자체좌표는 자연flow위치이며 자식의paint좌표만 이동한다.
      final footerTop = footer.localToGlobal(Offset.zero).dy;
      final panelTop = panel.localToGlobal(Offset.zero).dy;
      final next = math.max(
        panelTop - footerTop,
        math.min(0.0, viewportBottom - footerTop - footer.size.height),
      );
      if ((_footerTranslation - next).abs() > .1)
        setState(() => _footerTranslation = next);
    });
  }

  int _firstUnsubmitted(Map<String, dynamic> value) {
    final questions = value['questions'] as List? ?? const [];
    final submitted =
        (value['submitted_question_ids'] as List? ?? const [])
            .map((e) => e.toString())
            .toSet()
          ..addAll(_acknowledgedIds);
    for (var i = 0; i < questions.length; i++) {
      if (questions[i] is Map &&
          !submitted.contains(questions[i]['id']?.toString()))
        return i;
    }
    return questions.length;
  }

  @override
  void initState() {
    super.initState();
    _matchScroll.addListener(_scheduleStickyMeasure);
    _connect();
  }

  @override
  void dispose() {
    _matchScroll.dispose();
    _ackTimer?.cancel();
    _timer?.cancel();
    _fallbackPoller?.cancel();
    _socketSubscription?.cancel();
    _socket?.close();
    _answer.dispose();
    super.dispose();
  }

  /// 필요한 변수는 경기 ID다. 기본 경로는 Vercel REST 상태 조회와 폴링이다.
  /// 테스트에서 이벤트 소스를 주입한 경우에만 해당 계약을 검증한다.
  Future<void> _connect() async {
    if (widget.openSocket == null) {
      await _load();
      _startFallbackPolling();
      return;
    }
    try {
      final socket = await widget.openSocket!.call();
      if (!mounted) {
        await socket.close();
        return;
      }
      _socket = socket;
      _socketSubscription = socket.events.listen(
        _handleSocketEvent,
        onError: (_) => _socketLost(),
        onDone: _socketLost,
      );
    } catch (_) {
      await _load();
      _startFallbackPolling();
    }
  }

  void _socketLost() {
    final socket = _socket;
    _socket = null;
    unawaited(socket?.close());
    if (!mounted || _showingResult || _switchingMatch) return;
    _startFallbackPolling();
    if (_pendingQuestionId != null && _submitting) unawaited(_replayPending());
  }

  /// 필요한 변수 없음.
  /// 작동 원리: Vercel REST 상태를 2초 간격으로 확인해 경기 종료·교체를 감지한다.
  void _startFallbackPolling() {
    _fallbackPoller?.cancel();
    _fallbackPoller = Timer(const Duration(seconds: 2), () async {
      if (!mounted || _switchingMatch || _showingResult) return;
      try {
        await _load();
      } catch (error) {
        if (mounted) {
          setState(
            () => _feedback = studentFacingApiError(
              error,
              fallback: '경기 상태를 갱신하지 못했어요.',
            ),
          );
        }
      }
      if (mounted && !_switchingMatch && !_showingResult) {
        _startFallbackPolling();
      }
    });
  }

  /// 필요한 변수는 최신 경기 상태다.
  /// 작동 원리는 서버가 반환한 제출 완료 문항을 건너뛰고 아직 풀지 않은 첫 문항만 화면에 고정하는 것이다.
  void _applyMatchState(Map<String, dynamic> value) {
    if (value['match_id'] != null && value['match_id'] != widget.matchId)
      return;
    final nextIndex = _firstUnsubmitted(value);
    setState(() {
      _state = value;
      _remaining = (value['remaining_seconds'] as num?)?.toInt() ?? 0;
      _remainingDeadline = DateTime.now().add(
        Duration(seconds: math.max(0, _remaining)),
      );
      if (_pendingQuestionId == null && !_answerAcknowledged)
        _index = nextIndex;
      _loadError = null;
    });
  }

  /// 필요한 변수는 선택적으로 WebSocket이 전달한 종료 결과다.
  /// 작동 원리는 모든 타이머·소켓을 닫고 결과를 한 번만 조회한 뒤 현재 경기 화면을 분석 화면으로 즉시 교체하는 것이다.
  Future<void> _openResult([Map<String, dynamic>? initialResult]) async {
    if (_showingResult || !mounted) return;
    _showingResult = true;
    if (_state != null) _state!['finished'] = true;
    _ackTimer?.cancel();
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
      setState(
        () => _feedback = studentFacingApiError(
          error,
          fallback: '경기는 종료됐지만 결과를 불러오지 못했어요.',
        ),
      );
      _startFallbackPolling();
    }
  }

  /// 필요한 변수는 서버 이벤트 유형과 data 본문이다.
  /// 경기 상태·답안 결과·종료를 각각 기존 화면 상태와 피드백으로 연결한다.
  void _handleSocketEvent(Map<String, dynamic> event) {
    if (!mounted || _switchingMatch || _showingResult) return;
    final type = event['type']?.toString();
    final rawData = event['data'];
    if (rawData is Map &&
        rawData['match_id'] != null &&
        rawData['match_id'] != widget.matchId)
      return;
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
      _acceptAnswerResult(Map<String, dynamic>.from(rawData));
    } else if (type == 'match_finished' && rawData is Map) {
      unawaited(_openResult(Map<String, dynamic>.from(rawData)));
    } else if (type == 'error') {
      setState(() {
        _submitting = false;
        _feedback =
            event['message']?.toString() ??
            '제출 응답을 확인하지 못했습니다. 같은 요청으로 다시 확인하세요.';
      });
    }
  }

  /// 필요한 변수는 현재 남은 시간이다. 서버 상태 사이 구간만 1초 단위로 보간한다.
  void _startLocalTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _showingResult) return;
      if (_remaining > 0) {
        setState(
          () => _remaining = math.max(
            0,
            ((_remainingDeadline?.difference(DateTime.now()).inMilliseconds ??
                        0) /
                    1000)
                .ceil(),
          ),
        );
        if (_remaining == 0) unawaited(_load());
      }
    });
  }

  Future<void> _load() async {
    if (_loadingState || _switchingMatch || _showingResult) return;
    _loadingState = true;
    try {
      final value = await ArenaApi.instance.matchState(widget.matchId);
      if (!mounted || _switchingMatch || _showingResult) return;
      if (value['match_id'] != null && value['match_id'] != widget.matchId)
        throw const FormatException('경기 상태 ID가 일치하지 않습니다.');
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
    } catch (error) {
      if (mounted)
        setState(
          () => _loadError = studentFacingApiError(
            error,
            fallback: '경기 상태를 불러오지 못했습니다.',
          ),
        );
    } finally {
      _loadingState = false;
    }
  }

  /// 필요한 변수: 서버가 성립시킨 실제 사용자 경기 ID.
  /// 작동 원리: 연습 소켓과 타이머를 먼저 닫고 현재 라우트를 동일한 실전 경기 화면으로 교체한다.
  Future<void> _replaceWithHumanMatch(String matchId) async {
    if (_switchingMatch || !mounted) return;
    _switchingMatch = true;
    _ackTimer?.cancel();
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
    if (_submitting ||
        _showingResult ||
        _switchingMatch ||
        _answerAcknowledged ||
        _state?['finished'] == true ||
        _remaining <= 0 ||
        _remainingDeadline?.isAfter(DateTime.now()) == false ||
        answer.trim().isEmpty)
      return;
    final questions = _state?['questions'] as List? ?? const [];
    if (questions.isEmpty || _index >= questions.length) return;
    final question = Map<String, dynamic>.from(questions[_index] as Map);
    final questionId = question['id']?.toString();
    if (questionId == null || questionId.isEmpty) return;
    if (_acknowledgedIds.contains(questionId)) return;
    _pendingQuestionId ??= questionId;
    if (_pendingQuestionId != questionId) return;
    _pendingAnswer ??= answer;
    _pendingKey ??=
        'arena-${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(0x100000000).toRadixString(16)}';
    setState(() {
      _submitting = true;
      _feedback = null;
    });
    try {
      final socket = _socket;
      if (socket != null) {
        socket.send({
          'type': 'submit_answer',
          'question_id': _pendingQuestionId,
          'answer': _pendingAnswer,
          'idempotency_key': _pendingKey,
        });
        _ackTimer?.cancel();
        _ackTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && _submitting) unawaited(_replayPending());
        });
        return;
      }
      await _replayPending();
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _feedback = studentFacingApiError(error, fallback: '답안을 제출하지 못했어요.');
        });
        if (_socket != null) _socketLost();
      }
    }
  }

  Future<void> _replayPending() async {
    final id = _pendingQuestionId, answer = _pendingAnswer, key = _pendingKey;
    if (!mounted ||
        _replaying ||
        _showingResult ||
        _switchingMatch ||
        _answerAcknowledged ||
        id == null ||
        answer == null ||
        key == null)
      return;
    if (_state?['finished'] == true) {
      unawaited(_openResult());
      return;
    }
    if (_remaining <= 0 ||
        _remainingDeadline?.isAfter(DateTime.now()) == false) {
      unawaited(_load());
      return;
    }
    _replaying = true;
    try {
      final result = await ArenaApi.instance.submit(
        widget.matchId,
        id,
        answer,
        idempotencyKey: key,
      );
      _acceptAnswerResult(result);
    } catch (error) {
      if (!mounted ||
          _showingResult ||
          _switchingMatch ||
          _answerAcknowledged ||
          _pendingQuestionId != id)
        return;
      setState(() {
        _submitting = false;
        _feedback = studentFacingApiError(
          error,
          fallback: '응답을 확인하지 못했습니다. 같은 제출로 다시 확인하세요.',
        );
      });
    } finally {
      _replaying = false;
    }
  }

  void _acceptAnswerResult(Map<String, dynamic> result) {
    final id = result['question_id']?.toString();
    if (!mounted ||
        _showingResult ||
        _switchingMatch ||
        id == null ||
        id != _pendingQuestionId ||
        _acknowledgedIds.contains(id) ||
        (result['match_id'] != null && result['match_id'] != widget.matchId))
      return;
    _ackTimer?.cancel();
    if (result['correct'] is! bool || result['finished'] is! bool) {
      setState(() {
        _submitting = false;
        _feedback = '채점 응답을 확인하지 못했습니다. 같은 제출로 다시 확인하세요.';
      });
      return;
    }
    _acknowledgedIds.add(id);
    setState(() {
      _submitting = false;
      _answerAcknowledged = true;
      _feedback = result['correct'] is bool
          ? (result['correct'] == true ? '정답입니다' : '오답입니다')
          : '제출 확인됨 · 채점 응답 확인 불가';
      if (result['scores'] is Map) _state!['scores'] = result['scores'];
    });
    if (result['finished'] == true)
      unawaited(_openResult());
    else
      unawaited(_load());
  }

  void _nextQuestion() {
    if (!_answerAcknowledged ||
        _submitting ||
        _showingResult ||
        _switchingMatch)
      return;
    if (_state?['finished'] == true) {
      unawaited(_openResult());
      return;
    }
    setState(() {
      _index = _firstUnsubmitted(_state ?? {});
      _answerAcknowledged = false;
      _pendingQuestionId = null;
      _pendingAnswer = null;
      _pendingKey = null;
      _selectedChoice = null;
      _feedback = null;
      _answer.clear();
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    final wide = MediaQuery.sizeOf(context).width > 820;
    _scheduleStickyMeasure();
    final outerPadding = (MediaQuery.sizeOf(context).width * .024).clamp(
      18.0,
      34.0,
    );
    final scoreHeight = _scoreHeight(mobile);
    final questions = _state?['questions'] as List? ?? const [];
    final current = _index.clamp(0, math.max(0, questions.length - 1)).toInt();
    final question = questions.isNotEmpty && questions[current] is Map
        ? Map<String, dynamic>.from(questions[current] as Map)
        : <String, dynamic>{};
    final choices = question['choices'] as List? ?? const [];
    final canChoose =
        !_loadingState &&
        !_submitting &&
        !_answerAcknowledged &&
        _pendingQuestionId == null &&
        !_showingResult &&
        !_switchingMatch &&
        _state?['finished'] != true &&
        _remaining > 0 &&
        _index < questions.length;
    final answer =
        _pendingAnswer ?? (choices.isEmpty ? _answer.text : _selectedChoice);
    return StudentHtmlShell(
      title: '실시간 대결',
      railWidth: 76,
      mobileBackButton: true,
      activeRoute: AppRoutes.studentDashboard,
      showBottomNavigation: false,
      onMenu: () => Navigator.of(context).maybePop(),
      headerTrailing: null,
      child: ColoredBox(
        color: const Color(0xFFF0F0F2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 0 : outerPadding),
          child: SizedBox.expand(
            key: _matchViewport,
            child: CustomScrollView(
              controller: _matchScroll,
              slivers: [
                if (!mobile)
                  SliverToBoxAdapter(child: SizedBox(height: outerPadding)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ArenaMatchPinnedScore(
                    height: scoreHeight,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 1260,
                          minHeight: scoreHeight,
                          maxHeight: scoreHeight,
                        ),
                        child: _matchScoreboard(mobile, questions.length),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: mobile
                      ? const EdgeInsets.fromLTRB(13, 10, 13, 24)
                      : EdgeInsets.only(top: 12, bottom: outerPadding),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1260),
                        child: _state == null || questions.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    if (_loadError == null && _state == null)
                                      const CircularProgressIndicator()
                                    else
                                      Text(_loadError ?? '경기 문항이 없습니다.'),
                                    if (_loadError != null || _state != null)
                                      TextButton(
                                        onPressed: _load,
                                        child: const Text('다시 확인'),
                                      ),
                                  ],
                                ),
                              )
                            : wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _questionPanel(
                                      mobile,
                                      question,
                                      choices,
                                      questions.length,
                                      canChoose,
                                      answer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 294,
                                    child: _opponentPanel(
                                      mobile,
                                      questions.length,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _questionPanel(
                                    mobile,
                                    question,
                                    choices,
                                    questions.length,
                                    canChoose,
                                    answer,
                                  ),
                                  SizedBox(height: mobile ? 10 : 16),
                                  _opponentPanel(mobile, questions.length),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _teamScore(bool mine) {
    final team = (_state?['team'] as num?)?.toInt();
    if (team != 0 && team != 1) return {};
    final scores = _state?['scores'];
    final raw = scores is Map
        ? scores[(mine ? team : 1 - team!).toString()]
        : null;
    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  double _scoreHeight(bool mobile) {
    double line(double size, FontWeight weight) {
      final painter = TextPainter(
        text: TextSpan(
          text: '나 00',
          style: Theme.of(context).textTheme.bodyMedium!.merge(
            TextStyle(fontSize: size, fontWeight: weight),
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final person = mobile
        ? line(9, FontWeight.w400) + line(27, FontWeight.w700) + 2 + 18
        : math.max(
                line(34, FontWeight.w700),
                2 * line(9, FontWeight.w800) + 3,
              ) +
              28;
    final clock =
        math.max(
          mobile ? 20.0 : 24.0,
          line(mobile ? 8 : 10, FontWeight.w800) + 2,
        ) +
        4 +
        line(mobile ? 19 : 24, FontWeight.w700) +
        line(9, FontWeight.w400);
    return math.max(mobile ? 82.0 : 98.0, math.max(person, clock));
  }

  Widget _matchScoreboard(bool mobile, int total) {
    Widget person(bool mine) {
      final score = _teamScore(mine);
      final count = score['correct'] is num ? score['correct'].toString() : '—';
      final submitted = score['attempted'] is num
          ? '${score['attempted']}/$total 제출'
          : '제출 진도 확인 불가';
      final name = mine ? '나' : '상대';
      final number = Text(
        count,
        style: TextStyle(
          fontSize: mobile ? 27 : 34,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
      final names = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFFA1A1AA),
            ),
          ),
          if (!mobile)
            Text(
              submitted,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFFA1A1AA),
              ),
            ),
        ],
      );
      return Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 5 : 22,
            vertical: mobile ? 9 : 14,
          ),
          child: mobile
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFFA1A1AA),
                      ),
                    ),
                    const SizedBox(height: 2),
                    number,
                  ],
                )
              : Row(
                  mainAxisAlignment: mine
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: mine
                      ? [
                          Flexible(child: names),
                          const SizedBox(width: 12),
                          SizedBox(width: 42, child: number),
                        ]
                      : [
                          SizedBox(width: 42, child: number),
                          const SizedBox(width: 12),
                          Flexible(child: names),
                        ],
                ),
        ),
      );
    }

    final time = _state == null
        ? '—'
        : '${(_remaining ~/ 60).toString().padLeft(2, '0')}:${(_remaining % 60).toString().padLeft(2, '0')}';
    return Container(
      key: const ValueKey('arena-match-scoreboard'),
      constraints: BoxConstraints(minHeight: mobile ? 82 : 98),
      color: const Color(0xFF09090B),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            person(true),
            Container(
              width: mobile ? 112 : 190,
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: Color(0xFF29292D)),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: mobile ? 7 : 10),
                    constraints: BoxConstraints(minHeight: mobile ? 20 : 24),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF29292D)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            width: 7,
                            height: 7,
                            color: const Color(0xFFA1A1AA),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _socket != null ? '테스트 이벤트' : '서버 상태',
                          style: TextStyle(
                            fontSize: mobile ? 8 : 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: mobile ? 19 : 24,
                      letterSpacing: -.96,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    total == 0
                        ? '—'
                        : '${math.min(_index + 1, total)} / $total',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFFA1A1AA),
                    ),
                  ),
                ],
              ),
            ),
            person(false),
          ],
        ),
      ),
    );
  }

  Widget _questionPanel(
    bool mobile,
    Map<String, dynamic> question,
    List choices,
    int total,
    bool canChoose,
    String? answer,
  ) {
    final submitted = (_state?['submitted_question_ids'] as List? ?? const [])
        .map((e) => e.toString())
        .toSet();
    final questions = _state?['questions'] as List? ?? const [];
    final dots = Row(
      children: List.generate(
        total,
        (i) => Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 5),
            color:
                i == _index ||
                    (questions[i] is Map &&
                        submitted.contains(questions[i]['id']?.toString()))
                ? const Color(0xFF09090B)
                : const Color(0x1909090B),
          ),
        ),
      ),
    );
    final promptSize = mobile
        ? 23.0
        : (MediaQuery.sizeOf(context).width * .03).clamp(24.0, 38.0);
    final padding = mobile
        ? 16.0
        : (MediaQuery.sizeOf(context).width * .04).clamp(22.0, 46.0);
    final progress = Container(
      padding: mobile
          ? const EdgeInsets.all(10)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _matchSurface(),
      child: Row(
        children: [
          Expanded(child: dots),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '문제 ${math.min(_index + 1, total)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!mobile) const SizedBox(height: 4),
              if (!mobile)
                const Text(
                  '제출 후 이전 문제로 돌아갈 수 없습니다.',
                  style: TextStyle(fontSize: 9, color: Color(0xFF71717A)),
                ),
            ],
          ),
        ],
      ),
    );
    final card = Container(
      key: const ValueKey('arena-match-question-card'),
      constraints: BoxConstraints(minHeight: mobile ? 360 : 400),
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: mobile ? 22 : padding,
      ),
      decoration: _matchSurface(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question['tags']?.toString() ?? '서버 제공 문항',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Color(0xFF71717A),
                ),
              ),
              SizedBox(height: mobile ? 12 : 14),
              ContentBlocksView(
                blocks: parseTextWithLatex(
                  question['prompt']?.toString() ?? '문항 확인 불가',
                ),
                inline: true,
                spacing: 12,
                textStyle: TextStyle(
                  fontSize: promptSize,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -promptSize * .045,
                ),
                latexStyle: TextStyle(
                  fontSize: promptSize,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: mobile ? 26 : 34),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (choices.isNotEmpty)
                _choiceGrid(mobile, choices, canChoose)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '숫자 답 입력',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF71717A),
                      ),
                    ),
                    const SizedBox(height: 9),
                    TextField(
                      key: const ValueKey('arena-match-answer'),
                      controller: _answer,
                      enabled: canChoose,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: canChoose ? _submit : null,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-.]')),
                      ],
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: const InputDecoration(
                        hintText: '숫자 답을 입력하세요',
                        filled: true,
                        fillColor: Color(0xFFFDFDFE),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Color(0xFF09090B)),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_feedback != null)
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F5),
                    border: Border.all(color: const Color(0xFF09090B)),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          color: const Color(0xFF09090B),
                          child: Icon(
                            _answerAcknowledged
                                ? Icons.check
                                : Icons.info_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _feedback!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '정답과 해설은 대결 종료 후 제공 범위에서 확인할 수 있습니다.',
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.45,
                                  color: Color(0xFF71717A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    final enabled =
        !_loadingState &&
        !_submitting &&
        !_showingResult &&
        !_switchingMatch &&
        _state?['finished'] != true &&
        _remaining > 0 &&
        _index < total &&
        (answer?.trim().isNotEmpty == true);
    var answerLabel = answer;
    for (final raw in choices) {
      if (raw is Map && raw['id']?.toString() == answer) {
        answerLabel = raw['label']?.toString() ?? answer;
        break;
      }
    }
    final copy = _answerAcknowledged
        ? '채점 결과를 확인하고 다음으로 이동하세요.'
        : _pendingQuestionId != null
        ? '같은 제출 요청으로 응답을 다시 확인합니다.'
        : answer == null || answer.isEmpty
        ? '답을 선택하면 제출할 수 있습니다.'
        : '선택한 답 · $answerLabel';
    final button = FilledButton(
      key: const ValueKey('arena-match-submit'),
      onPressed: _answerAcknowledged
          ? _nextQuestion
          : enabled
          ? () => _submit(answer!)
          : null,
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.standard,
        minimumSize: Size(mobile ? 0 : 150, 50),
        shape: const RoundedRectangleBorder(),
        backgroundColor: const Color(0xFF09090B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        textStyle: TextStyle(
          fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _submitting
                  ? '제출 중…'
                  : _answerAcknowledged
                  ? '다음 문제'
                  : _pendingQuestionId != null
                  ? '제출 다시 확인'
                  : '답 제출',
            ),
          ),
          const SizedBox(width: 18),
          const Icon(Icons.arrow_forward, size: 18),
        ],
      ),
    );
    final footer = Container(
      key: const ValueKey('arena-match-submit-bar'),
      margin: const EdgeInsets.only(top: 8),
      padding: mobile
          ? const EdgeInsets.all(10)
          : const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: _matchSurface(),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  copy,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF71717A),
                  ),
                ),
                const SizedBox(height: 18),
                Align(alignment: Alignment.centerLeft, child: button),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    copy,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF71717A),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                button,
              ],
            ),
    );
    return Column(
      key: _questionAnchor,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        progress,
        const SizedBox(height: 8),
        card,
        Transform.translate(
          key: _footerAnchor,
          offset: Offset(0, _footerTranslation),
          child: footer,
        ),
        if (_loadError != null)
          Semantics(liveRegion: true, child: Text(_loadError!)),
      ],
    );
  }

  BoxDecoration _matchSurface() => BoxDecoration(
    color: const Color(0xFFFDFDFE),
    border: Border.all(color: const Color(0x1909090B)),
  );

  Widget _choiceGrid(bool mobile, List choices, bool enabled) {
    Widget choice(int i) {
      final raw = choices[i] is Map ? choices[i] as Map : const {};
      final id = raw['id']?.toString();
      final selected = id != null && id == _selectedChoice;
      final ink = selected ? Colors.white : const Color(0xFF09090B);
      final marker = i < 26 ? String.fromCharCode(65 + i) : '${i + 1}';
      final VoidCallback? select = enabled && id != null
          ? () => setState(() => _selectedChoice = id)
          : null;
      return Semantics(
        selected: selected,
        button: true,
        enabled: select != null,
        excludeSemantics: true,
        onTap: select,
        label: '선택지 $marker, ${raw['label']?.toString() ?? '—'}',
        child: OutlinedButton(
          key: ValueKey('arena-match-choice-$i'),
          onPressed: select,
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.standard,
            minimumSize: Size(0, mobile ? 58 : 64),
            padding: const EdgeInsets.all(10),
            shape: const RoundedRectangleBorder(),
            backgroundColor: selected
                ? const Color(0xFF09090B)
                : const Color(0xFFFDFDFE),
            foregroundColor: ink,
            side: BorderSide(
              color: selected
                  ? const Color(0xFF09090B)
                  : const Color(0x1909090B),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Container(
                  key: ValueKey('arena-match-marker-$i'),
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF29292D)
                          : const Color(0x1909090B),
                    ),
                  ),
                  child: Text(
                    marker,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: ContentBlocksView(
                  blocks: parseTextWithLatex(raw['label']?.toString() ?? '—'),
                  inline: true,
                  textStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                  latexStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final columns = mobile ? 2 : 5;
    return Column(
      children: [
        for (var start = 0; start < choices.length; start += columns)
          Padding(
            padding: EdgeInsets.only(
              bottom: start + columns < choices.length ? 8 : 0,
            ),
            child: Row(
              children: [
                for (
                  var j = start;
                  j < math.min(start + columns, choices.length);
                  j++
                ) ...[
                  if (j > start) const SizedBox(width: 8),
                  Expanded(child: choice(j)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _opponentPanel(bool mobile, int total) {
    final score = _teamScore(false);
    final attempted = score['attempted'] is num
        ? (score['attempted'] as num).toInt()
        : null;
    final progress = attempted != null && total > 0
        ? (attempted / total).clamp(0.0, 1.0)
        : null;
    Widget metric(String name, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Flex(
        direction: mobile ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: mobile
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 9, color: Color(0xFF71717A)),
          ),
          if (mobile) const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
    return Container(
      key: const ValueKey('arena-match-opponent'),
      padding: EdgeInsets.all(mobile ? 16 : 20),
      decoration: _matchSurface(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'OPPONENT LIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            '상대 진행 상태',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress ?? 0,
                  minHeight: 7,
                  color: const Color(0xFF09090B),
                  backgroundColor: const Color(0xFFF3F3F5),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                progress == null ? '—' : '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 20, bottom: 14),
            decoration: const BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: Color(0x1909090B)),
              ),
            ),
            child: mobile
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: metric('현재 문항', '확인 불가')),
                        const VerticalDivider(
                          width: 1,
                          color: Color(0x1909090B),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.zero,
                            child: metric(
                              '제출 점수',
                              score['correct'] is num
                                  ? '${score['correct']}점'
                                  : '—',
                            ),
                          ),
                        ),
                        const VerticalDivider(
                          width: 1,
                          color: Color(0x1909090B),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.zero,
                            child: metric('연결', '확인 불가'),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      metric('현재 문항', '확인 불가'),
                      const Divider(height: 1, color: Color(0x1909090B)),
                      metric(
                        '제출 점수',
                        score['correct'] is num ? '${score['correct']}점' : '—',
                      ),
                      const Divider(height: 1, color: Color(0x1909090B)),
                      metric('연결', '확인 불가'),
                    ],
                  ),
          ),
          if (mobile) const SizedBox(height: 14),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '상대의 선택지와 답은 대결이 끝날 때까지 공개되지 않습니다.',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.5,
                    color: Color(0xFF71717A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            '실시간 상태 동기화',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            '연결이 끊기면 자동으로 상태를 다시 확인합니다.',
            style: TextStyle(
              fontSize: 10,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 필요한 변수: 종료 경기 ID와 선택적으로 이미 수신한 결과.
/// 작동 원리: 승패·레이팅 변동을 먼저 보여 주고 같은 화면 아래에 문항별 제출·정답 분석을 이어서 표시한다.
/// Native sliver의 기존 pinned 동작만 사용하며 경기 데이터나 타이머를 소유하지 않는다.
class _ArenaMatchPinnedScore extends SliverPersistentHeaderDelegate {
  _ArenaMatchPinnedScore({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(covariant _ArenaMatchPinnedScore oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

Map<String, dynamic>? _arenaVerifiedParticipant(Map<String, dynamic> result) {
  final viewer = result['viewer_user_id'];
  if (viewer is! String || viewer.trim().isEmpty) return null;
  for (final row
      in result['participants'] is List
          ? result['participants'] as List
          : const []) {
    if (row is Map &&
        row['user_id'] == viewer &&
        row['team'] is int &&
        (row['team'] == 0 || row['team'] == 1) &&
        result['viewer_team'] == row['team']) {
      return Map<String, dynamic>.from(row);
    }
  }
  return null;
}

/// 다른 학생 답을 복사하지 않고, 이 경기의 종료·본인 관계가 확인된 데이터만 소유한다.
Map<String, dynamic> _arenaOwnedResult(
  Map<String, dynamic> source,
  String matchId,
) {
  final mine = _arenaVerifiedParticipant(source);
  if (source['match_id'] != matchId ||
      source['finished'] != true ||
      mine == null) {
    return {'_validation_error': '종료된 본인 경기 결과를 확인하지 못했습니다.'};
  }
  final result = <String, dynamic>{
    for (final key in [
      'match_id',
      'finished',
      'practice',
      'queue_type',
      'viewer_user_id',
      'viewer_team',
      'finish_reason',
      'started_at',
      'finished_at',
      'winner_team',
      'scores',
      'question_count',
      'participants',
      'answers_expires_at',
      'answers_expired',
    ])
      if (source.containsKey(key)) key: source[key],
  };
  result['analysis'] = [
    for (final row
        in source['analysis'] is List ? source['analysis'] as List : const [])
      if (row is Map)
        {
          for (final key in [
            'position',
            'question_id',
            'prompt',
            'answer_type',
            'choices',
            'tags',
            'correct_answer',
            'correct_answer_label',
          ])
            if (row.containsKey(key)) key: row[key],
          'team_answers': {
            for (final entry
                in (row['team_answers'] is Map
                        ? row['team_answers'] as Map
                        : const {})
                    .entries)
              if (entry.key.toString() == '${mine['team']}' &&
                  entry.value is Map &&
                  entry.value['user_id'] == source['viewer_user_id'])
                entry.key.toString(): {
                  for (final key in [
                    'user_id',
                    'answer',
                    'answer_label',
                    'correct',
                    'elapsed',
                  ])
                    if ((entry.value as Map).containsKey(key))
                      key: entry.value[key],
                },
          },
        },
  ];
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(result)) as Map);
}

void _arenaDiscardRawAnswers(Map<String, dynamic>? result) {
  if (result == null) return;
  for (final row
      in result['analysis'] is List ? result['analysis'] as List : const []) {
    if (row is! Map) continue;
    row.remove('correct_answer');
    row.remove('correct_answer_label');
    for (final answer
        in (row['team_answers'] is Map ? row['team_answers'] as Map : const {})
            .values) {
      if (answer is Map) {
        answer.remove('answer');
        answer.remove('answer_label');
      }
    }
  }
  result['answers_expired'] = true;
}

String _arenaAnswerLabel(Map<String, dynamic> item, String raw) {
  for (final choice
      in item['choices'] is List ? item['choices'] as List : const []) {
    if (choice is Map && choice['id']?.toString() == raw)
      return choice['label']?.toString() ?? raw;
  }
  return raw;
}

class ArenaResultPage extends StatefulWidget {
  ArenaResultPage({
    super.key,
    required this.matchId,
    Map<String, dynamic>? initialResult,
  }) : initialResult = initialResult == null
           ? null
           : _arenaOwnedResult(initialResult, matchId);

  final String matchId;
  final Map<String, dynamic>? initialResult;

  @override
  State<ArenaResultPage> createState() => _ArenaResultPageState();
}

class _ArenaResultPageState extends State<ArenaResultPage> {
  Map<String, dynamic>? _result;
  String? _error;
  Timer? _answerExpiry;
  DateTime? _firstDeadline;
  String? _ackViewer;
  bool _ackSent = false;
  bool _answerDisplayExpired = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialResult != null) {
      _acceptResult(widget.initialResult!);
    } else {
      unawaited(_load());
    }
  }

  void _acceptResult(Map<String, dynamic> value) {
    final owned = _arenaOwnedResult(value, widget.matchId);
    if (owned['_validation_error'] != null) {
      _arenaDiscardRawAnswers(_result);
      _arenaDiscardRawAnswers(widget.initialResult);
      _result = null;
      _error = owned['_validation_error'].toString();
      return;
    }
    _ackViewer = owned['viewer_user_id'] as String;
    _firstDeadline ??= DateTime.now().toUtc().add(const Duration(minutes: 5));
    final serverDeadline = DateTime.tryParse(
      owned['answers_expires_at']?.toString() ?? '',
    );
    final deadline =
        serverDeadline != null && serverDeadline.isBefore(_firstDeadline!)
        ? serverDeadline
        : _firstDeadline!;
    _answerExpiry?.cancel();
    _result = owned;
    _error = null;
    if (_answerDisplayExpired ||
        owned['answers_expired'] == true ||
        !deadline.isAfter(DateTime.now().toUtc())) {
      _answerDisplayExpired = true;
      _arenaDiscardRawAnswers(_result);
      _arenaDiscardRawAnswers(widget.initialResult);
    } else {
      _answerExpiry = Timer(deadline.difference(DateTime.now().toUtc()), () {
        if (!mounted) return;
        setState(() {
          _answerDisplayExpired = true;
          _arenaDiscardRawAnswers(_result);
          _arenaDiscardRawAnswers(widget.initialResult);
        });
        _acknowledgeResult();
      });
    }
  }

  /// 결과 답안을 감춘 뒤 서버 저장본도 한 번만 파기한다.
  void _acknowledgeResult() {
    final viewer = _ackViewer;
    if (_ackSent || viewer == null) return;
    _ackSent = true;
    unawaited(
      ArenaApi.instance.acknowledgeResult(widget.matchId, viewer).catchError((
        _,
      ) {
        // 종료 후 UI/context·답을 로그에 남기지 않는다.
      }),
    );
  }

  @override
  void dispose() {
    _answerExpiry?.cancel();
    _arenaDiscardRawAnswers(_result);
    _arenaDiscardRawAnswers(widget.initialResult);
    _result = null;
    _acknowledgeResult();
    super.dispose();
  }

  /// 필요한 변수는 종료 경기 ID다.
  /// 작동 원리는 참가자 전용 결과 API를 캐시 없이 읽고 실패 시 재시도 가능한 오류를 보존하는 것이다.
  Future<void> _load() async {
    try {
      final value = await ArenaApi.instance.matchResult(widget.matchId);
      if (mounted) {
        setState(() {
          _acceptResult(value);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _arenaDiscardRawAnswers(_result);
          _arenaDiscardRawAnswers(widget.initialResult);
          _result = null;
          _error = studentFacingApiError(error, fallback: '경기 결과를 불러오지 못했어요.');
        });
      }
    }
  }

  /// 필요한 변수는 결과 참가자 목록과 현재 사용자 ID다.
  /// 작동 원리는 확정 viewer ID와 팀이 일치한 본인만 찾고, 없으면 다른 학생으로 대체하지 않는 것이다.
  Map<String, dynamic>? _myParticipant(Map<String, dynamic> result) =>
      _arenaVerifiedParticipant(result);

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
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('결과 다시 불러오기'),
                    ),
                  ],
                ),
        ),
      );
    }
    final mine = _myParticipant(result);
    if (mine == null) {
      return const Scaffold(body: Center(child: Text('본인 경기 결과를 확인할 수 없습니다.')));
    }
    final viewerTeam =
        (result['viewer_team'] as num?)?.toInt() ??
        (mine['team'] as num?)?.toInt() ??
        0;
    final analysis = result['analysis'] as List? ?? const [];
    return StudentHtmlShell(
      title: '대결 결과',
      railWidth: 76,
      mobileBackButton: true,
      activeRoute: AppRoutes.studentDashboard,
      child: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobile = MediaQuery.sizeOf(context).width <= 720;
            final padding = mobile
                ? 13.0
                : (MediaQuery.sizeOf(context).width * .024).clamp(18.0, 34.0);
            final review = Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFDFDFE),
                border: Border.all(color: const Color(0x1A09090B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x1A09090B)),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ANSWER REVIEW',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF71717A),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '문항별 결과',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.88,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '본인 답안만 확인할 수 있으며, 결과를 떠나거나 보관 시간이 끝나면 파기됩니다.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF71717A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final raw in analysis)
                    if (raw is Map)
                      _ArenaAnalysisCard(
                        item: Map<String, dynamic>.from(raw),
                        viewerTeam: viewerTeam,
                        viewerUserId: result['viewer_user_id'] as String,
                        answersExpired: result['answers_expired'] == true,
                      ),
                ],
              ),
            );
            return ListView(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 24),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ArenaResultSummary(result: result, mine: mine),
                    const SizedBox(height: 12),
                    if (constraints.maxWidth <= 820)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          review,
                          const SizedBox(height: 12),
                          _ArenaResultFacts(result: result, mine: mine),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: review),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 260,
                            child: _ArenaResultFacts(
                              result: result,
                              mine: mine,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: mobile ? double.infinity : 220,
                        height: 50,
                        child: FilledButton(
                          key: const ValueKey('arena-result-return'),
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: FilledButton.styleFrom(
                            shape: const RoundedRectangleBorder(),
                            minimumSize: const Size(0, 50),
                            backgroundColor: const Color(0xFF09090B),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.standard,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  '대결장으로 돌아가기',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
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
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width <= 720;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The reference inline span sits in a 17.6px parent line box, not a 14.4px leaf box.
        SizedBox(
          height: 17.6,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              result['practice'] == true ? 'BOT MATCH RESULT' : 'MATCH RESULT',
              style: const TextStyle(
                fontSize: 10,
                height: 1.44,
                letterSpacing: 1.4,
                color: Color(0xFF71717A),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: (width * .05).clamp(34.0, 58.0),
            height: 84 / 58,
            fontWeight: FontWeight.w900,
            letterSpacing: -(width * .05).clamp(34.0, 58.0) * .07,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _arenaFinishReasonLabel(result['finish_reason']?.toString()),
          style: const TextStyle(
            fontSize: 11,
            height: 16 / 11,
            color: Color(0xFF71717A),
          ),
        ),
      ],
    );
    Widget score(String label, Map<String, dynamic> value) => SizedBox(
      width: 82,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF71717A)),
          ),
          Text(
            '${value['correct'] ?? '—'}',
            style: const TextStyle(
              fontSize: 52,
              height: 1,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
    final scoresView = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        score('나', myScore),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(':', style: TextStyle(color: Colors.white)),
        ),
        score(result['practice'] == true ? '봇' : '상대', opponentScore),
      ],
    );
    final rating = Container(
      height: mobile ? 106 : 104,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF29292D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '티어 점수',
            style: TextStyle(fontSize: 9, color: Color(0xFF71717A)),
          ),
          const SizedBox(height: 4),
          Text(
            '${delta >= 0 ? '+' : ''}$delta',
            style: const TextStyle(
              fontSize: 32,
              height: 1,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${mine['rating_before'] ?? '—'} → ${mine['rating_after'] ?? '—'}',
            style: const TextStyle(fontSize: 9, color: Color(0xFF71717A)),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        key: const ValueKey('arena-result-hero'),
        padding: mobile
            ? const EdgeInsets.symmetric(vertical: 22, horizontal: 18)
            : const EdgeInsets.all(28),
        color: const Color(0xFF09090B),
        child: mobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: 22),
                  Center(child: scoresView),
                  const SizedBox(height: 22),
                  rating,
                ],
              )
            : constraints.maxWidth <= 820
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: heading),
                      scoresView,
                    ],
                  ),
                  const SizedBox(height: 28),
                  rating,
                ],
              )
            : Row(
                children: [
                  Expanded(child: heading),
                  scoresView,
                  const SizedBox(width: 28),
                  SizedBox(width: 220, child: rating),
                ],
              ),
      ),
    );
  }
}

/// Actual participant scores and finish reason; no prototype totals are fabricated.
class _ArenaResultFacts extends StatelessWidget {
  const _ArenaResultFacts({required this.result, required this.mine});
  final Map<String, dynamic> result;
  final Map<String, dynamic> mine;

  @override
  Widget build(BuildContext context) {
    final team = mine['team'];
    final scores = result['scores'] as Map? ?? const {};
    final mineScore = scores['$team'] as Map? ?? const {};
    final opponent = scores['${1 - (team as num).toInt()}'] as Map? ?? const {};
    final count = result['question_count'];
    String fraction(Map score) {
      final correct = score['correct'];
      if (count is! int ||
          count <= 0 ||
          correct is! int ||
          correct < 0 ||
          correct > count) {
        return '미확인';
      }
      return '$correct / $count';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFE),
        border: Border.all(color: const Color(0x1A09090B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '이번 대결 요약',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          for (final entry in {
            '정답': fraction(mineScore),
            '상대 점수': fraction(opponent),
            '종료 사유': _arenaFinishReasonLabel(
              result['finish_reason']?.toString(),
            ),
          }.entries)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
              ),
              child: Row(
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF71717A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      key: ValueKey('arena-result-fact-${entry.key}'),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            '답안은 종료 후 최대 5분 보관하며, 결과 화면을 떠나면 파기 요청을 보냅니다.',
            style: TextStyle(fontSize: 10, color: Color(0xFF71717A)),
          ),
        ],
      ),
    );
  }
}

/// 필요한 변수: 한 문항의 종료 분석과 현재 팀 번호.
/// 작동 원리는 수식 문제·내 답·정답·정오답 상태를 한 카드에서 비교하게 만드는 것이다.
class _ArenaAnalysisCard extends StatelessWidget {
  const _ArenaAnalysisCard({
    required this.item,
    required this.viewerTeam,
    required this.viewerUserId,
    required this.answersExpired,
  });

  final Map<String, dynamic> item;
  final int viewerTeam;
  final String viewerUserId;
  final bool answersExpired;

  /// 필요한 변수는 현재 팀의 제출 답안과 공개된 정답이다. 정오답 색상과 수식 본문을 함께 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final answers = Map<String, dynamic>.from(
      item['team_answers'] as Map? ?? const {},
    );
    final rawAnswer = answers['$viewerTeam'];
    final answer = rawAnswer is Map && rawAnswer['user_id'] == viewerUserId
        ? Map<String, dynamic>.from(rawAnswer)
        : null;
    final correct = answer?['correct'] == true;
    const statusColor = Color(0xFF09090B);
    final status = answer == null
        ? (answersExpired ? '답안 파기됨' : '미제출')
        : correct
        ? '정답'
        : '오답';
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    final statusView = Text(
      status,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${item['position'] ?? '—'}번${item['tags'] is List && (item['tags'] as List).isNotEmpty ? ' · ${(item['tags'] as List).join(' · ')}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, color: Color(0xFF71717A)),
        ),
        const SizedBox(height: 4),
        ContentBlocksView(
          blocks: parseTextWithLatex(item['prompt']?.toString() ?? ''),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          latexStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: _ArenaRenderedAnswerLine(
                label: '내 답',
                value: answersExpired
                    ? '자동 파기됨'
                    : answer == null
                    ? '제출하지 않음'
                    : answer['answer_label']?.toString() ??
                          _arenaAnswerLabel(
                            item,
                            answer['answer']?.toString() ?? '답 정보 없음',
                          ),
                fontSize: 9,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('·', style: TextStyle(fontSize: 9)),
            ),
            Flexible(
              child: _ArenaRenderedAnswerLine(
                label: '정답',
                value: answersExpired
                    ? '자동 파기됨'
                    : item['correct_answer_label']?.toString() ??
                          _arenaAnswerLabel(
                            item,
                            item['correct_answer']?.toString() ?? '정답 정보 없음',
                          ),
                fontSize: 9,
              ),
            ),
          ],
        ),
        if (mobile) ...[const SizedBox(height: 12), statusView],
      ],
    );
    return Container(
      key: ValueKey('arena-review-row-${item['position']}'),
      constraints: const BoxConstraints(minHeight: 84),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: mobile ? 12 : 18),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFE),
        border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: correct ? statusColor : null,
              border: Border.all(color: const Color(0x1A09090B)),
            ),
            child: Icon(
              correct ? Icons.check : Icons.close,
              size: 18,
              color: correct ? Colors.white : statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: content),
          if (!mobile) ...[const SizedBox(width: 12), statusView],
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
    this.fontSize,
  });

  final String label;
  final String value;
  final double? fontSize;

  /// 필요한 변수는 라벨과 수식 포함 답안 값이다. 라벨 옆 남은 폭에서 인라인 수식을 자동 줄바꿈한다.
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label: ',
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800),
      ),
      Flexible(
        child: ContentBlocksView(
          blocks: parseTextWithLatex(value),
          textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800),
          latexStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
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
