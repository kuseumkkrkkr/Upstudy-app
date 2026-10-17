import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:s11/shared/services/storage/local_db.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

//=============================================================================
// 노트패드 편집기
//=============================================================================

class NotepadPage extends StatefulWidget {
  const NotepadPage({super.key, this.persistenceEnabled = true});

  /// 테스트나 임시 세션에서 로컬 DB 입출력을 끌 수 있으며 기본 제품 동작은 저장을 유지한다.
  final bool persistenceEnabled;

  @override
  State<NotepadPage> createState() => _NotepadPageState();
}

class _NotepadPageState extends State<NotepadPage>
    with TickerProviderStateMixin {
  static const _storageKey = 'notepad_strokes_v2';
  static const _textStorageKey = 'notepad_text_v1';
  static const _titleStorageKey = 'notepad_title_v1';
  static const _baseHeight = 540.0;
  static const _extendHeight = 1200.0;
  static const _maxHeight = 50000.0;
  static const _minPointDistance = 0.6;
  static const _eraserRadius = 26.0;
  static const _lineGap = 28.0;

  // 색상 팔레트 (빨/파/검 3색만)
  static const List<Color> _penColors = [
    Color(0xFF000000), // 검정
    Color(0xFF1E88E5), // 파랑
    Color(0xFFE53935), // 빨강
  ];

  static const List<double> _penWidths = [1, 3, 5, 8];

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _recallController = TextEditingController();
  final TextEditingController _reviewTitleController = TextEditingController();
  final ValueNotifier<int> _paintVersion = ValueNotifier<int>(0);
  final List<_Stroke> _noteStrokes = <_Stroke>[];
  final List<_UndoAction> _noteUndoStack = <_UndoAction>[];
  final List<_UndoAction> _noteRedoStack = <_UndoAction>[];
  final List<_Stroke> _reviewStrokes = <_Stroke>[];
  final List<_UndoAction> _reviewUndoStack = <_UndoAction>[];
  final List<_UndoAction> _reviewRedoStack = <_UndoAction>[];

  List<_Stroke> get _strokes => _isReviewing ? _reviewStrokes : _noteStrokes;
  List<_UndoAction> get _undoStack =>
      _isReviewing ? _reviewUndoStack : _noteUndoStack;
  List<_UndoAction> get _redoStack =>
      _isReviewing ? _reviewRedoStack : _noteRedoStack;
  TextEditingController get _activeTextController =>
      _isReviewing ? _recallController : _textController;
  Size _composeSize = const Size(390, 540);
  final List<_Stroke> _pendingEraseRemoved = <_Stroke>[];

  double _canvasHeight = _baseHeight;
  _Stroke? _currentStroke;
  _ToolMode _toolMode = _ToolMode.pen;
  _MobileInputMode _mobileInputMode = _MobileInputMode.pen;
  int _nextStrokeOrder = 0;
  Offset? _lastFilteredPoint;
  Offset? _lastPoint;
  Offset? _eraserPosition;
  Timer? _saveTimer;

  bool _showLines = false;
  bool _isAttached = false;
  bool _isReviewing = false;
  bool _reviewCompleted = false;
  Color _penColor = Colors.black;
  double _penWidth = 3;
  bool _isHighlighter = false; // 형광펜 모드

  bool get _canPersist => widget.persistenceEnabled && !kIsWeb;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    unawaited(_loadStrokes());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _textController.dispose();
    _recallController.dispose();
    _reviewTitleController.dispose();
    _paintVersion.dispose();
    _saveTimer?.cancel();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 320 &&
        _canvasHeight < _maxHeight) {
      setState(
        () => _canvasHeight = (_canvasHeight + _extendHeight).clamp(
          _baseHeight,
          _maxHeight,
        ),
      );
    }
  }

  Future<void> _loadStrokes() async {
    if (!_canPersist) return;
    final raw = await LocalDb.instance.getString(_storageKey);
    final savedText = await LocalDb.instance.getString(_textStorageKey);
    final savedTitle = await LocalDb.instance.getString(_titleStorageKey);
    if (savedTitle != null) _titleController.text = savedTitle;
    if (savedText != null) {
      _textController.text = savedText;
    }
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = <_Stroke>[];
      for (final item in decoded) {
        if (item is Map) {
          loaded.add(_Stroke.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      if (!mounted) return;
      setState(() {
        _noteStrokes
          ..clear()
          ..addAll(loaded..sort((a, b) => a.order.compareTo(b.order)));
        _canvasHeight = _estimateHeight(loaded);
      });
      _paintVersion.value += 1;
    } catch (_) {
      // ignore
    }
  }

  double _estimateHeight(List<_Stroke> strokes) {
    var maxY = _baseHeight;
    for (final stroke in strokes) {
      for (final point in stroke.points) {
        if (point.position.dy + 320 > maxY) {
          maxY = point.position.dy + 320;
        }
      }
    }
    return maxY.clamp(_baseHeight, _maxHeight);
  }

  void _scheduleSave() {
    if (!_canPersist) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _persistStrokes);
  }

  Future<void> _persistStrokes() async {
    if (!_canPersist) return;
    final payload = jsonEncode(_noteStrokes.map((e) => e.toJson()).toList());
    await LocalDb.instance.setString(_storageKey, payload);
    await LocalDb.instance.setString(_textStorageKey, _textController.text);
    await LocalDb.instance.setString(_titleStorageKey, _titleController.text);
  }

  void _createNewNote() {
    setState(() {
      _isReviewing = false;
      _titleController.clear();
      _textController.clear();
      _strokes.clear();
      _undoStack.clear();
      _redoStack.clear();
      _isAttached = false;
      _isReviewing = false;
      _recallController.clear();
      _reviewStrokes.clear();
      _reviewUndoStack.clear();
      _reviewRedoStack.clear();
      _reviewCompleted = false;
      _currentStroke = null;
      _canvasHeight = _baseHeight;
    });
    _paintVersion.value += 1;
    _scheduleSave();
  }

  void _clearInk() {
    _strokes.clear();
    _undoStack.clear();
    _redoStack.clear();
    _currentStroke = null;
    _paintVersion.value += 1;
    _scheduleSave();
    if (mounted) setState(() {});
  }

  void _startBlankReview() {
    _recallController.clear();
    _reviewTitleController.text =
        '백지 복습 · ${_titleController.text.trim().isEmpty ? '제목 없는 노트' : _titleController.text}';
    setState(() {
      _reviewStrokes.clear();
      _reviewUndoStack.clear();
      _reviewRedoStack.clear();
      _currentStroke = null;
      _isReviewing = true;
    });
    _paintVersion.value++;
  }

  void _finishReview({bool completed = false}) {
    setState(() {
      _isReviewing = false;
      _currentStroke = null;
      _reviewCompleted = _reviewCompleted || completed;
    });
    _paintVersion.value++;
  }

  Future<void> _showReviewComparison() async {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '비교 닫기',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (sheetContext, animation, secondaryAnimation) => Stack(
        children: [
          Positioned.fill(
            top: 64,
            child: GestureDetector(
              onTap: () => Navigator.of(sheetContext).pop(),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: const ColoredBox(color: Color(0x5C111114)),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: StatefulBuilder(
                builder: (context, setSheetState) => SafeArea(
                  top: false,
                  child: Container(
                    key: const ValueKey('notepad-review-sheet'),
                    constraints: BoxConstraints(
                      maxHeight:
                          (MediaQuery.sizeOf(context).height - 64) *
                          (mobile ? .91 : .88),
                    ),
                    width: 920,
                    padding: mobile
                        ? const EdgeInsets.fromLTRB(14, 8, 14, 16)
                        : const EdgeInsets.fromLTRB(20, 8, 20, 22),
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Column(
                      children: [
                        _NotepadSheetHandle(),
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '백지 복습',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF7B7B83),
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    '원문과 비교',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: '닫기',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F1F3),
                                fixedSize: const Size(48, 48),
                                shape: const RoundedRectangleBorder(),
                              ),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                              },
                              icon: const Icon(Icons.close, size: 20),
                            ),
                          ],
                        ),
                        const Divider(height: 1, color: Color(0xFFE7E7EA)),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cards = [
                                _ReviewCard(
                                  label: '기준 노트',
                                  title: _titleController.text.trim().isEmpty
                                      ? '제목 없는 노트'
                                      : _titleController.text,
                                  body: _textController.text.trim().isEmpty
                                      ? '타이핑한 내용 없음'
                                      : _textController.text,
                                  child: _buildInkPreview(_noteStrokes),
                                ),
                                _ReviewCard(
                                  label: '내가 기억한 내용',
                                  title: _recallController.text.trim().isEmpty
                                      ? '타이핑한 내용 없음'
                                      : _recallController.text,
                                  body: '',
                                  child: _buildInkPreview(_reviewStrokes),
                                ),
                              ];
                              return SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: constraints.maxWidth <= 720
                                    ? Column(
                                        children: [
                                          for (final card in cards)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              child: card,
                                            ),
                                        ],
                                      )
                                    : Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          for (final card in cards)
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                    ),
                                                child: card,
                                              ),
                                            ),
                                        ],
                                      ),
                              );
                            },
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE7E7EA)),
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 50),
                                    foregroundColor: const Color(0xFF17171A),
                                    side: const BorderSide(
                                      color: Color(0xFF17171A),
                                    ),
                                    shape: const RoundedRectangleBorder(),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  onPressed: () {
                                    _recallController.clear();
                                    setState(() {
                                      _reviewStrokes.clear();
                                      _reviewUndoStack.clear();
                                      _reviewRedoStack.clear();
                                    });
                                    _paintVersion.value++;
                                    Navigator.of(sheetContext).pop();
                                  },
                                  child: const Text('다시 써보기'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    Navigator.of(sheetContext).pop();
                                    _finishReview(completed: true);
                                  },
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 50),
                                    shape: const RoundedRectangleBorder(),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    backgroundColor: const Color(0xFF17171A),
                                  ),
                                  child: const Text('복습 완료'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInkPreview(List<_Stroke> strokes) => Container(
    width: double.infinity,
    color: Colors.white,
    child: FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: _composeSize.width,
        height: _composeSize.height,
        child: CustomPaint(
          painter: _NotepadPainter(
            strokes: strokes,
            current: null,
            toolMode: _ToolMode.pen,
            eraserRadius: _eraserRadius,
            eraserPosition: null,
            showLines: false,
            isDark: false,
            repaint: _paintVersion,
          ),
        ),
      ),
    ),
  );

  Future<void> _showNotepadMoreSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x52111114),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _NotepadSheetHandle(),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '노트 메뉴',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                    const Divider(height: 1, color: Color(0xFFEDEDF0)),
                    _NotepadMenuAction(
                      icon: Icons.menu_book_outlined,
                      title: '백지 복습 시작',
                      subtitle:
                          _textController.text.trim().isEmpty &&
                              _strokes.isEmpty
                          ? '먼저 복습할 내용을 적어주세요.'
                          : '원문을 가리고 기억에서 꺼내 씁니다.',
                      enabled:
                          !_isReviewing &&
                          (_textController.text.trim().isNotEmpty ||
                              _strokes.isNotEmpty),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Future<void>.delayed(
                          const Duration(milliseconds: 220),
                          () {
                            if (mounted) _startBlankReview();
                          },
                        );
                      },
                    ),
                    _NotepadMenuAction(
                      icon: _isAttached
                          ? Icons.check_circle_outline
                          : Icons.add,
                      title: _isAttached ? '현재 학습에 첨부됨' : '현재 학습에 첨부',
                      subtitle: '학습 화면에서 이 노트를 함께 봅니다.',
                      onTap: () {
                        setState(() => _isAttached = !_isAttached);
                        setSheetState(() {});
                      },
                    ),
                    _NotepadMenuAction(
                      icon: Icons.auto_fix_high_outlined,
                      title: '필기 전체 지우기',
                      subtitle: '입력한 글자는 그대로 둡니다.',
                      last: true,
                      onTap: () {
                        _clearInk();
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startStroke(Offset position, double pressure) {
    final stroke = _Stroke(
      color: _penColor,
      baseWidth: _penWidth,
      order: _nextStrokeOrder++,
      isHighlighter: _isHighlighter,
    );
    stroke.addPoint(position, _normalizePressure(pressure));
    _currentStroke = stroke;
    _lastPoint = position;
    _lastFilteredPoint = null;
    _paintVersion.value += 1;
  }

  void _updateStroke(Offset position, double pressure) {
    final last = _lastPoint;
    if (last != null && (position - last).distance < _minPointDistance) {
      return;
    }
    final filtered = _filterPoint(position);
    _currentStroke?.addPoint(filtered, _normalizePressure(pressure));
    _lastPoint = position;
    _paintVersion.value += 1;
  }

  /// 필요한 변수는 현재 작성 중인 획과 실행 취소 스택이다.
  /// 작동 원리는 완성된 획을 저장한 뒤 화면 전체를 갱신해 도구막대의 되돌리기 버튼도 즉시 활성화한다.
  void _endStroke() {
    final stroke = _currentStroke;
    final hasCompletedStroke = stroke != null && stroke.points.isNotEmpty;
    if (stroke != null && stroke.points.isNotEmpty) {
      _strokes.add(stroke);
      _recordAction(_AddAction(stroke));
      _scheduleSave();
    }
    _currentStroke = null;
    _lastPoint = null;
    _lastFilteredPoint = null;
    _eraserPosition = null;
    _paintVersion.value += 1;
    if (hasCompletedStroke && mounted) {
      setState(() {});
    }
  }

  void _startEraser(Offset position) {
    _pendingEraseRemoved.clear();
    _eraseAt(position);
    _eraserPosition = position;
    _paintVersion.value += 1;
  }

  void _updateEraser(Offset position) {
    _eraseAt(position);
    _eraserPosition = position;
    _paintVersion.value += 1;
  }

  /// 필요한 변수는 이번 지우개 동작에서 제거한 획 목록이다.
  /// 작동 원리는 제거 묶음을 하나의 실행 취소 항목으로 저장하고 도구 활성 상태를 다시 그린다.
  void _finishEraser() {
    final hasRemovedStroke = _pendingEraseRemoved.isNotEmpty;
    if (hasRemovedStroke) {
      _recordAction(_RemoveAction(List<_Stroke>.from(_pendingEraseRemoved)));
      _pendingEraseRemoved.clear();
      _scheduleSave();
    }
    _eraserPosition = null;
    _paintVersion.value += 1;
    if (hasRemovedStroke && mounted) {
      setState(() {});
    }
  }

  void _eraseAt(Offset position) {
    if (_strokes.isEmpty) return;
    final removed = <_Stroke>[];
    for (final stroke in _strokes) {
      if (stroke.hitTestCircle(position, _eraserRadius)) {
        removed.add(stroke);
      }
    }
    if (removed.isEmpty) return;
    _strokes.removeWhere(removed.contains);
    _pendingEraseRemoved.addAll(removed);
  }

  /// 필요한 변수는 마지막 실행 취소 항목과 현재 획 목록이다.
  /// 작동 원리는 추가·삭제 동작을 반대로 적용하고 버튼 활성 상태까지 같은 프레임에 갱신한다.
  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      final action = _undoStack.removeLast();
      _redoStack.add(action);
      if (action is _AddAction) {
        _strokes.remove(action.stroke);
      } else if (action is _RemoveAction) {
        _strokes.addAll(action.strokes);
        _strokes.sort((a, b) => a.order.compareTo(b.order));
      }
    });
    _paintVersion.value += 1;
    _scheduleSave();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      final action = _redoStack.removeLast();
      if (action is _AddAction) {
        _strokes.add(action.stroke);
      } else if (action is _RemoveAction) {
        _strokes.removeWhere(action.strokes.contains);
      }
      _strokes.sort((a, b) => a.order.compareTo(b.order));
      _undoStack.add(action);
    });
    _paintVersion.value += 1;
    _scheduleSave();
  }

  void _recordAction(_UndoAction action) {
    _undoStack.add(action);
    _redoStack.clear();
  }

  /// 필요한 변수는 현재 펜 색상·굵기·줄 표시·형광펜 상태다.
  /// 작동 원리는 모바일에서 자주 쓰지 않는 세부 설정을 참조 이미지와 같은
  /// 둥근 바텀시트에 모아 캔버스와 하단 핵심 도구의 공간을 확보하는 것이다.
  Future<void> _showMobileToolsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateSheet(VoidCallback update) {
              setState(update);
              setSheetState(() {});
            }

            return SafeArea(
              top: false,
              child: Container(
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
                      '필기 도구',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '색상과 굵기, 노트 배경을 한곳에서 설정하세요.',
                      style: TextStyle(
                        color: Color(0xFF68686E),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      '펜 색상',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final color in _penColors) ...[
                          _MobileColorChoice(
                            color: color,
                            selected: _penColor == color,
                            onTap: () => updateSheet(() {
                              _mobileInputMode = _MobileInputMode.pen;
                              _penColor = color;
                              _toolMode = _ToolMode.pen;
                            }),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      '펜 굵기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final width in _penWidths)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _MobileWidthChoice(
                                width: width,
                                selected: _penWidth == width,
                                onTap: () =>
                                    updateSheet(() => _penWidth = width),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _MobileToolSettingRow(
                      icon: Icons.brush_rounded,
                      title: '형광펜',
                      subtitle: '반투명한 펜으로 중요한 부분을 표시합니다.',
                      value: _isHighlighter,
                      onChanged: (value) => updateSheet(() {
                        _isHighlighter = value;
                        if (value) {
                          _mobileInputMode = _MobileInputMode.pen;
                          _toolMode = _ToolMode.pen;
                        }
                      }),
                    ),
                    const SizedBox(height: 10),
                    _MobileToolSettingRow(
                      icon: Icons.grid_on_rounded,
                      title: '노트 줄',
                      subtitle: '필기 간격을 맞추는 가이드 줄을 표시합니다.',
                      value: _showLines,
                      onChanged: (value) =>
                          updateSheet(() => _showLines = value),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _strokes.isEmpty
                            ? null
                            : () {
                                Navigator.of(sheetContext).pop();
                                Future<void>.delayed(
                                  const Duration(milliseconds: 220),
                                  () {
                                    if (mounted) {
                                      _clearAll();
                                    }
                                  },
                                );
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB42318),
                          side: const BorderSide(color: Color(0xFFF0C8C4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text(
                          '모든 필기 지우기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _clearAll() {
    if (_strokes.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('모두 지우기'),
        content: const Text('모든 필기 내용을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                if (_strokes.isNotEmpty) {
                  _recordAction(_RemoveAction(List<_Stroke>.from(_strokes)));
                  _strokes.clear();
                }
                _currentStroke = null;
              });
              _paintVersion.value += 1;
              _scheduleSave();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B402B),
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Offset _filterPoint(Offset next) {
    const smoothing = 0.55;
    final last = _lastFilteredPoint;
    if (last == null) {
      _lastFilteredPoint = next;
      return next;
    }
    final filtered = Offset(
      last.dx + (next.dx - last.dx) * smoothing,
      last.dy + (next.dy - last.dy) * smoothing,
    );
    _lastFilteredPoint = filtered;
    return filtered;
  }

  double _normalizePressure(double pressure) {
    if (pressure.isNaN || pressure.isInfinite) return 1.0;
    return pressure.clamp(0.0, 1.0);
  }

  Widget _buildCompose({
    required bool isDark,
    required bool mobile,
    required double height,
  }) {
    final isTyping = _mobileInputMode == _MobileInputMode.typing;
    final contentPadding = mobile ? 22.0 : 44.0;
    return SizedBox(
      key: const ValueKey('notepad-compose'),
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: !isTyping,
            child: TextField(
              key: const ValueKey('notepad-text-editor'),
              controller: _activeTextController,
              readOnly: !isTyping,
              expands: true,
              maxLines: null,
              minLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                color: const Color(0xFF202024),
                fontSize: mobile ? 16 : 17,
                fontWeight: FontWeight.w500,
                height: 1.75,
              ),
              onChanged: (_) {
                setState(() {});
                _scheduleSave();
              },
              decoration: InputDecoration(
                filled: false,
                hintText: isTyping
                    ? (_isReviewing ? '기억나는 내용을 입력하세요' : '내용을 입력하세요')
                    : null,
                hintStyle: const TextStyle(color: Color(0xFFB0B0B6)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(
                  contentPadding,
                  0,
                  contentPadding,
                  mobile ? 84 : 80,
                ),
              ),
            ),
          ),
          IgnorePointer(
            ignoring:
                isTyping ||
                (mobile && _mobileInputMode == _MobileInputMode.move),
            child: Listener(
              key: const ValueKey('notepad-canvas'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                final pos = event.localPosition;
                if (_toolMode == _ToolMode.pen) {
                  _startStroke(pos, event.pressure);
                } else {
                  _startEraser(pos);
                }
              },
              onPointerMove: (event) {
                final pos = event.localPosition;
                if (_toolMode == _ToolMode.pen) {
                  _updateStroke(pos, event.pressure);
                } else {
                  _updateEraser(pos);
                }
              },
              onPointerUp: (_) {
                if (_toolMode == _ToolMode.pen) {
                  _endStroke();
                } else {
                  _finishEraser();
                }
              },
              onPointerCancel: (_) {
                if (_toolMode == _ToolMode.pen) {
                  _endStroke();
                } else {
                  _finishEraser();
                }
              },
              child: CustomPaint(
                painter: _NotepadPainter(
                  strokes: _strokes,
                  current: _currentStroke,
                  toolMode: _toolMode,
                  eraserRadius: _eraserRadius,
                  eraserPosition: _eraserPosition,
                  showLines: _showLines,
                  isDark: isDark,
                  repaint: _paintVersion,
                ),
              ),
            ),
          ),
          if (_activeTextController.text.isEmpty &&
              _strokes.isEmpty &&
              !isTyping)
            Positioned(
              top: 4,
              left: contentPadding,
              child: IgnorePointer(
                child: Text(
                  _isReviewing ? '기억나는 내용을 써보세요' : '화면에 바로 써보세요',
                  style: const TextStyle(
                    color: Color(0xFFB0B0B6),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetadata(String dateLabel) => DefaultTextStyle(
    style: const TextStyle(
      color: Color(0xFF9A9AA1),
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(_isReviewing ? '백지 복습' : dateLabel),
        if (_isReviewing || _reviewCompleted) ...[
          Container(width: 1, height: 10, color: const Color(0xFFD8D8DC)),
          Text(_isReviewing ? '기준 노트 가림' : '백지 복습 완료'),
        ],
        Container(width: 1, height: 10, color: const Color(0xFFD8D8DC)),
        Text('${_activeTextController.text.length}자'),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = isStudentDensityMobile(context);
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final dateLabel =
        '${now.month}월 ${now.day}일 ${now.hour < 12 ? '오전' : '오후'} '
        '$hour:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _NotepadHeader(
                  saveLabel: _canPersist ? '저장됨' : '저장되지 않음',
                  showStatus: MediaQuery.sizeOf(context).width > 410,
                  onBack: () => Navigator.maybePop(context),
                  onNew: _createNewNote,
                  onMore: _showNotepadMoreSheet,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final sheetMinHeight = isMobile
                          ? constraints.maxHeight
                          : constraints.maxHeight - 62;
                      final headerHeight =
                          (isMobile ? 26.0 : 34.0) +
                          (isMobile ? 33.0 : 35.0) +
                          10 +
                          14;
                      final composeMinimum = isMobile ? 500.0 : 540.0;
                      final availableComposeHeight =
                          sheetMinHeight - headerHeight - (isMobile ? 16 : 18);
                      final composeHeight =
                          _canvasHeight > availableComposeHeight
                          ? _canvasHeight
                          : availableComposeHeight > composeMinimum
                          ? availableComposeHeight
                          : composeMinimum;
                      _composeSize = Size(
                        (constraints.maxWidth - (isMobile ? 0 : 40)).clamp(
                          0,
                          860,
                        ),
                        composeHeight,
                      );
                      return SingleChildScrollView(
                        controller: _scrollController,
                        physics: _mobileInputMode == _MobileInputMode.move
                            ? const BouncingScrollPhysics()
                            : const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Container(
                            color: isMobile
                                ? Colors.white
                                : const Color(0xFFF3F3F5),
                            padding: EdgeInsets.fromLTRB(
                              isMobile ? 0 : 20,
                              isMobile ? 0 : 20,
                              isMobile ? 0 : 20,
                              isMobile ? 16 : 42,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 860,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  constraints: BoxConstraints(
                                    minHeight: sheetMinHeight,
                                  ),
                                  color: _isReviewing
                                      ? const Color(0xFFFBFBFC)
                                      : Colors.white,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          isMobile ? 22 : 44,
                                          isMobile ? 26 : 34,
                                          isMobile ? 22 : 44,
                                          0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            TextField(
                                              key: const ValueKey(
                                                'notepad-title',
                                              ),
                                              controller: _isReviewing
                                                  ? _reviewTitleController
                                                  : _titleController,
                                              readOnly: _isReviewing,
                                              maxLength: 60,
                                              onChanged: (_) => _scheduleSave(),
                                              style: TextStyle(
                                                color: const Color(0xFF17171A),
                                                fontSize: _isReviewing
                                                    ? 22
                                                    : isMobile
                                                    ? 25
                                                    : 27,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -.8,
                                                height: 1.3,
                                              ),
                                              decoration: const InputDecoration(
                                                filled: false,
                                                hintText: '제목',
                                                counterText: '',
                                                hintStyle: TextStyle(
                                                  color: Color(0xFF8D8D94),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                disabledBorder:
                                                    InputBorder.none,
                                                errorBorder: InputBorder.none,
                                                focusedErrorBorder:
                                                    InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            _buildMetadata(dateLabel),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: isMobile ? 16 : 18),
                                      _buildCompose(
                                        isDark: isDark,
                                        mobile: isMobile,
                                        height: composeHeight,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _NotepadToolDock(
                  mobile: isMobile,
                  inputMode: _mobileInputMode,
                  toolMode: _toolMode,
                  isHighlighter: _isHighlighter,
                  canUndo: _undoStack.isNotEmpty,
                  canRedo: _redoStack.isNotEmpty,
                  onTyping: () => setState(
                    () => _mobileInputMode = _MobileInputMode.typing,
                  ),
                  onPen: () => setState(() {
                    _mobileInputMode = _MobileInputMode.pen;
                    _toolMode = _ToolMode.pen;
                    _isHighlighter = false;
                  }),
                  onHighlighter: () => setState(() {
                    _mobileInputMode = _MobileInputMode.pen;
                    _toolMode = _ToolMode.pen;
                    _isHighlighter = true;
                  }),
                  onEraser: () => setState(() {
                    _mobileInputMode = _MobileInputMode.pen;
                    _toolMode = _ToolMode.eraser;
                  }),
                  onUndo: _undo,
                  onRedo: _redo,
                ),
              ],
            ),
            if (_isReviewing)
              Positioned(
                left: isMobile ? 8 : 16,
                right: isMobile ? 8 : 16,
                bottom: isMobile ? 68 : 88,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: _NotepadReviewBar(
                      mobile: isMobile,
                      onCompare: _showReviewComparison,
                      onExit: _finishReview,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotepadToolDock extends StatelessWidget {
  const _NotepadToolDock({
    required this.mobile,
    required this.inputMode,
    required this.toolMode,
    required this.isHighlighter,
    required this.canUndo,
    required this.canRedo,
    required this.onTyping,
    required this.onPen,
    required this.onHighlighter,
    required this.onEraser,
    required this.onUndo,
    required this.onRedo,
  });

  final bool mobile;
  final _MobileInputMode inputMode;
  final _ToolMode toolMode;
  final bool isHighlighter;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onTyping;
  final VoidCallback onPen;
  final VoidCallback onHighlighter;
  final VoidCallback onEraser;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    final controls = <Widget>[
      _NotepadDockButton(
        label: '타이핑',
        icon: Icons.keyboard_outlined,
        selected: inputMode == _MobileInputMode.typing,
        onPressed: onTyping,
      ),
      const _NotepadDockDivider(),
      _NotepadDockButton(
        label: '펜',
        icon: Icons.edit_outlined,
        selected:
            inputMode == _MobileInputMode.pen &&
            toolMode == _ToolMode.pen &&
            !isHighlighter,
        onPressed: onPen,
      ),
      _NotepadDockButton(
        label: '형광펜',
        icon: Icons.border_color_outlined,
        selected: isHighlighter,
        onPressed: onHighlighter,
      ),
      _NotepadDockButton(
        label: '지우개',
        icon: Icons.auto_fix_high_outlined,
        selected:
            inputMode == _MobileInputMode.pen && toolMode == _ToolMode.eraser,
        onPressed: onEraser,
      ),
      const _NotepadDockDivider(),
      _NotepadDockButton(
        label: '되돌리기',
        icon: Icons.undo_rounded,
        selected: false,
        enabled: canUndo,
        onPressed: canUndo ? onUndo : null,
      ),
      _NotepadDockButton(
        label: '다시 실행',
        icon: Icons.redo_rounded,
        selected: false,
        enabled: canRedo,
        onPressed: canRedo ? onRedo : null,
      ),
    ];

    if (mobile) {
      return Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E2E5))),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F0F0F0F),
                  blurRadius: 18,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Row(
                  children: controls
                      .map(
                        (control) => control is _NotepadDockDivider
                            ? control
                            : Expanded(child: control),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFDEDEE2)),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0F0F12),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < controls.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                controls[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotepadDockDivider extends StatelessWidget {
  const _NotepadDockDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 24,
    margin: const EdgeInsets.symmetric(horizontal: 3),
    color: const Color(0xFFDEDEE2),
  );
}

class _NotepadDockButton extends StatelessWidget {
  const _NotepadDockButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      enabled: enabled && onPressed != null,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFECECEF) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: enabled
                    ? const Color(0xFF323238)
                    : const Color(0xFFB8B8BA),
              ),
              if (selected)
                Positioned(
                  bottom: 5,
                  left: 13,
                  right: 13,
                  child: Container(height: 2, color: const Color(0xFF111113)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 필요한 변수는 선택할 색상과 현재 선택 여부다.
/// 작동 원리는 큰 원형 색상 버튼과 체크 표시로 모바일에서도 현재 펜 색상을 즉시 구분하게 한다.
class _MobileColorChoice extends StatelessWidget {
  const _MobileColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? const Color(0xFF202022) : Colors.transparent,
            width: 3,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 25)
            : null,
      ),
    );
  }
}

/// 필요한 변수는 후보 굵기와 선택 여부다.
/// 작동 원리는 실제 굵기의 선 미리보기를 큰 선택 카드에 그려 숫자 없이도 결과를 예상하게 한다.
class _MobileWidthChoice extends StatelessWidget {
  const _MobileWidthChoice({
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF202022) : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 28,
          height: width.clamp(2, 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFF414145),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// 필요한 변수는 설정 아이콘·제목·설명·스위치 값이다.
/// 작동 원리는 60px 이상의 행 전체를 눌러도 값이 바뀌는 모바일 설정 카드로 세부 도구를 제공한다.
class _MobileToolSettingRow extends StatelessWidget {
  const _MobileToolSettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F6),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: const Color(0xFF202022)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF717176),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// HTML 기준 노트 상단바의 뒤로가기·저장 상태·새 노트·더보기 동작을 배치한다.
class _NotepadHeader extends StatelessWidget {
  const _NotepadHeader({
    required this.saveLabel,
    required this.showStatus,
    required this.onBack,
    required this.onNew,
    required this.onMore,
  });

  final String saveLabel;
  final bool showStatus;
  final VoidCallback onBack;
  final VoidCallback onNew;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFECECEF))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '뒤로',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 22),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: showStatus
                  ? Semantics(
                      liveRegion: true,
                      label: saveLabel,
                      child: Text(
                        saveLabel,
                        style: const TextStyle(
                          color: Color(0xFF72727A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          IconButton(
            tooltip: '새 노트',
            onPressed: onNew,
            icon: const Icon(Icons.add, size: 21),
          ),
          IconButton(
            tooltip: '노트 더보기',
            onPressed: onMore,
            icon: const Icon(Icons.more_horiz, size: 21),
          ),
        ],
      ),
    );
  }
}

class _NotepadSheetHandle extends StatelessWidget {
  const _NotepadSheetHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 38,
      height: 4,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: const Color(0xFFD5D5DA)),
    ),
  );
}

class _NotepadMenuAction extends StatelessWidget {
  const _NotepadMenuAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool last;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: '$title. $subtitle',
    child: InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF8F8F9),
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFEDEDF0))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Icon(
                icon,
                size: 20,
                color: enabled
                    ? const Color(0xFF17171A)
                    : const Color(0xFF929299),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? const Color(0xFF17171A)
                          : const Color(0xFF929299),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF83838B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NotepadReviewBar extends StatelessWidget {
  const _NotepadReviewBar({
    required this.mobile,
    required this.onCompare,
    required this.onExit,
  });
  final bool mobile;
  final VoidCallback onCompare;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: EdgeInsets.fromLTRB(mobile ? 14 : 18, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD9D9DD)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x240F0F12),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '원문을 가렸어요',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                if (!mobile)
                  const Text(
                    '기억나는 만큼 작성한 뒤 비교하세요.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF777780)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onCompare,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF17171A),
                shape: const RoundedRectangleBorder(),
                padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 16),
              ),
              child: const Text(
                '원문과 비교',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: '백지 복습 끝내기',
              onPressed: onExit,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF0F0F2),
                shape: const RoundedRectangleBorder(),
              ),
              icon: const Icon(Icons.close, size: 19),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.label,
    required this.title,
    required this.body,
    this.child,
  });

  final String label;
  final String title;
  final String body;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: BoxConstraints(
      minHeight: MediaQuery.sizeOf(context).width <= 720 ? 250 : 300,
    ),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFDEDEE2)),
      color: const Color(0xFFFAFAFA),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF777780),
          ),
        ),
        if (title.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              height: 1.55,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (body.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: Color(0xFF44444A),
            ),
          ),
        ],
        if (child != null) ...[
          const SizedBox(height: 14),
          Container(
            key: ValueKey('notepad-review-canvas-$label'),
            width: double.infinity,
            height: 180,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E2E5))),
            ),
            child: child!,
          ),
        ],
        if (title.isEmpty && body.isEmpty && child == null)
          const Text('타이핑한 내용 없음'),
      ],
    ),
  );
}

