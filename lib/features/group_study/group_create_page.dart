import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:s11/app/student_route_registry.dart';
import 'package:s11/features/group_study/group_find_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

/// Independent HTML group-create form. Only the authenticated API creates data.
class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key, this.initialGroups});

  /// Null means membership is unverified, not zero groups.
  final List<StudyGroup>? initialGroups;

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _members = TextEditingController(text: '5');
  final _password = TextEditingController();
  List<StudyGroup>? _mine;
  bool _loading = false;
  bool _submitting = false;
  bool _completed = false;
  bool _settingsOpen = false;
  bool _public = true;
  bool _locked = false;
  String? _membershipError;
  String? _formError;

  bool get _atLimit => _mine != null && _mine!.length >= 3;
  bool get _canSubmit =>
      _mine != null &&
      !_loading &&
      _membershipError == null &&
      !_atLimit &&
      !_submitting &&
      !_completed;

  @override
  void initState() {
    super.initState();
    if (widget.initialGroups != null) {
      _mine = List.of(widget.initialGroups!);
    } else {
      _loadMine();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _members.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _membershipError = null;
    });
    try {
      final groups = await ApiClient.instance.listStudyGroups();
      if (mounted) setState(() => _mine = groups);
    } catch (error) {
      if (mounted) {
        setState(
          () => _membershipError = studentFacingApiError(
            error,
            fallback: '내 그룹 정보를 확인하지 못했어요.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Validate locally, then preserve server-authoritative access and persistence.
  Future<void> _submit() async {
    if (!_canSubmit) return;
    final name = _name.text.trim();
    final description = _description.text.trim();
    final members = int.tryParse(_members.text);
    final password = _password.text.trim();
    String? error;
    if (name.isEmpty || name.length > 40) {
      error = '그룹 이름을 1–40자로 입력해 주세요.';
    } else if (description.length > 120) {
      error = '소개는 최대 120자까지 입력할 수 있어요.';
    } else if (members == null || members < 2 || members > 100) {
      error = '최대 인원은 2–100명으로 입력해 주세요.';
    } else if (_locked && !RegExp(r'^[0-9]{4,10}$').hasMatch(password)) {
      error = '비밀번호는 4–10자리 숫자로 입력해 주세요.';
    }
    if (error != null) {
      setState(() {
        _formError = error;
        _settingsOpen = true;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      final group = await ApiClient.instance.createStudyGroup(
        name: name,
        description: description.isEmpty ? null : description,
        maxMembers: members,
        isPublic: _public,
        lockEnabled: _locked,
        password: _locked ? password : null,
      );
      if (!mounted) return;
      if (group.id.trim().isEmpty) {
        // An ambiguous write must not be presented as success or auto-retried.
        setState(() {
          _completed = true;
          _formError = '생성 결과를 확인하지 못했어요. 내 그룹에서 확인해 주세요.';
        });
        return;
      }
      _completed = true;
      Navigator.of(context).pushReplacementNamed(
        StudentRouteRegistry.byId('group-detail')!.route,
        arguments: group.id,
        result: true,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _formError = studentFacingApiError(
            error,
            fallback: '그룹을 만들지 못했어요.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(
        StudentRouteRegistry.byId('groups')!.route,
      );
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required String keyName,
    String? hint,
    int? maxLength,
    int lines = 1,
    bool numeric = false,
    String? note,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: MediaQuery.sizeOf(context).width <= 600 ? 12 : 13, fontWeight: MediaQuery.sizeOf(context).width <= 600 ? FontWeight.w700 : FontWeight.w800, letterSpacing: 0),
            ),
            if (note != null && lines == 1) ...[
              const SizedBox(width: 8),
              Text(
                note,
                style: const TextStyle(fontSize: 11, color: Color(0xFF666B73)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: ValueKey(keyName),
          controller: controller,
          enabled: !_submitting,
          maxLength: maxLength,
          maxLines: lines,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          inputFormatters: numeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          style: TextStyle(fontSize: MediaQuery.sizeOf(context).width <= 600 ? 14 : 16, height: MediaQuery.sizeOf(context).width <= 600 ? 1.5 : lines == 1 ? 1.75 : null, letterSpacing: 0),
          textAlignVertical: MediaQuery.sizeOf(context).width > 600 && lines == 1 ? TextAlignVertical.center : null,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFFCFD3D9)),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFFCFD3D9)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFF2458D6)),
            ),
            constraints: BoxConstraints(minHeight: lines > 1 && MediaQuery.sizeOf(context).width > 600 ? 80 : 52, maxHeight: lines > 1 && MediaQuery.sizeOf(context).width > 600 ? 80 : double.infinity),
          ),
        ),
        if (note != null && lines > 1) Padding(padding: const EdgeInsets.only(top: 5), child: Align(alignment: Alignment.centerRight, child: Text(note, style: const TextStyle(fontSize: 11, color: Color(0xFF666B73), letterSpacing: 0)))),
      ],
    ),
  );

  Widget _toggle(
    String label,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
    String keyName,
  ) => Container(
    constraints: const BoxConstraints(minHeight: 68),
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFE2E5E9))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Color(0xFF666B73),
                ),
              ),
            ],
          ),
        ),
        _HtmlGroupToggle(
          key: ValueKey(keyName),
          label: label,
          controlId: keyName,
          value: value,
          onChanged: _submitting ? null : onChanged,
        ),
      ],
    ),
  );

  Widget _form(bool compact) => Container(
    key: const ValueKey('group-create-form'),
    padding: compact ? EdgeInsets.zero : const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      border: compact ? null : Border.all(color: const Color(0xFFDFE2E6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          '그룹 이름',
          _name,
          keyName: 'group-create-name',
          hint: '예: 미적분 매일 한 문제',
          maxLength: 40,
          note: '필수',
        ),
        _field(
          '소개',
          _description,
          keyName: 'group-create-description',
          hint: '함께 공부할 내용을 알려주세요.',
          maxLength: 120,
          lines: 3,
          note: '최대 120자',
        ),
        Container(
          margin: EdgeInsets.only(top: compact ? 2 : 0, bottom: 18),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFDFE2E6)),
              bottom: BorderSide(color: Color(0xFFDFE2E6)),
            ),
          ),
          child: Column(
            children: [
              InkWell(
                key: const ValueKey('group-create-settings'),
                onTap: () => setState(() => _settingsOpen = !_settingsOpen),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 66),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '참여 설정',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '인원 · 검색 공개 · 비밀번호',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF666B73),
                              ),
                            ),
                          ],
                        ),
                      ),
                      RotatedBox(
                        quarterTurns: _settingsOpen ? 1 : 0,
                        child: const StudentHtmlGlyph(
                          icon: StudentHtmlIcon.arrow,
                          color: Color(0xFF111317),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_settingsOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Column(
                    children: [
                      _field(
                        '최대 인원',
                        _members,
                        keyName: 'group-create-members',
                        numeric: true,
                      ),
                      _toggle(
                        '검색에서 찾을 수 있음',
                        '공개 그룹 찾기에 표시돼요.',
                        _public,
                        (v) => setState(() => _public = v),
                        'group-create-public',
                      ),
                      _toggle(
                        '참여 비밀번호 사용',
                        '4–10자리 숫자로 잠글 수 있어요.',
                        _locked,
                        (v) => setState(() => _locked = v),
                        'group-create-locked',
                      ),
                      if (_locked)
                        _field(
                          '참여 비밀번호',
                          _password,
                          keyName: 'group-create-password',
                          numeric: true,
                          maxLength: 10,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_formError != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _formError!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB42318)),
              ),
            ),
          ),
        FilledButton(
          key: const ValueKey('group-create-submit'),
          onPressed: _canSubmit ? _submit : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 54),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: const Color(0xFF111317),
            shape: const RoundedRectangleBorder(),
            textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
              fontSize: compact ? 14 : 16,
              fontWeight: compact ? FontWeight.w800 : FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_submitting ? '그룹 만드는 중' : '그룹 만들기'),
              const SizedBox(width: 10),
              const StudentHtmlGlyph(
                icon: StudentHtmlIcon.arrow,
                size: 19,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 600;
    final count = _membershipError != null || _loading ? null : _mine?.length;
    return StudentHtmlShell(
      title: '그룹 만들기', activeRoute: '/groups', mobileBackButton: true, onMenu: _back,
      showHeaderActions: false, showBottomNavigation: !compact,
      child: ColoredBox(color: compact ? Colors.white : const Color(0xFFF7F7F8),
        child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1040),
          child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(groupSceneHorizontalPadding(width), groupSceneTopPadding(width), groupSceneHorizontalPadding(width), groupSceneBottomPadding(width)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              GroupTaskHeading(title: '그룹 만들기', description: count == null ? '현재 —/3개 · 내 그룹 정보를 확인해 주세요.' : '현재 ' + count.toString() + '/3개 · ' + (3-count).clamp(0,3).toString() + '개 더 이용할 수 있어요.'),
              if (_loading) const LinearProgressIndicator(),
              if (_membershipError != null) ...[
                Semantics(liveRegion: true, child: Text(_membershipError!, style: const TextStyle(color: Color(0xFFB42318),fontSize:12))),
                TextButton(onPressed:_loadMine,child:const Text('다시 시도')),
              ],
              if (_atLimit) ...[const Text('그룹은 최대 3개까지 이용할 수 있어요.'), TextButton(onPressed:_back,child:const Text('내 그룹 보기'))]
              else Align(alignment:Alignment.topCenter,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:680),child:_form(compact))),
            ]),
          ),
        )),
      ),
    );
  }
}

