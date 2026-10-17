import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:s11/app/router.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

enum BookbagMaterialKind { textbook, exam, bookmark }

/// 분류 버튼은 중앙 다이얼로그 대신 원문 하단 자료 시트를 연다.
Future<void> showBookbagMaterialSheet(
  BuildContext context, {
  required BookbagMaterialKind kind,
  required Future<List<BookbagMaterial>> Function() loadMaterials,
  bool allowUnauthenticatedPreview = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxWidth: MediaQuery.sizeOf(context).width <= 720 ? double.infinity : 640,
  ),
  backgroundColor: StudentDensityTokens.surface,
  barrierColor: StudentDensityTokens.dark.withValues(alpha: .52),
  shape: const RoundedRectangleBorder(),
  builder: (_) =>
      _BookbagMaterialSheet(kind: kind, loadMaterials: loadMaterials,
        allowUnauthenticatedPreview: allowUnauthenticatedPreview),
);

class _BookbagMaterialSheet extends StatefulWidget {
  const _BookbagMaterialSheet({
    required this.kind,
    required this.loadMaterials,
    required this.allowUnauthenticatedPreview,
  });
  final BookbagMaterialKind kind;
  final Future<List<BookbagMaterial>> Function() loadMaterials;
  final bool allowUnauthenticatedPreview;
  @override
  State<_BookbagMaterialSheet> createState() => _BookbagMaterialSheetState();
}

