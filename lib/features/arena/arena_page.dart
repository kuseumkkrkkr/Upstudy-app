import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'arena_api.dart';

/// 학생 대시보드에서 실시간 대결장을 연다.
Future<void> showArena(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const ArenaPage()));

/// 필요한 변수: 서버의 네 큐 요약.
/// 1v1/2v2 시험·OX 큐와 독립 티어를 한 화면에 표시한다.
class ArenaPage extends StatefulWidget {
  const ArenaPage({super.key});

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
    _load();
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
          final summary = await ArenaApi.instance.summary();
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
    return Scaffold(
      appBar: AppBar(title: const Text('수학 대결장')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '실력으로 증명하는 20분',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text('시험은 객관식 5 + 단답형 5, OX는 10문제로 진행됩니다.'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 18),
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
    );
  }
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            TierBadge(tier: tier, size: 68),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$tier 티어 · ${(data['rating'] as num? ?? 1500).toStringAsFixed(0)}점',
                  ),
                  Text(
                    '${data['wins']}승 ${data['losses']}패 ${data['draws']}무 · 예상 ${data['estimated_wait_seconds']}초',
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: disabled ? null : (waiting ? onCancel : onJoin),
              child: Text(waiting ? '취소' : '매칭'),
            ),
          ],
        ),
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
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answer.dispose();
    _chat.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final value = await ArenaApi.instance.matchState(widget.matchId);
    if (!mounted) return;
    setState(() {
      _state = value;
      _remaining = value['remaining_seconds'] as int? ?? 0;
    });
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _remaining > 0) setState(() => _remaining--);
    });
  }

  Future<void> _submit(String answer) async {
    final questions = _state?['questions'] as List? ?? const [];
    if (questions.isEmpty) return;
    final question = Map<String, dynamic>.from(questions[_index] as Map);
    try {
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
