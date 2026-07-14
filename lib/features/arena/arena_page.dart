import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'arena_api.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

/// 학생 대시보드에서 실시간 대결장을 연다.
Future<void> showArena(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const ArenaPage()));

/// 필요한 변수: 서버의 네 큐 요약.
/// 1v1/2v2 시험·OX 큐와 독립 티어를 한 화면에 표시한다.
class ArenaPage extends StatefulWidget {
  const ArenaPage({super.key, this.initialSummary});

  final Map<String, dynamic>? initialSummary;

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
    _summary = widget.initialSummary;
    if (_summary == null) _load();
  }

  @override
  void dispose() {
    _matchPoller?.cancel();
    super.dispose();
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

  /// 필요한 변수: 선택한 큐 ID. 매칭을 시작하고 즉시 성립하면 경기 화면으로 이동한다.
  Future<void> _join(String queueType) async {
    setState(() {
      _waitingQueue = queueType;
      _error = null;
    });
    try {
      final result = await ArenaApi.instance.join(queueType);
      if (!mounted) return;
      final matchId = result['match_id']?.toString();
      if (matchId != null && matchId.isNotEmpty) {
        await _openMatch(matchId);
      } else {
        _matchPoller?.cancel();
        _matchPoller = Timer.periodic(const Duration(seconds: 2), (_) async {
          final summary = await ArenaApi.instance.summary(forceRefresh: true);
          final active = summary['active_match_id']?.toString();
          if (active != null && active.isNotEmpty && mounted) {
            _matchPoller?.cancel();
            await _openMatch(active);
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _waitingQueue = null;
          _error = error.toString();
        });
      }
    }
  }

  /// 필요한 변수 없음. 현재 매칭 대기를 서버와 화면에서 함께 취소한다.
  Future<void> _cancel() async {
    _matchPoller?.cancel();
    await ArenaApi.instance.cancel();
    if (mounted) setState(() => _waitingQueue = null);
  }

  /// 필요한 변수: 성립된 경기 ID. 대기 상태를 정리하고 경기 화면을 연다.
  Future<void> _openMatch(String matchId) async {
    _matchPoller?.cancel();
    if (!mounted) return;
    setState(() => _waitingQueue = null);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ArenaMatchPage(matchId: matchId)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final queues = List<Map<String, dynamic>>.from(
      (_summary?['queues'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final profile = Map<String, dynamic>.from(
      _summary?['profile'] as Map? ??
          (queues.isEmpty ? const {} : queues.first),
    );
    final rating = (profile['rating'] as num? ?? 1580).round();
    final wins = (profile['wins'] as num? ?? 18).round();
    final losses = (profile['losses'] as num? ?? 9).round();
    final draws = (profile['draws'] as num? ?? 2).round();
    final tier = profile['tier']?.toString() ?? 'B';
    final total = math.max(1, wins + losses + draws);
    final winRate = wins / total * 100;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: Colors.black,
                showLevelIndicator: false,
                onMenu: () => toggleAppDrawer(context),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 24, 14, 40),
                  children: [
                    _ArenaHero(
                      tier: tier,
                      rating: rating,
                      wins: wins,
                      losses: losses,
                      draws: draws,
                      winRate: winRate,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 56),
                    const Text(
                      'CHOOSE YOUR MATCH',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.8,
                        color: Colors.black54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '대결 방식 선택',
                      style: TextStyle(
                        fontSize: 32,
                        letterSpacing: -1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '각 방식의 레이팅과 전적은 독립적으로 기록됩니다.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 22),
                    if (_summary == null)
                      const Center(child: CircularProgressIndicator()),
                    ...queues.map(
                      (queue) => _QueueCard(
                        data: queue,
                        waiting: _waitingQueue == queue['queue_type'],
                        disabled:
                            _waitingQueue != null &&
                            _waitingQueue != queue['queue_type'],
                        onJoin: () => _join(queue['queue_type'].toString()),
                        onCancel: _cancel,
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

class _ArenaHero extends StatelessWidget {
  const _ArenaHero({
    required this.tier,
    required this.rating,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
  });

  final String tier;
  final int rating;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;

  /// 필요한 변수는 티어·레이팅·승패무·승률이다.
  /// 작동 원리는 HTML의 랭크 소개와 검은 프로필 카드를 한 덩어리로 구성해 첫 화면 정보 밀도를 고정하는 것이다.
  @override
  Widget build(BuildContext context) {
    final nextTierRating = ((rating ~/ 300) + 1) * 300;
    final progress = (rating % 300) / 300;
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 44),
          const Text(
            '실력으로 증명하는\n20분.',
            style: TextStyle(
              fontSize: 42,
              height: .98,
              letterSpacing: -2.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 46),
          const Text(
            '시험 대결은 객관식 5문항과 단답형 5문항, OX 대결은 10문항으로 진행됩니다.',
            style: TextStyle(fontSize: 15, height: 1.8, color: Colors.black54),
          ),
          const SizedBox(height: 34),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$tier TIER까지', style: const TextStyle(fontSize: 11)),
              Text(
                '${math.max(0, nextTierRating - rating)}점',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
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
          const SizedBox(height: 34),
          _ArenaProfileCard(
            tier: tier,
            rating: rating,
            wins: wins,
            losses: losses,
            draws: draws,
            winRate: winRate,
          ),
        ],
      ),
    );
  }
}

class _ArenaProfileCard extends StatelessWidget {
  const _ArenaProfileCard({
    required this.tier,
    required this.rating,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
  });

  final String tier;
  final int rating;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;

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
              TierBadge(tier: tier, size: 80),
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
                      '$tier TIER · 상위 18%',
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
              for (final result in ['W', 'W', 'L', 'W', 'D'])
                Container(
                  width: 25,
                  height: 25,
                  margin: const EdgeInsets.only(left: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: result == 'W' ? Colors.white : Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: result == 'W' ? Colors.black : Colors.white54,
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
  });
  final Map<String, dynamic> data;
  final bool waiting;
  final bool disabled;
  final VoidCallback onJoin;
  final VoidCallback onCancel;

  String get _label =>
      const {
        'duel_exam': '1v1 시험 대결',
        'duel_ox': '1v1 OX 대결',
        'team_exam': '2v2 시험 대결',
        'team_ox': '2v2 OX 대결',
      }[data['queue_type']] ??
      '대결';

  @override
  Widget build(BuildContext context) {
    final tier = data['tier']?.toString() ?? 'C';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E1E3)),
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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$tier 티어 · ${(data['rating'] as num? ?? 1500).toStringAsFixed(0)}점',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                Text(
                  '${data['wins'] ?? 0}승 ${data['losses'] ?? 0}패 ${data['draws'] ?? 0}무 · 예상 ${data['estimated_wait_seconds'] ?? 0}초',
                  style: const TextStyle(fontSize: 10, color: Colors.black45),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: disabled ? null : (waiting ? onCancel : onJoin),
            child: Text(waiting ? '취소' : '매칭'),
          ),
        ],
      ),
    );
  }
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
  ArenaSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
        onError: (_) => _load(),
      );
    } catch (_) {
      await _load();
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
      setState(() {
        _state = value;
        _remaining = (value['remaining_seconds'] as num?)?.toInt() ?? 0;
      });
      _startLocalTimer();
    } else if (type == 'answer_result' && rawData is Map) {
      final result = Map<String, dynamic>.from(rawData);
      setState(() {
        _feedback = result['correct'] == true
            ? '정답입니다!'
            : '오답 · ${result['attempts_remaining']}회 남음';
        _answer.clear();
      });
    } else if (type == 'error') {
      setState(() => _feedback = event['message']?.toString());
    }
  }

  /// 필요한 변수는 현재 남은 시간이다. 서버 상태 사이 구간만 1초 단위로 보간한다.
  void _startLocalTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _remaining > 0) setState(() => _remaining--);
    });
  }

  Future<void> _load() async {
    final value = await ArenaApi.instance.matchState(widget.matchId);
    if (!mounted) return;
    setState(() {
      _state = value;
      _remaining = value['remaining_seconds'] as int? ?? 0;
    });
    _startLocalTimer();
  }

  Future<void> _submit(String answer) async {
    final questions = _state?['questions'] as List? ?? const [];
    if (questions.isEmpty) return;
    final question = Map<String, dynamic>.from(questions[_index] as Map);
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
        _feedback = result['correct'] == true
            ? '정답입니다!'
            : '오답 · ${result['attempts_remaining']}회 남음';
        _answer.clear();
      });
      await _load();
    } catch (error) {
      if (mounted) setState(() => _feedback = error.toString());
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
    final question = Map<String, dynamic>.from(
      questions[math.min(_index, questions.length - 1)] as Map,
    );
    final choices = question['choices'] as List? ?? const [];
    final teamMode = _state!['queue_type'].toString().startsWith('team_');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${(_remaining ~/ 60).toString().padLeft(2, '0')}:${(_remaining % 60).toString().padLeft(2, '0')} · ${_index + 1}/10',
        ),
      ),
      body: Row(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  question['tags']?.toString() ?? '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  question['prompt'].toString(),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                if (choices.isNotEmpty)
                  ...choices.map((raw) {
                    final value = Map<String, dynamic>.from(raw as Map);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: () => _submit(value['id'].toString()),
                        child: Text(value['label'].toString()),
                      ),
                    );
                  }),
                if (choices.isEmpty)
                  TextField(
                    controller: _answer,
                    onSubmitted: _submit,
                    decoration: const InputDecoration(
                      labelText: '정답 입력',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (choices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FilledButton(
                      onPressed: () => _submit(_answer.text),
                      child: const Text('제출'),
                    ),
                  ),
                if (_feedback != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_feedback!),
                  ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _index > 0
                          ? () => setState(() => _index--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      onPressed: _index + 1 < questions.length
                          ? () => setState(() => _index++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (teamMode)
            SizedBox(
              width: 280,
              child: _TeamChat(
                matchId: widget.matchId,
                messages: _state!['chat'] as List? ?? const [],
                controller: _chat,
                onSent: _load,
              ),
            ),
        ],
      ),
    );
  }
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
