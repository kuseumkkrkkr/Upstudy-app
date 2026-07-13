import 'dart:async';
import 'package:flutter/material.dart';
import '../models/textbook.dart';
import '../models/content_block.dart';
import '../widgets/content_blocks_view.dart';
import '../services/api_client.dart';

// ??? Exact Student Colors ???

const Color _kPrimary = Color(0xFF0A0A0A);
const Color _kPrimaryLight = Color(0xFF27272A);
const Color _kBg = Color(0xFFF4F4F5);
const Color _kBorder = Color(0xFFE3E3E7);

// ??? Preview Data Models ???

class _PreviewEntry {
  final int chapterIndex;
  final int level; // 0 = chapter, 1 = section
  final String title;
  final List<String> paragraphs;
  final List<String> images;
  _PreviewEntry({
    required this.chapterIndex,
    required this.level,
    required this.title,
    this.paragraphs = const [],
    this.images = const [],
  });
}

class _TocEntry {
  final int entryIndex;
  final int chapterIndex;
  final int level;
  final String title;
  final bool hasChildren;
  _TocEntry({
    required this.entryIndex,
    required this.chapterIndex,
    required this.level,
    required this.title,
    required this.hasChildren,
  });
}

class _SearchResult {
  final int entryIndex;
  final String title;
  final String preview;
  _SearchResult({
    required this.entryIndex,
    required this.title,
    required this.preview,
  });
}

// ??? Student View Preview Widget ???

class StudentViewPreview extends StatefulWidget {
  final BookData book;
  final double scale;
  final VoidCallback? onEditPressed;

  const StudentViewPreview({
    super.key,
    required this.book,
    required this.scale,
    this.onEditPressed,
  });

  @override
  State<StudentViewPreview> createState() => _StudentViewPreviewState();
}

class _StudentViewPreviewState extends State<StudentViewPreview> {
  // ??? Data ???
  late final List<_PreviewEntry> _contentEntries;
  late final List<_TocEntry> _tocEntries;
  late final List<bool> _chapterExpanded;

  // ??? Scroll & Layout ???
  final ScrollController _contentController = ScrollController();
  final List<GlobalKey> _sectionKeys = [];
  final List<double> _sectionOffsets = [];

  // ??? State ???
  final ValueNotifier<int> _activeEntryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _sidebarCollapsedNotifier = ValueNotifier<bool>(
    false,
  );
  int _activeEntryIndex = 0;
  Timer? _scrollThrottleTimer;

  // ??? Caching ???
  final Map<String, List<ContentBlock>> _latexCache =
      <String, List<ContentBlock>>{};

  // ??? Viewport culling ???
  static const double _viewportOverscan = 800.0;
  static const double _averageItemHeight = 200.0;

  @override
  void initState() {
    super.initState();
    _contentEntries = _buildContentEntries(widget.book.chapters);
    _tocEntries = _buildTocEntries(_contentEntries);
    _chapterExpanded = List.generate(widget.book.chapters.length, (i) => true);
    for (var i = 0; i < _contentEntries.length; i++) {
      _sectionKeys.add(GlobalKey());
      _sectionOffsets.add(0.0);
    }

    _contentController.addListener(_handleContentScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cacheSectionOffsets());
  }

  List<_PreviewEntry> _buildContentEntries(List<BookChapter> chapters) {
    final entries = <_PreviewEntry>[];
    for (var i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      entries.add(
        _PreviewEntry(
          chapterIndex: i,
          level: 0,
          title: chapter.title,
          paragraphs: chapter.intro,
        ),
      );
      for (final section in chapter.sections) {
        entries.add(
          _PreviewEntry(
            chapterIndex: i,
            level: 1,
            title: section.title,
            paragraphs: section.paragraphs,
            images: section.images,
          ),
        );
      }
    }
    return entries;
  }

