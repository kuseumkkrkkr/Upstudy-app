import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/services/api_client.dart';

VoidCallback buildWeaknessReviewAction(BuildContext context) {
  return () {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future.microtask(() => showWeaknessReviewModal(context: navigator.context));
  };
}

Future<T?> showWeaknessReviewModal<T>({required BuildContext context}) {
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
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            const Center(child: WeaknessReviewModal()),
          ],
        ),
      );
    },
  );
}

class WeaknessReviewModal extends StatefulWidget {
  const WeaknessReviewModal({super.key});

  @override
  State<WeaknessReviewModal> createState() => _WeaknessReviewModalState();
}

enum _ReviewSection { problemRedo, concept, oxQuiz, flashcard, chat }

class _ReviewActionEntry {
  const _ReviewActionEntry({
    required this.section,
    required this.icon,
    required this.label,
  });
  final _ReviewSection section;
  final IconData icon;
  final String label;
}

class _ProblemAttempt {
  const _ProblemAttempt({
    required this.title,
    required this.tags,
    required this.updatedAt,
    required this.retryCount,
    required this.seed,
    required this.codebaseId,
  });
  final String title;
  final List<String> tags;
  final DateTime updatedAt;
  final int retryCount;
  final String seed;
  final int codebaseId;
}

class _Flashcard {
  const _Flashcard({
    required this.tag,
    required this.subject,
    required this.concept,
    required this.weaknessCount,
  });
  final String tag;
  final String subject;
  final String concept;
  final int weaknessCount;
}

class _OxQuestion {
  _OxQuestion({
    required this.tag,
    required this.question,
    required this.answer,
    this.id,
  });
  final int? id;
  final String tag;
  final String question;
  final bool answer;
  bool? userAnswer;
}

class _WeaknessReviewModalState extends State<WeaknessReviewModal> {
  static const _actions = [
    _ReviewActionEntry(
      section: _ReviewSection.problemRedo,
      icon: Icons.restart_alt_rounded,
      label: '문제 다시풀기',
    ),
    _ReviewActionEntry(
      section: _ReviewSection.concept,
      icon: Icons.menu_book_outlined,
      label: '개념 다시보기',
    ),
    _ReviewActionEntry(
      section: _ReviewSection.oxQuiz,
      icon: Icons.quiz_outlined,
      label: 'OX퀴즈 풀기',
    ),
    _ReviewActionEntry(
      section: _ReviewSection.flashcard,
      icon: Icons.style_outlined,
      label: '플래시카드 보기',
    ),
    _ReviewActionEntry(
      section: _ReviewSection.chat,
      icon: Icons.chat_bubble_outline,
      label: '채팅형 복습',
    ),
  ];

  bool _loading = true;
  String? _errorMessage;
  List<WeaknessTag> _weaknessTags = const [];

  static const _dayOptions = [1, 3, 7, 14, 30];

  final Set<int> _selectedDays = {7};
  _ReviewSection _selectedSection = _ReviewSection.problemRedo;

  final TextEditingController _hashtagController = TextEditingController();
  final TextEditingController _flashcardSearchController =
      TextEditingController();
  final TextEditingController _oxSearchController = TextEditingController();
  final TextEditingController _oxTagInputController = TextEditingController();

  final List<_ProblemAttempt> _attempts = [];
  bool _historyLoading = true;
  String? _historyError;

  final List<_Flashcard> _flashcards = const [
    _Flashcard(
      tag: '#기하',
      subject: '수학 상',
      concept: '평면도형의 닮음 조건과 닮음비 관계',
      weaknessCount: 7,
    ),
    _Flashcard(
      tag: '#적분',
      subject: '수학 하',
      concept: '부정적분과 정적분의 연결, 치환 적분 기본형',
      weaknessCount: 5,
    ),
    _Flashcard(
      tag: '#확률',
      subject: '확률과 통계',
      concept: '확률변수의 기댓값 계산 틀',
      weaknessCount: 9,
    ),
    _Flashcard(
      tag: '#영어어법',
      subject: '영어',
      concept: '분사구문의 시제·태 일치 원리',
      weaknessCount: 3,
    ),
    _Flashcard(
      tag: '#한국사근현대',
      subject: '한국사',
      concept: '대한민국 정부 수립 전후 연표 핵심 사건',
      weaknessCount: 1,
    ),
  ];

