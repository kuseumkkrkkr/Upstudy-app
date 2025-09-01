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

class mainEditor extends StatelessWidget {
  const mainEditor({super.key});

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
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    title: 'Fleather - rich-text editor with Autocomplete',
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // FastAPI 서버 URL
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<EditorState> _editorKey = GlobalKey();
  final TextEditingController _autocompleteController = TextEditingController();
  final LayerLink _layerLink = LayerLink();

  FleatherController? _controller;
  OverlayEntry? _overlayEntry;
  bool _showAutocomplete = false;

  // FastAPI 서버 URL (실제 서버 주소로 변경)
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
    _overlayEntry?.remove();
    _autocompleteController.dispose();
    super.dispose();
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
  }

  void _setupTextChangeListener() {
    // 텍스트 변경 감지를 위한 리스너 설정
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideAutocomplete();
      }
    });
  }

  Future<void> _initController() async {
    try {
      final result = await rootBundle.loadString('assets/welcome.json');
      final heuristics = ParchmentHeuristics(
        formatRules: [],
        insertRules: [ForceNewlineForInsertsAroundInlineImageRule()],
        deleteRules: [],
      ).merge(ParchmentHeuristics.fallback);
      final doc = ParchmentDocument.fromJson(
        jsonDecode(result),
        heuristics: heuristics,
      );
      _controller = FleatherController(document: doc);
    } catch (err, st) {
      if (kDebugMode) {
        print('Cannot read welcome.json: $err\n$st');
      }
      _controller = FleatherController();
    }

    // 텍스트 변경 리스너 추가
    _controller?.addListener(_onTextChanged);
    setState(() {});
  }

  void _onTextChanged() {
    if (_controller == null) return;

    final selection = _controller!.selection;
    if (!selection.isCollapsed) {
      _hideAutocomplete();
      return;
    }

    // 현재 커서 위치에서 단어 추출
    final plainText = _controller!.document.toPlainText();
    final cursorPosition = selection.baseOffset;

    final currentWord = _getCurrentWord(plainText, cursorPosition);

    if (currentWord.isNotEmpty && currentWord.length >= 2) {
      _showAutocompleteForWord(currentWord);
    } else {
      _hideAutocomplete();
    }
  }

  String _getCurrentWord(String text, int cursorPosition) {
    if (cursorPosition <= 0 || cursorPosition > text.length) return '';

    // 커서 이전 텍스트에서 현재 단어 찾기
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

  bool _isWordSeparator(String char) {
    return char == ' ' ||
        char == '\n' ||
        char == '\t' ||
        char == ',' ||
        char == '.';
  }

  Future<List<String>> _fetchAutocompleteResults(String query) async {
    try {
      final queryParams = {
        'context': query,
        'full_text': _controller?.document.toPlainText() ?? '',
        'max_suggestions': '3',
      };

      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/sentence-complete',
        ).replace(queryParameters: queryParams),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<dynamic> suggestions = jsonResponse['suggestions'] ?? [];
        return suggestions.map((e) => e.toString()).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Autocomplete API error: $e');
      }
    }
    return [];
  }

  void _showAutocompleteForWord(String word) async {
    final suggestions = await _fetchAutocompleteResults(word);

    if (suggestions.isNotEmpty && mounted) {
      _showAutocompleteOverlay(suggestions, word);
    } else {
      _hideAutocomplete();
    }
  }

  void _showAutocompleteOverlay(List<String> suggestions, String currentWord) {
    _hideAutocomplete(); // 기존 오버레이 제거

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 200,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 30),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).cardColor,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(suggestion),
                    onTap: () => _selectSuggestion(suggestion, currentWord),
                    hoverColor: Colors.grey.shade100,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _showAutocomplete = true;
  }

  void _selectSuggestion(String suggestion, String currentWord) {
    if (_controller == null) return;

    final selection = _controller!.selection;
    final plainText = _controller!.document.toPlainText();
    final cursorPosition = selection.baseOffset;

    // 현재 단어의 시작 위치 찾기
    int start = cursorPosition - 1;
    while (start >= 0 && !_isWordSeparator(plainText[start])) {
      start--;
    }
    start++;

    // 현재 단어를 선택된 제안으로 교체
    final wordLength = currentWord.length;
    _controller!.replaceText(
      start,
      wordLength,
      suggestion,
      selection: TextSelection.collapsed(offset: start + suggestion.length),
    );

    _hideAutocomplete();
  }

  void _hideAutocomplete() {
    if (_showAutocomplete) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _showAutocomplete = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Fleather Demo with Autocomplete'),
      ),
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
                FleatherToolbar.basic(
                  controller: _controller!,
                  editorKey: _editorKey,
                ),
                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                Expanded(
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
                        misspelledTextStyle: DefaultTextStyle.of(context).style,
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
          padding: const EdgeInsets.only(left: 4, right: 2, top: 2, bottom: 2),
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
    final canLaunch = await canLaunchUrl(uri);
    if (canLaunch) {
      await launchUrl(uri);
    }
  }
}

/// This is an example insert rule that will insert a new line before and
/// after inline image embed.
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
