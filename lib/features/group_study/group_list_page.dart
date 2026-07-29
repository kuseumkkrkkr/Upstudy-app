import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key, this.initialGroups});

  final List<Object>? initialGroups;

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  List<StudyGroup> _groups = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialGroups = widget.initialGroups;
    if (initialGroups != null) {
      _groups = initialGroups.map(_coerceGroup).toList(growable: false);
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
      if (!mounted) return;
      setState(() {
        _error = studentFacingApiError(
          e,
          fallback: '그룹을 불러오지 못했어요.',
          unavailable: '그룹 연결이 잠시 불안정해요. 잠시 후 다시 시도해 주세요.',
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            studentFacingApiError(
              e,
              fallback: '그룹을 만들지 못했어요.',
              unavailable: '그룹 생성 연결이 잠시 불안정해요. 잠시 후 다시 시도해 주세요.',
            ),
          ),
        ),
      );
    }
  }

  /// 필요한 변수는 그룹 검색·초대 참가 API와 목록 갱신 콜백이다.
  /// 작동 원리는 독립 모달에서 서버 검색과 코드 확인 후 참가를 실제로 수행하는 것이다.
  void _openFindSheet() {
    showDialog<void>(
      context: context,
      builder: (_) => _GroupFindDialog(onJoined: _load),
    );
  }

  /// 필요한 변수는 내 그룹 상태와 현재 화면 폭이다.
  /// 작동 원리는 780px 이하에서는 전폭 세로 흐름을, PC에서는 제한된 본문 폭 안의 헤더·목록 카드를 사용한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      drawer: mobile ? null : const AppDrawer(),
      bottomNavigationBar: mobile
          ? const MobileStudentBottomAppBar(activeRoute: '/groups')
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: Colors.black,
                showLevelIndicator: false,
                showUtilityActions: !mobile,
                onMenu: mobile ? null : () => toggleAppDrawer(context),
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    StudentDensityPage(
                      padding: EdgeInsets.fromLTRB(
                        studentDensityHorizontalPadding(context),
                        studentDensityVerticalPadding(context),
                        studentDensityHorizontalPadding(context),
                        48,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (mobile) ...[
                            const _GroupListHeading(
                              fontSize: 32,
                              compact: true,
                            ),
                            const SizedBox(height: 16),
                            _MobileGroupActions(
                              onFind: _openFindSheet,
                              onCreate: _openCreateDialog,
                            ),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Expanded(
                                  child: _GroupListHeading(fontSize: 54),
                                ),
                                StudentDensityButton(
                                  onPressed: _openFindSheet,
                                  label: '그룹 찾기 · 코드 참가',
                                ),
                                const SizedBox(width: 8),
                                StudentDensityButton(
                                  onPressed: _openCreateDialog,
                                  label: '그룹 만들기',
                                  primary: true,
                                ),
                              ],
                            ),
                          SizedBox(height: mobile ? 26 : 22),
                          if (!mobile) ...[
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
                          ],
                          const Text(
                            '내 그룹',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_loading)
                            const Center(child: CircularProgressIndicator())
                          else if (_error != null)
                            _GroupLoadError(message: _error!, onRetry: _load)
                          else
                            _GroupListCard(groups: _groups),
                        ],
                      ),
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
  const _GroupListHeading({required this.fontSize, this.compact = false});

  final double fontSize;
  final bool compact;

  /// 필요한 변수는 반응형 제목 크기와 모바일 축약 여부다.
  /// 작동 원리: 모바일은 영문 표식과 설명을 숨겨 기능명만 남기고 PC는 기존 안내를 유지한다.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!compact) ...[
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
      ],
      Text(
        '그룹 스터디',
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900),
      ),
      if (!compact) ...[
        const SizedBox(height: 6),
        const Text(
          '내 그룹의 새 학습과 대화를 먼저 확인하고, 필요할 때만 검색하거나 초대 코드로 참가하세요.',
          style: TextStyle(color: Colors.black45),
        ),
      ],
    ],
  );
}