  final Set<String> _oxSelectedTags = {};
  final List<_OxQuestion> _oxQuestions = [];
  int? _oxScore;
  bool _onlyWeakFlashcards = false;
  String? _reportSubjectFilter;
  bool _oxLoading = false;
  bool _selectMode = false;
  final Set<String> _selectedAttemptKeys = {};

  @override
  void initState() {
    super.initState();
    _loadWeaknessTags();
    _loadProblemHistory();
  }

  @override
  void dispose() {
    _hashtagController.dispose();
    _flashcardSearchController.dispose();
    _oxSearchController.dispose();
    super.dispose();
  }

  // ✅ FIX 1: 누락된 닫는 중괄호 추가 — 메서드가 제대로 닫히지 않아 build()가 메서드 내부로 파싱되던 문제 수정
  Future<void> _loadWeaknessTags() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final tags = await ApiClient.instance.fetchWeaknessTags();
      if (!mounted) return;
      setState(() {
        _weaknessTags = tags;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  } // ← 누락된 닫는 중괄호

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 1200.0;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 820.0;
        const baseWidth = 1200.0;
        const baseHeight = 820.0;
        final width = math.min(baseWidth, maxW * 0.95);
        final height = math.min(baseHeight, maxH * 0.95);
        final scale = (width / baseWidth).clamp(0.6, 1.0);
        final horizontalPadding = 24 * scale;
        final gap = 12 * scale;
        final contentWidth = width - (horizontalPadding * 2);
        final topTileWidth =
            (contentWidth - (gap * (_actions.length - 1))) / _actions.length;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              top: true,
              child: Center(
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16 * scale),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(20 * scale),
                            child: IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.black,
                                size: 30 * scale,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 2 * scale),
                            child: Text(
                              '약점 복습',
                              style: GoogleFonts.inter(
                                fontSize: 26 * scale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: Row(
                          children: List.generate(_actions.length, (index) {
                            final action = _actions[index];
                            final selected =
                                _selectedSection == action.section;
                            final tile = _ReviewActionTile(
                              action: action,
                              scale: scale,
                              width: topTileWidth,
                              height: 96 * scale,
                              selected: selected,
                              onTap: () => setState(
                                () => _selectedSection = action.section,
                              ),
                            );
                            if (index == _actions.length - 1) {
                              return tile;
                            }
                            return Padding(
                              padding: EdgeInsets.only(right: gap),
                              child: tile,
                            );
                          }),
                        ),
                      ),
                      SizedBox(height: 18 * scale),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: _buildSectionBody(
                            scale: scale,
                            horizontalPadding: horizontalPadding,
                            gap: gap,
                          ),
                        ),
                      ),
                      SizedBox(height: 12 * scale),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ FIX 2: _buildRecordPanel을 클래스 내부 메서드로 올바르게 위치
  Widget _buildSectionBody({
    required double scale,
    required double horizontalPadding,
    required double gap,
  }) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: TextStyle(
            fontSize: 14 * scale,
            color: Colors.redAccent,
          ),
        ),
      );
    }
    switch (_selectedSection) {
      case _ReviewSection.problemRedo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '문제 다시풀기',
              style: GoogleFonts.inter(
                fontSize: 18 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10 * scale),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: _buildRecordPanel(scale)),
                  SizedBox(width: gap),
                  Expanded(flex: 2, child: _buildFilterPanel(scale)),
                ],
              ),
            ),
          ],
        );
      case _ReviewSection.flashcard:
        return _buildFlashcardPanel(scale);
      case _ReviewSection.oxQuiz:
        return _buildOxQuizPanel(scale);
      case _ReviewSection.chat:
        return _buildChatPanel(scale);
      case _ReviewSection.concept:
        return _buildConceptPanel(scale);
    }
  }

  Future<void> _loadProblemHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final items = await ApiClient.instance.fetchProblemHabits(
        days: _selectedDays.isEmpty ? 60 : _selectedDays.reduce((a, b) => a < b ? a : b),
        tag: _hashtagController.text.trim().isEmpty
            ? null
            : _hashtagController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _attempts
          ..clear()
          ..addAll(
            items.map(
              (it) => _ProblemAttempt(
                title: it.questTitle ?? '문제',
                tags: it.tags,
                updatedAt: DateTime.tryParse(it.updatedAt) ?? DateTime.now(),
                retryCount: it.retryCount,
                seed: it.seed,
                codebaseId: it.codebaseId,
              ),
            ),
          );
        _historyLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyLoading = false;
        _historyError = error.toString();
      });
    }
  }

  List<_ProblemAttempt> get _filteredAttempts {
    final now = DateTime.now();
    final thresholdDays =
        _selectedDays.isEmpty ? _dayOptions.last : _selectedDays.reduce(math.min);
    final query = _hashtagController.text.trim().toLowerCase();
    return _attempts.where((attempt) {
      final within = now.difference(attempt.updatedAt).inDays <= thresholdDays;
      final matches = query.isEmpty ||
          attempt.tags.any(
            (t) => t.toLowerCase().contains(query.replaceAll('#', '')),
          );
      return within && matches;
    }).toList();
  }

  String _attemptKey(_ProblemAttempt attempt) =>
      '${attempt.codebaseId}-${attempt.seed}';

  Widget _buildRecordPanel(double scale) {
    final attempts = _filteredAttempts;
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: const Color(0xFFE1E3E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '풀이 내역',
            style: GoogleFonts.inter(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8 * scale),
          Expanded(
            child: _historyLoading
                ? const Center(child: CircularProgressIndicator())
                : _historyError != null
                ? Center(
                    child: Text(
                      _historyError!,
                      style: TextStyle(
                        fontSize: 13 * scale,
                        color: Colors.redAccent,
                      ),
                    ),
                  )
                : attempts.isEmpty
                ? Center(
                    child: Text(
                      '조건에 맞는 풀이 내역이 없습니다.',
                      style: TextStyle(
                        fontSize: 13 * scale,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: attempts.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8 * scale),
                    itemBuilder: (context, index) {
                      final item = attempts[index];
                      final key = _attemptKey(item);
                      final selected = _selectedAttemptKeys.contains(key);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectMode)
                            Checkbox(
                              value: selected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedAttemptKeys.add(key);
                                  } else {
                                    _selectedAttemptKeys.remove(key);
                                  }
                                });
                              },
                            ),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 12 * scale,
                                horizontal: 12 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10 * scale),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8 * scale,
                                          vertical: 4 * scale,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1B402B)
                                              .withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(8 * scale),
                                        ),
                                        child: Text(
                                          item.tags.isNotEmpty
                                              ? item.tags.first
                                              : '#태그없음',
                                          style: TextStyle(
                                            fontSize: 12 * scale,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1B402B),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '재시도 ${item.retryCount}회',
                                        style: TextStyle(
                                          fontSize: 11 * scale,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 6 * scale),
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 14 * scale,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 4 * scale),
                                  Text(
                                    '최근 풀이: ${item.updatedAt.month}/${item.updatedAt.day}',
                                    style: TextStyle(
                                      fontSize: 12 * scale,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  SizedBox(height: 10 * scale),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: const Color(0xFF1B402B),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10 * scale),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14 * scale,
                                          vertical: 10 * scale,
                                        ),
                                      ),
                                      onPressed: () => _replayAttempt(item),
                                      child: const Icon(Icons.restart_alt_outlined),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _replayAttempt(_ProblemAttempt attempt) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('문제를 불러오는 중...')),
    );
    ApiClient.instance
        .replayProblemHabit(codebaseId: attempt.codebaseId, seed: attempt.seed)
        .then((quest) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '문제 불러옴: ${quest['data']?['quest_title'] != null ? '1개' : '완료'}',
          ),
        ),
      );
      // TODO: navigate into 문제풀이 화면 with quest payload.
    }).catchError((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('불러오기 실패: $error')),
      );
    });
  }

  void _replayBatch(List<_ProblemAttempt> attempts) async {
    if (attempts.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${attempts.length}문제 다시 불러오는 중...')),
    );
    for (final item in attempts) {
      try {
        await ApiClient.instance
            .replayProblemHabit(codebaseId: item.codebaseId, seed: item.seed);
      } catch (_) {
        // ignore individual failures; continue batch
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${attempts.length}문제 준비 완료 (문제풀이 화면에서 순차 진행하세요)')),
    );
  }

  Widget _buildFlashcardPanel(double scale) {
    final query = _flashcardSearchController.text.trim().toLowerCase();
    final onlyWeak = _onlyWeakFlashcards;
    final cards = _flashcards
        .where((c) =>
            (query.isEmpty ||
                c.tag.toLowerCase().contains(query.replaceAll('#', ''))) &&
            (!onlyWeak || c.weaknessCount > 0))
        .toList()
      ..sort((a, b) =>
          onlyWeak ? b.weaknessCount.compareTo(a.weaknessCount) : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '플래시카드 보기',
              style: GoogleFonts.inter(
                fontSize: 18 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Text('나의 약점 보기'),
                Switch(
                  value: onlyWeak,
                  onChanged: (value) =>
                      setState(() => _onlyWeakFlashcards = value),
                ),
              ],
            ),
            if (onlyWeak)
              TextButton.icon(
                onPressed: () => _showWeaknessReport(scale),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('보고서 보기'),
              ),
          ],
        ),
        SizedBox(height: 10 * scale),
        TextField(
          controller: _flashcardSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '태그를 검색해 보세요',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10 * scale),
            ),
          ),
        ),
        SizedBox(height: 14 * scale),
        Expanded(
          child: cards.isEmpty
              ? Center(
                  child: Text(
                    '조건에 맞는 플래시카드가 없습니다.',
                    style: TextStyle(
                      fontSize: 13 * scale,
                      color: Colors.grey.shade600,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: cards.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10 * scale),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return Container(
                      padding: EdgeInsets.all(14 * scale),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12 * scale),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 3,
                            color: Color(0x15000000),
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8 * scale,
                                  vertical: 4 * scale,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B402B)
                                      .withOpacity(0.08),
                                  borderRadius:
                                      BorderRadius.circular(8 * scale),
                                ),
                                child: Text(
                                  card.tag,
                                  style: TextStyle(
                                    fontSize: 12 * scale,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1B402B),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8 * scale),
                              Text(
                                card.subject,
                                style: TextStyle(
                                  fontSize: 12 * scale,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const Spacer(),
                              if (card.weaknessCount > 0)
                                Text(
                                  '지적 ${card.weaknessCount}회',
                                  style: TextStyle(
                                    fontSize: 12 * scale,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.redAccent.shade200,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 8 * scale),
                          Text(
                            card.concept,
                            style: TextStyle(
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showWeaknessReport(double scale) {
    final subjects = _flashcards.map((c) => c.subject).toSet().toList()..sort();
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final filtered = _flashcards
            .where((c) =>
                c.weaknessCount > 0 &&
                (_reportSubjectFilter == null ||
                    _reportSubjectFilter == c.subject))
            .toList();
        final total = filtered.fold<int>(0, (sum, c) => sum + c.weaknessCount);
        return Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '약점 태그 보고서 (Top30 버블)',
                    style: GoogleFonts.inter(
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  DropdownButton<String?>(
                    value: _reportSubjectFilter,
                    hint: const Text('과목 필터'),
                    onChanged: (value) => setState(() => _reportSubjectFilter = value),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('전체')),
                      ...subjects.map(
                        (s) => DropdownMenuItem(value: s, child: Text(s)),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12 * scale),
              Wrap(
                spacing: 8 * scale,
                runSpacing: 8 * scale,
                children: filtered.map((c) {
                  final size =
                      (40 + math.min(c.weaknessCount, 30) * 3).toDouble();
                  final active = _reportSubjectFilter == null ||
                      _reportSubjectFilter == c.subject;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF1B402B).withOpacity(0.12)
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? const Color(0xFF1B402B)
                            : Colors.grey.shade500,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      c.tag,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11 * scale,
                        color: active
                            ? const Color(0xFF1B402B)
                            : Colors.grey.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 14 * scale),
              Text(
                '과목별 비중',
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6 * scale),
              ...subjects.map((s) {
                final value = _flashcards
                    .where((c) => c.subject == s)
                    .fold<int>(0, (sum, c) => sum + c.weaknessCount);
                final pct = total == 0 ? 0 : (value / total * 100).round();
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4 * scale),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120 * scale,
                        child: Text(
                          s,
                          style: TextStyle(fontSize: 12 * scale),
                        ),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : value / total,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          color: const Color(0xFF1B402B),
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      Text('$pct%'),
                    ],
                  ),
                );
              }),
              SizedBox(height: 10 * scale),
              Text(
                '자주 틀린 과목부터 정리해 보세요. 과목 필터를 바꾸면 해당 과목 태그만 강조됩니다.',
                style: TextStyle(
                  fontSize: 12 * scale,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOxQuizPanel(double scale) {
    final questions = _oxQuestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'O, X 퀴즈 (gemini-3.1-flash-lite, LaTeX 지원)',
          style: GoogleFonts.inter(
            fontSize: 18 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10 * scale),
        Text(
          '태그를 최대 20개 선택하면 태그당 최대 3문항을 생성/재사용합니다. 각 태그에 50문항 이상이면 더 이상 생성하지 않고 재사용만 합니다.',
          style: TextStyle(
            fontSize: 12 * scale,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 10 * scale),
        TextField(
          controller: _oxTagInputController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '#적분, #확률 처럼 콤마로 입력 후 적용',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.check),
              onPressed: _applyOxTagsFromInput,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10 * scale),
            ),
          ),
        ),
        SizedBox(height: 8 * scale),
        if (_oxSelectedTags.isNotEmpty)
          Wrap(
            spacing: 8 * scale,
            runSpacing: 8 * scale,
            children: _oxSelectedTags.map((tag) {
              return Chip(
                label: Text(tag),
                onDeleted: () => setState(() {
                  _oxSelectedTags.remove(tag);
                }),
              );
            }).toList(),
          ),
        SizedBox(height: 12 * scale),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _oxLoading || _oxSelectedTags.isEmpty
                  ? null
                  : _generateOxQuiz,
              icon: _oxLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('퀴즈 생성 / 불러오기'),
            ),
            SizedBox(width: 10 * scale),
            if (_oxScore != null)
              Text(
                '채점 결과: $_oxScore / ${questions.length}',
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B402B),
                ),
              ),
          ],
        ),
        SizedBox(height: 10 * scale),
        Expanded(
          child: questions.isEmpty
              ? Center(
                  child: Text(
                    '퀴즈를 생성하면 여기에 표시됩니다.',
                    style: TextStyle(
                      fontSize: 13 * scale,
                      color: Colors.grey.shade600,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: questions.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10 * scale),
                  itemBuilder: (context, index) {
                    final q = questions[index];
                    return Container(
                      padding: EdgeInsets.all(12 * scale),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12 * scale),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                q.tag,
                                style: TextStyle(
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1B402B),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '정답 저장됨 · 서버 캐시 사용',
                                style: TextStyle(
                                  fontSize: 11 * scale,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8 * scale),
                          Text(
                            q.question,
                            style: TextStyle(
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          Row(
                            children: [
                              _oxAnswerButton(
                                scale: scale,
                                label: 'O',
                                selected: q.userAnswer == true,
                                onTap: () => setState(() => q.userAnswer = true),
                              ),
                              SizedBox(width: 8 * scale),
                              _oxAnswerButton(
                                scale: scale,
                                label: 'X',
                                selected: q.userAnswer == false,
                                onTap: () =>
                                    setState(() => q.userAnswer = false),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (questions.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _gradeOx,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B402B),
                foregroundColor: Colors.white,
              ),
              child: const Text('채점하기'),
            ),
          ),
      ],
    );
  }

  List<_OxQuestion> get _currentOxQuestions => _oxQuestions;

  void _generateOxQuiz() {
    if (_oxSelectedTags.isEmpty) return;
    setState(() {
      _oxLoading = true;
      _oxScore = null;
    });
    ApiClient.instance
        .generateOxQuiz(tags: _oxSelectedTags.toList(), perTag: 3)
        .then((items) {
      setState(() {
        _oxQuestions
          ..clear()
          ..addAll(items.map(
            (item) => _OxQuestion(
              id: item.id,
              tag: item.tag,
              question: item.question,
              answer: item.answer,
            ),
          ));
        _oxLoading = false;
      });
    }).catchError((error) {
      setState(() {
        _oxLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('퀴즈 생성 실패: $error')),
      );
    });
  }

  void _applyOxTagsFromInput() {
    final raw = _oxTagInputController.text;
    final parsed = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.startsWith('#') ? e : '#$e')
        .toList();
    setState(() {
      _oxSelectedTags
        ..clear()
        ..addAll(parsed.take(20));
    });
  }

  void _gradeOx() {
    final questions = _currentOxQuestions;
    if (questions.isEmpty) return;
    var correct = 0;
    for (final q in questions) {
      if (q.userAnswer == q.answer) correct++;
    }
    setState(() => _oxScore = correct);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('채점 완료: $correct / ${questions.length}')),
    );
  }

  Widget _oxAnswerButton({
    required double scale,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor:
              selected ? const Color(0xFF1B402B) : Colors.white,
          foregroundColor: selected ? Colors.white : Colors.black87,
          side: BorderSide(
            color:
                selected ? const Color(0xFF1B402B) : Colors.grey.shade400,
          ),
          padding: EdgeInsets.symmetric(vertical: 10 * scale),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
  Widget _buildFilterPanel(double scale) {
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: const Color(0xFFE1E3E6)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '필터',
              style: GoogleFonts.inter(
                fontSize: 16 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12 * scale),
            Text(
              '기간 (일) — 문제 다시풀기만 지원',
              style: TextStyle(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 6 * scale),
            Wrap(
              spacing: 6 * scale,
              runSpacing: 6 * scale,
              children: _dayOptions.map((day) {
                final selected = _selectedDays.contains(day);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selected ? _selectedDays.remove(day) : _selectedDays.add(day);
                    });
                    _loadProblemHistory();
                  },
                child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * scale,
                      vertical: 6 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1B402B)
                          : const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.circular(8 * scale),
                    ),
                    child: Text(
                      '$day일',
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 12 * scale),
            TextField(
              controller: _hashtagController,
              onChanged: (_) {
                setState(() {});
                _loadProblemHistory();
              },
              decoration: InputDecoration(
                labelText: '해시태그 검색',
                hintText: '#적분, #확률 등',
                isDense: true,
                prefixIcon: const Icon(Icons.tag),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10 * scale),
                ),
              ),
            ),
            SizedBox(height: 10 * scale),
            Text(
              '문제를 다시 풀 때는 저장된 “코드베이스 번호 + 시드” 조합으로 동일 문제를 재생성합니다.',
              style: TextStyle(
                fontSize: 11 * scale,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 12 * scale),
            ElevatedButton.icon(
              onPressed: _filteredAttempts.isEmpty
                  ? null
                  : () => _replayBatch(_filteredAttempts),
              icon: const Icon(Icons.replay_circle_filled_outlined),
              label: Text('일괄 다시풀기 (${_filteredAttempts.length}문제)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B402B),
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 8 * scale),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectMode = !_selectMode;
                  if (!_selectMode) _selectedAttemptKeys.clear();
                });
              },
              icon: Icon(_selectMode ? Icons.check_box : Icons.check_box_outline_blank),
              label: Text(_selectMode ? '선택 다시풀기 모드 종료' : '선택 다시풀기 모드'),
            ),
            if (_selectMode)
              Padding(
                padding: EdgeInsets.only(top: 8 * scale),
                child: ElevatedButton(
                  onPressed: _selectedAttemptKeys.isEmpty
                      ? null
                      : () => _replayBatch(
                            _filteredAttempts
                                .where((a) => _selectedAttemptKeys.contains(_attemptKey(a)))
                                .toList(),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedAttemptKeys.isEmpty
                        ? Colors.grey
                        : const Color(0xFF1B402B),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    '${_selectedAttemptKeys.length}문제 다시풀기',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPanel(double scale) {
    final messages = [
      {'sender': 'Tutor', 'text': '틀린 문제의 핵심 개념을 짧게 리마인드해 드릴게요.'},
      {'sender': 'Student', 'text': '적분의 평균값 정리를 자꾸 헷갈려요.'},
      {'sender': 'Tutor', 'text': '함수의 연속성과 도함수의 존재 조건을 먼저 체크하면 좋아요.'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '채팅형 복습 (더미)',
          style: GoogleFonts.inter(
            fontSize: 18 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10 * scale),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12 * scale),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: EdgeInsets.all(12 * scale),
            child: ListView.separated(
              itemCount: messages.length,
              separatorBuilder: (_, __) => SizedBox(height: 8 * scale),
              itemBuilder: (context, index) {
                final message = messages[index];
                final sender = message['sender']!;
                final text = message['text']!;
                final isTutor = sender == 'Tutor';
                return Align(
                  alignment:
                      isTutor ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12 * scale,
                      vertical: 10 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: isTutor
                          ? Colors.white
                          : const Color(0xFF1B402B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10 * scale),
                      border: Border.all(
                        color: isTutor
                            ? const Color(0xFFE5E7EB)
                            : const Color(0xFF1B402B).withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 13 * scale),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: 10 * scale),
        TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: '곧 채팅형 복습이 열립니다.',
            prefixIcon: const Icon(Icons.chat_bubble_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12 * scale),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConceptPanel(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '개념 다시보기',
          style: GoogleFonts.inter(
            fontSize: 18 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10 * scale),
        Text(
          '학습 내역 기반 개념 복습 화면이 여기에 표시됩니다. (리뉴얼 예정)',
          style: TextStyle(
            fontSize: 13 * scale,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 12 * scale),
        Expanded(
          child: Center(
            child: Icon(
              Icons.menu_book_outlined,
              size: 64 * scale,
              color: Colors.grey.shade400,
            ),
          ),
        ),
      ],
    );
  }
} // ← _WeaknessReviewModalState 닫는 중괄호

class _ReviewActionTile extends StatelessWidget {
  const _ReviewActionTile({
    required this.action,
    required this.scale,
    required this.width,
    required this.height,
    this.iconSize,
    this.onTap,
    this.selected = false,
  });

  final _ReviewActionEntry action;
  final double scale;
  final double width;
  final double height;
  final double? iconSize;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14 * scale),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14 * scale),
          border: Border.all(
            color:
                selected ? const Color(0xFF1B402B) : const Color(0xFFE5E5E5),
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4,
              color: Color(0x22000000),
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 12 * scale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              action.icon,
              size: iconSize ?? 34 * scale,
              color:
                  selected ? const Color(0xFF1B402B) : Colors.grey.shade700,
            ),
            SizedBox(height: 8 * scale),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14 * scale,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF1B402B)
                    : Colors.grey.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
