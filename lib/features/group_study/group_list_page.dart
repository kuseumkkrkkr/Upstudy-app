import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key, this.initialGroups});

  final List<Object>? initialGroups;

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  List<StudyGroup> _groups = const [];
  List<StudyGroup> _discoverGroups = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialGroups = widget.initialGroups;
    if (initialGroups != null) {
      _groups = initialGroups.map(_coerceGroup).toList(growable: false);
      _discoverGroups = [
        StudyGroup(
          id: 'preview-geometry',
          name: '기하 집중반',
          description: '도형의 닮음과 피타고라스 문제를 매일 공유해요.',
          memberCount: 8,
          maxMembers: 12,
        ),
        StudyGroup(
          id: 'preview-probability',
          name: '확률 실전 스터디',
          description: '주 3회 시험지를 풀고 Flow로 풀이를 비교합니다.',
          memberCount: 11,
          maxMembers: 16,
        ),
        StudyGroup(
          id: 'preview-writing',
          name: '서술형 첨삭 모임',
          description: '풀이 과정 중심으로 서로의 Flow를 확인합니다.',
          memberCount: 6,
          maxMembers: 8,
          lockEnabled: true,
        ),
      ];
      _loading = false;
    } else {
      _load();
    }
  }

  /// 필요한 변수는 선택적 미리보기 그룹 객체다.
  /// 작동 원리는 과거 AcademyGroup 입력도 실제 소셜 StudyGroup 모델로 변환해 시안 캡처와 운영 경로를 함께 유지하는 것이다.
  StudyGroup _coerceGroup(Object value) {
    if (value is StudyGroup) return value;
    final group = value as AcademyGroup;
    return StudyGroup(
      id: group.groupId,
      name: group.name,
      description: group.subject,
      memberCount: group.maxMembers,
      maxMembers: group.maxMembers,
      isPublic: group.searchable,
    );
  }

  /// 필요한 변수는 인증 사용자와 소셜 그룹 API다.
  /// 작동 원리는 내 그룹 한 번만 조회하고 공개 그룹은 사용자가 검색할 때만 요청해 초기 DB 부하를 제한하는 것이다.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await ApiClient.instance.listStudyGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 필요한 변수는 HTML 그룹 생성 폼 값이다.
  /// 작동 원리는 실제 소셜 그룹 생성 API 성공 후 내 그룹 목록을 다시 조회하는 것이다.
  Future<void> _openCreateDialog() async {
    final form = await showDialog<_CreateGroupForm>(
      context: context,
      builder: (_) => const _CreateGroupDialog(),
    );
    if (form == null) return;

    try {
      await ApiClient.instance.createStudyGroup(
        name: form.name,
        description: form.description,
        maxMembers: form.maxMembers,
        password: form.password,
        isPublic: true,
        lockEnabled: form.password?.isNotEmpty == true,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
    }
  }

  /// 필요한 변수는 그룹 검색·초대 참가 API와 목록 갱신 콜백이다.
  /// 작동 원리는 HTML 그룹 찾기 시트에서 서버 검색과 코드 확인 후 참가를 실제로 수행하는 것이다.
  void _openFindSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _GroupFindSheet(onJoined: _load),
    );
  }

  /// 필요한 변수는 공개 그룹 검색어다.
  /// 작동 원리는 최소 한 글자 검색에서 최대 6개만 요청해 DISCOVER 카드 목록을 갱신하는 것이다.
  Future<void> _searchDiscover(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    try {
      final groups = await ApiClient.instance.searchStudyGroups(
        query: normalized,
        limit: 6,
      );
      if (!mounted) return;
      setState(() => _discoverGroups = groups);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공개 그룹을 검색하지 못했습니다.')));
    }
  }

  /// 필요한 변수는 내 그룹·공개 그룹 상태와 현재 화면 폭이다.
  /// 작동 원리는 모바일은 전폭 액션, PC는 HTML처럼 제목 오른쪽 액션과 52px 본문 여백을 적용하는 것이다.
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: Colors.black,
                showLevelIndicator: false,
                onMenu: () => toggleAppDrawer(context),
                onTitleTap: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainStudentPage()),
                  (route) => false,
                ),
                items: studentTopNavItems(
                  context,
                  active: StudentTopDestination.social,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 14 : 52,
                    compact ? 24 : 52,
                    compact ? 14 : 52,
                    40,
                  ),
                  children: [
                    if (compact) ...[
                      const _GroupListHeading(fontSize: 32),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _openFindSheet,
                        child: const Text('그룹 찾기 · 코드 참가'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF202022),
                        ),
                        onPressed: _openCreateDialog,
                        child: const Text('그룹 만들기'),
                      ),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Expanded(
                            child: _GroupListHeading(fontSize: 54),
                          ),
                          OutlinedButton(
                            onPressed: _openFindSheet,
                            child: const Text('그룹 찾기 · 코드 참가'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF202022),
                            ),
                            onPressed: _openCreateDialog,
                            child: const Text('그룹 만들기'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 22),
                    const Text(
                      'CONTINUE TOGETHER',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        color: Colors.black54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '내 그룹',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_error != null)
                      Center(child: Text(_error!))
                    else
                      _GroupListCard(groups: _groups),
                    const SizedBox(height: 16),
                    _InviteCodeCard(onJoined: _load),
                    const SizedBox(height: 28),
                    _GroupDiscoverSection(
                      groups: _discoverGroups,
                      onSearch: _searchDiscover,
                      onJoined: _load,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupListHeading extends StatelessWidget {
  const _GroupListHeading({required this.fontSize});

  final double fontSize;

  /// 필요한 변수는 반응형 제목 크기다.
  /// 작동 원리는 그룹 영문 표식·제목·설명을 HTML과 같은 간격으로 하나의 소개 블록에 묶는 것이다.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'GROUP STUDY',
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.7,
          color: Colors.black54,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '그룹 스터디',
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 6),
      const Text(
        '내 그룹의 새 학습과 대화를 먼저 확인하고, 필요할 때만 검색하거나 초대 코드로 참가하세요.',
        style: TextStyle(color: Colors.black45),
      ),
    ],
  );
}