class _BookbagMaterialSheetState extends State<_BookbagMaterialSheet> {
  late Future<List<BookbagMaterial>> _future;
  int _epoch = 0;
  ApiSessionScope? _renderScope;
  @override
  void initState() {
    super.initState();
    ApiClient.instance.sessionChanges.addListener(_sessionChanged);
    _future = _load();
  }
  Future<List<BookbagMaterial>> _load() async {
    final epoch = ++_epoch;
    final api = ApiClient.instance;
    final scope = widget.allowUnauthenticatedPreview && !api.hasAuthenticatedSession
        ? null : await api.requireSessionScope();
    final rows = await widget.loadMaterials();
    if (!mounted || epoch != _epoch) throw StateError('Material scene changed');
    if (scope != null) api.assertSessionScope(scope);
    _renderScope = scope;
    return rows;
  }
  void _sessionChanged() {
    if (!mounted) return;
    setState(() {
      _renderScope = null;
      _future = _load();
    });
  }
  @override
  void dispose() {
    _epoch++;
    ApiClient.instance.sessionChanges.removeListener(_sessionChanged);
    super.dispose();
  }
  void _close() => Navigator.of(context).pop();
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    final title = switch (widget.kind) {
      BookbagMaterialKind.textbook => '교재',
      BookbagMaterialKind.exam => '시험지',
      BookbagMaterialKind.bookmark => '북마크',
    };
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        autofocus: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mobile
                ? MediaQuery.sizeOf(context).height * .72
                : (MediaQuery.sizeOf(context).height - 28)
                      .clamp(0, 680)
                      .toDouble(),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 14 : 18,
                0,
                mobile ? 14 : 18,
                18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      color: StudentDensityTokens.ink,
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minHeight: 54),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: StudentDensityTokens.line),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            onPressed: _close,
                            tooltip: '닫기',
                            icon: const Icon(Icons.close, size: 19),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<List<BookbagMaterial>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done)
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      if (snapshot.hasError)
                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(studentFacingApiError(
                                snapshot.error!,
                                fallback: '자료를 불러오지 못했습니다.',
                              )),
                            ),
                            if (snapshot.error is ApiException &&
                                (snapshot.error as ApiException).statusCode == 401)
                              TextButton(
                                onPressed: () {
                                  final navigator = Navigator.of(context);
                                  navigator.pop();
                                  navigator.pushNamed('/login');
                                },
                                child: const Text('로그인'),
                              ),
                            TextButton(
                              onPressed: () => setState(() {
                                _future = _load();
                              }),
                              child: const Text('다시 시도'),
                            ),
                          ],
                        );
                      final rows = (snapshot.data ?? [])
                          .where((row) => row.kind == widget.kind)
                          .toList();
                      if (rows.isEmpty)
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('보관된 자료가 없습니다.'),
                        );
                      return Column(
                        children: [
                          for (final row in rows)
                            InkWell(
                              onTap: () {
                                if (_renderScope != null && !ApiClient.instance.isCurrentSessionScope(_renderScope!)) return;
                                if (_renderScope == null && !widget.allowUnauthenticatedPreview) return;
                                _close();
                                row.onOpen();
                              },
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 72,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: StudentDensityTokens.line,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      color: StudentDensityTokens.surfaceMuted,
                                      child: Icon(row.icon, size: 19),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            row.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            row.detail,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: StudentDensityTokens.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      widget.kind ==
                                              BookbagMaterialKind.textbook
                                          ? '이어읽기'
                                          : widget.kind ==
                                                BookbagMaterialKind.exam
                                          ? '미리보기'
                                          : '보기',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward, size: 14),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 자료 관리에 필요한 표시값만 전달한다. 실제 모델·열기 동작은 부모가 소유한다.
/// 미제공 상태·날짜는 null이며 HTML 샘플값으로 보충하지 않는다.
class BookbagMaterial {
  const BookbagMaterial({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.onOpen,
    this.addedAt,
    this.completedAt,
    this.status,
  });
  final String id;
  final BookbagMaterialKind kind;
  final String title;
  final String detail;
  final DateTime? addedAt;
  final DateTime? completedAt;
  final String? status;
  final VoidCallback onOpen;
  String get kindLabel => switch (kind) {
    BookbagMaterialKind.textbook => '교재',
    BookbagMaterialKind.exam => '시험지',
    BookbagMaterialKind.bookmark => '북마크',
  };
  IconData get icon => switch (kind) {
    BookbagMaterialKind.textbook => Icons.menu_book_outlined,
    BookbagMaterialKind.exam => Icons.check,
    BookbagMaterialKind.bookmark => Icons.auto_awesome_outlined,
  };
}

/// 독립 내 자료 페이지. 읽기/검색/필터/로컬 정렬만 하며 삭제·순서 저장은 하지 않는다.
class BookbagDetailsPage extends StatefulWidget {
  const BookbagDetailsPage({super.key, required this.loadMaterials,
    this.allowUnauthenticatedPreview = false});
  final Future<List<BookbagMaterial>> Function() loadMaterials;
  /// Explicit synthetic test fixtures only; real private scenes require auth.
  @visibleForTesting
  final bool allowUnauthenticatedPreview;
  @override
  State<BookbagDetailsPage> createState() => _BookbagDetailsPageState();
}

class _BookbagDetailsPageState extends State<BookbagDetailsPage> {
  late Future<List<BookbagMaterial>> _future;
  String _query = '';
  BookbagMaterialKind? _kind;
  bool _oldest = false;
  int _epoch = 0;
  ApiSessionScope? _renderScope;
  @override
  void initState() {
    super.initState();
    ApiClient.instance.sessionChanges.addListener(_sessionChanged);
    _future = _load();
  }

  Future<List<BookbagMaterial>> _load() async {
    final epoch = ++_epoch;
    final api = ApiClient.instance;
    final scope = widget.allowUnauthenticatedPreview && !api.hasAuthenticatedSession
        ? null : await api.requireSessionScope();
    final rows = await widget.loadMaterials();
    if (!mounted || epoch != _epoch) throw StateError('Material scene changed');
    if (scope != null) api.assertSessionScope(scope);
    _renderScope = scope;
    return rows;
  }
  void _sessionChanged() {
    if (!mounted) return;
    setState(() {
      _query = '';
      _kind = null;
      _oldest = false;
      _renderScope = null;
      _future = _load();
    });
  }
  @override
  void dispose() {
    _epoch++;
    ApiClient.instance.sessionChanges.removeListener(_sessionChanged);
    super.dispose();
  }

  void _retry() => setState(() {
    _future = _load();
  });

  void _open(BookbagMaterial row) {
    if (_renderScope != null && !ApiClient.instance.isCurrentSessionScope(_renderScope!)) return;
    if (_renderScope == null && !widget.allowUnauthenticatedPreview) return;
    row.onOpen();
  }

  Future<void> _filter() async {
    final epoch = _epoch;
    final choice = await showModalBottomSheet<(BookbagMaterialKind?, bool)>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 520),
      backgroundColor: StudentDensityTokens.surface,
      barrierColor: StudentDensityTokens.dark.withValues(alpha: .46),
      shape: const RoundedRectangleBorder(),
      builder: (_) => _MaterialFilterSheet(kind: _kind, oldest: _oldest),
    );
    if (!mounted || choice == null || epoch != _epoch) return;
    setState(() {
      _kind = choice.$1;
      _oldest = choice.$2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    final padding = mobile
        ? 10.0
        : (MediaQuery.sizeOf(context).width * .03).clamp(18, 34).toDouble();
    return StudentHtmlShell(
      title: '내 자료 상세보기',
      activeRoute: mobile ? AppRoutes.bookbag : AppRoutes.learningTools,
      reserveContextTrack: MediaQuery.sizeOf(context).width > 1040,
      mobileBackButton: true,
      railWidth: MediaQuery.sizeOf(context).width > 1040 ? 84 : 72,
      onMenu: () => Navigator.of(context).maybePop(),
      child: FutureBuilder<List<BookbagMaterial>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(studentFacingApiError(
                      snapshot.error!,
                      fallback: '자료를 불러오지 못했습니다.',
                    )),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _retry, child: const Text('다시 시도')),
                    if (snapshot.error is ApiException &&
                        (snapshot.error as ApiException).statusCode == 401)
                      TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/login'),
                      child: const Text('로그인'),
                    ),
                  ],
                ),
              ),
            );
          final rows = List<BookbagMaterial>.of(snapshot.data ?? const [])
              .where(
                (row) =>
                    (_kind == null || row.kind == _kind) &&
                    '${row.title} ${row.detail}'.toLowerCase().contains(
                      _query.toLowerCase(),
                    ),
              )
              .toList();
          rows.sort((a, b) {
            if (a.addedAt == null && b.addedAt == null)
              return a.id.compareTo(b.id);
            if (a.addedAt == null) return 1;
            if (b.addedAt == null) return -1;
            final value = a.addedAt!.compareTo(b.addedAt!);
            return value == 0
                ? a.id.compareTo(b.id)
                : (_oldest ? value : -value);
          });
          return Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                Container(
                  key: const ValueKey('bookbag-material-toolbar'),
                  padding: EdgeInsets.all(mobile ? 10 : 14),
                  decoration: BoxDecoration(
                    color: StudentDensityTokens.surface,
                    border: Border.all(color: StudentDensityTokens.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: ValueKey('material-search-$_epoch'),
                          onChanged: (value) => setState(() => _query = value),
                          decoration: InputDecoration(
                            hintText: '자료명 검색',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            filled: true,
                            fillColor: StudentDensityTokens.surfaceMuted,
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: StudentDensityTokens.line,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: mobile ? 8 : 12),
                      OutlinedButton(
                        onPressed: _filter,
                        style: _buttonStyle(mobile ? 48 : 50),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_alt_outlined, size: 16),
                            const SizedBox(width: 6),
                            const Text('필터'),
                            if (_kind != null) const Text(' 1'),
                          ],
                        ),
                      ),
                      SizedBox(width: mobile ? 8 : 12),
                      Tooltip(
                        message: '자료 순서 저장 계약 검증 후 사용할 수 있습니다.',
                        child: OutlinedButton(
                          onPressed: null,
                          style: _buttonStyle(mobile ? 48 : 50),
                          child: const Text('순서 편집'),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: mobile ? 10 : 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      key: const ValueKey('bookbag-material-results'),
                      padding: EdgeInsets.fromLTRB(
                        mobile ? 10 : 18,
                        0,
                        mobile ? 10 : 18,
                        mobile ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: StudentDensityTokens.surface,
                        border: Border.all(color: StudentDensityTokens.line),
                      ),
                      child: Column(
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              minHeight: mobile ? 58 : 66,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: StudentDensityTokens.line,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '전체 자료',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Text(
                                  '${rows.length}개',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: StudentDensityTokens.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (rows.isEmpty)
                            SizedBox(
                              height: 220,
                              child: Center(
                                child: Text(
                                  (snapshot.data ?? []).isEmpty
                                      ? '보관된 자료가 없습니다.'
                                      : '조건에 맞는 자료가 없습니다.',
                                ),
                              ),
                            ),
                          for (final row in rows)
                            _MaterialRow(material: row, mobile: mobile, onOpen: () => _open(row)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

ButtonStyle _buttonStyle(double height) => OutlinedButton.styleFrom(
  minimumSize: Size(0, height),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  shape: const RoundedRectangleBorder(),
  foregroundColor: StudentDensityTokens.ink,
  textStyle: const TextStyle(
    fontFamily: 'Noto Sans KR',
    fontSize: 11,
    fontWeight: FontWeight.w900,
  ),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);
String _date(DateTime? value) =>
    value == null ? '—' : '${value.month}월 ${value.day}일';

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.material, required this.mobile, required this.onOpen});
  final BookbagMaterial material;
  final bool mobile;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final completed = material.status == '완료';
    final actionText = TextPainter(
      text: const TextSpan(text: '열기', style: TextStyle(
        fontFamily: 'Noto Sans KR', fontSize: 11, fontWeight: FontWeight.w900)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final openWidth = math.max(48.0, actionText.width + 24);
    actionText.dispose();
    final actionsWidth = openWidth + 6 + 48;
    final iconTrack = mobile ? 46.0 : 48.0;
    final gap = mobile ? 9.0 : 14.0;
    final dates = Row(
      children: [
        for (final date in [
          ('추가일', material.addedAt),
          ('완료일', material.completedAt),
        ]) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date.$1,
                  style: const TextStyle(
                    fontSize: 11,
                    color: StudentDensityTokens.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _date(date.$2),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (date.$1 == '추가일') const SizedBox(width: 8),
        ],
      ],
    );
    return Container(
      key: ValueKey('material-row-${material.id}'),
      constraints: const BoxConstraints(minHeight: 92),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: mobile ? 2 : 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: StudentDensityTokens.line)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final flexibleWidth = constraints.maxWidth - iconTrack - actionsWidth - gap * (mobile ? 2 : 3);
        // CSS minmax(210px, 1fr) / minmax(150px, .45fr).
        final dateWidth = math.max(150.0, flexibleWidth * .45 / 1.45);
        final copyWidth = mobile ? math.max(0.0, flexibleWidth) : math.max(210.0, flexibleWidth - dateWidth);
        return Column(
        children: [
          Row(
            children: [
              SizedBox(
                key: ValueKey('material-icon-track-${material.id}'),
                width: iconTrack,
                child: Align(alignment: Alignment.centerLeft, child: Container(
                width: mobile ? 44 : 46,
                height: mobile ? 50 : 52,
                decoration: BoxDecoration(
                  color: StudentDensityTokens.surfaceMuted,
                  border: Border.all(color: StudentDensityTokens.line),
                ),
                child: Icon(material.icon, size: 20),
              ))),
              SizedBox(width: mobile ? 9 : 14),
              SizedBox(
                key: ValueKey('material-copy-${material.id}'),
                width: copyWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(material.kindLabel, style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w900,
                          color: StudentDensityTokens.muted,
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                          decoration: BoxDecoration(
                            color: completed ? StudentDensityTokens.ink : StudentDensityTokens.surfaceMuted,
                            border: Border.all(color: completed ? StudentDensityTokens.ink : StudentDensityTokens.line),
                          ),
                          child: Text(material.status ?? '—', style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w900,
                            color: completed ? StudentDensityTokens.surface : StudentDensityTokens.ink,
                          )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      material.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      material.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: StudentDensityTokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!mobile) ...[
                const SizedBox(width: 14),
                SizedBox(key: ValueKey('material-dates-${material.id}'), width: dateWidth, child: dates),
              ],
              SizedBox(width: mobile ? 9 : 14),
              SizedBox(
                key: ValueKey('material-actions-${material.id}'),
                width: actionsWidth,
                child: Row(children: [
              SizedBox(width: openWidth, child: OutlinedButton(
                onPressed: onOpen,
                style: _buttonStyle(48),
                child: const Text('열기'),
              )),
              const SizedBox(width: 6),
              Tooltip(
                message: '자료 삭제 계약 검증 후 사용할 수 있습니다.',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.more_horiz),
                    tooltip: '자료 관리 준비 중',
                  ),
                ),
              ),
                ]),
              ),
            ],
          ),
          if (mobile) ...[
            const SizedBox(height: 9),
            Padding(
              key: ValueKey('material-mobile-date-span-${material.id}'),
              padding: EdgeInsets.only(left: iconTrack + gap),
              child: SizedBox(key: ValueKey('material-dates-${material.id}'), child: dates)),
          ],
        ],
      );}),
    );
  }
}

