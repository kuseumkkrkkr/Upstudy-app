import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/business/repositories/exam_paper_store.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

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
  final AcademyGroup? initialGroup;
  final List<AcademyGroupMember>? initialMembers;
  final List<SolveHistoryItem>? initialShareHistory;
  final List<ExamPaperEntry>? initialShareExams;
  final List<StudyGroupMessage>? initialChatMessages;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  AcademyGroup? _group;
  List<AcademyGroupMember> _members = const [];
  bool _loading = true;
  String? _error;
  bool _showExamPapers = false;

  /// 필요한 변수는 선택적 그룹·멤버 초기값이다.
  /// 작동 원리는 초기값이 있으면 즉시 렌더하고 실제 진입은 그룹과 멤버 GET을 병렬 실행하는 것이다.
  @override
  void initState() {
    super.initState();
    if (widget.initialGroup != null) {
      _group = widget.initialGroup;
      _members = widget.initialMembers ?? const [];
      _loading = false;
    } else {
      unawaited(_load());
    }
  }

  /// 필요한 변수는 그룹 ID다.
  /// 작동 원리는 그룹 메타와 멤버를 동시에 요청해 한 번의 화면 갱신으로 반영하는 것이다.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        ApiClient.instance.getAcademyGroup(widget.groupId),
        ApiClient.instance.listGroupMembers(widget.groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _group = responses[0].data as AcademyGroup?;
        _members = (responses[1].data as List<AcademyGroupMember>?) ?? const [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '그룹 정보를 불러오지 못했습니다.';
        _loading = false;
      });
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
        memberCount: _members.length,
        initialMessages: widget.initialChatMessages,
      ),
    );
  }

  /// 필요한 변수는 현재 그룹 멤버 목록이다.
  /// 작동 원리는 HTML 그룹 멤버 모달처럼 역할·접속 상태를 목록으로 표시한다.
  void _openMembers() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _GroupActionSheet(
        kicker: '${_members.length} MEMBERS',
        title: '그룹 멤버',
        description: '현재 그룹의 멤버와 역할을 확인합니다.',
        children: [
          for (final member in _members)
            _GroupActionRow(
              title: member.userId,
              detail: member.role,
              meta: member.status,
            ),
          if (_members.isEmpty)
            const _GroupActionRow(
              title: '김학생 · 나',
              detail: '멤버 · 온라인',
              meta: 'B',
            ),
        ],
      ),
    );
  }

  /// 필요한 변수는 현재 자료 탭이다.
  /// 작동 원리는 Flow에서는 태그·공유자·기간을, 시험지에서는 제목·공유자를 입력하는 HTML 필터 시트를 연다.
  void _openResourceFilter() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _GroupActionSheet(
        kicker: _showExamPapers ? 'GROUP EXAM FILTER' : 'GROUP FLOW FILTER',
        title: _showExamPapers ? '공유 시험지 필터' : '공유 Flow 필터',
        description: '태그, 공유자, 날짜 범위를 함께 적용해 그룹 자료를 찾습니다.',
        children: [
          const TextField(
            decoration: InputDecoration(
              labelText: '태그',
              hintText: '#일차함수 #기울기',
            ),
          ),
          const SizedBox(height: 10),
          const TextField(
            decoration: InputDecoration(labelText: '공유자', hintText: '이수학'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: '최근 7일',
            decoration: const InputDecoration(labelText: '기간'),
            items: const ['최근 7일', '최근 30일', '전체 기간']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(growable: false),
            onChanged: (_) {},
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF202022),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('필터 적용'),
          ),
        ],
      ),
    );
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

  /// 필요한 변수는 그룹·멤버 로딩 상태와 현재 자료 탭이다.
  /// 작동 원리는 HTML 그룹 공간의 소개, 그룹 카드, 자료 전환, 공유 풀이 순서로 렌더링하는 것이다.
  @override
  Widget build(BuildContext context) {
    final group = _group;
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
                        padding: const EdgeInsets.fromLTRB(14, 24, 14, 40),
                        children: [
                          const Text(
                            'GROUP SPACE',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.7,
                              color: Colors.black54,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            group?.name ?? '그룹 스터디',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '공지와 함께 만든 학습 자료를 확인하고, 채팅은 필요할 때 모달로 엽니다.',
                            style: TextStyle(color: Colors.black45),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Text('그룹 목록'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF202022),
                            ),
                            onPressed: _openChat,
                            child: Text('채팅 열기 · ${_members.length}'),
                          ),
                          const SizedBox(height: 12),
                          _GroupHero(
                            group: group,
                            memberCount: _members.length,
                            onMembers: _openMembers,
                          ),
                          const SizedBox(height: 12),
                          _ResourceSwitch(
                            showExamPapers: _showExamPapers,
                            onChanged: (value) =>
                                setState(() => _showExamPapers = value),
                          ),
                          const SizedBox(height: 12),
                          _SharedResourcesCard(
                            showExamPapers: _showExamPapers,
                            onFilter: _openResourceFilter,
                            onShare: _openShareResource,
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

class _GroupHero extends StatelessWidget {
  const _GroupHero({
    required this.group,
    required this.memberCount,
    required this.onMembers,
  });
  final AcademyGroup? group;
  final int memberCount;
  final VoidCallback onMembers;

  /// 필요한 변수는 그룹 정보와 현재 멤버 수다.
  /// 작동 원리는 공개·정원·과목 메타와 오늘 공지를 하나의 둥근 그룹 카드에 배치하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE0E0E2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF202022),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '함',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
                        label: group?.searchable == true ? '공개 그룹' : '비공개 그룹',
                      ),
                      _MetaPill(
                        label: '$memberCount / ${group?.maxMembers ?? 20}명',
                      ),
                      _MetaPill(label: group?.grade ?? '그룹장 이수학'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    group?.subject ?? '함수와 도형을 함께 공부하는 중학교 스터디',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 28, color: Color(0xFFE2E2E4)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onMembers,
            icon: const Icon(Icons.group_outlined, size: 17),
            label: const Text('멤버 보기'),
          ),
        ),
        const Row(
          children: [
            Expanded(
              child: Text(
                '오늘 20시 일차함수 챌린지',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '시험지는 19:50에 공유됩니다.',
              style: TextStyle(fontSize: 9, color: Colors.black45),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ResourceSwitch extends StatelessWidget {
  const _ResourceSwitch({
    required this.showExamPapers,
    required this.onChanged,
  });
  final bool showExamPapers;
  final ValueChanged<bool> onChanged;

  /// 필요한 변수는 시험지 탭 선택 여부다.
  /// 작동 원리는 그룹 문제풀이와 시험지를 두 칸 카드로 전환하고 활성 자료만 검게 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE0E0E2)),
    ),
    child: Row(
      children: [
        _ResourceButton(
          label: '그룹 문제풀기',
          subtitle: '공유 Flow 8',
          selected: !showExamPapers,
          onTap: () => onChanged(false),
        ),
        _ResourceButton(
          label: '그룹 시험지',
          subtitle: '공유 3',
          selected: showExamPapers,
          onTap: () => onChanged(true),
        ),
      ],
    ),
  );
}

class _ResourceButton extends StatelessWidget {
  const _ResourceButton({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF202022) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: selected ? Colors.white54 : Colors.black45,
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
    required this.showExamPapers,
    required this.onFilter,
    required this.onShare,
  });
  final bool showExamPapers;
  final VoidCallback onFilter;
  final VoidCallback onShare;

  /// 필요한 변수는 현재 선택 자료 탭이다.
  /// 작동 원리는 공유 풀이 또는 시험지의 대표 항목을 필터·공유 버튼과 함께 큰 콘텐츠 카드로 표시하는 것이다.
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
        Text(
          showExamPapers ? '그룹 시험지' : '그룹 문제풀이',
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onFilter,
                child: const Text('필터'),
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
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFB),
            border: Border.all(color: const Color(0xFFE0E0E2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                showExamPapers ? '일차함수 주간 테스트' : '두 점을 지나는 일차함수',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '#일차함수   #기울기',
                style: TextStyle(fontSize: 10, color: Colors.black45),
              ),
              const Divider(height: 28),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '김학생 · 오늘 14:32',
                    style: TextStyle(fontSize: 10, color: Colors.black45),
                  ),
                  Text('열람 ›', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GroupChatSheet extends StatefulWidget {
  const _GroupChatSheet({
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    this.initialMessages,
  });

  final String groupId;
  final String groupName;
  final int memberCount;
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
  String? _error;

  /// 필요한 변수는 선택적 초기 메시지 또는 그룹 메시지 API다.
  /// 작동 원리는 시트가 열릴 때 최근 30개만 불러와 첫 렌더의 DB·네트워크 부하를 제한하는 것이다.
  @override
  void initState() {
    super.initState();
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
      _messages =
          widget.initialMessages ??
          await ApiClient.instance.fetchStudyGroupMessages(
            groupId: widget.groupId,
            limit: 30,
          );
    } catch (_) {
      _error = '최근 대화를 불러오지 못했습니다.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 필요한 변수는 현재 가장 오래된 메시지 시각과 그룹 ID다.
  /// 작동 원리는 이전 30개를 앞에 합치고 중복 ID를 제거하며 최대 500개까지만 보존하는 것이다.
  Future<void> _loadPrevious() async {
    if (_loadingPrevious || _messages.isEmpty) return;
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
        _messages = [
          ...previous.where((item) => !ids.contains(item.messageId)),
          ..._messages,
        ].take(_maxMessages).toList(growable: false);
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
  /// 작동 원리는 HTML 그룹 채팅의 상태 행, 최근 대화, 고정 작성기를 720px 이내 시트에 배치하는 것이다.
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: SizedBox(
        height: 620,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GROUP CHAT',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.7,
                color: Colors.black54,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.groupName} 채팅',
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              '${widget.memberCount}명 · 최근 30개부터 표시 · 최대 500개',
              style: const TextStyle(color: Colors.black45),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _messages.isEmpty || _loadingPrevious
                    ? null
                    : _loadPrevious,
                child: Text(_loadingPrevious ? '불러오는 중…' : '이전 메시지 더보기'),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _messages.isEmpty
                  ? Center(child: Text(_error!))
                  : _messages.isEmpty
                  ? const Center(child: Text('첫 메시지를 남겨 보세요.'))
                  : ListView.separated(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      message.userId.isEmpty
                                          ? '그룹 멤버'
                                          : message.userId,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    message.createdAt,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(message.text),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: '그룹에 메시지를 입력하세요',
                suffixIcon: IconButton(
                  tooltip: '메시지 전송',
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
  const _MetaPill({required this.label});
  final String label;

  /// 필요한 변수는 그룹 메타 레이블이다.
  /// 작동 원리는 작은 회색 캡슐로 공개·정원·그룹장 정보를 압축한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F6),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 8, color: Colors.black54),
    ),
  );
}