class _GroupFindSheet extends StatefulWidget {
  const _GroupFindSheet({required this.onJoined});

  final Future<void> Function() onJoined;

  /// 필요한 변수는 가입 후 목록 갱신 콜백이다.
  /// 작동 원리는 서버 그룹 검색과 초대 코드 참가를 한 HTML 시트에서 관리하는 상태를 만든다.
  @override
  State<_GroupFindSheet> createState() => _GroupFindSheetState();
}

class _GroupFindSheetState extends State<_GroupFindSheet> {
  final TextEditingController _query = TextEditingController();
  final TextEditingController _invite = TextEditingController();
  final TextEditingController _password = TextEditingController();
  List<StudyGroup> _results = const [];
  bool _searching = false;
  bool _joining = false;

  /// 필요한 변수는 검색어·초대 코드·비밀번호 컨트롤러다.
  /// 작동 원리는 시트 종료 시 모든 텍스트와 민감 정보 리소스를 해제하는 것이다.
  @override
  void dispose() {
    _query.dispose();
    _invite.dispose();
    _password.dispose();
    super.dispose();
  }

  /// 필요한 변수는 그룹 검색어다.
  /// 작동 원리는 서버 검색 결과를 최대 10개만 받아 현재 시트 목록으로 교체하는 것이다.
  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty || _searching) return;
    setState(() => _searching = true);
    try {
      final results = await ApiClient.instance.searchStudyGroups(
        query: query,
        limit: 10,
      );
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('그룹을 검색하지 못했습니다: $error')));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// 필요한 변수는 초대 코드와 선택 비밀번호다.
  /// 작동 원리는 코드 메타를 먼저 확인하고 사용자 승인 뒤 참가 API와 목록 갱신을 순서대로 실행하는 것이다.
  Future<void> _joinByCode() async {
    final code = _invite.text.trim();
    if (code.isEmpty || _joining) return;
    setState(() => _joining = true);
    try {
      final meta = await ApiClient.instance.fetchStudyGroupInviteMeta(code);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(meta.name),
          content: Text(
            '${meta.description}\n\n${meta.members} / ${meta.maxMembers}명${meta.lockEnabled ? '\n비밀번호가 필요한 그룹입니다.' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('참가'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await ApiClient.instance.joinStudyGroupByInviteCode(
        inviteCode: code,
        password: _password.text.trim().isEmpty ? null : _password.text.trim(),
      );
      await widget.onJoined();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('그룹에 참가하지 못했습니다: $error')));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  /// 필요한 변수는 검색 결과와 코드 참가 상태다.
  /// 작동 원리는 HTML FIND STUDY GROUP처럼 검색·코드·비밀번호 필드와 결과 목록을 세로 배치하는 것이다.
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 720),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'FIND STUDY GROUP',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.7,
                color: Colors.black54,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '그룹 찾기',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _query,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: '그룹 이름 검색',
                suffixIcon: IconButton(
                  tooltip: '그룹 검색',
                  onPressed: _searching ? null : _search,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            for (final group in _results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(group.name),
                subtitle: Text(
                  '${group.description ?? '그룹 스터디'} · ${group.memberCount}/${group.maxMembers}명',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      await ApiClient.instance.joinStudyGroup(
                        groupId: group.id,
                        password: group.password,
                      );
                      await widget.onJoined();
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('참가 실패: $error')));
                    }
                  },
                  child: const Text('참가'),
                ),
              ),
            const Divider(height: 30),
            TextField(
              controller: _invite,
              decoration: const InputDecoration(labelText: '초대 코드'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호가 있는 경우'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF202022),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _joining ? null : _joinByCode,
              child: Text(_joining ? '확인 중…' : '코드 확인 후 참가'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GroupDiscoverSection extends StatefulWidget {
  const _GroupDiscoverSection({
    required this.groups,
    required this.onSearch,
    required this.onJoined,
  });

  final List<StudyGroup> groups;
  final Future<void> Function(String query) onSearch;
  final Future<void> Function() onJoined;

  /// 필요한 변수는 검색 결과와 검색·가입 콜백이다.
  /// 작동 원리는 HTML DISCOVER 섹션의 입력과 공개 그룹 카드를 관리하는 상태를 만든다.
  @override
  State<_GroupDiscoverSection> createState() => _GroupDiscoverSectionState();
}

class _GroupDiscoverSectionState extends State<_GroupDiscoverSection> {
  final TextEditingController _controller = TextEditingController();
  bool _searching = false;
  String? _joiningId;

  /// 필요한 변수는 검색 입력 컨트롤러다.
  /// 작동 원리는 화면 종료 시 텍스트 리소스를 해제하는 것이다.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 필요한 변수는 검색어와 상위 서버 검색 콜백이다.
  /// 작동 원리는 중복 요청을 막고 완료 후 입력 상태만 한 번 갱신하는 것이다.
  Future<void> _search() async {
    if (_searching || _controller.text.trim().isEmpty) return;
    setState(() => _searching = true);
    await widget.onSearch(_controller.text);
    if (mounted) setState(() => _searching = false);
  }

  /// 필요한 변수는 선택 공개 그룹 ID와 선택 비밀번호다.
  /// 작동 원리는 실제 가입 API 성공 후 내 그룹 목록을 갱신하고 실패는 현재 화면에 알린다.
  Future<void> _join(StudyGroup group) async {
    if (_joiningId != null) return;
    setState(() => _joiningId = group.id);
    try {
      await ApiClient.instance.joinStudyGroup(
        groupId: group.id,
        password: group.password,
      );
      await widget.onJoined();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${group.name}에 참가했습니다.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('그룹에 참가하지 못했습니다: $error')));
    } finally {
      if (mounted) setState(() => _joiningId = null);
    }
  }

  /// 필요한 변수는 공개 그룹 결과와 검색·가입 상태다.
  /// 작동 원리는 HTML처럼 섹션 제목, 인라인 검색, 3개 카드 순으로 렌더링하는 것이다.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'DISCOVER',
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.7,
          color: Colors.black54,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '공개 그룹 찾기',
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 5),
      const Text(
        '이름으로 검색하고 공개 또는 비밀번호 그룹에 참가할 수 있습니다.',
        style: TextStyle(color: Colors.black45),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(hintText: '그룹 이름 검색'),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF202022),
            ),
            onPressed: _searching ? null : _search,
            child: Text(_searching ? '검색 중…' : '검색'),
          ),
        ],
      ),
      const SizedBox(height: 14),
      for (final group in widget.groups.take(6))
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE0E0E2)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  group.name.isEmpty ? 'G' : group.name.substring(0, 1),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      group.description ?? '함께 공부하는 공개 그룹',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${group.memberCount} / ${group.maxMembers}명${group.lockEnabled ? ' · 비밀번호' : ''}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _joiningId == null ? () => _join(group) : null,
                child: Text(_joiningId == group.id ? '참가 중…' : '참가'),
              ),
            ],
          ),
        ),
      if (widget.groups.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('검색어를 입력해 공개 그룹을 찾아보세요.')),
        ),
    ],
  );
}

