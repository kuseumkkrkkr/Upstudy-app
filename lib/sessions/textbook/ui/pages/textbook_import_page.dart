import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'book_source_picker.dart'
    if (dart.library.js_interop) 'book_source_picker_web.dart';
import 'package:flutter/material.dart';
import 'package:s11/shared/business/repositories/textbook_store.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

/// Private BookData import; never publishes author manuscripts to a public catalogue.
class TextbookImportPage extends StatefulWidget {
  const TextbookImportPage({super.key});
  @override
  State<TextbookImportPage> createState() => _TextbookImportPageState();
}

class _TextbookImportPageState extends State<TextbookImportPage> {
  final _expectedHash = TextEditingController();
  String? _source, _hash, _title, _error;
  int _bytes = 0, _pages = 0;
  bool _busy = false;
  ApiSessionScope? _scope;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.sessionChanges.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted) return;
    setState(() {
      _source = _hash = _title = null;
      _scope = null;
      _expectedHash.clear();
      _error = '계정이 변경되었습니다. 파일을 다시 선택해 주세요.';
    });
  }

  @override
  void dispose() {
    ApiClient.instance.sessionChanges.removeListener(_sessionChanged);
    _expectedHash.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final scope = await ApiClient.instance.requireSessionScope();
      final bytes = await pickBookSource();
      if (!mounted || bytes == null) return;
      ApiClient.instance.assertSessionScope(scope);
      if (bytes.length > 512 * 1024) throw const FormatException('size');
      final source = utf8.decode(bytes);
      // A BOM would change the byte checksum when the text is re-encoded.
      if (bytes.length >= 3 &&
          bytes[0] == 239 &&
          bytes[1] == 187 &&
          bytes[2] == 191) {
        throw const FormatException('bom');
      }
      final value = jsonDecode(source);
      if (value is! Map ||
          value['chapters'] is! List ||
          value['title'] is! String) {
        throw const FormatException('book');
      }
      final chapters = value['chapters'] as List;
      setState(() {
        _source = source;
        _hash = sha256.convert(bytes).toString();
        _scope = scope;
        _title = value['title'] as String;
        _bytes = bytes.length;
        _pages = chapters.whereType<Map>().fold(
          0,
          (sum, chapter) =>
              sum +
              (chapter['pages'] is List
                  ? (chapter['pages'] as List).length
                  : 0),
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _source = _hash = null;
          _scope = null;
          _error = '512 KiB 이하의 UTF-8 JSON(BOM 없음)을 선택해 주세요. 로그인 상태도 확인해 주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final source = _source, hash = _hash, scope = _scope;
    if (source == null || hash == null || scope == null) return;
    final expected = _expectedHash.text.trim().toLowerCase();
    if (expected.isNotEmpty && expected != hash) {
      setState(() => _error = '예상 SHA-256과 파일이 다릅니다. 저장하지 않았습니다.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final book = await TextbookStore.importSource(
        source,
        hash,
        expectedScope: scope,
      );
      ApiClient.instance.assertSessionScope(scope);
      if (mounted) Navigator.pop<BookData>(context, book);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = '저장하지 못했습니다: ${error.message}');
    } catch (_) {
      if (mounted) {
        setState(() => _error = '저장 결과를 확인하지 못했습니다. 같은 파일로 재시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StudentHtmlShell(
    title: '교재 JSON 가져오기',
    activeRoute: '/bookbag',
    mobileBackButton: true,
    onMenu: () => Navigator.maybePop(context),
    showBottomNavigation: false,
    showHeaderActions: false,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '개인 서재에 가져오기',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            const Text(
              '공개 출판하지 않습니다. BookData의 본문·수식·그래프·슬라이더를 읽으며 임의 HTML/JavaScript는 가져오지 않습니다. 질문·힌트·정답 블록은 표시형이며, 독립 HTML의 점 드래그·거리 측정·입력 채점은 포함되지 않습니다.',
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.upload_file),
              label: const Text('JSON 파일 선택'),
            ),
            if (_source != null) ...[
              const SizedBox(height: 16),
              Text(
                _title ?? '',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('$_bytes bytes · 명시 페이지 $_pages개 · 보충 설명도 유지합니다.'),
              const SizedBox(height: 12),
              SelectableText('SHA-256\n$_hash'),
              const SizedBox(height: 16),
              TextField(
                controller: _expectedHash,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: '예상 SHA-256 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(_error!),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy || _source == null ? null : _save,
              child: Text(_busy ? '처리 중…' : '내 서재에 저장'),
            ),
          ],
        ),
      ),
    ),
  );
}
