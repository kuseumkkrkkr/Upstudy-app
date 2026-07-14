import 'dart:async';

import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({
    super.key,
    required this.groupId,
    this.initialGroup,
    this.initialMembers,
  });

  final String groupId;
  final AcademyGroup? initialGroup;
  final List<AcademyGroupMember>? initialMembers;

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
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_group?.name ?? '그룹'} 채팅',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            for (final member in _members.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(member.userId),
                subtitle: Text(member.role),
              ),
            const TextField(
              decoration: InputDecoration(
                hintText: '메시지 입력',
                suffixIcon: Icon(Icons.send_rounded),
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
                          ),
                          const SizedBox(height: 12),
                          _ResourceSwitch(
                            showExamPapers: _showExamPapers,
                            onChanged: (value) =>
                                setState(() => _showExamPapers = value),
                          ),
                          const SizedBox(height: 12),
                          _SharedResourcesCard(showExamPapers: _showExamPapers),
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
  const _GroupHero({required this.group, required this.memberCount});
  final AcademyGroup? group;
  final int memberCount;

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
  const _SharedResourcesCard({required this.showExamPapers});
  final bool showExamPapers;

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
              child: OutlinedButton(onPressed: () {}, child: const Text('필터')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF202022),
                ),
                onPressed: () {},
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