class _GroupListCard extends StatelessWidget {
  const _GroupListCard({required this.groups});
  final List<StudyGroup> groups;

  /// 필요한 변수는 현재 사용자의 그룹 목록이다.
  /// 작동 원리는 최근 활동순 캡슐과 그룹 메타 행을 시안처럼 구분선 목록으로 렌더링하는 것이다.
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: compact ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xFFDEDEE1)),
            ),
            child: const Text(
              '최근 활동순',
              style: TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < groups.length; index++)
          _GroupRow(group: groups[index], index: index),
      ],
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.index});
  final StudyGroup group;
  final int index;

  /// 필요한 변수는 그룹 정보와 목록 위치다.
  /// 작동 원리는 그룹 문자 배지·소개·멤버 메타를 한 행에 배치하고 기존 상세 라우트로 연결하는 것이다.
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () =>
        Navigator.pushNamed(context, '/group/detail', arguments: group.groupId),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDEDEE1))),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index == 0
                  ? const Color(0xFF202022)
                  : const Color(0xFFE8E8EB),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              group.name.isEmpty ? 'G' : group.name.substring(0, 1),
              style: TextStyle(
                color: index == 0 ? Colors.white : Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  group.description ?? '함께 공부하는 그룹',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                if (MediaQuery.sizeOf(context).width < 720) ...[
                  const SizedBox(height: 7),
                  Text(
                    '${group.memberCount} / ${group.maxMembers == 0 ? '—' : group.maxMembers}명 · ${group.isPublic ? '공개' : '비공개'}',
                    style: const TextStyle(fontSize: 9, color: Colors.black38),
                  ),
                ],
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 720) ...[
            _GroupMetaBadge(
              '${group.memberCount} / ${group.maxMembers == 0 ? '—' : group.maxMembers}명',
            ),
            const SizedBox(width: 8),
            _GroupMetaBadge(group.isPublic ? '공개' : '비공개'),
            if (group.lockEnabled) ...[
              const SizedBox(width: 8),
              const _GroupMetaBadge('잠금 활동'),
            ],
            const SizedBox(width: 12),
          ],
          if (index == 0)
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF202022),
                shape: BoxShape.circle,
              ),
              child: const Text(
                '5',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            const Icon(Icons.chevron_right, color: Colors.black38),
        ],
      ),
    ),
  );
}