//=============================================================================
// 우측 사이드바 툴바 (56px 축소)
//=============================================================================

class _RightSidebar extends StatelessWidget {
  const _RightSidebar({
    required this.sidebarBg,
    required this.sidebarBorder,
    required this.isDark,
    required this.toolMode,
    required this.penColor,
    required this.penWidth,
    required this.showLines,
    required this.isHighlighter,
    required this.showColorPanel,
    required this.showWidthPanel,
    required this.showEraserPanel,
    required this.canUndo,
    required this.canRedo,
    required this.canClear,
    required this.onToolChanged,
    required this.onColorTap,
    required this.onWidthTap,
    required this.onEraserTap,
    required this.onHighlighterTap,
    required this.onColorChanged,
    required this.onWidthChanged,
    required this.onLinesChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onBack,
  });

  final Color sidebarBg;
  final Color sidebarBorder;
  final bool isDark;
  final _ToolMode toolMode;
  final Color penColor;
  final double penWidth;
  final bool showLines;
  final bool isHighlighter;
  final bool showColorPanel;
  final bool showWidthPanel;
  final bool showEraserPanel;
  final bool canUndo;
  final bool canRedo;
  final bool canClear;
  final ValueChanged<_ToolMode> onToolChanged;
  final VoidCallback onColorTap;
  final VoidCallback onWidthTap;
  final VoidCallback onEraserTap;
  final VoidCallback onHighlighterTap;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<bool> onLinesChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? Colors.white70 : const Color(0xFF8E8E93);
    final selectedBg = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFE8F5E9);
    final selectedIconColor = const Color(0xFF1B402B);

    return Container(
      width: 56,
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      decoration: BoxDecoration(
        color: sidebarBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sidebarBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // 나가기 버튼 (최상단)
          _SidebarButton(
            icon: Icons.close,
            tooltip: '나가기',
            selected: false,
            selectedColor: selectedIconColor,
            selectedBg: selectedBg,
            iconColor: const Color(0xFFE53935),
            onTap: onBack,
          ),
          const Divider(height: 16, indent: 8, endIndent: 8),
          // 펜 도구
          _SidebarButton(
            icon: Icons.edit,
            tooltip: '펜',
            selected:
                toolMode == _ToolMode.pen &&
                !showColorPanel &&
                !showWidthPanel &&
                !isHighlighter,
            selectedColor: selectedIconColor,
            selectedBg: selectedBg,
            iconColor: iconColor,
            onTap: () => onToolChanged(_ToolMode.pen),
          ),
          const SizedBox(height: 2),
          // 형광펜
          _SidebarButton(
            icon: Icons.brush,
            tooltip: '형광펜',
            selected: isHighlighter,
            selectedColor: selectedIconColor,
            selectedBg: selectedBg,
            iconColor: iconColor,
            accentColor: isHighlighter ? Colors.yellow : null,
            onTap: onHighlighterTap,
          ),
          const SizedBox(height: 2),
          // 색상 선택
          _SidebarButton(
            icon: Icons.palette_outlined,
            tooltip: '색상',
            selected: showColorPanel,
            selectedColor: selectedIconColor,
            selectedBg: selectedBg,
            iconColor: iconColor,
            accentColor: penColor,
            onTap: onColorTap,
          ),
          const SizedBox(height: 2),
          // 굵기 선택
          _SidebarButton(
            icon: Icons.line_weight,
            tooltip: '굵기',
            selected: showWidthPanel,
            selectedColor: selectedIconColor,
            selectedBg: selectedBg,
            iconColor: iconColor,
            accentSize: penWidth,
            onTap: onWidthTap,
          ),
          const Divider(height: 16, indent: 8, endIndent: 8),
          // 지우개
          _SidebarButton(
            icon: Icons.auto_fix_high,
            tooltip: '지우개',
            selected: toolMode == _ToolMode.eraser || showEraserPanel,
            selectedColor: selectedIconColor,
            selectedBg: selectedBg,
            iconColor: iconColor,
            onTap: () {
              if (toolMode == _ToolMode.eraser) {
                onEraserTap();
              } else {
                onToolChanged(_ToolMode.eraser);
              }
            },
          ),
          const SizedBox(height: 2),
          // 라인 토글
          _SidebarButton(
            icon: showLines ? Icons.grid_on : Icons.grid_off,
            tooltip: '라인',
            selected: showLines,
            selectedColor: selectedIconColor,
            selectedBg: selectedBg,
            iconColor: iconColor,
            onTap: () => onLinesChanged(!showLines),
          ),
          const SizedBox(height: 2),
          // 실행취소
          _SidebarButton(
            icon: Icons.undo,
            tooltip: '실행 취소',
            selected: false,
            selectedColor: selectedIconColor,
            selectedBg: selectedBg,
            iconColor: canUndo ? iconColor : Colors.grey,
            onTap: canUndo ? onUndo : null,
          ),
          const SizedBox(height: 2),
          _SidebarButton(
            icon: Icons.redo,
            tooltip: '다시 실행',
            selected: false,
            selectedColor: selectedIconColor,
            selectedBg: selectedBg,
            iconColor: canRedo ? iconColor : Colors.grey,
            onTap: canRedo ? onRedo : null,
          ),
          const SizedBox(height: 2),
          // 모두 지우기
          _SidebarButton(
            icon: Icons.delete_outline,
            tooltip: '모두 지우기',
            selected: false,
            selectedColor: selectedIconColor,
            selectedBg: selectedBg,
            iconColor: canClear ? const Color(0xFFE53935) : Colors.grey,
            onTap: canClear ? onClear : null,
          ),
          const Spacer(),
          // 패널 영역 (색상/굵기/지우개)
          if (showColorPanel)
            _ColorPanel(
              penColor: penColor,
              isDark: isDark,
              onColorChanged: onColorChanged,
            ),
          if (showWidthPanel)
            _WidthPanel(
              penWidth: penWidth,
              isDark: isDark,
              onWidthChanged: onWidthChanged,
            ),
          if (showEraserPanel) _EraserPanel(isDark: isDark),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

//=============================================================================
// 사이드바 버튼 (축소 40px)
//=============================================================================

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.selectedColor,
    required this.selectedBg,
    required this.iconColor,
    this.accentColor,
    this.accentSize,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final Color selectedColor;
  final Color selectedBg;
  final Color iconColor;
  final Color? accentColor;
  final double? accentSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: selected ? selectedColor : iconColor),
              // 색상 인디케이터
              if (accentColor != null)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? selectedBg : Colors.white,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              // 굵기 인디케이터
              if (accentSize != null)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    width: accentSize! * 1.0 + 2,
                    height: accentSize! * 1.0 + 2,
                    decoration: BoxDecoration(
                      color: selected ? selectedColor : iconColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? selectedBg : Colors.white,
                        width: 1.2,
                      ),
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

//=============================================================================
// 색상 패널 (3색: 검/파/빨)
//=============================================================================

class _ColorPanel extends StatelessWidget {
  const _ColorPanel({
    required this.penColor,
    required this.isDark,
    required this.onColorChanged,
  });

  final Color penColor;
  final bool isDark;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final color in _NotepadPageState._penColors) ...[
            GestureDetector(
              onTap: () => onColorChanged(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: penColor == color ? 28 : 22,
                height: penColor == color ? 28 : 22,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: penColor == color
                        ? (isDark ? Colors.white : const Color(0xFF1B402B))
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: penColor == color
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: penColor == color
                    ? Icon(
                        Icons.check,
                        size: 12,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

//=============================================================================
// 굵기 패널
//=============================================================================

class _WidthPanel extends StatelessWidget {
  const _WidthPanel({
    required this.penWidth,
    required this.isDark,
    required this.onWidthChanged,
  });

  final double penWidth;
  final bool isDark;
  final ValueChanged<double> onWidthChanged;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);
    final chipBg = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF5F5F7);
    final selectedColor = const Color(0xFF1B402B);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final width in _NotepadPageState._penWidths) ...[
            GestureDetector(
              onTap: () => onWidthChanged(width),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 34,
                height: 34,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: penWidth == width
                      ? (isDark
                            ? const Color(0xFF4A4A4C)
                            : const Color(0xFFE8F5E9))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: penWidth == width
                        ? selectedColor
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: width * 2.0,
                    height: width * 2.0,
                    decoration: BoxDecoration(
                      color: penWidth == width
                          ? selectedColor
                          : (isDark ? Colors.white54 : const Color(0xFF8E8E93)),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

//=============================================================================
// 지우개 패널
//=============================================================================

class _EraserPanel extends StatelessWidget {
  const _EraserPanel({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_fix_high,
            size: 18,
            color: isDark ? Colors.white70 : const Color(0xFF8E8E93),
          ),
          const SizedBox(height: 4),
          Text(
            '지우개',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white30 : Colors.black26,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white54 : Colors.black45,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_NotepadPageState._eraserRadius.toInt()}',
            style: TextStyle(
              fontSize: 8,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : const Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }
}

//=============================================================================
// 스트로크 & 라인
//=============================================================================

class _Stroke {
  _Stroke({
    required this.color,
    required this.baseWidth,
    required this.order,
    this.isHighlighter = false,
  });

  final Color color;
  final double baseWidth;
  final int order;
  final bool isHighlighter;
  final List<_StrokePoint> points = <_StrokePoint>[];
  Rect? bounds;

  void addPoint(Offset position, double pressure) {
    points.add(_StrokePoint(position, pressure));
    final radius = baseWidth / 2;
    final pointRect = Rect.fromCircle(center: position, radius: radius);
    bounds = bounds == null ? pointRect : bounds!.expandToInclude(pointRect);
  }

  bool hitTestCircle(Offset center, double radius) {
    final currentBounds = bounds;
    if (currentBounds == null) return false;
    if (!currentBounds.inflate(radius).contains(center)) return false;
    if (points.length == 1) {
      return (points.first.position - center).distance <= radius;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i].position;
      final b = points[i + 1].position;
      if (_distanceToSegment(center, a, b) <= radius) {
        return true;
      }
    }
    return false;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLen2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLen2 == 0) return (p - a).distance;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLen2;
    final clamped = t.clamp(0.0, 1.0);
    final closest = Offset(a.dx + ab.dx * clamped, a.dy + ab.dy * clamped);
    return (p - closest).distance;
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color.toARGB32(),
      'baseWidth': baseWidth,
      'order': order,
      'isHighlighter': isHighlighter,
      'points': points
          .map((e) => {'x': e.position.dx, 'y': e.position.dy, 'p': e.pressure})
          .toList(),
    };
  }

  factory _Stroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    final points = <_StrokePoint>[];
    if (rawPoints is List) {
      for (final item in rawPoints) {
        if (item is Map) {
          final dx = (item['x'] as num?)?.toDouble() ?? 0.0;
          final dy = (item['y'] as num?)?.toDouble() ?? 0.0;
          final p = (item['p'] as num?)?.toDouble() ?? 1.0;
          points.add(_StrokePoint(Offset(dx, dy), p));
        }
      }
    }
    final stroke = _Stroke(
      color: Color((json['color'] as num?)?.toInt() ?? Colors.black.toARGB32()),
      baseWidth: (json['baseWidth'] as num?)?.toDouble() ?? 3.0,
      order: (json['order'] as num?)?.toInt() ?? 0,
      isHighlighter: (json['isHighlighter'] as bool?) ?? false,
    );
    stroke.points.addAll(points);
    return stroke;
  }
}

class _NotepadPainter extends CustomPainter {
  _NotepadPainter({
    required this.strokes,
    required this.current,
    required this.toolMode,
    required this.eraserRadius,
    required this.eraserPosition,
    required this.showLines,
    required this.isDark,
    super.repaint,
  });

  final List<_Stroke> strokes;
  final _Stroke? current;
  final _ToolMode toolMode;
  final double eraserRadius;
  final Offset? eraserPosition;
  final bool showLines;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // 미세 줄무늬 배경
    if (showLines) {
      final linePaint = Paint()
        ..color = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE8E8ED)
        ..strokeWidth = 0.8;
      for (
        var y = _NotepadPageState._lineGap;
        y < size.height;
        y += _NotepadPageState._lineGap
      ) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
      // 세로 마진 라인
      final marginPaint = Paint()
        ..color = const Color(0xFFFF6B6B)
        ..strokeWidth = 0.6;
      canvas.drawLine(
        const Offset(60, 0),
        Offset(60, size.height),
        marginPaint,
      );
    }

    _StrokePainter.drawStrokes(canvas, strokes, currentStroke: current);

    // 지우개 시각화
    if (toolMode == _ToolMode.eraser && eraserPosition != null) {
      final fill = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06)
        ..style = PaintingStyle.fill;
      final border = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(eraserPosition!, eraserRadius, fill);
      canvas.drawCircle(eraserPosition!, eraserRadius, border);
      final centerDot = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(eraserPosition!, 3, centerDot);
    }
  }

  @override
  bool shouldRepaint(covariant _NotepadPainter oldDelegate) {
    return oldDelegate.strokes.length != strokes.length ||
        oldDelegate.current != current ||
        oldDelegate.showLines != showLines ||
        oldDelegate.toolMode != toolMode ||
        oldDelegate.eraserPosition != eraserPosition ||
        oldDelegate.isDark != isDark;
  }
}

