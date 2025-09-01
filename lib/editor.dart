import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fleather/fleather.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pages/prompt.dart';
import 'models/text_diff.dart';
import 'widgets/rewrite_view.dart';

enum AutocompleteMode { word, sentence }

enum EditorMode { edit, rewrite }

class MainEditor extends StatelessWidget {
  const MainEditor({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    localizationsDelegates: const [
      FleatherLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: FleatherLocalizations.supportedLocales,
    debugShowCheckedModeBanner: false,
    theme: ThemeData.light().copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.black,
        splashColor: Colors.grey.shade300,
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.resolveWith(
            (states) => Colors.black,
          ),
          overlayColor: MaterialStateProperty.resolveWith(
            (states) => states.contains(MaterialState.pressed)
                ? Colors.grey.shade300
                : null,
          ),
        ),
      ),
    ),
    darkTheme: ThemeData.dark(),
    title: 'Fleather - AI Autocomplete Editor',
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<EditorState> _editorKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();

  FleatherController? _controller;
  OverlayEntry? _overlayEntry;
  bool _showAutocomplete = false;
  AutocompleteMode _autocompleteMode = AutocompleteMode.word;
  EditorMode _editorMode = EditorMode.edit;
  List<TextDiff>? _currentDiffs;
  bool _isRewriting = false;
  String _selectedModel = 'gemini'; // 현재 선택된 AI 모델

  DateTime? _lastRequestTime;
  static const Duration requestCooldown = Duration(seconds: 3);

  Timer? _debounceTimer;
  static const Duration debounceDelay = Duration(milliseconds: 1500);

