import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/business/repositories/textbook_store.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart' as reader;

/// Free, server-published textbooks. Personal drafts never become public here.
class PublicTextbooksPage extends StatefulWidget {
  const PublicTextbooksPage({
    super.key,
    this.loadItems,
    this.acquireBook,
    this.onOpen,
  });

  final Future<List<Map<String, dynamic>>> Function()? loadItems;
  final Future<BookData> Function(String bookId)? acquireBook;
  final void Function(BookData book)? onOpen;

  @override
  State<PublicTextbooksPage> createState() => _PublicTextbooksPageState();
}

class _PublicTextbooksPageState extends State<PublicTextbooksPage> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  String? _busyId;
  bool _loginRequired = false;
  String _query = '';
  int _epoch = 0;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    if (widget.loadItems == null) {
      ApiClient.instance.sessionChanges.addListener(_sessionChanged);
    }
    _load();
  }

  void _sessionChanged() {
    _epoch++;
    setState(() {
      _items = null;
      _busyId = null;
    });
    _load();
  }

  @override
  void dispose() {
    _epoch++;
    if (widget.loadItems == null) {
      ApiClient.instance.sessionChanges.removeListener(_sessionChanged);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final epoch = _epoch;
    final request = ++_loadRequest;
    setState(() {
      _error = null;
      _loginRequired = false;
    });
    try {
      final api = ApiClient.instance;
      final loader = widget.loadItems;
      final scope = loader == null ? await api.requireSessionScope() : null;
      final items = loader != null
          ? await loader()
          : await api.listPublicTextbooks(expectedScope: scope);
      if (scope != null) api.assertSessionScope(scope);
      if (mounted && epoch == _epoch && request == _loadRequest) {
        setState(() => _items = items);
      }
    } catch (error) {
      if (mounted && epoch == _epoch && request == _loadRequest) {
        setState(() {
          _loginRequired = error is ApiException && error.statusCode == 401;
          _error = _loginRequired
              ? '로그인이 필요합니다. 다시 로그인해 주세요.'
              : '공개 교재를 불러오지 못했습니다.';
        });
      }
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    if (_busyId != null) return;
    final epoch = _epoch;
    final id = item['textbook_id'].toString();
    setState(() {
      _busyId = id;
      _error = null;
    });
    final api = ApiClient.instance;
    ApiSessionScope? scope;
    try {
      final BookData book;
      if (widget.acquireBook != null) {
        book = await widget.acquireBook!(id);
      } else {
        scope = await api.requireSessionScope();
        if (item['owned'] != true) {
          await api.acquirePublicTextbook(id, expectedScope: scope);
        }
        final library = await TextbookStore.loadLibrary(forceRefresh: true);
        api.assertSessionScope(scope);
        if (!library.any((entry) => entry.id == id)) {
          throw StateError(
            'Public acquisition is not yet visible in the library',
          );
        }
        final body = await api.getTextbook(id);
        api.assertSessionScope(scope);
        book = BookData.fromJson(body);
      }
      if (!mounted || epoch != _epoch) return;
      if (scope != null) api.assertSessionScope(scope);
      // A catalogue refresh must not cancel an acquisition or overwrite its
      // confirmed ownership with an older response.
      _loadRequest++;
      setState(() {
        for (final current in _items ?? <Map<String, dynamic>>[]) {
          if (current['textbook_id'].toString() == id) current['owned'] = true;
        }
      });
      final open = widget.onOpen;
      if (open != null) {
        open(book);
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => reader.BookWidget(book: book)),
        );
      }
    } catch (_) {
      if (mounted &&
          epoch == _epoch &&
          (scope == null || api.isCurrentSessionScope(scope))) {
        setState(() => _error = '교재를 열지 못했습니다. 같은 교재로 다시 시도해 주세요.');
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (_items ?? const <Map<String, dynamic>>[]).where(
      (item) =>
          '${item['title']} ${item['subtitle']} ${item['curriculum_version']}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFDFE),
        foregroundColor: const Color(0xFF09090B),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '기본 제공 교재',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '공개 교재 · 0코인',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('기본 제공 교재입니다. 무료로 담으면 책가방에서도 다시 열 수 있습니다.'),
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(
                labelText: '교재 검색',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            if (_error != null) ...[
              Semantics(liveRegion: true, child: Text(_error!)),
              TextButton(
                onPressed: _loginRequired
                    ? () => Navigator.of(context).pushNamed('/login')
                    : _load,
                child: Text(_loginRequired ? '로그인' : '다시 시도'),
              ),
            ],
            if (_items == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (_items != null && items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(_query.isEmpty ? '공개된 교재가 없습니다.' : '검색 결과가 없습니다.'),
              ),
            for (final item in items)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(20),
                color: const Color(0xFFFDFDFE),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']?.toString() ?? '교재',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(item['subtitle']?.toString() ?? ''),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111113),
                        foregroundColor: const Color(0xFFFDFDFE),
                        minimumSize: const Size(0, 48),
                        shape: const RoundedRectangleBorder(),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: _busyId == null ? () => _open(item) : null,
                      child: Text(
                        _busyId == item['textbook_id']
                            ? '처리 중…'
                            : item['owned'] == true
                            ? '교재 열기'
                            : '0코인 · 책가방에 담기',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
