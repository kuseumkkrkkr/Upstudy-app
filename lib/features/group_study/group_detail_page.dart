import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/business/repositories/exam_paper_store.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/shared_flow_view_page.dart';

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({
    super.key,
    required this.groupId,
    this.initialGroup,
    this.initialMembers,
    this.initialShareHistory,
    this.initialShareExams,
    this.initialChatMessages,
  });

  final String groupId;
  final Object? initialGroup;
  final List<StudyGroupMember>? initialMembers;
  final List<SolveHistoryItem>? initialShareHistory;
  final List<ExamPaperEntry>? initialShareExams;
  final List<StudyGroupMessage>? initialChatMessages;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  StudyGroup? _group;
  List<StudyGroupMember> _members = const [];
  List<SharedFlowItem> _sharedFlows = const [];
  List<GroupSharedExam> _sharedExams = const [];
  List<StudyGroupSchedule> _schedules = const [];
  bool _loadingResources = false;
  bool _loading = true;
  String? _error;
  bool _showExamPapers = false;
  List<String> _flowTags = const [];
  String _flowUserId = '';
  int? _flowRecentDays;
  String _currentUsername = '';

  String get _currentRole =>
      _members
          .where((member) => member.username == _currentUsername)
          .map((member) => member.role)
          .firstOrNull ??
      'member';

  bool get _canManageGroup => const {'admin', 'deputy'}.contains(_currentRole);

  /// 필요한 변수는 선택적 그룹·멤버 초기값이다.
  /// 작동 원리는 초기값이 있으면 즉시 렌더하고 실제 진입은 그룹과 멤버 GET을 병렬 실행하는 것이다.
  @override
  void initState() {
    super.initState();
    unawaited(_loadCurrentUser());
    if (widget.initialGroup != null) {
      _group = _coerceGroup(widget.initialGroup!);
      _members = widget.initialMembers ?? const [];
      _loading = false;
      unawaited(_loadResources());
      unawaited(_loadSchedules());
    } else {
      unawaited(_load());
    }
  }

  /// 필요한 변수는 과거 AcademyGroup 또는 실제 StudyGroup 초기값이다.
  /// 작동 원리는 미리보기 호환 입력을 소셜 그룹 모델로 변환해 운영·감사 화면이 같은 UI를 사용하게 하는 것이다.
  StudyGroup _coerceGroup(Object value) {
    if (value is StudyGroup) return value;
    final group = value as AcademyGroup;
    return StudyGroup(
      id: group.groupId,
      name: group.name,
      description: group.subject,
      memberCount: 0,
      maxMembers: group.maxMembers,
      isPublic: group.searchable,
    );
  }

  /// 필요한 변수는 그룹 ID다.
  /// 작동 원리는 그룹 메타와 멤버를 동시에 요청해 한 번의 화면 갱신으로 반영하는 것이다.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait<Object>([
        ApiClient.instance.listStudyGroups(),
        ApiClient.instance.listStudyGroupMembers(widget.groupId),
      ]);
      if (!mounted) return;
      final groups = responses[0] as List<StudyGroup>;
      final members = responses[1] as List<StudyGroupMember>;
      setState(() {
        _group = groups.where((item) => item.id == widget.groupId).firstOrNull;
        _members = members;
        _loading = false;
      });
      unawaited(_loadResources());
      unawaited(_loadSchedules());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '그룹 정보를 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }

  /// 필요한 변수는 로그인 세션의 내 프로필이다.
  /// 작동 원리는 현재 사용자 ID를 한 번만 가져와 그룹 생성자에게만 일정 추가
  /// 버튼을 보이게 하며, 서버 권한 검증은 별도로 유지한다.
  Future<void> _loadCurrentUser() async {
    try {
      final profile = await ApiClient.instance.getMyProfile();
      if (mounted) {
        setState(() {
          _currentUsername = profile.username;
        });
      }
    } catch (_) {
      // 권한 버튼만 숨기고 그룹 조회는 계속 진행한다.
    }
  }

  /// 필요한 변수는 그룹 ID다.
  /// 작동 원리는 캐시 없는 일정 조회 결과만 반영해 이미 지난 일정이 화면에 남지
  /// 않도록 하며, 만료 삭제는 서버가 일관되게 처리한다.
  Future<void> _loadSchedules() async {
    try {
      final schedules = await ApiClient.instance.listStudyGroupSchedules(
        widget.groupId,
      );
      if (!mounted) return;
      setState(() => _schedules = schedules);
    } catch (_) {
      // 일정 조회 실패가 그룹 본문과 자료 조회를 막지 않도록 조용히 유지한다.
    }
  }

  /// 필요한 변수는 입력한 제목, 날짜와 선택 시간이다.
  /// 작동 원리는 그룹장에게만 입력 UI를 제공하되 실제 생성 권한은 서버가 다시
  /// 검증하고, 성공 응답만 현재 일정 목록에 삽입한다.
  Future<void> _openScheduleComposer() async {
    final group = _group;
    if (group == null || !_canManageGroup) return;
    final titleController = TextEditingController();
    var selectedDate = DateTime.now();
    TimeOfDay? selectedTime;
    final created = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '그룹 일정 추가',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '일정 제목'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setSheetState(() => selectedDate = picked);
                  }
                },
                child: Text(
                  '${selectedDate.year}.${selectedDate.month}.${selectedDate.day}',
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime ?? TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setSheetState(() => selectedTime = picked);
                  }
                },
                child: Text(
                  selectedTime == null
                      ? '시간 선택 (선택)'
                      : selectedTime!.format(context),
                ),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await ApiClient.instance.createStudyGroupSchedule(
                      groupId: widget.groupId,
                      title: titleController.text,
                      scheduledDate:
                          '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                      scheduledTime: selectedTime == null
                          ? null
                          : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('일정을 추가하지 못했습니다: $error')),
                      );
                    }
                  }
                },
                child: const Text('추가'),
              ),
            ],
          ),
        ),
      ),
    );
    titleController.dispose();
    if (created == true) await _loadSchedules();
  }

  /// 필요한 변수는 그룹 ID와 현재 자료 탭이다.
  /// 작동 원리는 Flow·시험지 GET을 병렬 실행하고 한 번의 setState로 공유 자료 카드를 갱신하는 것이다.
  Future<void> _loadResources() async {
    if (_loadingResources) return;
    setState(() => _loadingResources = true);
    try {
      final now = DateTime.now();
      final from = _flowRecentDays == null
          ? null
          : now
                .subtract(Duration(days: _flowRecentDays!))
                .toUtc()
                .toIso8601String();
      final responses = await Future.wait<Object>([
        ApiClient.instance.listSharedFlows(
          widget.groupId,
          limit: 30,
          tags: _flowTags,
          userId: _flowUserId,
          from: from,
          to: _flowRecentDays == null ? null : now.toUtc().toIso8601String(),
        ),
        ApiClient.instance.listGroupSharedExams(widget.groupId, limit: 30),
      ]);
      if (!mounted) return;
      setState(() {
        _sharedFlows = responses[0] as List<SharedFlowItem>;
        _sharedExams = responses[1] as List<GroupSharedExam>;
      });
    } catch (_) {
      // 본문 진입은 유지하고 사용자가 새로고침할 때 다시 조회한다.
    } finally {
      if (mounted) setState(() => _loadingResources = false);
    }
  }

  /// 필요한 변수는 소유한 공유 Flow ID다.
  /// 작동 원리는 서버 삭제 성공 뒤 현재 목록에서 해당 항목만 제거해 불필요한 전체 재조회 요청을 피하는 것이다.
  Future<void> _deleteFlow(String shareId) async {
    try {
      await ApiClient.instance.deleteSharedFlow(shareId);
      if (!mounted) return;
      setState(() {
        _sharedFlows = _sharedFlows
            .where((item) => item.id != shareId)
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('공유를 취소하지 못했습니다: $error')));
    }
  }

  /// 필요한 변수는 그룹명과 멤버 목록이다.
  /// 작동 원리는 현재 그룹 대화를 바텀시트로 열고 입력 필드를 유지해 본문 위치를 보존하는 것이다.
  void _openChat() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _GroupChatSheet(
        groupId: widget.groupId,
        groupName: _group?.name ?? '그룹',
        initialMessages: widget.initialChatMessages,
      ),
    );
  }

  /// 필요한 변수는 현재 그룹의 사용자 ID·닉네임 목록이다.
  /// 작동 원리는 소셜 그룹 API가 반환한 실제 계정 ID와 닉네임을 그대로 목록에 표시해 예비 하드코딩 멤버를 제거하는 것이다.
  Future<void> _openMembers() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _GroupMembersSheet(
        groupId: widget.groupId,
        groupName: _group?.name ?? '그룹',
        currentUsername: _currentUsername,
        initialMembers: _members,
      ),
    );
    if (result == 'deleted' && mounted) {
      Navigator.of(context).pop(true);
      return;
    }
    if (result == 'invite' && mounted) {
      final invited = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => _GroupFriendInviteSheet(
          groupId: widget.groupId,
          memberUsernames: _members.map((member) => member.username).toSet(),
        ),
      );
      if (invited == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('그룹 초대를 보냈습니다. 상대방이 수락하면 참여합니다.')),
        );
      }
    }
    if (mounted) await _load();
  }

  /// 필요한 변수는 현재 자료 탭이다.
  /// 작동 원리는 Flow에서는 태그·공유자·기간을, 시험지에서는 제목·공유자를 입력하는 HTML 필터 시트를 연다.
  Future<void> _openResourceFilter() async {
    final tagsController = TextEditingController(text: _flowTags.join(' '));
    final userController = TextEditingController(text: _flowUserId);
    var recentDays = _flowRecentDays;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _GroupActionSheet(
          kicker: _showExamPapers ? 'GROUP EXAM FILTER' : 'GROUP FLOW FILTER',
          title: _showExamPapers ? '공유 시험지 필터' : '공유 Flow 필터',
          description: _showExamPapers
              ? '시험지 제목과 공유자를 화면에서 빠르게 확인합니다.'
              : '태그, 공유자, 날짜 범위를 함께 적용해 그룹 Flow를 찾습니다.',
          children: [
            TextField(
              controller: tagsController,
              enabled: !_showExamPapers,
              decoration: const InputDecoration(
                labelText: '태그',
                hintText: '#일차함수 #기울기',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: userController,
              enabled: !_showExamPapers,
              decoration: const InputDecoration(
                labelText: '공유자 ID',
                hintText: 'student-01',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              initialValue: recentDays,
              decoration: const InputDecoration(labelText: '기간'),
              items: const [
                DropdownMenuItem(value: 7, child: Text('최근 7일')),
                DropdownMenuItem(value: 30, child: Text('최근 30일')),
                DropdownMenuItem(value: null, child: Text('전체 기간')),
              ],
              onChanged: _showExamPapers
                  ? null
                  : (value) => setSheetState(() => recentDays = value),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF202022),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('필터 적용'),
            ),
          ],
        ),
      ),
    );
    final tagsText = tagsController.text;
    final userId = userController.text.trim();
    tagsController.dispose();
    userController.dispose();
    if (applied != true || !mounted || _showExamPapers) return;
    final tags = tagsText
        .split(RegExp(r'[\s,]+'))
        .map((tag) => tag.trim().replaceFirst('#', ''))
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
    setState(() {
      _flowTags = tags;
      _flowUserId = userId;
      _flowRecentDays = recentDays;
    });
    await _loadResources();
  }

  /// 필요한 변수는 그룹 ID와 현재 자료 탭이다.
  /// 작동 원리는 Flow 최근 풀이 또는 시험지 선택 범위를 설명하고 선택 자료를 공유하는 HTML 시트를 연다.
  void _openShareResource() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _GroupShareSheet(
        groupId: widget.groupId,
        shareExam: _showExamPapers,
        initialHistory: widget.initialShareHistory,
        initialExams: widget.initialShareExams,
      ),
    );
  }

  /// 필요한 변수는 현재 그룹, 멤버·일정·공유 자료 상태와 기존 기능 콜백이다.
  /// 작동 원리는 모바일에서 그룹 요약과 핵심 행동을 한 카드로 모으고 자료 기능은 기존 콜백에 그대로 연결하는 것이다.
  Widget _buildMobileDashboard(StudyGroup? group) {
    final memberCount = _members.isEmpty
        ? group?.memberCount ?? 0
        : _members.length;
    return Scaffold(
      key: const ValueKey('mobile-group-dashboard'),
      backgroundColor: const Color(0xFFF4F4F6),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (headerContext) => Ios26TopBar(
                brandColor: Colors.black,
                showLevelIndicator: false,
                showUtilityActions: true,
                onTitleTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/student/dashboard',
                  (route) => false,
                ),
                onBack: () => Navigator.of(context).maybePop(),
                onMenu: () => toggleAppDrawer(headerContext),
                showMenuWithBack: true,
                items: studentTopNavItems(
                  headerContext,
                  active: StudentTopDestination.social,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          studentDensityHorizontalPadding(context),
                          12,
                          studentDensityHorizontalPadding(context),
                          48,
                        ),
                        children: [
                          _MobileGroupOverview(
                            group: group,
                            memberCount: memberCount,
                            schedules: _schedules,
                            canCreateSchedule:
                                _canManageGroup && _currentUsername.isNotEmpty,
                            onCreateSchedule: _openScheduleComposer,
                            onMembers: _openMembers,
                            onChat: _openChat,
                          ),
                          const SizedBox(height: 26),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Expanded(
                                child: Text(
                                  '학습 자료',
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.7,
                                  ),
                                ),
                              ),
                              Text(
                                '${_sharedFlows.length + _sharedExams.length}개',
                                style: const TextStyle(
                                  color: Colors.black45,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ResourceSwitch(
                            mobile: true,
                            showExamPapers: _showExamPapers,
                            flowCount: _sharedFlows.length,
                            examCount: _sharedExams.length,
                            onChanged: (value) =>
                                setState(() => _showExamPapers = value),
                          ),
                          const SizedBox(height: 10),
                          _SharedResourcesCard(
                            mobile: true,
                            showExamPapers: _showExamPapers,
                            loading: _loadingResources,
                            flows: _sharedFlows,
                            exams: _sharedExams,
                            flowTags: _flowTags,
                            recentDays: _flowRecentDays,
                            onFilter: _openResourceFilter,
                            onShare: _openShareResource,
                            onDeleteFlow: _deleteFlow,
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

  /// 필요한 변수는 그룹·멤버 로딩 상태와 현재 자료 탭이다.
  /// 작동 원리는 HTML 그룹 공간의 소개, 그룹 카드, 자료 전환, 공유 풀이 순서로 렌더링하는 것이다.
  @override
  Widget build(BuildContext context) {
    final group = _group;
    final mobile = isStudentDensityMobile(context);
    if (mobile) return _buildMobileDashboard(group);
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
                onTitleTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/student/dashboard',
                  (route) => false,
                ),
                onMenu: () => toggleAppDrawer(context),
                items: studentTopNavItems(
                  context,
                  active: StudentTopDestination.social,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
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
                                _GroupDetailHeader(
                                  mobile: mobile,
                                  title: group?.name ?? '그룹 스터디',
                                  memberCount: _members.length,
                                  onBack: () =>
                                      Navigator.of(context).maybePop(),
                                  onMembers: _openMembers,
                                  onChat: _openChat,
                                ),
                                SizedBox(height: mobile ? 14 : 18),
                                _GroupHero(
                                  group: group,
                                  memberCount: _members.length,
                                  schedules: _schedules,
                                  canCreateSchedule:
                                      _canManageGroup &&
                                      _currentUsername.isNotEmpty,
                                  onCreateSchedule: _openScheduleComposer,
                                  onMembers: _openMembers,
                                ),
                                const SizedBox(height: 12),
                                _ResourceSwitch(
                                  showExamPapers: _showExamPapers,
                                  flowCount: _sharedFlows.length,
                                  examCount: _sharedExams.length,
                                  onChanged: (value) =>
                                      setState(() => _showExamPapers = value),
                                ),
                                const SizedBox(height: 12),
                                _SharedResourcesCard(
                                  showExamPapers: _showExamPapers,
                                  loading: _loadingResources,
                                  flows: _sharedFlows,
                                  exams: _sharedExams,
                                  flowTags: _flowTags,
                                  recentDays: _flowRecentDays,
                                  onFilter: _openResourceFilter,
                                  onShare: _openShareResource,
                                  onDeleteFlow: _deleteFlow,
                                ),
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

class _MobileGroupOverview extends StatelessWidget {
  const _MobileGroupOverview({
    required this.group,
    required this.memberCount,
    required this.schedules,
    required this.canCreateSchedule,
    required this.onCreateSchedule,
    required this.onMembers,
    required this.onChat,
  });

  final StudyGroup? group;
  final int memberCount;
  final List<StudyGroupSchedule> schedules;
  final bool canCreateSchedule;
  final VoidCallback onCreateSchedule;
  final VoidCallback onMembers;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final name = group?.name.trim().isNotEmpty == true
        ? group!.name.trim()
        : '그룹 스터디';
    final description = group?.description?.trim().isNotEmpty == true
        ? group!.description!.trim()
        : '함께 공부하고 풀이를 나누는 학습 공간';
    final maxMembers = group?.maxMembers ?? 0;
    final capacity = maxMembers > 0
        ? (memberCount / maxMembers).clamp(0.0, 1.0)
        : 0.0;
    final schedule = schedules.firstOrNull;

    return Container(
      key: const ValueKey('mobile-group-overview'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0D000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF315FD6), width: 2),
                ),
                child: Text(
                  name.characters.first,
                  style: const TextStyle(
                    color: Color(0xFF315FD6),
                    fontSize: 24,
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
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Text(
                group?.isPublic == true ? '공개 그룹' : '비공개 그룹',
                style: const TextStyle(
                  color: Color(0xFF315FD6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                maxMembers > 0
                    ? '$memberCount / $maxMembers명'
                    : '$memberCount명',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: capacity,
              backgroundColor: const Color(0xFFEDEEF2),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF315FD6)),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            key: const ValueKey('mobile-group-schedule'),
            padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Color(0xFF315FD6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '다음 일정',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schedule == null
                            ? '예정된 일정이 없습니다.'
                            : '${schedule.scheduledDate}${schedule.scheduledTime == null ? '' : ' ${schedule.scheduledTime}'} · ${schedule.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canCreateSchedule)
                  TextButton(
                    key: const ValueKey('mobile-group-add-schedule'),
                    onPressed: onCreateSchedule,
                    child: const Text('추가'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    key: const ValueKey('mobile-group-members'),
                    onPressed: onMembers,
                    icon: const Icon(Icons.group_outlined, size: 18),
                    label: const Text('멤버 보기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF202022),
                      side: const BorderSide(color: Color(0xFFB9B9BE)),
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
                  height: 46,
                  child: FilledButton.icon(
                    key: const ValueKey('mobile-group-chat'),
                    onPressed: onChat,
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 17,
                    ),
                    label: const Text('채팅 열기'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF202022),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupDetailHeader extends StatelessWidget {
  const _GroupDetailHeader({
    required this.mobile,
    required this.title,
    required this.memberCount,
    required this.onBack,
    required this.onMembers,
    required this.onChat,
  });

  final bool mobile;
  final String title;
  final int memberCount;
  final VoidCallback onBack;
  final VoidCallback onMembers;
  final VoidCallback onChat;

  /// 필요한 변수는 화면 형태, 그룹명·멤버 수와 세 가지 이동 동작이다.
  /// 작동 원리는 모바일은 제목 아래 전폭 버튼을, PC는 제목 오른쪽의 압축 제어부를 배치해 화면 폭별 정보 우선순위를 분리한다.
  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StudentDensityEyebrow('STUDY GROUP'),
        const SizedBox(height: 7),
        Text(
          title,
          style: TextStyle(
            fontSize: mobile ? 30 : 42,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: mobile ? -1.2 : -2.1,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '함께 공부하고, 풀이를 나누는 우리만의 학습 공간',
          style: TextStyle(color: Colors.black45, fontSize: 13),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StudentDensityButton(label: '그룹 목록', onPressed: onBack),
        StudentDensityButton(label: '멤버 $memberCount명', onPressed: onMembers),
        StudentDensityButton(label: '채팅 열기', primary: true, onPressed: onChat),
      ],
    );
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [copy, const SizedBox(height: 18), actions],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: copy),
        const SizedBox(width: 24),
        actions,
      ],
    );
  }
}

class _GroupHero extends StatelessWidget {
  const _GroupHero({
    required this.group,
    required this.memberCount,
    required this.schedules,
    required this.canCreateSchedule,
    required this.onCreateSchedule,
    required this.onMembers,
  });
  final StudyGroup? group;
  final int memberCount;
  final List<StudyGroupSchedule> schedules;
  final bool canCreateSchedule;
  final VoidCallback onCreateSchedule;
  final VoidCallback onMembers;

  /// 필요한 변수는 그룹 메타, 서버 일정, 생성자 권한이다.
  /// 작동 원리는 교사 계정이 만든 그룹은 흰 컨테이너로 구분하고, 만료 정리된
  /// 일정만 표시한다. 일정 추가 동작은 그룹장에게만 제공한다.
  @override
  Widget build(BuildContext context) {
    final teacherGroup = group?.isTeacherGroup == true;
    final foreground = teacherGroup ? Colors.black : Colors.white;
    final muted = teacherGroup ? Colors.black54 : Colors.white70;
    final schedule = schedules.isEmpty ? null : schedules.first;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: teacherGroup ? Colors.white : const Color(0xFF202022),
        borderRadius: BorderRadius.circular(24),
        border: teacherGroup
            ? Border.all(color: const Color(0xFFE0E0E3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      children: [
                        _MetaPill(
                          label: group?.isPublic == true ? '공개 그룹' : '비공개 그룹',
                          dark: true,
                        ),
                        _MetaPill(
                          label: '$memberCount / ${group?.maxMembers ?? 20}명',
                          dark: true,
                        ),
                        _MetaPill(
                          label: group?.isTeacherGroup == true
                              ? '교사 그룹'
                              : '스터디 그룹',
                          dark: !teacherGroup,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      group?.description ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(
            height: 30,
            color: teacherGroup
                ? const Color(0xFFE0E0E3)
                : const Color(0xFF3A3A3D),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  schedule == null
                      ? '등록된 그룹 일정이 없습니다.'
                      : '${schedule.scheduledDate}${schedule.scheduledTime == null ? '' : ' ${schedule.scheduledTime}'} ${schedule.title}',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (canCreateSchedule)
                TextButton(
                  onPressed: onCreateSchedule,
                  child: Text('일정 추가', style: TextStyle(color: foreground)),
                ),
              TextButton.icon(
                onPressed: onMembers,
                icon: const Icon(
                  Icons.group_outlined,
                  size: 17,
                  color: Colors.grey,
                ),
                label: Text('멤버 보기', style: TextStyle(color: muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResourceSwitch extends StatelessWidget {
  const _ResourceSwitch({
    this.mobile = false,
    required this.showExamPapers,
    required this.flowCount,
    required this.examCount,
    required this.onChanged,
  });
  final bool mobile;
  final bool showExamPapers;
  final int flowCount;
  final int examCount;
  final ValueChanged<bool> onChanged;

  /// 필요한 변수는 시험지 탭 선택 여부다.
  /// 작동 원리는 그룹 문제풀이와 시험지를 두 칸 카드로 전환하고 활성 자료만 검게 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    key: mobile ? const ValueKey('mobile-group-resource-switch') : null,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: mobile ? Colors.white : const Color(0xFFE9E9EC),
      borderRadius: BorderRadius.circular(mobile ? 18 : 15),
      border: mobile ? Border.all(color: const Color(0x0D000000)) : null,
    ),
    child: Row(
      children: [
        _ResourceButton(
          mobile: mobile,
          label: mobile ? '문제풀이' : '그룹 문제풀기',
          subtitle: '$flowCount개',
          selected: !showExamPapers,
          onTap: () => onChanged(false),
        ),
        _ResourceButton(
          mobile: mobile,
          label: mobile ? '시험지' : '그룹 시험지',
          subtitle: '$examCount개',
          selected: showExamPapers,
          onTap: () => onChanged(true),
        ),
      ],
    ),
  );
}

class _ResourceButton extends StatelessWidget {
  const _ResourceButton({
    this.mobile = false,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final bool mobile;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// 필요한 변수는 레이블·보조문구·선택 상태다.
  /// 작동 원리는 선택된 그룹 자료만 검은 배경과 흰 글자로 강조하는 것이다.
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? mobile
                    ? const Color(0xFFEFF3FF)
                    : const Color(0xFF202022)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(mobile ? 14 : 12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? mobile
                          ? const Color(0xFF315FD6)
                          : Colors.white
                    : Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: selected
                    ? mobile
                          ? const Color(0xFF315FD6)
                          : Colors.white54
                    : Colors.black45,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SharedResourcesCard extends StatelessWidget {
  const _SharedResourcesCard({
    this.mobile = false,
    required this.showExamPapers,
    required this.loading,
    required this.flows,
    required this.exams,
    required this.flowTags,
    required this.recentDays,
    required this.onFilter,
    required this.onShare,
    required this.onDeleteFlow,
  });
  final bool mobile;
  final bool showExamPapers;
  final bool loading;
  final List<SharedFlowItem> flows;
  final List<GroupSharedExam> exams;
  final List<String> flowTags;
  final int? recentDays;
  final VoidCallback onFilter;
  final VoidCallback onShare;
  final Future<void> Function(String shareId) onDeleteFlow;

  /// 필요한 변수는 공유 Flow의 식별자와 제목이다.
  /// 작동 원리는 공유 상세 페이지에서 문제 원문을 재현하고, 그 위에 공유된 풀이 과정을 함께 보여주는 것이다.
  Future<void> _openFlow(BuildContext context, SharedFlowItem flow) async {
    if (flow.id.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('아직 열 수 없는 미리보기 자료입니다.')));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SharedFlowViewPage(
          shareId: flow.id,
          title: flow.title ?? '공유된 문제 풀이',
        ),
      ),
    );
  }

  /// 필요한 변수는 현재 선택 자료 탭과 공유 목록이다.
  /// 작동 원리는 문제 원문을 열 수 있다는 목적을 제목·행동 버튼에 명확히 드러내고, 공유 자료를 빠르게 훑을 수 있는 카드 목록으로 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    key: mobile ? const ValueKey('mobile-group-resources') : null,
    padding: EdgeInsets.all(mobile ? 16 : 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(mobile ? 24 : 22),
      border: Border.all(
        color: mobile ? const Color(0x0D000000) : const Color(0xFFE0E0E2),
      ),
      boxShadow: mobile
          ? const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ]
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!mobile) ...[
          Text(
            showExamPapers ? 'SHARED PAPERS' : 'SHARED SOLVES',
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.6,
              color: Colors.black54,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          showExamPapers
              ? mobile
                    ? '공유된 시험지'
                    : '그룹 시험지'
              : mobile
              ? '공유된 풀이'
              : '그룹 문제풀이',
          style: TextStyle(
            fontSize: mobile ? 17 : 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: mobile ? 4 : 6),
        Text(
          showExamPapers
              ? '그룹 멤버가 공유한 시험지를 확인하세요.'
              : '문제 원문과 멤버의 풀이 과정을 함께 확인하세요.',
          style: TextStyle(fontSize: mobile ? 11 : 13, color: Colors.black54),
        ),
        SizedBox(height: mobile ? 16 : 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onFilter,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tune_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('필터'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF202022),
                ),
                onPressed: onShare,
                child: Text(showExamPapers ? '시험지 공유' : '내 풀이 공유'),
              ),
            ),
          ],
        ),
        if (!showExamPapers) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in flowTags) _MetaPill(label: '#$tag'),
              if (recentDays != null) _MetaPill(label: '최근 $recentDays일'),
            ],
          ),
        ],
        SizedBox(height: mobile ? 12 : 18),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if ((showExamPapers && exams.isEmpty) ||
            (!showExamPapers && flows.isEmpty))
          Padding(
            padding: EdgeInsets.symmetric(vertical: mobile ? 18 : 24),
            child: const Center(child: Text('공유된 자료가 없습니다.')),
          )
        else if (showExamPapers)
          for (final exam in exams)
            _SharedResourceTile(
              title: exam.title.isEmpty ? '그룹 시험지' : exam.title,
              tags: '시험지 · 답안 제외',
              sender: exam.senderName,
              createdAt: exam.createdAt,
              onOpen: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(exam.title),
                  content: Text(
                    '공유자 ${exam.senderName}\n시험지 ID ${exam.examId}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
              ),
            )
        else
          for (final flow in flows)
            _SharedResourceTile(
              title: flow.title ?? '공유 Flow',
              tags: flow.tags.isEmpty
                  ? '문제와 풀이 과정 공유'
                  : flow.tags.map((tag) => '#$tag').join('  '),
              sender: flow.senderId.isEmpty ? '그룹 멤버' : flow.senderId,
              createdAt: flow.createdAt?.toIso8601String() ?? '',
              onDelete: flow.id.isEmpty ? null : () => onDeleteFlow(flow.id),
              onOpen: () => _openFlow(context, flow),
            ),
      ],
    ),
  );
}

class _SharedResourceTile extends StatelessWidget {
  const _SharedResourceTile({
    required this.title,
    required this.tags,
    required this.sender,
    required this.createdAt,
    required this.onOpen,
    this.onDelete,
  });

  final String title;
  final String tags;
  final String sender;
  final String createdAt;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  /// 필요한 변수는 공유 자료 제목·태그·작성자·시각과 열람·삭제 콜백이다.
  /// 작동 원리는 자료 성격과 핵심 행동을 분리해, 한 번의 탭으로 문제와 풀이를 열 수 있게 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F8FA),
      border: Border.all(color: const Color(0xFFE4E4E8)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEAEAFF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.auto_stories_outlined,
                color: Color(0xFF4B53A8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          tags,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFF62626A)),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            Text(
              '$sender · $createdAt',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('공유 취소'),
                  ),
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('문제·풀이 보기'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF202022),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

class _GroupMembersSheet extends StatefulWidget {
  const _GroupMembersSheet({
    required this.groupId,
    required this.groupName,
    required this.currentUsername,
    required this.initialMembers,
  });

  final String groupId;
  final String groupName;
  final String currentUsername;
  final List<StudyGroupMember> initialMembers;

  @override
  State<_GroupMembersSheet> createState() => _GroupMembersSheetState();
}

class _GroupMembersSheetState extends State<_GroupMembersSheet> {
  late List<StudyGroupMember> _members = widget.initialMembers;
  String? _busyUsername;

  String get _myRole =>
      _members
          .where((member) => member.username == widget.currentUsername)
          .map((member) => member.role)
          .firstOrNull ??
      'member';

  String _roleLabel(String role) => switch (role) {
    'admin' => '관리자',
    'deputy' => '부관리자',
    _ => '멤버',
  };

  List<PopupMenuEntry<String>> _actionsFor(StudyGroupMember member) {
    if (member.username == widget.currentUsername) return const [];
    final actions = <PopupMenuEntry<String>>[];
    if (_myRole == 'admin' && member.role != 'admin') {
      actions.add(
        PopupMenuItem(
          value: member.role == 'deputy' ? 'member' : 'deputy',
          child: Text(member.role == 'deputy' ? '부관리자 해제' : '부관리자 임명'),
        ),
      );
      actions.add(const PopupMenuItem(value: 'admin', child: Text('관리자 양도')));
    }
    final canRemove =
        member.role != 'admin' &&
        (_myRole == 'admin' ||
            (_myRole == 'deputy' && member.role == 'member'));
    if (canRemove) {
      actions.add(const PopupMenuItem(value: 'remove', child: Text('그룹에서 추방')));
    }
    return actions;
  }

  Future<bool> _confirm(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('확인'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _runAction(StudyGroupMember member, String action) async {
    if (_busyUsername != null) return;
    if (action == 'admin' &&
        !await _confirm('관리자 양도', '${member.username}님에게 관리자 권한을 양도할까요?')) {
      return;
    }
    if (action == 'remove' &&
        !await _confirm('멤버 추방', '${member.username}님을 그룹에서 추방할까요?')) {
      return;
    }
    setState(() => _busyUsername = member.username);
    try {
      if (action == 'remove') {
        await ApiClient.instance.removeStudyGroupMember(
          groupId: widget.groupId,
          username: member.username,
        );
      } else {
        await ApiClient.instance.changeStudyGroupMemberRole(
          groupId: widget.groupId,
          username: member.username,
          role: action,
        );
      }
      final members = await ApiClient.instance.listStudyGroupMembers(
        widget.groupId,
      );
      if (mounted) setState(() => _members = members);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('멤버 권한을 변경하지 못했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _busyUsername = null);
    }
  }

  Future<void> _deleteGroup() async {
    if (!await _confirm('그룹 삭제', '${widget.groupName} 그룹과 모든 대화를 삭제할까요?')) {
      return;
    }
    try {
      await ApiClient.instance.deleteStudyGroup(widget.groupId);
      if (mounted) Navigator.of(context).pop('deleted');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('그룹을 삭제하지 못했습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '그룹 멤버',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('group-invite-friend'),
              onPressed: () => Navigator.of(context).pop('invite'),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('내 친구 초대'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                key: const ValueKey('group-member-scroll'),
                itemCount: _members.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final member = _members[index];
                  final actions = _actionsFor(member);
                  return Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F6F8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.username,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          _roleLabel(member.role),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (_busyUsername == member.username)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (actions.isNotEmpty)
                          PopupMenuButton<String>(
                            key: ValueKey('member-actions-${member.username}'),
                            onSelected: (action) => _runAction(member, action),
                            itemBuilder: (_) => actions,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_myRole == 'admin') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('delete-study-group'),
                onPressed: _deleteGroup,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('그룹 삭제'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _GroupFriendInviteSheet extends StatefulWidget {
  const _GroupFriendInviteSheet({
    required this.groupId,
    required this.memberUsernames,
  });

  final String groupId;
  final Set<String> memberUsernames;

  @override
  State<_GroupFriendInviteSheet> createState() =>
      _GroupFriendInviteSheetState();
}

class _GroupFriendInviteSheetState extends State<_GroupFriendInviteSheet> {
  List<FriendProfile> _friends = const [];
  bool _loading = true;
  String? _invitingUserId;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFriends());
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final friends = await ApiClient.instance.listFriends(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _friends = friends
            .where(
              (friend) => !widget.memberUsernames.contains(friend.username),
            )
            .toList(growable: false);
      });
    } catch (_) {
      if (mounted) setState(() => _error = '친구 목록을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite(FriendProfile friend) async {
    if (_invitingUserId != null) return;
    setState(() => _invitingUserId = friend.userId);
    try {
      await ApiClient.instance.inviteFriendToStudyGroup(
        groupId: widget.groupId,
        username: friend.username,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구를 초대하지 못했습니다.')));
      setState(() => _invitingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * .72;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '내 친구 초대',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text('친구로 등록된 사용자만 이 그룹에 바로 초대할 수 있습니다.'),
              const SizedBox(height: 18),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _loadFriends,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      )
                    : _friends.isEmpty
                    ? const Center(child: Text('초대할 수 있는 친구가 없습니다.'))
                    : ListView.separated(
                        itemCount: _friends.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final friend = _friends[index];
                          final label = (friend.name ?? '').trim().isNotEmpty
                              ? friend.name!.trim()
                              : friend.username;
                          final isInviting = _invitingUserId == friend.userId;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Text(label.characters.first.toUpperCase()),
                            ),
                            title: Text(label),
                            subtitle: Text('@${friend.username}'),
                            trailing: FilledButton(
                              onPressed: _invitingUserId == null
                                  ? () => _invite(friend)
                                  : null,
                              child: isInviting
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('초대'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupChatSheet extends StatefulWidget {
  const _GroupChatSheet({
    required this.groupId,
    required this.groupName,
    this.initialMessages,
  });

  final String groupId;
  final String groupName;
  final List<StudyGroupMessage>? initialMessages;

  /// 필요한 변수는 그룹·멤버·선택적 초기 메시지다.
  /// 작동 원리는 최근 메시지 조회와 입력 전송을 관리하는 독립 채팅 시트 상태를 만든다.
  @override
  State<_GroupChatSheet> createState() => _GroupChatSheetState();
}

class _GroupChatSheetState extends State<_GroupChatSheet> {
  static const int _maxMessages = 500;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<StudyGroupMessage> _messages = const [];
  bool _loading = true;
  bool _loadingPrevious = false;
  bool _sending = false;
  bool _hasPrevious = true;
  String? _error;

  /// 필요한 변수는 서버의 ISO-8601 시간 문자열이다.
  /// 작동 원리는 당일 메시지는 현지 시각만, 다른 날짜의 메시지는 월/일만 반환해 채팅 행을 짧게 표시하는 것이다.
  String _formatMessageTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    return '${local.month}/${local.day}';
  }

  /// 필요한 변수는 메시지 시간 문자열이다.
  /// 작동 원리는 메시지 목록의 날짜가 바뀌는 지점에만 날짜 구분선을 표시해 실제 메신저처럼 대화를 묶는 것이다.
  String _messageDateKey(String raw) {
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    return '${parsed.year}-${parsed.month}-${parsed.day}';
  }

  /// 필요한 변수는 표시할 닉네임이다.
  /// 작동 원리는 서버 닉네임을 우선 사용하고, 구형 응답에는 안전한 대체 문구를 적용하는 것이다.
  String _senderName(StudyGroupMessage message) {
    if (message.senderName.trim().isNotEmpty) return message.senderName.trim();
    return '그룹 멤버';
  }

  /// 필요한 변수는 닉네임이다.
  /// 작동 원리는 긴 닉네임도 작은 원형 아바타 안에서 식별 가능하도록 첫 글자만 반환하는 것이다.
  String _avatarLetter(String name) => name.characters.first.toUpperCase();

  /// 필요한 변수는 메시지와 말풍선 방향·색상이다.
  /// 작동 원리는 본인 메시지는 오른쪽, 다른 멤버 메시지는 왼쪽에 배치하고 닉네임·본문·시각을 하나의 말풍선으로 묶는 것이다.
  Widget _buildMessageBubble(StudyGroupMessage message) {
    final isMine = message.isMine;
    final sender = _senderName(message);
    final bubbleColor = isMine ? const Color(0xFF202022) : Colors.white;
    final textColor = isMine ? Colors.white : const Color(0xFF202124);
    final timeColor = isMine ? Colors.white60 : Colors.black38;
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 315),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 5),
            bottomRight: Radius.circular(isMine ? 5 : 18),
          ),
          boxShadow: isMine
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  sender,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF62626A),
                  ),
                ),
              ),
            Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.35),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatMessageTime(message.createdAt),
                style: TextStyle(fontSize: 10, color: timeColor),
              ),
            ),
          ],
        ),
      ),
    );
    if (isMine) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFE4E5FF),
            shape: BoxShape.circle,
          ),
          child: Text(
            _avatarLetter(sender),
            style: const TextStyle(
              color: Color(0xFF4B53A8),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        bubble,
      ],
    );
  }

  /// 필요한 변수는 선택적 초기 메시지 또는 그룹 메시지 API다.
  /// 작동 원리는 시트가 열릴 때 최근 30개만 불러와 첫 렌더의 DB·네트워크 부하를 제한하는 것이다.
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels <= 80 &&
          _hasPrevious &&
          !_loadingPrevious) {
        unawaited(_loadPrevious());
      }
    });
    unawaited(_loadInitial());
  }

  /// 필요한 변수는 입력·스크롤 컨트롤러다.
  /// 작동 원리는 시트 종료 시 네이티브 리소스를 즉시 해제하는 것이다.
  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 필요한 변수는 초기 메시지 주입값과 그룹 ID다.
  /// 작동 원리는 미리보기 데이터가 있으면 API를 건너뛰고 운영 진입만 최근 메시지를 조회한다.
  Future<void> _loadInitial() async {
    try {
      final messages =
          widget.initialMessages ??
          await ApiClient.instance.fetchStudyGroupMessages(
            groupId: widget.groupId,
            limit: 30,
          );
      _messages = messages;
      _hasPrevious = widget.initialMessages == null && messages.length == 30;
    } catch (_) {
      _error = '최근 대화를 불러오지 못했습니다.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        // 실제 메신저처럼 입장 직후 가장 최근 메시지 위치를 보여준다.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    }
  }

  /// 필요한 변수는 현재 가장 오래된 메시지 시각과 그룹 ID다.
  /// 작동 원리는 이전 30개를 앞에 합치고 중복 ID를 제거하며 최대 500개까지만 보존하는 것이다.
  Future<void> _loadPrevious() async {
    if (_loadingPrevious || !_hasPrevious || _messages.isEmpty) return;
    final oldMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    setState(() => _loadingPrevious = true);
    try {
      final previous = await ApiClient.instance.fetchStudyGroupMessages(
        groupId: widget.groupId,
        limit: 30,
        before: _messages.first.createdAt,
      );
      if (!mounted) return;
      final ids = _messages.map((item) => item.messageId).toSet();
      setState(() {
        _hasPrevious = previous.length == 30;
        _messages = [
          ...previous.where((item) => !ids.contains(item.messageId)),
          ..._messages,
        ].take(_maxMessages).toList(growable: false);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final addedExtent =
              _scrollController.position.maxScrollExtent - oldMaxExtent;
          _scrollController.jumpTo(addedExtent.clamp(0, double.infinity));
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이전 메시지를 불러오지 못했습니다.')));
    } finally {
      if (mounted) setState(() => _loadingPrevious = false);
    }
  }

  /// 필요한 변수는 공백을 제거한 입력 메시지와 그룹 ID다.
  /// 작동 원리는 서버 전송 성공 응답만 목록 끝에 추가하고 최대 500개 정책을 유지하는 것이다.
  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await ApiClient.instance.sendStudyGroupMessage(
        groupId: widget.groupId,
        text: message,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _messages = [..._messages, sent].reversed
            .take(_maxMessages)
            .toList(growable: false)
            .reversed
            .toList(growable: false);
      });
      await Future<void>.delayed(Duration.zero);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('메시지를 보내지 못했습니다: $error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// 필요한 변수는 로딩·메시지·입력·전송 상태다.
  /// 작동 원리는 전체 높이의 메신저 화면 안에 헤더·대화 목록·고정 입력창을 분리해 실제 채팅방의 시각적 위계를 만드는 것이다.
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * .88,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF202022),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.groupName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null && _messages.isEmpty
                    ? Center(child: Text(_error!))
                    : _messages.isEmpty
                    ? const Center(child: Text('첫 메시지를 남겨 보세요.'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final previous = index > 0
                              ? _messages[index - 1]
                              : null;
                          final showDate =
                              previous == null ||
                              _messageDateKey(previous.createdAt) !=
                                  _messageDateKey(message.createdAt);
                          return Column(
                            children: [
                              if (showDate)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8E9EF),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      child: Text(
                                        _formatMessageTime(message.createdAt),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildMessageBubble(message),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E6EB))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: '메시지를 입력하세요',
                          filled: true,
                          fillColor: const Color(0xFFF3F4F7),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: '메시지 전송',
                      onPressed: _sending ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF202022),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFBFC0C5),
                      ),
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupShareSheet extends StatefulWidget {
  const _GroupShareSheet({
    required this.groupId,
    required this.shareExam,
    this.initialHistory,
    this.initialExams,
  });

  final String groupId;
  final bool shareExam;
  final List<SolveHistoryItem>? initialHistory;
  final List<ExamPaperEntry>? initialExams;

  /// 필요한 변수는 그룹 ID와 공유 자료 종류다.
  /// 작동 원리는 시험지 또는 최근 풀이를 실제 저장소에서 읽는 선택기 상태를 만든다.
  @override
  State<_GroupShareSheet> createState() => _GroupShareSheetState();
}

class _GroupShareSheetState extends State<_GroupShareSheet> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<ExamPaperEntry> _exams = const [];
  List<SolveHistoryItem> _history = const [];
  final Set<String> _selected = <String>{};

  /// 필요한 변수는 현재 공유 종류다.
  /// 작동 원리는 시험지는 로컬 저장소, 풀이는 최근 60일 API를 한 번만 조회한다.
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// 필요한 변수는 시험지 저장소 또는 풀이 이력 API다.
  /// 작동 원리는 최대 30개 후보만 유지해 바텀시트 렌더와 메모리 사용을 제한한다.
  Future<void> _load() async {
    try {
      if (widget.shareExam) {
        _exams = (widget.initialExams ?? await ExamPaperStore.load())
            .take(30)
            .toList(growable: false);
      } else {
        _history =
            widget.initialHistory ??
            await ApiClient.instance.fetchSolveHistory(
              days: 60,
              kind: 'problem',
              limit: 30,
            );
      }
    } catch (_) {
      _error = widget.shareExam ? '내 시험지를 불러오지 못했습니다.' : '최근 풀이를 불러오지 못했습니다.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 필요한 변수는 후보의 안정적인 식별자와 체크 상태다.
  /// 작동 원리는 풀이 공유는 최대 5개, 시험지는 1개만 선택하도록 제한한다.
  void _toggle(String id, bool selected) {
    setState(() {
      if (!selected) {
        _selected.remove(id);
        return;
      }
      if (widget.shareExam) _selected.clear();
      if (!widget.shareExam && _selected.length >= 5) return;
      _selected.add(id);
    });
  }

  /// 필요한 변수는 선택 시험지 또는 최대 5개 풀이와 그룹 ID다.
  /// 작동 원리는 실제 공유 API를 호출하고 모든 요청이 성공한 경우에만 시트를 닫는다.
  Future<void> _submit() async {
    if (_selected.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      if (widget.shareExam) {
        await ApiClient.instance.shareGroupExam(
          groupId: widget.groupId,
          examId: _selected.first,
        );
      } else {
        const emptyStatus = {
          'status': <Object>[],
          'in_panic': <Object>[],
          'ai_opinion': '',
          'o_reasons': <Object>[],
        };
        for (final item in _history.where(
          (entry) => _selected.contains(_historyId(entry)),
        )) {
          await ApiClient.instance.shareFlowToGroup(
            groupId: widget.groupId,
            questId: item.questId ?? '',
            codebaseId: item.codebaseId ?? 0,
            seed: item.seed ?? 0,
            questTitle: item.questTitleRaw,
            statusJson: jsonEncode(emptyStatus),
            tags: item.hashTags,
          );
        }
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(widget.shareExam ? '시험지를 공유했습니다.' : '풀이 Flow를 공유했습니다.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('공유하지 못했습니다: $error')));
    }
  }

  /// 필요한 변수는 풀이의 문제 ID·코드베이스·시드다.
  /// 작동 원리는 API에 questId가 없는 과거 기록도 중복 없이 선택할 안정 키를 만든다.
  String _historyId(SolveHistoryItem item) =>
      item.questId ?? '${item.codebaseId ?? 0}_${item.seed ?? 0}';

  /// 필요한 변수는 로딩·후보·선택·전송 상태다.
  /// 작동 원리는 HTML 공유 모달처럼 설명, 선택 목록, 하단 공유 버튼 순으로 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final empty = widget.shareExam ? _exams.isEmpty : _history.isEmpty;
    return _GroupActionSheet(
      kicker: widget.shareExam ? 'SHARE EXAM' : 'SHARE SOLVE HISTORY',
      title: widget.shareExam ? '시험지 공유' : '내 풀이 공유',
      description: widget.shareExam
          ? '내 시험지 제목과 문항만 공유하며 학생 답안은 제외합니다.'
          : '최근 60일 풀이 내역에서 최대 5개를 선택해 Flow로 공유합니다.',
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null || empty)
          _GroupActionRow(
            title: _error ?? '공유할 자료가 없습니다.',
            detail: widget.shareExam
                ? '책가방에서 시험지를 먼저 만드세요.'
                : '문제를 푼 뒤 다시 확인하세요.',
            meta: '—',
          )
        else if (widget.shareExam)
          for (final exam in _exams)
            CheckboxListTile(
              value: _selected.contains(exam.examId),
              onChanged: (value) => _toggle(exam.examId, value ?? false),
              title: Text(
                exam.searchIndex.isEmpty
                    ? '시험지 ${exam.examId}'
                    : exam.searchIndex,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('${exam.questionCount}문항 · 답안 제외'),
              controlAffinity: ListTileControlAffinity.trailing,
            )
        else
          for (final item in _history)
            CheckboxListTile(
              value: _selected.contains(_historyId(item)),
              onChanged: (value) => _toggle(_historyId(item), value ?? false),
              title: Text(
                item.questTitleRaw?.trim().isNotEmpty == true
                    ? item.questTitleRaw!
                    : '문제 ${item.questId ?? item.codebaseId ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                item.hashTags.isEmpty
                    ? item.createdAt
                    : item.hashTags.map((tag) => '#$tag').join(' '),
              ),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF202022),
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _selected.isEmpty || _submitting ? null : _submit,
          child: Text(_submitting ? '공유 중…' : '선택 항목 공유'),
        ),
      ],
    );
  }
}

class _GroupActionSheet extends StatelessWidget {
  const _GroupActionSheet({
    required this.kicker,
    required this.title,
    required this.description,
    required this.children,
  });
  final String kicker;
  final String title;
  final String description;
  final List<Widget> children;

  /// 필요한 변수는 그룹 액션 제목·설명·본문 위젯이다.
  /// 작동 원리는 HTML 그룹 액션을 동일한 모바일 바텀시트 틀과 스크롤로 표시한다.
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 720),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              kicker,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.7,
                color: Colors.black54,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(description, style: const TextStyle(color: Colors.black45)),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _GroupActionRow extends StatelessWidget {
  const _GroupActionRow({
    required this.title,
    required this.detail,
    required this.meta,
  });
  final String title;
  final String detail;
  final String meta;

  /// 필요한 변수는 자료 제목·설명·상태다.
  /// 작동 원리는 그룹 공유 선택과 멤버 상태를 같은 고밀도 행으로 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F6F8),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                detail,
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(meta, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.dark = false});
  final String label;
  final bool dark;

  /// 필요한 변수는 그룹 메타 레이블이다.
  /// 작동 원리는 작은 회색 캡슐로 공개·정원·그룹장 정보를 압축한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: dark
          ? Colors.white.withValues(alpha: .14)
          : const Color(0xFFF5F5F6),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 8,
        color: dark ? Colors.white70 : Colors.black54,
        fontWeight: dark ? FontWeight.w700 : FontWeight.normal,
      ),
    ),
  );
}
