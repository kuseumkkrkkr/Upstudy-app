import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/ox_quiz_page.dart';
import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/rating_detail_modal.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/ui/components/tag_picker_dialog.dart';

VoidCallback buildWeaknessReviewAction(
  BuildContext context, {
  VoidCallback? reopenStudyModal,
}) {
  return () {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future.microtask(
      () => showWeaknessReviewModal(
        context: navigator.context,
        onBackToStudyModal: reopenStudyModal,
      ),
    );
  };
}

Future<T?> showWeaknessReviewModal<T>({
  required BuildContext context,
  VoidCallback? onBackToStudyModal,
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
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            Center(
              child: WeaknessReviewModal(
                onBackToStudyModal: onBackToStudyModal,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class WeaknessReviewModal extends StatefulWidget {
  const WeaknessReviewModal({
    super.key,
    this.onBackToStudyModal,
  });
  final VoidCallback? onBackToStudyModal;

  @override
  State<WeaknessReviewModal> createState() => _WeaknessReviewModalState();
}

enum _ReviewSection { problemRedo, concept, oxQuiz }

class _ReviewActionEntry {
  const _ReviewActionEntry({
    required this.section,
    required this.label,
  });
  final _ReviewSection section;
  final String label;
}

class _ProblemAttempt {
  const _ProblemAttempt({
    required this.titleBlocks,
    required this.tags,
    required this.updatedAt,
    required this.retryCount,
    required this.seed,
    required this.codebaseId,
    this.questId,
  });
  final List<ContentBlock> titleBlocks; // quest_title JSON blocks
  final List<String> tags;
  final DateTime updatedAt;
  final int retryCount;
  final String seed;
  final int codebaseId;
  final String? questId;
}

List<ContentBlock> _parseBlocks(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['blocks'] as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((b) => ContentBlock(
              type: b['type']?.toString() ?? 'text',
              content: b['content']?.toString() ?? '',
            ))
        .toList();
  } catch (_) {
    return [ContentBlock(type: 'text', content: raw)];
  }
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

class _ChatMessage {
  const _ChatMessage({
    required this.sender,
    required this.text,
  });
  final String sender;
  final String text;
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
      label: '문제 다시풀기',
    ),
    _ReviewActionEntry(
      section: _ReviewSection.concept,
      label: '개념 다시보기',
    ),
    _ReviewActionEntry(
      section: _ReviewSection.oxQuiz,
      label: 'OX퀴즈 풀기',
    ),
  ];

  bool _loading = true;
  String? _errorMessage;
  List<WeaknessTag> _weaknessTags = const [];
  final Set<String> _selectedWeakTags = <String>{};

  static const _dayOptions = [1, 3, 7, 14, 30];

  int _selectedDays = 7;
  _ReviewSection _selectedSection = _ReviewSection.problemRedo;
  final PageController _sectionPageController = PageController(initialPage: 0);

  final TextEditingController _hashtagController = TextEditingController();
  final TextEditingController _flashcardSearchController =
      TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

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
  int? _lastOxPerTag;
  bool _onlyWeakFlashcards = false;
  String? _reportSubjectFilter;
  bool _oxLoading = false;
  bool _selectMode = false;
  final Set<String> _selectedAttemptKeys = {};
  bool _chatSending = false;
  final List<_ChatMessage> _chatMessages = [
    _ChatMessage(
      sender: 'Tutor',
      text: '틀린 문제의 핵심 개념을 짧게 리마인드해 드릴게요.',
    ),
    _ChatMessage(
      sender: 'Student',
      text: '적분의 평균값 정리를 자꾸 헷갈려요.',
    ),
    _ChatMessage(
      sender: 'Tutor',
      text: '먼저 함수 연속성과 도함수 존재 조건을 체크하고, 평균값 정리의 가정이 맞는지 확인해 보세요.',
    ),
  ];

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
    _chatController.dispose();
    _chatScrollController.dispose();
    _sectionPageController.dispose();
    super.dispose();
  }

  void _handleBackTap() {
    Navigator.of(context).pop();
    if (widget.onBackToStudyModal != null) {
      Future.microtask(widget.onBackToStudyModal!);
    }
  }

  int _indexFromSection(_ReviewSection section) {
    final index = _actions.indexWhere((entry) => entry.section == section);
    if (index < 0) return 0;
    if (index >= _actions.length) return _actions.length - 1;
    return index;
  }

  _ReviewSection _sectionFromIndex(int index) {
    if (index < 0 || index >= _actions.length) {
      return _ReviewSection.problemRedo;
    }
    return _actions[index].section;
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
        final modalRadius = 16 * scale;
        final horizontalPadding = 24 * scale;
        final gap = 12 * scale;

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
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(modalRadius),
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
                                Icons.arrow_back,
                                color: Colors.black,
                                size: 30 * scale,
                              ),
                              onPressed: _handleBackTap,
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
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: _buildSectionBody(
                            scale: scale,
                            gap: gap,
                          ),
                        ),
                      ),
                      SizedBox(height: 12 * scale),
                      _buildActionBottomBar(
                        scale: scale,
                        horizontalPadding: horizontalPadding,
                        gap: gap,
                        modalRadius: modalRadius,
                      ),
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
    return PageView(
      controller: _sectionPageController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (index) {
        final nextSection = _sectionFromIndex(index);
        if (nextSection == _selectedSection) return;
        setState(() => _selectedSection = nextSection);
      },
      children: [
        _buildProblemRedoBody(scale: scale, gap: gap),
        _buildConceptPanel(scale),
        _buildOxQuizPanel(scale),
      ],
    );
  }

  Widget _buildProblemRedoBody({
    required double scale,
    required double gap,
  }) {
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
  }

  Widget _buildActionBottomBar({
    required double scale,
    required double horizontalPadding,
    required double gap,
    required double modalRadius,
  }) {
    return Container(
      height: 60 * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(modalRadius),
          bottomRight: Radius.circular(modalRadius),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4 * scale),
      child: Row(
        children: [
          for (var i = 0; i < _actions.length; i++) ...[
            Expanded(
              child: _ReviewActionTile(
                action: _actions[i],
                scale: scale,
                width: double.infinity,
                height: 44 * scale,
                selected: _selectedSection == _actions[i].section,
                onTap: () {
                  final section = _actions[i].section;
                  final pageIndex = _indexFromSection(section);
                  setState(() => _selectedSection = section);
                  _sectionPageController.animateToPage(
                    pageIndex,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
            ),
            if (i != _actions.length - 1) SizedBox(width: gap),
          ],
        ],
      ),
    );
  }

  Future<void> _loadProblemHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final items = await ApiClient.instance.fetchSolveHistory(
        days: _selectedDays,
        limit: 200,
        kind: 'problem',
      );
      if (!mounted) return;
      setState(() {
        _attempts
          ..clear()
          ..addAll(
            items.map((it) {
              final data = it.data ?? const <String, dynamic>{};
              return _ProblemAttempt(
                titleBlocks: _parseBlocks(it.questTitleRaw),
                tags: it.hashTags,
                updatedAt: DateTime.tryParse(it.createdAt) ?? DateTime.now(),
                retryCount: (data['retry_count'] as num?)?.toInt() ?? 1,
                seed: (it.seed ?? data['seed'] as int? ?? 0).toString(),
                codebaseId: it.codebaseId ?? data['codebase_id'] as int? ?? 0,
                questId: it.questId,
              );
            }),
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
        _selectedDays;
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
    const green = Color(0xFF1B402B);
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
          Row(
            children: [
              Text(
                '풀이 내역',
                style: GoogleFonts.inter(
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 6 * scale),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 7 * scale,
                  vertical: 2 * scale,
                ),
                decoration: BoxDecoration(
                  color: green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20 * scale),
                ),
                child: Text(
                  '${attempts.length}',
                  style: TextStyle(
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w700,
                    color: green,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          Expanded(
            child: _historyLoading
                ? const Center(child: CircularProgressIndicator())
                : _historyError != null
                ? Center(
                    child: Text(
                      _historyError!,
                      style: TextStyle(fontSize: 13 * scale, color: Colors.redAccent),
                    ),
                  )
                : attempts.isEmpty
                ? Center(
                    child: Text(
                      '조건에 맞는 풀이 내역이 없습니다.',
                      style: TextStyle(fontSize: 13 * scale, color: Colors.grey.shade500),
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
                            Padding(
                              padding: EdgeInsets.only(top: 4 * scale, right: 4 * scale),
                              child: Checkbox(
                                value: selected,
                                activeColor: green,
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
                            ),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(12 * scale),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10 * scale),
                                border: Border.all(
                                  color: selected
                                      ? green.withOpacity(0.5)
                                      : const Color(0xFFE8E8E8),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 태그 + 날짜 행
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      if (item.tags.isNotEmpty) ...[
                                        Expanded(
                                          child: Wrap(
                                            spacing: 4 * scale,
                                            runSpacing: 4 * scale,
                                            children: item.tags
                                                .take(3)
                                                .map((t) => Container(
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal: 7 * scale,
                                                        vertical: 3 * scale,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: green.withOpacity(0.08),
                                                        borderRadius: BorderRadius.circular(6 * scale),
                                                      ),
                                                      child: Text(
                                                        t.startsWith('#') ? t : '#$t',
                                                        style: TextStyle(
                                                          fontSize: 11 * scale,
                                                          fontWeight: FontWeight.w600,
                                                          color: green,
                                                        ),
                                                      ),
                                                    ))
                                                .toList(),
                                          ),
                                        ),
                                      ] else
                                        const Spacer(),
                                      SizedBox(width: 6 * scale),
                                      Text(
                                        '${item.updatedAt.month}/${item.updatedAt.day}',
                                        style: TextStyle(
                                          fontSize: 11 * scale,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8 * scale),
                                  // 문제 제목 (ContentBlocksView)
                                  item.titleBlocks.isNotEmpty
                                      ? ContentBlocksView(
                                          blocks: item.titleBlocks,
                                          textStyle: TextStyle(
                                            fontSize: 13 * scale,
                                            fontWeight: FontWeight.w600,
                                            height: 1.45,
                                            color: Colors.black87,
                                          ),
                                          latexStyle: TextStyle(
                                            fontSize: 13 * scale,
                                            fontWeight: FontWeight.w600,
                                            height: 1.45,
                                            color: Colors.black87,
                                          ),
                                        )
                                      : Text(
                                          '문제 정보 없음',
                                          style: TextStyle(
                                            fontSize: 13 * scale,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                  SizedBox(height: 10 * scale),
                                  // 하단: 재시도 횟수 + 다시풀기 버튼
                                  Row(
                                    children: [
                                      if (item.retryCount > 1)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8 * scale,
                                            vertical: 3 * scale,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6 * scale),
                                          ),
                                          child: Text(
                                            '${item.retryCount}회 시도',
                                            style: TextStyle(
                                              fontSize: 11 * scale,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () => _replayAttempt(item),
                                        icon: Icon(Icons.replay_rounded, size: 15 * scale),
                                        label: Text(
                                          '다시풀기',
                                          style: TextStyle(fontSize: 12 * scale),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: green,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10 * scale,
                                            vertical: 6 * scale,
                                          ),
                                        ),
                                      ),
                                    ],
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
        .replayProblemHabit(
          codebaseId: attempt.codebaseId,
          seed: attempt.seed,
          questId: attempt.questId,
        )
        .then((quest) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final config = ProblemSolveConfig(quests: [quest]);
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => BuildpageWidget(config: config)),
      );
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
      SnackBar(content: Text('${attempts.length}문제 불러오는 중...')),
    );
    final quests = <Map<String, dynamic>>[];
    for (final item in attempts) {
      try {
        final quest = await ApiClient.instance.replayProblemHabit(
          codebaseId: item.codebaseId,
          seed: item.seed,
          questId: item.questId,
        );
        quests.add(quest);
      } catch (_) {
        // ignore individual failures; continue batch
      }
    }
    if (!mounted) return;
    if (quests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('불러올 수 있는 문제가 없어요')),
      );
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final config = ProblemSolveConfig(quests: quests);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => BuildpageWidget(config: config)),
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
          'O, X 퀴즈',
          style: GoogleFonts.inter(
            fontSize: 18 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10 * scale),
        Text(
          '계층형 태그를 선택하면 태그당 2~3문항을 DB에서 무작위로 불러옵니다. 퀴즈를 생성한 뒤 시작 버튼으로 별도 화면에서 풉니다.',
          style: TextStyle(
            fontSize: 12 * scale,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 10 * scale),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _oxLoading ? null : _openOxTagPicker,
              icon: const Icon(Icons.checklist_rtl),
              label: const Text('태그 선택하기'),
            ),
            SizedBox(width: 8 * scale),
            if (_oxSelectedTags.isNotEmpty)
              Text(
                '${_oxSelectedTags.length}개 선택됨 (최대 20개)',
                style: TextStyle(
                  fontSize: 12 * scale,
                  color: Colors.grey.shade700,
                ),
              ),
          ],
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
              onPressed:
                  _oxLoading || _oxSelectedTags.isEmpty ? null : _generateOxQuiz,
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
            if (_lastOxPerTag != null)
              Text(
                '이번 세션: 태그당 $_lastOxPerTag문항',
                style: TextStyle(
                  fontSize: 12 * scale,
                  color: Colors.grey.shade700,
                ),
              ),
          ],
        ),
        SizedBox(height: 12 * scale),
        Container(
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
                    '생성된 문항',
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_oxScore != null)
                    Text(
                      '마지막 점수: $_oxScore / ${questions.length}',
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B402B),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8 * scale),
              Text(
                questions.isEmpty
                    ? '퀴즈를 생성하면 시작 버튼이 활성화됩니다.'
                    : '${questions.length}문항 준비됨. 시작하면 별도 화면에서 한 문제씩 풀 수 있어요.',
                style: TextStyle(
                  fontSize: 12 * scale,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 12 * scale),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: questions.isEmpty ? null : _startOxQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B402B),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 14 * scale,
                      vertical: 12 * scale,
                    ),
                  ),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('OX 퀴즈 시작'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_OxQuestion> get _currentOxQuestions => _oxQuestions;

  Future<void> _startOxQuiz() async {
    final questions = _currentOxQuestions;
    if (questions.isEmpty) return;
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => OxQuizPage(
          questions: questions
              .map(
                (q) => OxQuizQuestion(
                  id: q.id,
                  tag: q.tag,
                  question: q.question,
                  answer: q.answer,
                ),
              )
              .toList(),
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() => _oxScore = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OX 퀴즈 완료: $result / ${questions.length}')),
      );
    }
  }

  Future<void> _generateOxQuiz() async {
    if (_oxSelectedTags.isEmpty) return;
    final perTag = 2 + math.Random().nextInt(2); // 2~3문항 무작위
    setState(() {
      _oxLoading = true;
      _oxScore = null;
    });
    try {
      final items = await ApiClient.instance
          .generateOxQuiz(tags: _oxSelectedTags.toList(), perTag: perTag);
      if (!mounted) return;
      setState(() {
        _oxQuestions
          ..clear()
          ..addAll(items.map(
            (item) => _OxQuestion(
              id: item.id,
              tag: item.tag,
              question: item.question,
              answer: item.answer,
            )..userAnswer = null,
          ));
        _oxLoading = false;
        _lastOxPerTag = perTag;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _oxLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('퀴즈 생성 실패: $error')),
      );
    }
  }

  Future<void> _openOxTagPicker() async {
    final picked = await showTagPickerDialog(
      context: context,
      initialTags: _oxSelectedTags.toList(),
    );
    if (picked == null) return;
    setState(() {
      _oxSelectedTags
        ..clear()
        ..addAll(picked.take(20));
    });
  }

  Future<void> _appendChatMessage(_ChatMessage message) async {
    setState(() => _chatMessages.add(message));
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!_chatScrollController.hasClients) return;
    final position = _chatScrollController.position;
    final target = position.maxScrollExtent + 60;
    _chatScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendChat() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _chatSending) return;
    _chatController.clear();
    await _appendChatMessage(
      _ChatMessage(sender: 'Student', text: text),
    );
    setState(() => _chatSending = true);
    // 간단한 모의 튜터 응답
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    await _appendChatMessage(
      _ChatMessage(
        sender: 'Tutor',
        text: '이 부분은 베타 버전입니다. 곧 실시간 튜터 응답이 연결됩니다.\n지금은 먼저 핵심 정의와 대표 예제를 3분 안에 복습해 보세요.',
      ),
    );
    if (!mounted) return;
    setState(() => _chatSending = false);
  }

  Widget _buildFilterPanel(double scale) {
    const green = Color(0xFF1B402B);
    final filtered = _filteredAttempts;

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
            // 기간 선택
            Text(
              '기간',
              style: TextStyle(
                fontSize: 12 * scale,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 6 * scale),
            Row(
              children: _dayOptions.map((day) {
                final selected = _selectedDays == day;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_selectedDays == day) return;
                      setState(() => _selectedDays = day);
                      _loadProblemHistory();
                    },
                    child: Container(
                      margin: EdgeInsets.only(
                        right: day != _dayOptions.last ? 4 * scale : 0,
                      ),
                      padding: EdgeInsets.symmetric(vertical: 7 * scale),
                      decoration: BoxDecoration(
                        color: selected ? green : const Color(0xFFF3F3F3),
                        borderRadius: BorderRadius.circular(8 * scale),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day}일',
                        style: TextStyle(
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 12 * scale),

            // 태그 검색
            TextField(
              controller: _hashtagController,
              onChanged: (_) {
                setState(() {});
                _loadProblemHistory();
              },
              decoration: InputDecoration(
                hintText: '태그 검색  예) #적분',
                isDense: true,
                prefixIcon: Icon(Icons.tag, size: 18 * scale),
                filled: true,
                fillColor: const Color(0xFFF7F7F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8 * scale),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10 * scale),
              ),
            ),
            SizedBox(height: 14 * scale),

            // 일괄 다시풀기
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: filtered.isEmpty
                    ? null
                    : () => _replayBatch(filtered),
                icon: const Icon(Icons.replay, size: 16),
                label: Text('전체 다시풀기 (${filtered.length}문제)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  padding: EdgeInsets.symmetric(vertical: 10 * scale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8 * scale),
                  ),
                ),
              ),
            ),
            SizedBox(height: 6 * scale),

            // 선택 모드 토글
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectMode = !_selectMode;
                    if (!_selectMode) _selectedAttemptKeys.clear();
                  });
                },
                icon: Icon(
                  _selectMode ? Icons.close : Icons.checklist_rounded,
                  size: 16,
                ),
                label: Text(_selectMode ? '선택 모드 종료' : '선택 다시풀기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: green,
                  side: const BorderSide(color: Color(0xFF1B402B), width: 1),
                  padding: EdgeInsets.symmetric(vertical: 10 * scale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8 * scale),
                  ),
                ),
              ),
            ),
            if (_selectMode) ...[
              SizedBox(height: 6 * scale),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedAttemptKeys.isEmpty
                      ? null
                      : () => _replayBatch(
                            filtered
                                .where((a) => _selectedAttemptKeys.contains(_attemptKey(a)))
                                .toList(),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    padding: EdgeInsets.symmetric(vertical: 10 * scale),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8 * scale),
                    ),
                  ),
                  child: Text('선택 ${_selectedAttemptKeys.length}문제 다시풀기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatPanel(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '채팅형 복습 (베타)',
          style: GoogleFonts.inter(
            fontSize: 18 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10 * scale),
        Text(
          '약점 태그나 개념을 적어 보내면 곧바로 짧은 리마인드가 돌아옵니다. (현재는 베타 응답)',
          style: TextStyle(fontSize: 12 * scale, color: Colors.grey.shade700),
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
              controller: _chatScrollController,
              itemCount: _chatMessages.length,
              separatorBuilder: (_, __) => SizedBox(height: 8 * scale),
              itemBuilder: (context, index) {
                final message = _chatMessages[index];
                final sender = message.sender;
                final text = message.text;
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
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                minLines: 1,
                maxLines: 3,
                onSubmitted: (_) => _sendChat(),
                decoration: InputDecoration(
                  hintText: '약점을 입력하거나 질문을 남겨 보세요.',
                  prefixIcon: const Icon(Icons.chat_bubble_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12 * scale),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 12 * scale,
                    horizontal: 12 * scale,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10 * scale),
            ElevatedButton.icon(
              onPressed: _chatSending ? null : _sendChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B402B),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 14 * scale,
                  vertical: 12 * scale,
                ),
              ),
              icon: _chatSending
                  ? SizedBox(
                      width: 16 * scale,
                      height: 16 * scale,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _chatSending ? '보내는 중' : '보내기',
                style: TextStyle(fontSize: 13 * scale),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConceptPanel(double scale) {
    final tags = _weaknessTags;
    final selected = _selectedWeakTags;

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
        SizedBox(height: 8 * scale),
        if (tags.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                '약점 태그 데이터가 없습니다.',
                style: TextStyle(fontSize: 13 * scale, color: Colors.grey.shade600),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final tag = tags[index];
                final isSel = selected.contains(tag.tag);
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2 * scale),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isSel,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selected.add(tag.tag);
                            } else {
                              selected.remove(tag.tag);
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          '${tag.tag} (${tag.count})',
                          style: TextStyle(fontSize: 13 * scale),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        SizedBox(height: 8 * scale),
        Wrap(
          spacing: 8 * scale,
          runSpacing: 8 * scale,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                final top = tags.take(10).map((t) => t.tag).toSet();
                setState(() => _selectedWeakTags.addAll(top));
              },
              icon: const Icon(Icons.auto_awesome),
              label: Text('자동선택 (상위10)', style: TextStyle(fontSize: 12 * scale)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B402B),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => showRatingDetailModal(context: context),
              icon: const Icon(Icons.bar_chart),
              label: Text('보고서 보기', style: TextStyle(fontSize: 12 * scale)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1B402B),
                side: const BorderSide(color: Color(0xFF1B402B)),
                padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('미구현 기능입니다.')),
                );
              },
              icon: const Icon(Icons.access_time_filled),
              label: Text('방금 틀린 개념', style: TextStyle(fontSize: 12 * scale)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('미구현 기능입니다.')),
                );
              },
              icon: const Icon(Icons.history),
              label: Text('최근30개 틀린 개념', style: TextStyle(fontSize: 12 * scale)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
              ),
            ),
          ],
        ),
        SizedBox(height: 8 * scale),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: selected.isEmpty
                ? null
                : () {
                    final sel = selected.toList();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookWidget(
                          book: buildConceptBook(sel),
                        ),
                      ),
                    );
                  },
            icon: Icon(Icons.play_arrow, size: 20 * scale),
            label: Text(
              selected.isEmpty
                  ? '태그를 선택하세요'
                  : '선택 개 개념학습하기',
              style: TextStyle(fontSize: 14 * scale),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B402B),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: 20 * scale,
                vertical: 14 * scale,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12 * scale),
              ),
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
    this.onTap,
    this.selected = false,
  });

  final _ReviewActionEntry action;
  final double scale;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF1B402B);
    final inactiveColor = Colors.grey.shade700;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6 * scale),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6 * scale),
        ),
        padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: selected ? 24 * scale : 0,
              height: 2 * scale,
              decoration: BoxDecoration(
                color: selected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6 * scale),
              ),
            ),
            SizedBox(height: 5 * scale),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: GoogleFonts.inter(
                fontSize: (selected ? 13 : 12) * scale,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? activeColor : inactiveColor,
              ),
              child: Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