/// 두 참여 설정의 실제 bool callback을 공유한다. 트랙만 직각, 손잡이는 원형.
class _HtmlGroupToggle extends StatefulWidget {
  const _HtmlGroupToggle({super.key, required this.label, required this.controlId, required this.value, required this.onChanged});
  final String label, controlId;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  State<_HtmlGroupToggle> createState() => _HtmlGroupToggleState();
}

class _HtmlGroupToggleState extends State<_HtmlGroupToggle> {
  final _focus = FocusNode();
  bool _showFocus = false;
  void _activate() { if (widget.onChanged != null) { _focus.requestFocus(); widget.onChanged!(!widget.value); } }
  @override
  void dispose() { _focus.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Semantics(label: widget.label, toggled: widget.value, enabled: widget.onChanged != null, onTap: widget.onChanged == null ? null : _activate, child: FocusableActionDetector(
    focusNode: _focus, enabled: widget.onChanged != null,
    shortcuts: const {SingleActivator(LogicalKeyboardKey.space): ActivateIntent(), SingleActivator(LogicalKeyboardKey.enter): ActivateIntent()},
    actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { _activate(); return null; })},
    onShowFocusHighlight: (value) { if (mounted) setState(() => _showFocus = value); },
    child: GestureDetector(excludeFromSemantics: true, behavior: HitTestBehavior.opaque, onTap: widget.onChanged == null ? null : _activate, child: Container(width: 48, height: 48,
      decoration: BoxDecoration(border: _showFocus ? Border.all(color: const Color(0xFF2458D6)) : null),
      child: Center(child: SizedBox(key: ValueKey(widget.controlId + '-track'), width: 46, height: 26, child: ColoredBox(color: widget.value ? const Color(0xFF2458D6) : const Color(0xFFC9CDD3), child: Stack(children: [AnimatedPositioned(duration: const Duration(milliseconds: 160), curve: Curves.ease, left: widget.value ? 23 : 3, top: 3, child: Container(key: ValueKey(widget.controlId + '-thumb'), width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)))])))),
    )),
  ));
}