class _GroupMetaBadge extends StatelessWidget {
  const _GroupMetaBadge(this.label);

  final String label;

  /// 필요한 변수는 그룹 인원·공개·잠금 상태 레이블이다.
  /// 작동 원리는 PC 그룹 행의 우측 메타를 HTML과 같은 작은 흰 캡슐로 분리하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 8, color: Colors.black54),
    ),
  );
}

class _InviteCodeCard extends StatefulWidget {
  const _InviteCodeCard({required this.onJoined});

  final Future<void> Function() onJoined;

  @override
  State<_InviteCodeCard> createState() => _InviteCodeCardState();
}

class _InviteCodeCardState extends State<_InviteCodeCard> {
  final TextEditingController _controller = TextEditingController();
  bool _checking = false;

  /// 필요한 변수는 초대 코드 입력 컨트롤러다.
  /// 작동 원리는 카드 종료 시 텍스트 리소스를 해제하는 것이다.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 필요한 변수는 입력 초대 코드와 선택 비밀번호다.
  /// 작동 원리는 서버에서 그룹 메타를 먼저 확인해 사용자에게 보여준 뒤 확인 시 실제 코드 참가 API를 호출하는 것이다.
  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _checking) {
      if (code.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('초대 코드를 입력하세요.')));
      }
      return;
    }
    setState(() => _checking = true);
    try {
      final meta = await ApiClient.instance.fetchStudyGroupInviteMeta(code);
      if (!mounted) return;
      final password = await showDialog<String>(
        context: context,
        builder: (_) => _InviteConfirmDialog(meta: meta),
      );
      if (password == null || !mounted) return;
      await ApiClient.instance.joinStudyGroupByInviteCode(
        inviteCode: code,
        password: password.isEmpty ? null : password,
      );
      await widget.onJoined();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${meta.name}에 참가했습니다.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('초대 코드를 확인하지 못했습니다: $error')));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// 필요한 변수는 초대 코드 입력과 확인 동작이다.
  /// 작동 원리는 HTML의 INVITE CODE 카드와 우측 검은 확인 버튼을 같은 높이로 배치하는 것이다.
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text(
          'INVITE CODE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.6,
            color: Colors.black54,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '초대받은 그룹이 있나요?',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 6),
        Text(
          '코드를 확인하면 그룹명·설명·인원을 먼저 보여줍니다.',
          style: TextStyle(fontSize: 11, color: Colors.black45),
        ),
      ],
    );
    final codeField = Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'AF-24K8'),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF202022),
          ),
          onPressed: _checking ? null : _verify,
          child: Text(_checking ? '확인 중…' : '코드 확인'),
        ),
      ],
    );
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E0E2)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 20), codeField],
            )
          : Row(
              children: [
                Expanded(flex: 5, child: copy),
                const SizedBox(width: 36),
                Expanded(flex: 7, child: codeField),
              ],
            ),
    );
  }
}