  List<_TocEntry> _buildTocEntries(List<_PreviewEntry> entries) {
    final toc = <_TocEntry>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final hasChildren =
          e.level == 0 && (i + 1 < entries.length && entries[i + 1].level == 1);
      toc.add(
        _TocEntry(
          entryIndex: i,
          chapterIndex: e.chapterIndex,
          level: e.level,
          title: e.title,
          hasChildren: hasChildren,
        ),
      );
    }
    return toc;
  }

  // ??? Scroll Throttle ???

  void _handleContentScroll() {
    final timer = _scrollThrottleTimer;
    if (timer != null && timer.isActive) return;
    _scrollThrottleTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        _cacheSectionOffsets();
        _updateActiveEntry();
      }
    });
  }

  // ??? Section Offset Cache (with interpolation) ???

  void _cacheSectionOffsets() {
    final listBox = _listViewContext?.findRenderObject() as RenderBox?;
    if (listBox == null) return;
    final exact = <int, double>{};
    for (var i = 0; i < _sectionKeys.length; i++) {
      final box =
          _sectionKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        exact[i] =
            box.localToGlobal(Offset.zero, ancestor: listBox).dy +
            _contentController.offset;
      }
    }
    if (exact.isEmpty) return;
    for (var i = 0; i < _sectionOffsets.length; i++) {
      if (exact.containsKey(i)) {
        _sectionOffsets[i] = exact[i]!;
      } else {
        double? beforeOffset;
        int? beforeIdx;
        double? afterOffset;
        int? afterIdx;
        for (var j = i - 1; j >= 0; j--) {
          if (exact.containsKey(j)) {
            beforeOffset = exact[j];
            beforeIdx = j;
            break;
          }
        }
        for (var j = i + 1; j < _sectionOffsets.length; j++) {
          if (exact.containsKey(j)) {
            afterOffset = exact[j];
            afterIdx = j;
            break;
          }
        }
        if (beforeOffset != null &&
            afterOffset != null &&
            beforeIdx != null &&
            afterIdx != null) {
          final t = (i - beforeIdx) / (afterIdx - beforeIdx);
          _sectionOffsets[i] = beforeOffset + (afterOffset - beforeOffset) * t;
        } else if (beforeOffset != null && beforeIdx != null) {
          final avg = _averageItemHeight * widget.scale;
          _sectionOffsets[i] = beforeOffset + avg * (i - beforeIdx);
        } else if (afterOffset != null && afterIdx != null) {
          final avg = _averageItemHeight * widget.scale;
          _sectionOffsets[i] = afterOffset - avg * (afterIdx - i);
        }
      }
    }
  }

  BuildContext? get _listViewContext {
    for (final key in _sectionKeys) {
      final ctx = key.currentContext;
      if (ctx != null) return ctx;
    }
    return null;
  }

  // ??? Active Entry Update ???

  void _updateActiveEntry() {
    final offset = _contentController.offset + 12;
    int newIndex = 0;
    for (var i = 0; i < _sectionOffsets.length; i++) {
      if (_sectionOffsets[i] <= offset) {
        newIndex = i;
      } else {
        break;
      }
    }
    if (newIndex == _activeEntryIndex) return;
    setState(() {
      _activeEntryIndex = newIndex;
      _activeEntryNotifier.value = newIndex;
      final chapterIndex = _contentEntries[newIndex].chapterIndex;
      if (chapterIndex >= 0 && chapterIndex < _chapterExpanded.length) {
        if (!_chapterExpanded[chapterIndex]) {
          _chapterExpanded[chapterIndex] = true;
        }
      }
    });
  }

  // ??? Navigation ???

  void _scrollToEntry(int index) {
    if (index < 0 || index >= _sectionKeys.length) return;
    final key = _sectionKeys[index];
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.02,
      );
      return;
    }
    // Fallback: jump using cached offsets
    if (index < _sectionOffsets.length) {
      final target = _sectionOffsets[index] - 12;
      _contentController.animateTo(
        target.clamp(0.0, _contentController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleChapter(int chapterIndex) {
    setState(
      () => _chapterExpanded[chapterIndex] = !_chapterExpanded[chapterIndex],
    );
  }

  Future<void> _openProfileMenu(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _ProfileDialog(
        onProfileUpdated: () {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  Future<void> _openDeleteDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final isBusy = ValueNotifier<bool>(false);
    final errorText = ValueNotifier<String?>(null);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('?뚯썝?덊눜'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('?뺣쭚 ?덊눜?섏떆寃좎뒿?덇퉴? ???묒뾽? ?섎룎由????놁뒿?덈떎.'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '?꾩옱 鍮꾨?踰덊샇',
                border: OutlineInputBorder(),
              ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: errorText,
              builder: (_, error, __) => error == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('痍⑥냼'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isBusy,
            builder: (_, busy, __) => TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final password = passwordController.text;
                      if (password.isEmpty) {
                        errorText.value = '鍮꾨?踰덊샇瑜??낅젰?댁＜?몄슂.';
                        return;
                      }
                      isBusy.value = true;
                      try {
                        await ApiClient.instance.deleteMyProfile(
                          password: password,
                        );
                        await ApiClient.instance.clearToken();
                        if (!mounted) return;
                        Navigator.of(dialogContext).pop();
                        if (!mounted) return;
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (route) => false);
                      } catch (e) {
                        errorText.value = e.toString();
                      } finally {
                        isBusy.value = false;
                      }
                    },
              child: const Text('?덊눜'),
            ),
          ),
        ],
      ),
    );
    isBusy.dispose();
    errorText.dispose();
    passwordController.dispose();
  }

  Future<void> _openSettingsMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '설정',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('회원정보 수정'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openProfileMenu(context);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline),
                title: const Text('회원탈퇴'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openDeleteDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.white),
              child: FutureBuilder<UserProfile>(
                future: ApiClient.instance.getMyProfile(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final profile = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text(
                        'AIFlow',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A0A0A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF52525B),
                        ),
                      ),
                      Text(
                        profile.name,
                        style: const TextStyle(color: Color(0xFF71717A)),
                      ),
                    ],
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('프로필'),
              onTap: () {
                Navigator.pop(context);
                _openProfileMenu(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('설정'),
              onTap: () {
                Navigator.pop(context);
                _openSettingsMenu(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () async {
                Navigator.pop(context);
                await ApiClient.instance.clearToken();
                if (!mounted) return;
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ??? Search ???

  Future<void> _openSearch() async {
    final controller = TextEditingController();
    var results = <_SearchResult>[];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void performSearch(String query) {
            final q = query.trim().toLowerCase();
            if (q.isEmpty) {
              setModalState(() => results = []);
              return;
            }
            final found = <_SearchResult>[];
            for (var i = 0; i < _contentEntries.length; i++) {
              final entry = _contentEntries[i];
              final text = '${entry.title} ${entry.paragraphs.join(' ')}'
                  .toLowerCase();
              if (text.contains(q)) {
                var preview = entry.paragraphs.firstWhere(
                  (p) => p.toLowerCase().contains(q),
                  orElse: () => entry.title,
                );
                if (preview.length > 80) {
                  preview = '${preview.substring(0, 80)}...';
                }
                found.add(
                  _SearchResult(
                    entryIndex: i,
                    title: entry.title,
                    preview: preview,
                  ),
                );
              }
            }
            setModalState(() => results = found);
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Search field
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '검색어를 입력하세요',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  controller.clear();
                                  setModalState(() => results = []);
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _kPrimary),
                        ),
                      ),
                      onChanged: performSearch,
                    ),
                  ),
                  // Results
                  Expanded(
                    child: results.isEmpty && controller.text.isNotEmpty
                        ? Center(
                            child: Text(
                              '검색 결과가 없습니다',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final r = results[i];
                              return ListTile(
                                leading: const Icon(
                                  Icons.article_outlined,
                                  color: _kPrimary,
                                ),
                                title: Text(
                                  r.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  r.preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _scrollToEntry(r.entryIndex);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
  }

  // ??? Image Provider Resolution ???

  ImageProvider _resolveImageProvider(String source) {
    final trimmed = source.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }
    if (trimmed.startsWith('/')) {
      return NetworkImage(ApiClient.resourceUrl(trimmed));
    }
    return AssetImage(trimmed);
  }

  // ??? LaTeX Cache ???

  Widget _buildLatexAware(String text, TextStyle style) {
    final blocks = _latexCache.putIfAbsent(
      text,
      () => parseTextWithLatex(text),
    );
    return ContentBlocksView(inline: true, blocks: blocks, textStyle: style);
  }

  // ??? Graph Widget Selection (minimal stub, appended to last section) ???

  Widget? _buildGraphWidget(BookData book) {
    final tags = book.tags.map((t) => t.toLowerCase()).toList();
    if (tags.contains('trigonometric') ||
        tags.contains('trigonometry') ||
        tags.contains('삼각') ||
        tags.contains('sin') ||
        tags.contains('cos')) {
      return _GraphPlaceholderCard(
        title: '삼각 함수 그래프',
        formula: r'y = A\sin(Bx + C) + D',
        scale: widget.scale,
      );
    }
    if (tags.contains('exponential') ||
        tags.contains('지수') ||
        tags.contains('logarithm') == false && tags.contains('exp')) {
      return _GraphPlaceholderCard(
        title: '지수 함수 그래프',
        formula: r'y = a^x',
        scale: widget.scale,
      );
    }
    if (tags.contains('logarithm') || tags.contains('로그')) {
      return _GraphPlaceholderCard(
        title: '로그 함수 그래프',
        formula: r'y = \log_a x',
        scale: widget.scale,
      );
    }
    if (tags.contains('quadratic') || tags.contains('이차')) {
      return _GraphPlaceholderCard(
        title: '이차 함수 그래프',
        formula: r'y = ax^2 + bx + c',
        scale: widget.scale,
      );
    }
    if (tags.contains('linear') || tags.contains('일차')) {
      return _GraphPlaceholderCard(
        title: '일차 함수 그래프',
        formula: r'y = ax + b',
        scale: widget.scale,
      );
    }
    return null;
  }

  // ??? Lifecycle ???

  @override
  void dispose() {
    _contentController.dispose();
    _activeEntryNotifier.dispose();
    _sidebarCollapsedNotifier.dispose();
    _scrollThrottleTimer?.cancel();
    super.dispose();
  }

  // ??? Build ???

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Scaffold(
      endDrawer: _buildProfileDrawer(),
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.book.title),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
          if (widget.onEditPressed != null)
            TextButton.icon(
              onPressed: widget.onEditPressed,
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text('?몄쭛', style: TextStyle(color: Colors.white)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar
            ValueListenableBuilder<bool>(
              valueListenable: _sidebarCollapsedNotifier,
              builder: (context, collapsed, _) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: collapsed ? 0 : 260 * scale,
                  child: collapsed
                      ? null
                      : ClipRect(child: _buildSidebar(scale)),
                );
              },
            ),
            // Collapse handle (visible when sidebar is open)
            ValueListenableBuilder<bool>(
              valueListenable: _sidebarCollapsedNotifier,
              builder: (context, collapsed, _) {
                if (collapsed) {
                  return _buildCollapseHandle(collapsed: true);
                }
                return const SizedBox.shrink();
              },
            ),
            // Content
            Expanded(child: _buildContent(scale)),
          ],
        ),
      ),
    );
  }

  // ??? Sidebar Collapse Handle ???

  Widget _buildCollapseHandle({required bool collapsed}) {
    return GestureDetector(
      onTap: () => _sidebarCollapsedNotifier.value = !collapsed,
      child: Container(
        width: 18,
        height: 80,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 4,
              offset: Offset(1, 0),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Icon(
            collapsed ? Icons.chevron_right : Icons.chevron_left,
            key: ValueKey<bool>(collapsed),
            size: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // ??? Sidebar ???

  Widget _buildSidebar(double scale) {
    return Container(
      width: 260 * scale,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _kBorder)),
      ),
      child: Column(
        children: [
          // TOC header ??exact student style: "紐⑹감" text only, 52px height
          Container(
            height: 52 * scale,
            padding: EdgeInsets.symmetric(horizontal: 16 * scale),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(
              children: [
                Text(
                  '紐⑹감',
                  style: TextStyle(
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                  ),
                ),
                const Spacer(),
                // Collapse button
                IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    size: 18 * scale,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () => _sidebarCollapsedNotifier.value = true,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
          // TOC list
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _activeEntryNotifier,
              builder: (context, activeIndex, _) {
                return ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8 * scale),
                  itemCount: _tocEntries.length,
                  itemBuilder: (_, i) {
                    final toc = _tocEntries[i];
                    final isActive = activeIndex == toc.entryIndex;
                    final isChapter = toc.level == 0;
                    final isExpanded = isChapter
                        ? _chapterExpanded[toc.chapterIndex]
                        : true;

                    // Hide section entries if chapter collapsed
                    if (!isChapter && !_chapterExpanded[toc.chapterIndex]) {
                      return const SizedBox.shrink();
                    }

                    return InkWell(
                      onTap: () {
                        if (isChapter && toc.hasChildren) {
                          _toggleChapter(toc.chapterIndex);
                        }
                        _scrollToEntry(toc.entryIndex);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isChapter ? 12 * scale : 24 * scale,
                          vertical: 8 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? _kPrimary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6 * scale),
                          border: isActive
                              ? const Border(
                                  bottom: BorderSide(color: _kBorder),
                                )
                              : null,
                        ),
                        margin: EdgeInsets.symmetric(
                          horizontal: 8 * scale,
                          vertical: 2 * scale,
                        ),
                        child: Row(
                          children: [
                            if (isChapter && toc.hasChildren)
                              Icon(
                                isExpanded
                                    ? Icons.expand_more
                                    : Icons.chevron_right,
                                size: 16 * scale,
                                color: isActive
                                    ? Colors.white70
                                    : Colors.grey.shade500,
                              )
                            else
                              SizedBox(width: 16 * scale),
                            SizedBox(width: 4 * scale),
                            Expanded(
                              child: Text(
                                toc.title.isEmpty
                                    ? (isChapter ? 'Chapter' : 'Section')
                                    : toc.title,
                                style: TextStyle(
                                  fontSize: isChapter ? 13 * scale : 12 * scale,
                                  fontWeight: isChapter
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isActive
                                      ? Colors.white
                                      : (isChapter
                                            ? Colors.black87
                                            : Colors.black54),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Bottom tools ??exact student layout
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: 8 * scale,
            ),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolButton(
                  Icons.search,
                  '검색',
                  scale,
                  () => _openSearch(),
                ),
                _buildToolButton(Icons.chevron_left, '?댁쟾', scale, () {
                  if (_activeEntryIndex > 0) {
                    _scrollToEntry(_activeEntryIndex - 1);
                  }
                }),
                _buildToolButton(Icons.chevron_right, '?ㅼ쓬', scale, () {
                  if (_activeEntryIndex < _contentEntries.length - 1) {
                    _scrollToEntry(_activeEntryIndex + 1);
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(
    IconData icon,
    String tooltip,
    double scale,
    VoidCallback onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, size: 18 * scale, color: Colors.grey.shade600),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  // ??? Content Area ???

  Widget _buildContent(double scale) {
    return Container(
      color: _kBg,
      child: Column(
        children: [
          // Collapsed sidebar toggle (chevron handle on left edge)
          ValueListenableBuilder<bool>(
            valueListenable: _sidebarCollapsedNotifier,
            builder: (context, collapsed, _) {
              if (!collapsed) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.centerLeft,
                child: _buildCollapseHandle(collapsed: true),
              );
            },
          ),
          // Book title header
          if (widget.book.title.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20 * scale,
                20 * scale,
                24 * scale,
                16 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.book.title,
                    style: TextStyle(
                      fontSize: 28 * scale,
                      fontWeight: FontWeight.w800,
                      color: _kPrimary,
                    ),
                  ),
                  if (widget.book.subtitle.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4 * scale),
                      child: Text(
                        widget.book.subtitle,
                        style: TextStyle(
                          fontSize: 14 * scale,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // Content list
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ListView.builder(
                  controller: _contentController,
                  padding: EdgeInsets.fromLTRB(
                    20 * scale,
                    0,
                    24 * scale,
                    40 * scale,
                  ),
                  itemCount: _contentEntries.length,
                  itemBuilder: (_, i) {
                    return _buildContentEntry(
                      _contentEntries[i],
                      i,
                      scale,
                      constraints,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ??? Content Entry (with viewport culling) ???

  Widget _buildContentEntry(
    _PreviewEntry entry,
    int index,
    double scale,
    BoxConstraints constraints,
  ) {
    // Viewport culling: skip rendering if far offscreen
    final itemTop = index < _sectionOffsets.length
        ? _sectionOffsets[index]
        : 0.0;
    final viewportTop = _contentController.offset - _viewportOverscan;
    final viewportBottom =
        _contentController.offset + constraints.maxHeight + _viewportOverscan;

    final isFarOffscreen =
        itemTop + _averageItemHeight * widget.scale < viewportTop ||
        itemTop > viewportBottom;

    if (isFarOffscreen && _sectionOffsets[index] > 0) {
      // Return placeholder with same key to maintain scroll position
      return KeyedSubtree(
        key: _sectionKeys[index],
        child: SizedBox(height: _averageItemHeight * widget.scale),
      );
    }

    final isChapter = entry.level == 0;
    final titleStyle = TextStyle(
      fontSize: isChapter ? 24 * scale : 18 * scale,
      fontWeight: isChapter ? FontWeight.w800 : FontWeight.w700,
      color: _kPrimary,
      height: 1.3,
    );

    final contentBlocks = <Widget>[];

    // Title
    if (entry.title.isNotEmpty) {
      contentBlocks.add(
        KeyedSubtree(
          key: _sectionKeys[index],
          child: Padding(
            padding: EdgeInsets.only(
              top: isChapter ? 24 * scale : 16 * scale,
              bottom: 8 * scale,
            ),
            child: Text(entry.title, style: titleStyle),
          ),
        ),
      );
    } else {
      contentBlocks.add(
        KeyedSubtree(
          key: _sectionKeys[index],
          child: SizedBox(height: isChapter ? 24 * scale : 16 * scale),
        ),
      );
    }

    // Paragraphs with LaTeX cache
    final textStyle = TextStyle(
      fontSize: 15 * scale,
      height: 1.6,
      color: Colors.black87,
    );
    for (final para in entry.paragraphs) {
      if (para.trim().isEmpty) continue;
      contentBlocks.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8 * scale),
          child: _buildLatexAware(para, textStyle),
        ),
      );
    }

    // Images with proper provider resolution
    for (final img in entry.images) {
      if (img.trim().isEmpty) continue;
      contentBlocks.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8 * scale),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12 * scale),
            child: Image(
              image: _resolveImageProvider(img),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120 * scale,
                color: Colors.grey.shade200,
                child: Center(
                  child: Text(
                    '?대?吏 濡쒕뱶 ?ㅽ뙣',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12 * scale,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Bottom spacing
    contentBlocks.add(SizedBox(height: 16 * scale));

    // Append graph widget if this is the last entry and book has graph tags
    if (index == _contentEntries.length - 1) {
      final graph = _buildGraphWidget(widget.book);
      if (graph != null) contentBlocks.add(graph);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentBlocks,
    );
  }
}

// ??? Minimal Graph Placeholder Card ???

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.onProfileUpdated});

  final VoidCallback onProfileUpdated;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _schoolController = TextEditingController();
  final _gradeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ApiClient.instance.getMyProfile();
      _idController.text = profile.username;
      _nameController.text = profile.name;
      _emailController.text = profile.email ?? '';
      _schoolController.text = profile.school ?? '';
      _gradeController.text = profile.grade ?? '';
    } catch (e) {
      if (mounted) {
        _error = e.toString();
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final newId = _idController.text.trim();
    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newSchool = _schoolController.text.trim();
    final newGrade = _gradeController.text.trim();
    final pw = _passwordController.text;
    final pwConfirm = _passwordConfirmController.text;
    if (pw.isNotEmpty && pw != pwConfirm) {
      setState(() => _error = 'Password confirm does not match');
      return;
    }
    final body = <String, dynamic>{};
    if (newId.isNotEmpty) body['username'] = newId;
    if (newName.isNotEmpty) body['name'] = newName;
    if (newEmail.isNotEmpty) body['email'] = newEmail;
    if (newSchool.isNotEmpty) body['school'] = newSchool;
    if (newGrade.isNotEmpty) body['grade'] = newGrade;
    if (pw.isNotEmpty) body['password'] = pw;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiClient.instance.updateMyProfile(body);
      widget.onProfileUpdated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _schoolController.dispose();
    _gradeController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('프로필 수정'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: 'ID / Login ID',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _schoolController,
                    decoration: const InputDecoration(labelText: 'School'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _gradeController,
                    decoration: const InputDecoration(labelText: 'Grade'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password (optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordConfirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password confirm',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  if (_saving) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _GraphPlaceholderCard extends StatelessWidget {
  final String title;
  final String formula;
  final double scale;

  const _GraphPlaceholderCard({
    required this.title,
    required this.formula,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 12 * scale),
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: _kPrimaryLight, size: 20 * scale),
              SizedBox(width: 8 * scale),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.w700,
                  color: _kPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Container(
            height: 200 * scale,
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            child: Center(
              child: Text(
                '[洹몃옒??誘몃━蹂닿린]',
                style: TextStyle(
                  fontSize: 13 * scale,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
