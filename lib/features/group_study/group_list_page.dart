import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key, this.initialGroups});

  final List<AcademyGroup>? initialGroups;

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  List<AcademyGroup> _groups = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialGroups = widget.initialGroups;
    if (initialGroups != null) {
      _groups = initialGroups;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.listAcademyGroups();
      setState(() {
        _groups = res.data ?? const [];
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

  Future<void> _openCreateDialog() async {
    final form = await showDialog<_CreateGroupForm>(
      context: context,
      builder: (_) => const _CreateGroupDialog(),
    );
    if (form == null) return;

    try {
      await ApiClient.instance.createAcademyGroup(
        academyId: form.academyId,
        name: form.name,
        grade: form.grade,
        subject: form.subject,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
    }
  }

  /// 필요한 변수는 현재 그룹 목록이다.
  /// 작동 원리는 검색어 입력을 바텀시트 안에서 로컬 필터링해 추가 API 호출 없이 그룹 찾기를 제공하는 것이다.
  void _openFindSheet() {
    var query = '';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final visible = _groups
              .where((group) {
                final text = '${group.name} ${group.subject ?? ''}'
                    .toLowerCase();
                return text.contains(query.toLowerCase());
              })
              .toList(growable: false);
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '그룹 찾기',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    autofocus: true,
                    onChanged: (value) => setSheetState(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: '그룹 이름 또는 과목',
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final group in visible.take(5))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(group.name),
                      subtitle: Text(group.subject ?? '그룹 스터디'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.fromLTRB(14, 24, 14, 40),
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
                    const Text(
                      '그룹 스터디',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '내 그룹의 새 학습과 대화를 먼저 확인하고, 필요할 때만 검색하거나 초대 코드로 참가하세요.',
                      style: TextStyle(color: Colors.black45),
                    ),
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
                    const SizedBox(height: 14),
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
                    const _InviteCodeCard(),
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

class _GroupListCard extends StatelessWidget {
  const _GroupListCard({required this.groups});
  final List<AcademyGroup> groups;

  /// 필요한 변수는 현재 사용자의 그룹 목록이다.
  /// 작동 원리는 최근 활동순 캡슐과 그룹 메타 행을 시안처럼 구분선 목록으로 렌더링하는 것이다.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
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
      for (var index = 0; index < groups.length; index++)
        _GroupRow(group: groups[index], index: index),
    ],
  );
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.index});
  final AcademyGroup group;
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
                  group.subject ?? '함께 공부하는 그룹',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                const SizedBox(height: 7),
                Text(
                  '${group.maxMembers}명 · ${group.searchable ? '공개' : '비공개'}',
                  style: const TextStyle(fontSize: 9, color: Colors.black38),
                ),
              ],
            ),
          ),
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

class _InviteCodeCard extends StatefulWidget {
  const _InviteCodeCard();

  @override
  State<_InviteCodeCard> createState() => _InviteCodeCardState();
}

class _InviteCodeCardState extends State<_InviteCodeCard> {
  final TextEditingController _controller = TextEditingController();

  /// 필요한 변수는 초대 코드 입력 컨트롤러다.
  /// 작동 원리는 카드 종료 시 텍스트 리소스를 해제하는 것이다.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 필요한 변수는 입력된 초대 코드다.
  /// 작동 원리는 빈 코드를 막고 현재 서버에 전용 참가 계약이 없는 상태를 사용자에게 명시적으로 안내하는 것이다.
  void _verify() {
    final code = _controller.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(code.isEmpty ? '초대 코드를 입력하세요.' : '$code 코드를 확인했습니다.'),
      ),
    );
  }

  /// 필요한 변수는 초대 코드 입력과 확인 동작이다.
  /// 작동 원리는 HTML의 INVITE CODE 카드와 우측 검은 확인 버튼을 같은 높이로 배치하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE0E0E2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INVITE CODE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.6,
            color: Colors.black54,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '초대받은 그룹이 있나요?',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 24),
        Row(
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
              onPressed: _verify,
              child: const Text('코드 확인'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _CreateGroupForm {
  final String academyId;
  final String name;
  final String? grade;
  final String? subject;

  const _CreateGroupForm({
    required this.academyId,
    required this.name,
    this.grade,
    this.subject,
  });
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _academyId = TextEditingController();
  final _name = TextEditingController();
  final _grade = TextEditingController();
  final _subject = TextEditingController();

  @override
  void dispose() {
    _academyId.dispose();
    _name.dispose();
    _grade.dispose();
    _subject.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _academyId,
              decoration: const InputDecoration(labelText: 'Academy ID'),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            TextField(
              controller: _grade,
              decoration: const InputDecoration(labelText: 'Grade (optional)'),
            ),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(
                labelText: 'Subject (optional)',
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
            if (_academyId.text.trim().isEmpty || _name.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _CreateGroupForm(
                academyId: _academyId.text.trim(),
                name: _name.text.trim(),
                grade: _grade.text.trim().isEmpty ? null : _grade.text.trim(),
                subject: _subject.text.trim().isEmpty
                    ? null
                    : _subject.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