class _MaterialFilterSheet extends StatefulWidget {
  const _MaterialFilterSheet({required this.kind, required this.oldest});
  final BookbagMaterialKind? kind;
  final bool oldest;
  @override
  State<_MaterialFilterSheet> createState() => _MaterialFilterSheetState();
}

class _MaterialFilterSheetState extends State<_MaterialFilterSheet> {
  late BookbagMaterialKind? _kind = widget.kind;
  late bool _oldest = widget.oldest;
  void _close() => Navigator.of(context).pop();
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
    child: Focus(
      autofocus: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width <= 720 ? 14 : 18,
          0,
          MediaQuery.sizeOf(context).width <= 720 ? 14 : 18,
          18,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (MediaQuery.sizeOf(context).height - 24)
                .clamp(0, 620)
                .toDouble(),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    color: StudentDensityTokens.ink,
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '필터',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _close,
                        tooltip: '필터 닫기',
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 18),
                const Text(
                  '자료 유형',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final value in [null, ...BookbagMaterialKind.values])
                      Expanded(
                        child: _choice(
                          value == null
                              ? '전체'
                              : switch (value) {
                                  BookbagMaterialKind.textbook => '교재',
                                  BookbagMaterialKind.exam => '시험지',
                                  BookbagMaterialKind.bookmark => '북마크',
                                },
                          _kind == value,
                          () => setState(() => _kind = value),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),
                const Text(
                  '정렬',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _choice(
                        '최근 추가순',
                        !_oldest,
                        () => setState(() => _oldest = false),
                      ),
                    ),
                    Expanded(
                      child: _choice(
                        '오래된 추가순',
                        _oldest,
                        () => setState(() => _oldest = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: OutlinedButton(
                        style: _buttonStyle(50),
                        onPressed: () => setState(() {
                          _kind = null;
                          _oldest = false;
                        }),
                        child: const Text('초기화'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 13,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          backgroundColor: StudentDensityTokens.dark,
                          shape: const RoundedRectangleBorder(),
                          textStyle: const TextStyle(
                            fontFamily: 'Noto Sans KR',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: () =>
                            Navigator.of(context).pop((_kind, _oldest)),
                        child: const Text('적용'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _choice(String label, bool selected, VoidCallback onTap) => Semantics(
    selected: selected,
    child: TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: StudentDensityTokens.line),
        ),
        backgroundColor: selected
            ? StudentDensityTokens.dark
            : StudentDensityTokens.surface,
        foregroundColor: selected ? Colors.white : StudentDensityTokens.muted,
        textStyle: const TextStyle(
          fontFamily: 'Noto Sans KR',
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      onPressed: onTap,
      child: Text(label),
    ),
  );
}
