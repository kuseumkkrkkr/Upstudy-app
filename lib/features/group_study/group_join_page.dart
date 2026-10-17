import 'package:flutter/material.dart';
import 'package:s11/app/student_route_registry.dart';
import 'package:s11/features/group_study/group_find_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

class GroupJoinPage extends StatefulWidget {
  const GroupJoinPage({super.key, required this.inviteCode})
    : publicGroup = null;

  /// Uses the authenticated search summary only for display, not authorization.
  const GroupJoinPage.public({super.key, required StudyGroup group})
    : inviteCode = '',
      publicGroup = group;

  final String inviteCode;
  final StudyGroup? publicGroup;

  @override
  State<GroupJoinPage> createState() => _GroupJoinPageState();
}

class _GroupJoinPageState extends State<GroupJoinPage> {
  bool _isLoading = true;
  bool _isJoining = false;
  String? _error;
  StudyGroupInviteMeta? _meta;
  final _publicPassword = TextEditingController();
  String? _publicJoinError;
  bool _publicJoined = false;
  final _inviteInput = TextEditingController();
  int? _mineCount;
  String? _membershipError;

  @override
  void initState() {
    super.initState();
    _inviteInput.text = widget.inviteCode;
    if (widget.publicGroup == null) _loadMembership();
    if (widget.publicGroup == null && widget.inviteCode.trim().isNotEmpty) {
      _load();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _publicPassword.clear();
    _publicPassword.dispose();
    _inviteInput.dispose();
    super.dispose();
  }

  Future<void> _joinPublic() async {
    if (_isJoining || _publicJoined) return;
    final group = widget.publicGroup!;
    if (group.id.trim().isEmpty) {
      setState(() => _publicJoinError = '그룹 식별 정보를 확인하지 못했어요.');
      return;
    }
    final password = _publicPassword.text.trim();
    if (group.lockEnabled && password.isEmpty) {
      setState(() => _publicJoinError = '그룹 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      _isJoining = true;
      _publicJoinError = null;
    });
    try {
      // DTO flags/password never confer access. The server validates rights,
      // capacity and the user's entered password for this authenticated POST.
      await ApiClient.instance.joinStudyGroup(
        groupId: group.id,
        password: password.isEmpty ? null : password,
      );
      if (!mounted) return;
      setState(() => _publicJoined = true);
      Navigator.of(context).pushReplacementNamed(
        StudentRouteRegistry.byId('group-detail')!.route,
        arguments: group.id,
        result: true,
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _publicJoinError = studentFacingApiError(
          error,
          fallback: '그룹에 참여하지 못했어요.',
          notFound: '이 그룹을 찾지 못했어요.',
          unavailable: '그룹 참가 연결이 잠시 불안정해요. 잠시 후 다시 시도해 주세요.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _load() async {
    try {
      final meta = await ApiClient.instance.fetchStudyGroupInviteMeta(
        _inviteInput.text.trim().toUpperCase(),
      );
      if (meta.groupId.trim().isEmpty) throw const FormatException('Invalid invite metadata');
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = studentFacingApiError(e, fallback: '초대 정보를 확인하지 못했어요.', notFound: '초대 코드를 확인해 주세요.');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMembership() async {
    try {
      final mine = await ApiClient.instance.listStudyGroups();
      if (mounted) setState(() { _mineCount = mine.length; _membershipError = null; });
    } catch (error) {
      if (mounted) setState(() => _membershipError = studentFacingApiError(error, fallback: '내 그룹 정보를 확인하지 못했어요.'));
    }
  }

  Future<void> _lookupCode() async {
    if (_isLoading || _isJoining) return;
    final code = _inviteInput.text.trim().toUpperCase();
    if (_mineCount == null || _membershipError != null || _mineCount! >= 3 || !RegExp(r'^[A-Z0-9-]{4,20}$').hasMatch(code)) return;
    setState(() { _isLoading = true; _error = null; });
    await _load();
  }

  Future<void> _join() async {
    if (_isJoining) return;
    if (_mineCount == null || _membershipError != null || _mineCount! >= 3) return;
    final code = _inviteInput.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _error = '초대 코드를 확인해 주세요.');
      return;
    }
    final password = _publicPassword.text.trim();
    if (_meta?.lockEnabled == true && password.isEmpty) {
      setState(() => _error = '그룹 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() => _isJoining = true);
    try {
      final group = await ApiClient.instance.joinStudyGroupByInviteCode(
        inviteCode: code,
        password: _meta?.lockEnabled == true ? password : null,
      );
      if (group.id.trim().isEmpty) throw const FormatException('Invalid joined group');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${group.name}에 참여했어요')));
      Navigator.of(context).pushReplacementNamed(StudentRouteRegistry.byId('group-detail')!.route, arguments: group.id, result: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = studentFacingApiError(e, fallback: '그룹에 참여하지 못했어요.', notFound: '초대 코드를 확인해 주세요.'));
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  /// 필요한 변수는 현재 네비게이터 스택이다.
  /// 작동 원리는 초대 링크에서 진입했으면 이전 화면으로 돌아가고, 단독 경로면 실제 그룹 목록으로 복귀하는 것이다.
  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushNamedAndRemoveUntil('/groups', (route) => false);
  }

  /// 필요한 변수는 초대 메타 조회·참가 상태와 현재 화면 폭이다.
  /// 작동 원리는 모든 폭에서 같은 학생 셸을 유지하고, 참가 API의 로딩·실패·성공 흐름만 안쪽 카드에서 바꾸는 것이다.
  Widget _buildInviteBody(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 600;
    final meta = _meta;
    Widget row(String label, String value) => Container(constraints: const BoxConstraints(minHeight: 48), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDFE2E6)))), child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF666B73))), const SizedBox(width: 16), Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
    ]));
    return ColoredBox(color: compact ? Colors.white : const Color(0xFFF7F7F8), child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1040), child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(compact ? 14 : 28, compact ? 12 : 24, compact ? 14 : 28, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const GroupTaskHeading(title: '그룹 참여', description: '참여 전 그룹 정보를 확인하세요.'),
      if (_isLoading || _mineCount == null && _membershipError == null) const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
      else if (_membershipError != null || _error != null && meta == null) Semantics(liveRegion: true, child: Column(children: [Text(_membershipError ?? _error!), TextButton(onPressed: _membershipError != null ? _loadMembership : _load, child: const Text('다시 확인'))]))
      else if (_mineCount! >= 3) _codeLimit(context)
      else if (meta != null) Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: Container(key: const ValueKey('group-code-preview'), padding: EdgeInsets.all(compact ? 18 : 24), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFDFE2E6))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _codeSteps(confirmed: true), const SizedBox(height: 18),
        Row(children: [
          Container(width: 52, height: 52, alignment: Alignment.center, color: const Color(0xFFF4EBD3), child: Text(meta.name.isEmpty ? '?' : meta.name.substring(0,1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
          const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(meta.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(meta.description, style: const TextStyle(fontSize: 12, color: Color(0xFF666B73)))])),
        ]),
        const SizedBox(height: 18),
        row('구분', meta.isTeacherGroup == null ? '초대 코드 그룹' : meta.isTeacherGroup! ? '교사 그룹' : '학생 그룹'),
        row('인원', meta.members.toString() + ' / ' + meta.maxMembers.toString() + '명'),
        row('참여', meta.lockEnabled ? '비밀번호 필요' : '바로 참여'),
        if (meta.lockEnabled) ...[
          const SizedBox(height: 18), const Text('그룹 비밀번호', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const SizedBox(height: 8),
          TextField(key: const ValueKey('group-code-password'), controller: _publicPassword, obscureText: true, enabled: !_isJoining, maxLength: 10, keyboardType: TextInputType.number, decoration: const InputDecoration(counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.zero), contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Semantics(liveRegion: true, child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB42318))))),
        const SizedBox(height: 20),
        FilledButton(key: const ValueKey('group-code-confirm'), onPressed: _isJoining ? null : _join, style: FilledButton.styleFrom(minimumSize: const Size(0,54), shape: const RoundedRectangleBorder(), backgroundColor: const Color(0xFF111317), foregroundColor: Colors.white, textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0)), child: Text(_isJoining ? '참여 중…' : '참여하기 →')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _isJoining ? null : () => setState(() { _meta = null; _error = null; _publicPassword.clear(); }), style: OutlinedButton.styleFrom(minimumSize: const Size(0,50), shape: const RoundedRectangleBorder()), child: const Text('코드 다시 입력')),
      ])))),
    ])))));
  }

  Widget _codeSteps({required bool confirmed}) => Row(children: [
    for (var index=0;index<2;index++) ...[
      if (index>0) const SizedBox(width:8),
      Expanded(child: Container(height:34,alignment:Alignment.center,color:index==(confirmed?1:0)?const Color(0xFF111317):const Color(0xFFF3F4F6),child:Text(index==0?'1 코드 입력':'2 그룹 확인',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:index==(confirmed?1:0)?Colors.white:const Color(0xFF666B73))))),
    ],
  ]);

  Widget _codeLimit(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('현재 그룹을 3개 이용 중이에요.', style: TextStyle(fontSize:16,fontWeight:FontWeight.w700)),
    const SizedBox(height:6), const Text('새 그룹에 참여하려면 이용 중인 그룹 수를 먼저 줄여야 해요.',style:TextStyle(fontSize:12,color:Color(0xFF666B73))),
    TextButton(onPressed:_goBack,child:const Text('그룹으로 돌아가기')),
  ]);

  Widget _buildPublicBody(BuildContext context) {
    final group = widget.publicGroup!;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 600;
    Widget metaRow(String label, String value) => Container(
      key: ValueKey('group-public-meta-$label'),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDFE2E6))),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666B73)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    return ColoredBox(
      color: compact ? Colors.white : const Color(0xFFF7F7F8),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                groupSceneHorizontalPadding(width),
                groupSceneTopPadding(width),
                groupSceneHorizontalPadding(width),
                groupSceneBottomPadding(width),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GroupTaskHeading(
                    title: '그룹 참여',
                    description: '참여 전 그룹 정보를 확인하세요.',
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Container(
                        key: const ValueKey('group-public-join-preview'),
                        padding: compact
                            ? EdgeInsets.zero
                            : const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: compact
                              ? null
                              : Border.all(color: const Color(0xFFDFE2E6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3EAD1),
                                    border: Border.all(
                                      color: const Color(0xFFE8DBB8),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    group.name.isEmpty
                                        ? '그'
                                        : group.name.substring(0, 1),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF664A12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (group.description?.isNotEmpty == true)
                                        Text(
                                          group.description!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF666B73),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(height: 1, color: Color(0xFFDFE2E6)),
                            metaRow(
                              '구분',
                              group.isTeacherGroup ? '교사 그룹' : '학생 그룹',
                            ),
                            metaRow(
                              '인원',
                              '${group.memberCount} / ${group.maxMembers > 0 ? group.maxMembers : '—'}명',
                            ),
                            metaRow(
                              '참여',
                              group.lockEnabled ? '비밀번호 필요' : '바로 참여',
                            ),
                            const SizedBox(height: 20),
                            if (group.lockEnabled) ...[
                              const Text(
                                '그룹 비밀번호',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                key: const ValueKey(
                                  'group-public-join-password',
                                ),
                                controller: _publicPassword,
                                obscureText: true,
                                enabled: !_isJoining && !_publicJoined,
                                maxLength: 10,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '비밀번호 입력',
                                  counterText: '',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                            if (_publicJoinError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _publicJoinError!,
                                    key: const ValueKey(
                                      'group-public-join-error',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB42318),
                                    ),
                                  ),
                                ),
                              ),
                            FilledButton(
                              key: const ValueKey('group-public-join-submit'),
                              onPressed: _isJoining || _publicJoined
                                  ? null
                                  : _joinPublic,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 54),
                                visualDensity: VisualDensity.standard,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: const Color(0xFF111317),
                                foregroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(),
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge!
                                    .copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0,
                                    ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_isJoining ? '참여 중…' : '참여하기'),
                                  const SizedBox(width: 10),
                                  const StudentHtmlGlyph(
                                    icon: StudentHtmlIcon.arrow,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StudentHtmlShell(
      key: const ValueKey('group-join-screen'),
      title: '그룹 참여',
      activeRoute: '/groups',
      showContextAside: false,
      showHeaderActions: false,
      showBottomNavigation: MediaQuery.sizeOf(context).width > 600,
      mobileBackButton: true,
      onMenu: _goBack,
      onSearch: () => showStudentQuickSearch(context),
      onNotifications: () => showStudentNotifications(context),
      child: widget.publicGroup == null
          ? widget.inviteCode.trim().isEmpty && _meta == null ? _buildCodeBody(context) : _buildInviteBody(context)
          : _buildPublicBody(context),
    );
  }

  Widget _buildCodeBody(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 600;
    final ready = _mineCount != null && _membershipError == null && _mineCount! < 3 && !_isLoading && RegExp(r'^[A-Za-z0-9-]{4,20}$').hasMatch(_inviteInput.text.trim());
    final input = SizedBox(height: 54, child: TextField(key: const ValueKey('group-code-input'), controller: _inviteInput, enabled: !_isJoining && !_isLoading, textCapitalization: TextCapitalization.characters, maxLength: 20, onChanged: (_) => setState(() => _error = null), onSubmitted: (_) => _lookupCode(),
      style: const TextStyle(fontSize:18,fontWeight:FontWeight.w900,letterSpacing:2.16),
      decoration: const InputDecoration(hintText:'예: MATH24',counterText:'',border:OutlineInputBorder(borderRadius:BorderRadius.zero,borderSide:BorderSide(color:Color(0xFFCDD1D6))),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.zero,borderSide:BorderSide(color:Color(0xFFCDD1D6))),contentPadding:EdgeInsets.symmetric(horizontal:16,vertical:14)),
    ));
    final submit = SizedBox(height:54,child:FilledButton(key:const ValueKey('group-code-submit'),onPressed:ready?_lookupCode:null,style:FilledButton.styleFrom(minimumSize:const Size(0,54),padding:const EdgeInsets.symmetric(horizontal:6),shape:const RoundedRectangleBorder(),backgroundColor:const Color(0xFF111317),foregroundColor:Colors.white,disabledBackgroundColor:const Color(0xFFE4E6E9),disabledForegroundColor:const Color(0xFF989CA3),textStyle:Theme.of(context).textTheme.labelLarge!.copyWith(fontSize:14,fontWeight:FontWeight.w800,letterSpacing:0)),child:Text(_isLoading?'확인 중…':'그룹 확인')));
    return ColoredBox(color:compact?Colors.white:const Color(0xFFF7F7F8),child:Align(alignment:Alignment.topCenter,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1040),child:SingleChildScrollView(padding:EdgeInsets.fromLTRB(compact?14:28,compact?12:24,compact?14:28,24),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const GroupTaskHeading(title:'그룹 참여',description:'선생님에게 받은 초대 코드를 입력하세요.'),
      if(_mineCount!=null&&_mineCount!>=3) _codeLimit(context)
      else Align(alignment:Alignment.topCenter,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:680),child:Container(key:const ValueKey('group-code-entry-form'),padding:EdgeInsets.all(compact?0:24),decoration:BoxDecoration(color:Colors.white,border:compact?null:Border.all(color:const Color(0xFFDFE2E6))),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        _codeSteps(confirmed:false),const SizedBox(height:26),
        if(compact) ...[input,const SizedBox(height:8),submit]
        else Row(children:[Expanded(child:input),const SizedBox(width:8),SizedBox(width:88,child:submit)]),
        const SizedBox(height:10),
        const Text('영문·숫자·하이픈 4–20자리 · 대소문자 구분 없음',style:TextStyle(fontSize:11,color:Color(0xFF666B73),letterSpacing:0)),
        if(_membershipError!=null) ...[const SizedBox(height:10),Text(_membershipError!,style:const TextStyle(fontSize:12,color:Color(0xFFB42318))),TextButton(onPressed:_loadMembership,child:const Text('다시 확인'))],
        if(_error!=null) Padding(padding:const EdgeInsets.only(top:10),child:Semantics(liveRegion:true,child:Text(_error!,style:const TextStyle(fontSize:12,color:Color(0xFFB42318))))),
      ])))),
    ])))));
  }
}

class _InviteMetaPill extends StatelessWidget {
  const _InviteMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: StudentDensityTokens.surfaceMuted,
      border: Border.all(color: StudentDensityTokens.line),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: StudentDensityTokens.muted),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