/// 필요한 변수: 그룹 찾기·만들기 콜백이다.
/// 작동 원리: 모바일의 두 핵심 행동을 한 개의 무테 컨테이너 안에 큰 버튼으로 나란히 배치한다.
class _MobileGroupActions extends StatelessWidget {
  const _MobileGroupActions({required this.onFind, required this.onCreate});

  final VoidCallback onFind;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('group-mobile-actions'),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: TextButton.icon(
              onPressed: onFind,
              icon: const Icon(Icons.key_rounded, size: 19),
              label: const Text('코드로 참여'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF202022),
                backgroundColor: const Color(0xFFF4F4F6),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('그룹 만들기'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF202022),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _GroupFindDialog extends StatefulWidget {
  const _GroupFindDialog({required this.onJoined});

  final Future<void> Function() onJoined;

  /// 필요한 변수는 가입 후 목록 갱신 콜백이다.
  /// 작동 원리는 서버 그룹 검색과 초대 코드 참가를 하나의 독립 모달 상태로 관리하는 것이다.
  @override
  State<_GroupFindDialog> createState() => _GroupFindDialogState();
}

class _GroupFindDialogState extends State<_GroupFindDialog> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            studentFacingApiError(
              error,
              fallback: '그룹을 검색하지 못했어요.',
              unavailable: '그룹 검색 연결이 잠시 불안정해요. 잠시 후 다시 시도해 주세요.',
            ),
          ),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            studentFacingApiError(
              error,
              fallback: '그룹에 참가하지 못했어요.',
              notFound: '초대 코드를 찾지 못했어요. 코드를 다시 확인해 주세요.',
              unavailable: '그룹 참가 연결이 잠시 불안정해요. 잠시 후 다시 시도해 주세요.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  /// 필요한 변수는 검색 결과와 코드 참가 상태다.
  /// 작동 원리는 검색과 초대 코드 참가를 구획으로 나눈 고정 폭 모달에 배치해 빈 메인 화면을 유지하는 것이다.
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FIND STUDY GROUP',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.7,
                          color: Colors.black54,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        '그룹 찾기',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '이름으로 공개 그룹을 찾거나 초대 코드로 바로 참가하세요.',
              style: TextStyle(color: Colors.black45),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _query,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: '그룹 이름',
                hintText: '예: 중등 수학',
                suffixIcon: IconButton(
                  tooltip: '그룹 검색',
                  onPressed: _searching ? null : _search,
                  icon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                ),
              ),
            ),
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final group in _results)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${group.description ?? '그룹 스터디'} · ${group.memberCount}/${group.maxMembers}명',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                studentFacingApiError(
                                  error,
                                  fallback: '그룹에 참가하지 못했어요.',
                                  notFound: '이 그룹을 찾지 못했어요.',
                                  unavailable:
                                      '그룹 참가 연결이 잠시 불안정해요. 잠시 후 다시 시도해 주세요.',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('참가'),
                    ),
                  ),
                ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Divider(height: 1),
            ),
            const Text(
              '초대 코드로 참가',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _invite,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: '초대 코드',
                hintText: 'AF-24K8',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                hintText: '비밀번호가 있는 경우에만 입력',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF202022),
                minimumSize: const Size.fromHeight(50),
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

class _GroupListCard extends StatelessWidget {
  const _GroupListCard({required this.groups});
  final List<StudyGroup> groups;

  /// 필요한 변수는 현재 사용자의 그룹 목록이다.
  /// 작동 원리는 소속 그룹이 없으면 안내 문구만 표시하고, 있을 때만 정렬 표식과 그룹 행을 렌더링하는 것이다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    if (groups.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 6 : 28,
          vertical: mobile ? 24 : 28,
        ),
        child: const Text(
          '참여 중인 그룹이 없어요.\n그룹 찾기나 초대 코드로 시작해 보세요.',
          style: TextStyle(fontSize: 14, color: Colors.black45, height: 1.55),
        ),
      );
    }
    return StudentDensitySurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Container(
                width: mobile ? double.infinity : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
          ),
          for (var index = 0; index < groups.length; index++)
            _GroupRow(group: groups[index], index: index),
        ],
      ),
    );
  }
}