class _StrokePoint {
  const _StrokePoint(this.position, this.pressure);

  final Offset position;
  final double pressure;
}

class _StrokePainter extends CustomPainter {
  static const double _pressureMinFactor = 0.35;

  _StrokePainter({required this.strokes, required this.currentStroke});

  final List<_Stroke> strokes;
  final _Stroke? currentStroke;

  static void drawStrokes(
    Canvas canvas,
    List<_Stroke> strokes, {
    _Stroke? currentStroke,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    double pressureWidth(double baseWidth, double pressure) {
      final factor =
          _pressureMinFactor +
          (1 - _pressureMinFactor) * pressure.clamp(0.0, 1.0);
      return baseWidth * factor;
    }

    void drawOne(_Stroke stroke) {
      if (stroke.points.isEmpty) return;
      paint.color = stroke.color;
      if (stroke.isHighlighter) {
        // 형광펜: 투명도 40%, 더 두껍게
        paint.color = stroke.color.withValues(alpha: 0.4);
        paint.strokeWidth = stroke.baseWidth * 2.5;
        paint.strokeCap = StrokeCap.square;
      } else {
        paint.strokeCap = StrokeCap.round;
      }
      if (stroke.points.length == 1) {
        final point = stroke.points.first;
        final width = stroke.isHighlighter
            ? stroke.baseWidth * 2.5
            : pressureWidth(stroke.baseWidth, point.pressure);
        canvas.drawCircle(
          point.position,
          width / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        return;
      }
      for (var i = 0; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];
        if (stroke.isHighlighter) {
          paint.strokeWidth = stroke.baseWidth * 2.5;
        } else {
          paint.strokeWidth = pressureWidth(
            stroke.baseWidth,
            (p1.pressure + p2.pressure) * 0.5,
          );
        }
        canvas.drawLine(p1.position, p2.position, paint);
      }
    }

    final ordered = List<_Stroke>.from(strokes)
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final stroke in ordered) {
      drawOne(stroke);
    }
    if (currentStroke != null) {
      drawOne(currentStroke);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    drawStrokes(canvas, strokes, currentStroke: currentStroke);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) {
    return oldDelegate.strokes.length != strokes.length ||
        oldDelegate.currentStroke != currentStroke;
  }
}

enum _ToolMode { pen, eraser }

enum _MobileInputMode { typing, move, pen }

abstract class _UndoAction {
  const _UndoAction();
}

class _AddAction extends _UndoAction {
  const _AddAction(this.stroke);

  final _Stroke stroke;
}

class _RemoveAction extends _UndoAction {
  const _RemoveAction(this.strokes);

  final List<_Stroke> strokes;
}