  static const String apiBaseUrl = 'http://localhost:8000';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
    _initController();
    _setupTextChangeListener();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
  }

  void _setupTextChangeListener() {
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideAutocomplete();
      }
    });
  }

  Future<void> _initController() async {
    final heuristics = ParchmentHeuristics(
      formatRules: [],
      insertRules: [ForceNewlineForInsertsAroundInlineImageRule()],
      deleteRules: [],
    ).merge(ParchmentHeuristics.fallback);

    try {
      final result = await rootBundle.loadString('assets/welcome.json');
      final doc = ParchmentDocument.fromJson(
        jsonDecode(result),
        heuristics: heuristics,
      );
      _ensureEndsWithNewline(doc);
      _controller = FleatherController(document: doc);
    } catch (_) {
      final doc = ParchmentDocument.fromDelta(
        Delta()..insert('\n'),
        heuristics: heuristics,
      );
      _ensureEndsWithNewline(doc);
      _controller = FleatherController(document: doc);
    }

    _controller?.addListener(_onTextChanged);
    setState(() {});
  }

  void _ensureEndsWithNewline(ParchmentDocument doc) {
    final plainText = doc.toPlainText();
    if (!plainText.endsWith("\n")) {
      doc.insert(doc.length, "\n");
    }
  }

  void _onTextChanged() {
    if (_controller == null) return;

    final selection = _controller!.selection;
    if (!selection.isCollapsed) {
      _debounceTimer?.cancel();
      _hideAutocomplete();
      return;
    }

    if (kDebugMode) {
      print('Text changed, checking for autocomplete...');
    }

    final plainText = _controller!.document.toPlainText();
    final cursorPosition = selection.baseOffset;

    if (kDebugMode) {
      print(
        '현재 모드: ${_autocompleteMode == AutocompleteMode.word ? "단어" : "문장"}',
      );
      print('커서 위치: $cursorPosition');
      print('전체 텍스트 길이: ${plainText.length}');
    }

    // 기존 타이머 취소
    _debounceTimer?.cancel();

    if (_autocompleteMode == AutocompleteMode.word) {
      final currentWord = _getCurrentWord(plainText, cursorPosition);
      if (kDebugMode) {
        print('Current word: $currentWord');
      }
      if (currentWord.isNotEmpty && currentWord.length >= 2) {
        if (kDebugMode) {
          print('Scheduling word autocomplete request...');
        }
        _debounceTimer = Timer(debounceDelay, () {
          _tryRequestWordAutocomplete(currentWord);
        });
      } else {
        _hideAutocomplete();
      }
    } else {
      // 문장 모드: 문장이 끝나거나 충분한 텍스트가 있을 때
      final context = _getContextForSentence(plainText, cursorPosition);
      if (context.isNotEmpty && context.length >= 10) {
        if (kDebugMode) {
          print('Scheduling sentence autocomplete request...');
        }
        _debounceTimer = Timer(debounceDelay, () {
          _tryRequestSentenceAutocomplete(context);
        });
      } else {
        _hideAutocomplete();
      }
    }
  }

  void _tryRequestWordAutocomplete(String word) {
    final now = DateTime.now();
    if (_lastRequestTime != null &&
        now.difference(_lastRequestTime!) < requestCooldown) {
      return;
    }
    _lastRequestTime = now;
    _showWordAutocomplete(word);
  }

  void _tryRequestSentenceAutocomplete(String context) {
    final now = DateTime.now();
    if (_lastRequestTime != null &&
        now.difference(_lastRequestTime!) < requestCooldown) {
      return;
    }
    _lastRequestTime = now;
    _showSentenceAutocomplete(context);
  }

  String _getCurrentWord(String text, int cursorPosition) {
    if (cursorPosition <= 0 || cursorPosition > text.length) return '';
    int start = cursorPosition - 1;
    while (start >= 0 && !_isWordSeparator(text[start])) {
      start--;
    }
    start++;
    int end = cursorPosition;
    while (end < text.length && !_isWordSeparator(text[end])) {
      end++;
    }
    return text.substring(start, end);
  }

  String _getContextForSentence(String text, int cursorPosition) {
    if (cursorPosition <= 0) return '';

    // 현재 위치에서 최대 100자 이전까지 가져오기
    int start = (cursorPosition - 100).clamp(0, text.length);
    String context = text.substring(start, cursorPosition);

    // 마지막 완전한 단어까지만 포함
    context = context.trim();

    if (kDebugMode) {
      print('문장 컨텍스트 계산:');
      print('- 시작 위치: $start');
      print('- 커서 위치: $cursorPosition');
      print('- 추출된 컨텍스트: $context');
    }

    return context;
  }

  bool _isWordSeparator(String char) {
    return char == ' ' ||
        char == '\n' ||
        char == '\t' ||
        char == ',' ||
        char == '.';
  }

  Future<List<String>> _fetchWordAutocomplete(String query) async {
    try {
      // 전체 문서 내용 포함
      final plainText = _controller?.document.toPlainText() ?? '';

      final queryParams = {
        'context': query,
        'full_text': plainText,
        'max_suggestions': '3',
      };

      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/sentence-complete',
        ).replace(queryParameters: queryParams),
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        return results.map((e) => e.toString()).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Word autocomplete API error: $e');
      }
    }
    return [];
  }

  Future<List<String>> _fetchSentenceAutocomplete(String context) async {
    if (kDebugMode) {
      print('문장 자동완성 API 요청:');
      print('- 컨텍스트: $context');
    }

    try {
      // GET 요청으로 변경하고 전체 문서 내용도 포함
      final plainText = _controller?.document.toPlainText() ?? '';

      final queryParams = {
        'context': context,
        'full_text': plainText,
        'max_suggestions': '3',
      };

      if (kDebugMode) {
        print('API 요청 파라미터:');
        print('- context: $context');
        print('- full_text 길이: ${plainText.length}');
      }

      final uri = Uri.parse(
        '$apiBaseUrl/sentence-complete',
      ).replace(queryParameters: queryParams);

      if (kDebugMode) {
        print('API 요청 URL: $uri');
      }

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (kDebugMode) {
        print('API 응답 상태 코드: ${response.statusCode}');
        print('API 응답 바디: ${response.body}');
      }

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        final suggestions = results.map((e) => e.toString()).toList();

        if (kDebugMode) {
          print('받은 제안들:');
          for (var i = 0; i < suggestions.length; i++) {
            print('${i + 1}. ${suggestions[i]}');
          }
        }

        return suggestions;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sentence autocomplete API error: $e');
      }
    }
    return [];
  }

  void _showWordAutocomplete(String word) async {
    if (kDebugMode) {
      print('Requesting autocomplete for word: $word');
    }
    final suggestions = await _fetchWordAutocomplete(word);
    if (kDebugMode) {
      print('Got suggestions: $suggestions');
    }
    if (suggestions.isNotEmpty && mounted) {
      if (kDebugMode) {
        print('Showing autocomplete overlay');
      }
      _showAutocompleteOverlay(suggestions, word, isWordMode: true);
    } else {
      if (kDebugMode) {
        print('No suggestions, hiding autocomplete');
      }
      _hideAutocomplete();
    }
  }

  void _showSentenceAutocomplete(String context) async {
    final suggestions = await _fetchSentenceAutocomplete(context);
    if (suggestions.isNotEmpty && mounted) {
      _showAutocompleteOverlay(suggestions, context, isWordMode: false);
    } else {
      _hideAutocomplete();
    }
  }

  void _showAutocompleteOverlay(
    List<String> suggestions,
    String currentInput, {
    required bool isWordMode,
  }) {
    if (kDebugMode) {
      print('Showing autocomplete overlay:');
      print('- Suggestions: $suggestions');
      print('- Current input: $currentInput');
      print('- Word mode: $isWordMode');
    }
    _hideAutocomplete();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: isWordMode ? 200 : 400,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 30),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: BoxConstraints(maxHeight: isWordMode ? 200 : 300),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 헤더
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isWordMode ? Icons.text_fields : Icons.auto_fix_high,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isWordMode ? '단어 제안' : '문장 완성',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 제안 목록
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            suggestion,
                            style: TextStyle(fontSize: isWordMode ? 14 : 13),
                            maxLines: isWordMode ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSuggestion(
                            suggestion,
                            currentInput,
                            isWordMode,
                          ),
                          hoverColor: Colors.grey.shade100,
                          tileColor: Colors.white,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    _showAutocomplete = true;
  }

  void _selectSuggestion(
    String suggestion,
    String currentInput,
    bool isWordMode,
  ) {
    if (_controller == null) return;

    final selection = _controller!.selection;
    if (!selection.isValid) return;

    final cursorPosition = selection.baseOffset;
    final plainText = _controller!.document.toPlainText();

    if (cursorPosition < 0 || cursorPosition > plainText.length) return;

    if (isWordMode) {
      // 단어 모드: 현재 단어를 대체
      int start = cursorPosition;
      // 현재 커서 위치에서 뒤로 이동하며 단어의 시작 찾기
      while (start > 0 && !_isWordSeparator(plainText[start - 1])) {
        start--;
      }
      // 현재 커서 위치에서 앞으로 이동하며 단어의 끝 찾기
      int end = cursorPosition;
      while (end < plainText.length && !_isWordSeparator(plainText[end])) {
        end++;
      }

      if (start < end && end <= plainText.length) {
        _controller!.replaceText(
          start,
          end - start,
          suggestion,
          selection: TextSelection.collapsed(offset: start + suggestion.length),
        );
      }
    } else {
      // 문장 모드: 현재 위치에서 문장 추가
      try {
        if (kDebugMode) {
          print('문장 추가 시도:');
          print('- 커서 위치: $cursorPosition');
          print('- 전체 길이: ${plainText.length}');
          print('- 제안: $suggestion');
        }

        // 현재 커서 위치가 문서 끝이면, 맨 끝에 추가
        if (cursorPosition >= plainText.length) {
          _controller!.replaceText(
            plainText.length,
            0,
            '\n$suggestion', // 새 줄에 추가
            selection: TextSelection.collapsed(
              offset: plainText.length + suggestion.length + 1,
            ),
          );
        } else {
          // 현재 위치에 추가
          _controller!.replaceText(
            cursorPosition,
            0,
            ' $suggestion', // 공백 추가
            selection: TextSelection.collapsed(
              offset: cursorPosition + suggestion.length + 1,
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('문장 추가 오류: $e');
        }
      }
    }
    _hideAutocomplete();
  }

  void _hideAutocomplete() {
    if (_showAutocomplete) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _showAutocomplete = false;
    }
  }

  Future<void> _requestRewrite() async {
    if (_controller == null || _isRewriting) return;

    final text = _controller!.document.toPlainText();
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('텍스트를 입력해주세요')));
      return;
    }

    if (kDebugMode) {
      print('다시쓰기 요청:');
      print('텍스트 길이: ${text.length}');
    }

    setState(() => _isRewriting = true);

    try {
      // 프롬프트 설정에서 현재 선택된 모델 가져오기
      try {
        final promptResponse = await http.get(Uri.parse('$apiBaseUrl/prompt'));
        if (promptResponse.statusCode == 200) {
          final promptData = jsonDecode(promptResponse.body);
          _selectedModel = promptData['model'] ?? 'gemini';
        }
      } catch (e) {
        if (kDebugMode) {
          print('모델 정보 로드 실패: $e');
        }
      }

      final response = await http.post(
        Uri.parse(
          '$apiBaseUrl/prompt',
        ).replace(queryParameters: {'prompt': text, 'model': _selectedModel}),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 서버에서 오류 메시지가 있는지 확인
        if (data['error'] != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(data['error'])));
          return;
        }

        final diffs = (data['diffs'] as List)
            .map(
              (diff) => TextDiff(
                text: diff['text'],
                type: _parseDiffType(diff['type']),
                reason: diff['reason'],
              ),
            )
            .toList();

        if (diffs.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('수정할 내용을 찾지 못했습니다')));
          return;
        }

        setState(() {
          _currentDiffs = diffs;
          _editorMode = EditorMode.rewrite;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('서버 오류가 발생했습니다')));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Rewrite error: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('다시쓰기 요청 중 오류가 발생했습니다')));
      }
    } finally {
      if (mounted) {
        setState(() => _isRewriting = false);
      }
    }
  }

  DiffType _parseDiffType(String type) {
    switch (type) {
      case 'deletion':
        return DiffType.deletion;
      case 'addition':
        return DiffType.addition;
      default:
        return DiffType.unchanged;
    }
  }

  void _acceptAllDiffs() {
    if (_currentDiffs == null || _controller == null) return;

    final newText = _currentDiffs!
        .where((d) => d.type != DiffType.deletion)
        .map((d) => d.text)
        .join();

    _controller!.replaceText(
      0,
      _controller!.document.length,
      newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );

    setState(() {
      _editorMode = EditorMode.edit;
      _currentDiffs = null;
    });
  }

  void _rejectAllDiffs() {
    setState(() {
      _editorMode = EditorMode.edit;
      _currentDiffs = null;
    });
  }

  void _acceptDiff(TextDiff diff) {
    // 개별 수정사항 수락 로직은 나중에 구현
  }

  void _rejectDiff(TextDiff diff) {
    // 개별 수정사항 거절 로직은 나중에 구현
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // 왼쪽 그룹은 가로로 스크롤 가능하도록 처리해 폭이 좁아져도 오른쪽 버튼이 사라지지 않도록 함
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Text(
                    'AI 자동완성:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildModeButton(
                    mode: AutocompleteMode.word,
                    icon: Icons.text_fields,
                    label: '단어모드',
                    isSelected: _autocompleteMode == AutocompleteMode.word,
                  ),
                  const SizedBox(width: 8),
                  _buildModeButton(
                    mode: AutocompleteMode.sentence,
                    icon: Icons.auto_fix_high,
                    label: '문장모드',
                    isSelected: _autocompleteMode == AutocompleteMode.sentence,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          // ✅ 프롬프트 수정 버튼 (오른쪽 고정)
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PromptEditorPage()),
              );
            },
            icon: const Icon(Icons.edit, size: 16),
            label: const Text("프롬프트 수정"),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required AutocompleteMode mode,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _autocompleteMode = mode;
          });
          _hideAutocomplete();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade600 : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final picker = ImagePicker();
          final image = await picker.pickImage(source: ImageSource.gallery);
          if (image != null) {
            final selection = _controller!.selection;
            _controller!.replaceText(
              selection.baseOffset,
              selection.extentOffset - selection.baseOffset,
              EmbeddableObject(
                'image',
                inline: false,
                data: {
                  'source_type': kIsWeb ? 'url' : 'file',
                  'source': image.path,
                },
              ),
            );
            _controller!.replaceText(
              selection.baseOffset + 1,
              0,
              '\n',
              selection: TextSelection.collapsed(
                offset: selection.baseOffset + 2,
              ),
            );
          }
        },
        child: const Icon(Icons.add_a_photo),
      ),
      body: _controller == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 툴바 및 모드 선택기
                FleatherToolbar.basic(
                  controller: _controller!,
                  editorKey: _editorKey,
                ),
                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                _buildModeSelector(),
                // 다시쓰기 버튼
                if (_editorMode == EditorMode.edit)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _isRewriting ? null : _requestRewrite,
                          icon: _isRewriting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_fix_high),
                          label: Text(_isRewriting ? '처리 중...' : '다시쓰기'),
                        ),
                      ],
                    ),
                  ),
                // 에디터 또는 다시쓰기 뷰
                Expanded(
                  child:
                      _editorMode == EditorMode.rewrite && _currentDiffs != null
                      ? RewriteView(
                          originalText: _controller!.document.toPlainText(),
                          diffs: _currentDiffs!,
                          onAcceptAll: _acceptAllDiffs,
                          onRejectAll: _rejectAllDiffs,
                          onDiffAccepted: _acceptDiff,
                          onDiffRejected: _rejectDiff,
                          selectedModel: _selectedModel,
                        )
                      : Container(
                          color: Colors.white,
                          child: CompositedTransformTarget(
                            link: _layerLink,
                            child: FleatherEditor(
                              controller: _controller!,
                              focusNode: _focusNode,
                              editorKey: _editorKey,
                              padding: EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: MediaQuery.of(context).padding.bottom,
                              ),
                              onLaunchUrl: _launchUrl,
                              maxContentWidth: 800,
                              embedBuilder: _embedBuilder,
                              spellCheckConfiguration: SpellCheckConfiguration(
                                spellCheckService: DefaultSpellCheckService(),
                                misspelledSelectionColor: Colors.red,
                                misspelledTextStyle: DefaultTextStyle.of(
                                  context,
                                ).style,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _embedBuilder(BuildContext context, EmbedNode node) {
    if (node.value.type == 'icon') {
      final data = node.value.data;
      return Icon(
        IconData(int.parse(data['codePoint']), fontFamily: data['fontFamily']),
        color: Color(int.parse(data['color'])),
        size: 18,
      );
    }

    if (node.value.type == 'image') {
      final sourceType = node.value.data['source_type'];
      ImageProvider? image;
      if (sourceType == 'assets') {
        image = AssetImage(node.value.data['source']);
      } else if (sourceType == 'file') {
        image = FileImage(File(node.value.data['source']));
      } else if (sourceType == 'url') {
        image = NetworkImage(node.value.data['source']);
      } else if (sourceType == 'data') {
        RegExp regex = RegExp(
          r'^data:image\/(png|jpe?g|gif|bmp|webp);base64,',
          caseSensitive: false,
        );
        if (regex.hasMatch(node.value.data['source'])) {
          String base64Image = node.value.data['source'].replaceFirst(
            regex,
            '',
          );
          image = MemoryImage(base64Decode(base64Image));
        }
      }
      if (image != null) {
        return Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            width: (node.value.data['width'] as num?)?.toDouble() ?? 300,
            height: (node.value.data['height'] as num?)?.toDouble() ?? 300,
            decoration: BoxDecoration(
              image: DecorationImage(image: image, fit: BoxFit.cover),
            ),
          ),
        );
      }
    }

    return defaultFleatherEmbedBuilder(context, node);
  }

  void _launchUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class ForceNewlineForInsertsAroundInlineImageRule extends InsertRule {
  @override
  Delta? apply(Delta document, int index, Object data) {
    if (data is! String) return null;
    final iter = DeltaIterator(document);
    final previous = iter.skip(index);
    final target = iter.next();
    final cursorBeforeInlineEmbed = _isInlineImage(target.data);
    final cursorAfterInlineEmbed =
        previous != null && _isInlineImage(previous.data);

    if (cursorBeforeInlineEmbed || cursorAfterInlineEmbed) {
      final delta = Delta()..retain(index);
      if (cursorAfterInlineEmbed && !data.startsWith('\n')) {
        delta.insert('\n');
      }
      delta.insert(data);
      if (cursorBeforeInlineEmbed && !data.endsWith('\n')) {
        delta.insert('\n');
      }
      return delta;
    }
    return null;
  }

  bool _isInlineImage(Object data) {
    if (data is EmbeddableObject) {
      return data.type == 'image' && data.inline;
    }
    if (data is Map) {
      return data[EmbeddableObject.kTypeKey] == 'image' &&
          data[EmbeddableObject.kInlineKey];
    }
    return false;
  }
}