class _GroupLoadError extends StatelessWidget {
  const _GroupLoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  /// 필요한 변수는 학생용 오류 문구와 재조회 콜백이다.
  /// 작동 원리: 모바일은 짧은 고정 안내와 무테 표면을 사용하고 PC는 상세 오류 문구를 유지한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.cloud_off_rounded, size: 34, color: Colors.black54),
        const SizedBox(height: 12),
        Text(
          mobile ? '그룹을 불러오지 못했어요' : message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        if (mobile) ...[
          const SizedBox(height: 5),
          const Text(
            '연결을 확인하고 다시 시도해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 14, height: 1.4),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF202022),
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text('다시 불러오기'),
        ),
      ],
    );
    if (mobile) {
      return Container(
        key: const ValueKey('group-mobile-load-error'),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: content,
      );
    }
    return StudentDensitySurface(
      padding: const EdgeInsets.all(24),
      child: content,
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
      padding: EdgeInsets.symmetric(
        vertical: isStudentDensityMobile(context) ? 15 : 21,
        horizontal: isStudentDensityMobile(context) ? 18 : 24,
      ),
      decoration: BoxDecoration(
        border: isStudentDensityMobile(context)
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFDEDEE1))),
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
                if (isStudentDensityMobile(context)) ...[
                  const SizedBox(height: 7),
                  Text(
                    '${group.memberCount} / ${group.maxMembers == 0 ? '—' : group.maxMembers}명 · ${group.isPublic ? '공개' : '비공개'}',
                    style: const TextStyle(fontSize: 9, color: Colors.black38),
                  ),
                ],
              ],
            ),
          ),
          if (!isStudentDensityMobile(context)) ...[
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
  String? _validationMessage;

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

  /// 필요한 변수는 그룹 생성 입력과 검증 메시지 상태다.
  /// 작동 원리는 각 입력의 역할과 제약을 분명히 나누고, 유효한 값만 상위 API 호출용 폼으로 반환하는 것이다.
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEW STUDY GROUP',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.7,
                              color: Colors.black54,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            '그룹 만들기',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '함께 공부할 사람을 위한 그룹 정보를 입력하세요.',
                  style: TextStyle(color: Colors.black45),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '그룹 이름',
                    hintText: '예: 매일 수학 한 문제',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 4,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '그룹 소개',
                    hintText: '어떤 공부를 함께 할지 알려주세요. (선택)',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _maxMembers,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '최대 인원',
                    helperText: '2명부터 100명까지 설정할 수 있어요.',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    hintText: '숫자 4~10자리 (선택)',
                    helperText: '입력하면 비밀번호가 있는 비공개 참가 그룹이 됩니다.',
                  ),
                ),
                if (_validationMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _validationMessage!,
                    style: const TextStyle(
                      color: Color(0xFFB3261E),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF202022),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () {
                          final maxMembers = int.tryParse(
                            _maxMembers.text.trim(),
                          );
                          final password = _password.text.trim();
                          String? message;
                          if (_name.text.trim().isEmpty) {
                            message = '그룹 이름을 입력하세요.';
                          } else if (maxMembers == null ||
                              maxMembers < 2 ||
                              maxMembers > 100) {
                            message = '최대 인원은 2명에서 100명 사이로 입력하세요.';
                          } else if (password.isNotEmpty &&
                              (password.length < 4 ||
                                  password.length > 10 ||
                                  int.tryParse(password) == null)) {
                            message = '비밀번호는 숫자 4~10자리로 입력하세요.';
                          }
                          if (message != null) {
                            setState(() => _validationMessage = message);
                            return;
                          }
                          Navigator.of(context).pop(
                            _CreateGroupForm(
                              name: _name.text.trim(),
                              maxMembers: maxMembers!,
                              description: _description.text.trim().isEmpty
                                  ? null
                                  : _description.text.trim(),
                              password: password.isEmpty ? null : password,
                            ),
                          );
                        },
                        child: const Text('그룹 만들기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
