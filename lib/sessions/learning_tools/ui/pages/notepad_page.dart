import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:s11/shared/services/storage/local_db.dart';

//=============================================================================
// 노트패드 (삼성노트 스타일) - 우측 사이드바 툴바
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
  static const _baseHeight = 1400.0;
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
  final TextEditingController _textController = TextEditingController();
  final ValueNotifier<int> _paintVersion = ValueNotifier<int>(0);
  final List<_Stroke> _strokes = <_Stroke>[];
  final List<_UndoAction> _undoStack = <_UndoAction>[];
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

  bool _showLines = true;
  Color _penColor = Colors.black;
  double _penWidth = 3;
  bool _isHighlighter = false; // 형광펜 모드

  // 팝업 패널 상태
  bool _showColorPanel = false;
  bool _showWidthPanel = false;
  bool _showEraserPanel = false;

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
    _textController.dispose();
    _paintVersion.dispose();
    _saveTimer?.cancel();
    super.dispose();
  }

  void _closeAllPanels() {
    setState(() {
      _showColorPanel = false;
      _showWidthPanel = false;
      _showEraserPanel = false;
    });
  }

  void _toggleColorPanel() {
    setState(() {
      _showColorPanel = !_showColorPanel;
      _showWidthPanel = false;
      _showEraserPanel = false;
    });
  }

  void _toggleWidthPanel() {
    setState(() {
      _showWidthPanel = !_showWidthPanel;
      _showColorPanel = false;
      _showEraserPanel = false;
    });
  }

  void _toggleEraserPanel() {
    setState(() {
      _showEraserPanel = !_showEraserPanel;
      _showColorPanel = false;
      _showWidthPanel = false;
    });
  }

  void _toggleHighlighter() {
    setState(() {
      _isHighlighter = !_isHighlighter;
      if (_isHighlighter && _toolMode == _ToolMode.eraser) {
        _toolMode = _ToolMode.pen;
      }
    });
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
        _strokes
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
    final payload = jsonEncode(_strokes.map((e) => e.toJson()).toList());
    await LocalDb.instance.setString(_storageKey, payload);
    await LocalDb.instance.setString(_textStorageKey, _textController.text);
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
      _undoStack.add(_AddAction(stroke));
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
      _undoStack.add(_RemoveAction(List<_Stroke>.from(_pendingEraseRemoved)));
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
                  _undoStack.add(_RemoveAction(List<_Stroke>.from(_strokes)));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.sizeOf(context).width < 720;
    // 학습 도구 세션 레퍼런스에 맞춰 캔버스와 툴바를 중립 흑백으로 고정한다.
    const bgColor = Color(0xFFF7F7F7);
    const paperColor = Colors.white;
    const sidebarBg = Colors.white;
    const sidebarBorder = Color(0xFFE4E4E7);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _NotepadHeader(
              mobile: isMobile,
              onClose: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: Stack(
                children: [
                  // 메인 캔버스 영역 (전체 화면, 사이드바 공간 제외)
                  Row(
                    children: [
                      Expanded(
                        child: Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics:
                                isMobile &&
                                    _mobileInputMode != _MobileInputMode.move
                                ? const NeverScrollableScrollPhysics()
                                : const BouncingScrollPhysics(),
                            child: Container(
                              margin: EdgeInsets.all(isMobile ? 10 : 16),
                              decoration: BoxDecoration(
                                color: paperColor,
                                borderRadius: BorderRadius.circular(
                                  isMobile ? 20 : 12,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0.3)
                                        : Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  isMobile ? 20 : 12,
                                ),
                                child:
                                    isMobile &&
                                        _mobileInputMode ==
                                            _MobileInputMode.typing
                                    ? SizedBox(
                                        key: const ValueKey(
                                          'notepad-text-editor',
                                        ),
                                        height: _canvasHeight,
                                        child: TextField(
                                          controller: _textController,
                                          autofocus: true,
                                          expands: true,
                                          maxLines: null,
                                          minLines: null,
                                          keyboardType: TextInputType.multiline,
                                          textAlignVertical:
                                              TextAlignVertical.top,
                                          onChanged: (_) => _scheduleSave(),
                                          decoration: const InputDecoration(
                                            hintText: '내용을 입력하세요',
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.all(24),
                                          ),
                                        ),
                                      )
                                    : IgnorePointer(
                                        ignoring:
                                            isMobile &&
                                            _mobileInputMode ==
                                                _MobileInputMode.move,
                                        child: Listener(
                                          key: const ValueKey('notepad-canvas'),
                                          behavior: HitTestBehavior.opaque,
                                          onPointerDown: (event) {
                                            _closeAllPanels();
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
                                              _updateStroke(
                                                pos,
                                                event.pressure,
                                              );
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
                                          child: SizedBox(
                                            height: _canvasHeight,
                                            width: double.infinity,
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
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!isMobile)
                        // PC 레이아웃은 기존 우측 사이드바를 그대로 유지한다.
                        _RightSidebar(
                          sidebarBg: sidebarBg,
                          sidebarBorder: sidebarBorder,
                          isDark: isDark,
                          toolMode: _toolMode,
                          penColor: _penColor,
                          penWidth: _penWidth,
                          showLines: _showLines,
                          isHighlighter: _isHighlighter,
                          showColorPanel: _showColorPanel,
                          showWidthPanel: _showWidthPanel,
                          showEraserPanel: _showEraserPanel,
                          canUndo: _undoStack.isNotEmpty,
                          canClear: _strokes.isNotEmpty,
                          onToolChanged: (mode) {
                            setState(() => _toolMode = mode);
                            _closeAllPanels();
                          },
                          onColorTap: _toggleColorPanel,
                          onWidthTap: _toggleWidthPanel,
                          onEraserTap: _toggleEraserPanel,
                          onHighlighterTap: _toggleHighlighter,
                          onColorChanged: (color) =>
                              setState(() => _penColor = color),
                          onWidthChanged: (width) =>
                              setState(() => _penWidth = width),
                          onLinesChanged: (value) =>
                              setState(() => _showLines = value),
                          onUndo: _undo,
                          onClear: _clearAll,
                          onBack: () => Navigator.maybePop(context),
                        ),
                    ],
                  ),
                  // 웹에서는 저장 불가 알림
                  if (!_canPersist)
                    Positioned(
                      bottom: isMobile ? 10 : 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '웹에서는 저장되지 않습니다',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isMobile)
              _MobileNotepadToolbar(
                inputMode: _mobileInputMode,
                toolMode: _toolMode,
                penColor: _penColor,
                isHighlighter: _isHighlighter,
                canUndo: _undoStack.isNotEmpty,
                onTyping: () =>
                    setState(() => _mobileInputMode = _MobileInputMode.typing),
                onMove: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _mobileInputMode = _MobileInputMode.move);
                },
                onPen: () => setState(() {
                  _mobileInputMode = _MobileInputMode.pen;
                  _toolMode = _ToolMode.pen;
                  _isHighlighter = false;
                }),
                onEraser: () => setState(() {
                  _mobileInputMode = _MobileInputMode.pen;
                  _toolMode = _ToolMode.eraser;
                }),
                onUndo: _undo,
                onTools: _showMobileToolsSheet,
              ),
          ],
        ),
      ),
    );
  }
}

/// 필요한 변수는 현재 도구·펜 색상·실행 취소 가능 여부와 각 동작 콜백이다.
/// 작동 원리는 모바일 하단에서 입력·이동·필기 상태와 편집 도구를 명시적으로 분리한다.
class _MobileNotepadToolbar extends StatelessWidget {
  const _MobileNotepadToolbar({
    required this.inputMode,
    required this.toolMode,
    required this.penColor,
    required this.isHighlighter,
    required this.canUndo,
    required this.onTyping,
    required this.onMove,
    required this.onPen,
    required this.onEraser,
    required this.onUndo,
    required this.onTools,
  });

  final _MobileInputMode inputMode;
  final _ToolMode toolMode;
  final Color penColor;
  final bool isHighlighter;
  final bool canUndo;
  final VoidCallback onTyping;
  final VoidCallback onMove;
  final VoidCallback onPen;
  final VoidCallback onEraser;
  final VoidCallback onUndo;
  final VoidCallback onTools;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 16,
      shadowColor: const Color(0x26000000),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: _MobileNotepadAction(
                  tooltip: '타이핑 모드',
                  label: '타이핑',
                  icon: Icons.keyboard_rounded,
                  selected: inputMode == _MobileInputMode.typing,
                  onTap: onTyping,
                ),
              ),
              Expanded(
                child: _MobileNotepadAction(
                  tooltip: '페이지 이동 모드',
                  label: '이동',
                  icon: Icons.pan_tool_alt_outlined,
                  selected: inputMode == _MobileInputMode.move,
                  onTap: onMove,
                ),
              ),
              Expanded(
                child: _MobileNotepadAction(
                  tooltip: '펜',
                  label: '펜',
                  icon: Icons.edit_rounded,
                  selected:
                      inputMode == _MobileInputMode.pen &&
                      toolMode == _ToolMode.pen &&
                      !isHighlighter,
                  indicatorColor: penColor,
                  onTap: onPen,
                ),
              ),
              Expanded(
                child: _MobileNotepadAction(
                  tooltip: '지우개',
                  label: '지우개',
                  icon: Icons.auto_fix_high_rounded,
                  selected:
                      inputMode == _MobileInputMode.pen &&
                      toolMode == _ToolMode.eraser,
                  onTap: onEraser,
                ),
              ),
              Expanded(
                child: _MobileNotepadAction(
                  tooltip: '실행 취소',
                  label: '되돌리기',
                  icon: Icons.undo_rounded,
                  enabled: canUndo,
                  onTap: canUndo ? onUndo : null,
                ),
              ),
              Expanded(
                child: _MobileNotepadAction(
                  tooltip: '필기 도구',
                  label: '도구',
                  icon: Icons.tune_rounded,
                  onTap: onTools,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 필요한 변수는 도구 아이콘·레이블·선택 및 활성 상태다.
/// 작동 원리는 48px 이상 터치 영역과 텍스트 레이블을 함께 제공해 아이콘 의미를 분명히 한다.
class _MobileNotepadAction extends StatelessWidget {
  const _MobileNotepadAction({
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
    this.indicatorColor,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final Color? indicatorColor;

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = enabled && onTap != null;
    final foreground = !effectiveEnabled
        ? const Color(0xFFB8B8BA)
        : selected
        ? Colors.white
        : const Color(0xFF3F3F43);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: effectiveEnabled,
        selected: selected,
        label: tooltip,
        child: InkWell(
          onTap: effectiveEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 54),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF202022) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: foreground, size: 22),
                    if (indicatorColor != null)
                      Positioned(
                        right: -4,
                        bottom: -3,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

/// 노트패드 캔버스 위에 도구 이름과 세션 종료 동작을 고정한다.
/// 필요한 변수: 모바일 여부와 종료 콜백. 작동 원리: PC는 세션 헤더를 유지하고
/// 모바일은 제목과 닫기만 남긴 60px 헤더로 캔버스 공간을 확보한다.
class _NotepadHeader extends StatelessWidget {
  const _NotepadHeader({required this.mobile, required this.onClose});

  final bool mobile;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mobile ? 60 : 82,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E4E7))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!mobile)
                  const Text(
                    'LEARNING TOOL · SESSION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Color(0xFF71717A),
                    ),
                  ),
                if (!mobile) const SizedBox(height: 3),
                Text(
                  mobile ? '필기 노트' : '노트패드',
                  style: TextStyle(
                    fontSize: mobile ? 21 : 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              shape: const CircleBorder(
                side: BorderSide(color: Color(0xFFE4E4E7)),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