class _InviteConfirmDialog extends StatefulWidget {
  const _InviteConfirmDialog({required this.meta});

  final StudyGroupInviteMeta meta;

  /// 필요한 변수는 초대 메타다.
  /// 작동 원리는 비밀번호 필요 여부에 따라 참가 확인 폼 상태를 만든다.
  @override
  State<_InviteConfirmDialog> createState() => _InviteConfirmDialogState();
}

class _InviteConfirmDialogState extends State<_InviteConfirmDialog> {
  final TextEditingController _password = TextEditingController();

  /// 필요한 변수는 비밀번호 입력 컨트롤러다.
  /// 작동 원리는 다이얼로그 종료 시 민감한 입력 리소스를 즉시 해제하는 것이다.
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  /// 필요한 변수는 그룹 초대 메타와 비밀번호 입력이다.
  /// 작동 원리는 서버 참가 전 그룹명·설명·현재 인원을 HTML 확인 모달처럼 표시하는 것이다.
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.meta.name),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.meta.description),
        const SizedBox(height: 10),
        Text('${widget.meta.members} / ${widget.meta.maxMembers}명'),
        if (widget.meta.lockEnabled) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '그룹 비밀번호'),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_password.text.trim()),
        child: const Text('참가'),
      ),
    ],
  );
}

class _CreateGroupForm {
  final String name;
  final String? description;
  final int maxMembers;
  final String? password;

  const _CreateGroupForm({
    required this.name,
    required this.maxMembers,
    this.description,
    this.password,
  });
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _maxMembers = TextEditingController(text: '12');
  final _password = TextEditingController();

  /// 필요한 변수는 그룹명·설명·정원·비밀번호 입력 컨트롤러다.
  /// 작동 원리는 다이얼로그 종료 시 모든 텍스트 리소스를 해제하는 것이다.
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _maxMembers.dispose();
    _password.dispose();
    super.dispose();
  }

  /// 필요한 변수는 HTML 그룹 생성 입력과 검증 상태다.
  /// 작동 원리는 이름·설명·최대 인원·선택 숫자 비밀번호를 한 모달에서 수집해 상위 API 호출로 반환하는 것이다.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('그룹 만들기'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '그룹 이름'),
            ),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '설명'),
            ),
            TextField(
              controller: _maxMembers,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '최대 인원'),
            ),
            TextField(
              controller: _password,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '숫자 비밀번호 4~10자리 · 선택',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final maxMembers = int.tryParse(_maxMembers.text.trim());
            final password = _password.text.trim();
            if (_name.text.trim().isEmpty ||
                maxMembers == null ||
                maxMembers < 2 ||
                maxMembers > 100 ||
                (password.isNotEmpty &&
                    (password.length < 4 ||
                        password.length > 10 ||
                        int.tryParse(password) == null))) {
              return;
            }
            Navigator.pop(
              context,
              _CreateGroupForm(
                name: _name.text.trim(),
                maxMembers: maxMembers,
                description: _description.text.trim().isEmpty
                    ? null
                    : _description.text.trim(),
                password: password.isEmpty ? null : password,
              ),
            );
          },
          child: const Text('그룹 만들기'),
        ),
      ],
    );
  }
}
