import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:s11_teacher/pages/group_study/academy_dashboard_page.dart';
import 'package:s11_teacher/services/api_client.dart';
import 'package:s11_teacher/shared/theme/app_colors.dart';
import 'package:s11_teacher/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11_teacher/widgets/teacher_app_drawer.dart';

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.academyId,
  });

  final String groupId;
  final String groupName;
  final String academyId;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  bool _isLoading = true;
  String? _error;
  StudyGroup? _group;
  List<String> _members = [];
  List<AcademyGroupMember> _academyMembers = [];
  List<GroupAssignment> _assignments = [];
  List<StudyGroupNotice> _notices = [];
  Map<String, String> _studentUsernames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groups = await ApiClient.instance.listMyStudyGroups();
      final group = groups.firstWhere((item) => item.groupId == widget.groupId);
      final members = await ApiClient.instance.listGroupMembers(widget.groupId);
      final socialMembers = await ApiClient.instance
          .listStudyGroupMemberProfiles(widget.groupId);
      final academyMembers = widget.academyId.isEmpty
          ? <AcademyGroupMember>[]
          : await ApiClient.instance.listAcademyGroupMembers(
              groupId: widget.groupId,
              status: 'active',
            );
      final assignments = await ApiClient.instance.listAssignments(
        groupId: widget.groupId,
      );
      final notices = await ApiClient.instance.listGroupNotices(widget.groupId);
      if (!mounted) return;
      final studentMembers = academyMembers
          .where((member) => member.role.toLowerCase() == 'student')
          .toList();
      final usernames = {
        for (final member in socialMembers) member.userId: member.username,
      };
      if (studentMembers.isEmpty) {
        studentMembers.addAll(
          socialMembers
              .where((member) => member.userId != group.creatorId)
              .map(
                (member) => AcademyGroupMember(
                  memberId: member.userId,
                  groupId: widget.groupId,
                  userId: member.userId,
                  role: 'student',
                  status: 'active',
                ),
              ),
        );
      }
      setState(() {
        _group = group;
        _members = members;
        _academyMembers = studentMembers;
        _assignments = assignments;
        _notices = notices;
        _studentUsernames = usernames;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label 복사 완료')));
  }

  void _showQrDialog() {
    final group = _group;
    if (group == null) return;
    final inviteUrl = ApiClient.instance.buildStudentInviteUrl(
      group.inviteCode ?? '',
    );
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('참여 QR'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: inviteUrl, size: 190),
              const SizedBox(height: 10),
              SelectableText(inviteUrl, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberTab() {
    if (_members.isEmpty) {
      return const Center(child: Text('아직 참여한 멤버가 없습니다.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      itemBuilder: (_, index) {
        final name = _members[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Ios26FrostedCard(
            radius: 24,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(
                  0xFF45BF63,
                ).withValues(alpha: 0.12),
                child: Text(
                  name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Color(0xFF2C8D46)),
                ),
              ),
              title: Text(name),
              subtitle: const Text('교사 초대 링크 또는 참여코드로 입장'),
            ),
          ),
        );
      },
    );
  }

  Widget _courseTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        children: [
          _buildNoticeCard(),
          const SizedBox(height: 12),
          _LessonHeroTimetable(
            assignments: _assignments,
            students: _academyMembers,
            onDelete: _deleteAssignment,
            onShiftDueDate: _shiftAssignmentDueDate,
          ),
          const SizedBox(height: 12),
          Ios26FrostedCard(
            radius: 24,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _academyMembers.isEmpty ? null : _sendCourse,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('코스 보내주기'),
                ),
                FilledButton.icon(
                  onPressed: _academyMembers.isEmpty ? null : _sendHomework,
                  icon: const Icon(Icons.assignment_turned_in_rounded),
                  label: const Text('숙제 내주기'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.academyId.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AcademyDashboardPage(
                                academyId: widget.academyId,
                                groupId: widget.groupId,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('학습 분석'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _StudentAnalysisList(students: _academyMembers),
        ],
      ),
    );
  }

  Widget _buildNoticeCard() {
    return Ios26FrostedCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '공지사항',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _editNotice(),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('공지 작성'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '그룹 공지는 제목과 내용만 GUI로 입력하고, 삭제는 버튼으로 처리합니다.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (_notices.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.64),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text('등록된 공지사항이 없습니다.'),
            )
          else
            for (final notice in _notices.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: ListTile(
                    onTap: () => _showNoticePreview(notice),
                    title: Text(
                      notice.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${_noticePreviewText(notice.contentHtml)}\n${_noticeTimestamp(notice.updatedAt)}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '수정',
                          onPressed: () => _editNotice(existing: notice),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: '삭제',
                          onPressed: () => _deleteNotice(notice),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<List<String>?> _pickStudents() async {
    final initial = _academyMembers.map((m) => m.userId).toSet();
    return showDialog<List<String>>(
      context: context,
      builder: (_) => _StudentPickerDialog(
        students: _academyMembers,
        initialSelected: initial,
      ),
    );
  }

  Future<void> _sendCourse() async {
    final selectedStudents = await _pickStudents();
    if (selectedStudents == null || selectedStudents.isEmpty) return;
    final courses = await ApiClient.instance.listCoursesV2(mineOnly: true);
    if (!mounted) return;
    final course = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CoursePickerDialog(courses: courses),
    );
    if (course == null) return;
    final dueDate = _courseDueDate(course['duration']?.toString());
    final allSelected = selectedStudents.length == _academyMembers.length;
    await ApiClient.instance.createAssignment(
      groupId: widget.groupId,
      kind: 'course',
      refId: course['id']?.toString() ?? '',
      title: course['title']?.toString(),
      message: '[코스] ${course['title'] ?? '코스'} 배정이 도착했습니다.',
      dueDate: dueDate,
      targetUserIds: selectedStudents,
      chatMode: allSelected ? 'group' : 'direct',
    );
    await _loadData();
  }

  Future<void> _sendHomework() async {
    final selectedStudents = await _pickStudents();
    if (selectedStudents == null || selectedStudents.isEmpty) return;
    final documents = await ApiClient.instance.listTeacherDocuments(
      type: 'textbook',
    );
    if (!mounted) return;
    final document = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DocumentPickerDialog(documents: documents),
    );
    if (document == null || !mounted) return;
    final dueDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (dueDate == null) return;
    final id = _documentId(document);
    final title = document['title']?.toString() ?? '숙제';
    final allSelected = selectedStudents.length == _academyMembers.length;
    await ApiClient.instance.createAssignment(
      groupId: widget.groupId,
      kind: 'homework',
      refId: id,
      title: title,
      message: '[숙제] $title 과제가 도착했습니다.',
      dueDate: _formatDate(dueDate),
      targetUserIds: selectedStudents,
      chatMode: allSelected ? 'group' : 'direct',
    );
    await _loadData();
  }

  Future<void> _deleteAssignment(GroupAssignment assignment) async {
    await ApiClient.instance.deleteAssignment(assignment.assignmentId);
    await _loadData();
  }

  Future<void> _editNotice({StudyGroupNotice? existing}) async {
    final draft = await _showNoticeEditor(existing: existing);
    if (draft == null ||
        draft.title.isEmpty ||
        draft.contentText.trim().isEmpty) {
      return;
    }
    try {
      await ApiClient.instance.upsertGroupNotice(
        groupId: widget.groupId,
        title: draft.title,
        contentHtml: _plainTextToNoticeHtml(draft.contentText),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('공지 처리 실패: $e')));
    }
  }

  Future<void> _deleteNotice(StudyGroupNotice notice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('공지 삭제'),
        content: Text('"${notice.title}" 공지를 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.deleteGroupNoticeByTitle(
        groupId: widget.groupId,
        title: notice.title,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('공지 삭제 실패: $e')));
    }
  }

  Future<_NoticeDraft?> _showNoticeEditor({StudyGroupNotice? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(
      text: existing == null ? '' : _noticePreviewText(existing.contentHtml),
    );
    return showDialog<_NoticeDraft>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? '공지 작성' : '공지 수정'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                minLines: 10,
                maxLines: 16,
                decoration: const InputDecoration(
                  labelText: '내용',
                  hintText: '학생에게 보여줄 공지 내용을 입력하세요.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                _NoticeDraft(
                  title: titleCtrl.text.trim(),
                  contentText: contentCtrl.text,
                ),
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showNoticePreview(StudyGroupNotice notice) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(notice.title),
        content: SizedBox(
          width: 720,
          height: 520,
          child: InAppWebView(
            initialData: InAppWebViewInitialData(
              data: _buildNoticeHtmlDocument(notice.title, notice.contentHtml),
            ),
            initialSettings: InAppWebViewSettings(transparentBackground: true),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _shiftAssignmentDueDate(
    GroupAssignment assignment,
    int days,
  ) async {
    final current = DateTime.tryParse(assignment.dueDate ?? '');
    if (current == null) return;
    final next = current.add(Duration(days: days));
    await ApiClient.instance.updateAssignment(
      assignmentId: assignment.assignmentId,
      dueDate: _formatDate(next),
    );
    await _loadData();
  }

  String? _courseDueDate(String? duration) {
    final days = _parseDurationDays(duration);
    if (days == null) return null;
    return _formatDate(DateTime.now().add(Duration(days: days)));
  }

  int? _parseDurationDays(String? value) {
    final text = (value ?? '').trim().toLowerCase().replaceAll(' ', '');
    if (text.isEmpty) return null;
    final plain = int.tryParse(text);
    if (plain != null) return plain;
    final match = RegExp(
      r'(\d+)(일|주|개월|달|day|days|week|weeks|month|months)',
    ).firstMatch(text);
    if (match == null) return null;
    final amount = int.parse(match.group(1)!);
    final unit = match.group(2)!;
    if (unit == '주' || unit.startsWith('week')) return amount * 7;
    if (unit == '개월' || unit == '달' || unit.startsWith('month')) {
      return amount * 30;
    }
    return amount;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _documentId(Map<String, dynamic> document) {
    return (document['textbook_id'] ??
            document['document_id'] ??
            document['id'] ??
            '')
        .toString();
  }

  Widget _chatTab() {
    return _GroupChatWorkspace(
      groupId: widget.groupId,
      students: _academyMembers,
      studentUsernames: _studentUsernames,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _Ios26DetailShell(
        groupName: widget.groupName,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _Ios26DetailShell(
        groupName: widget.groupName,
        child: Center(
          child: Ios26FrostedCard(radius: 28, child: Text('오류: $_error')),
        ),
      );
    }

    final group = _group!;
    final inviteCode = group.inviteCode ?? '-';
    final inviteUrl = ApiClient.instance.buildStudentInviteUrl(
      group.inviteCode ?? '',
    );

    return _Ios26DetailShell(
      groupName: group.name,
      trailingIcons: [
        Ios26ActionIcon(
          icon: Icons.content_copy_rounded,
          label: '코드 복사',
          onTap: () => _copy(inviteCode, '참여코드'),
        ),
        Ios26ActionIcon(
          icon: Icons.qr_code_rounded,
          label: 'QR 보기',
          onTap: _showQrDialog,
          active: true,
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Ios26FrostedCard(
              radius: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.school_outlined,
                          color: AppColors.primary,
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
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              group.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4FBF6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF7BC58F)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '검색 불가, 코드/URL로만 참가',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('그룹코드: $inviteCode'),
                        const SizedBox(height: 4),
                        Text(
                          inviteUrl,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DetailActionButton(
                              onPressed: () => _copy(inviteCode, '참여코드'),
                              icon: Icons.pin_outlined,
                              label: '코드 복사',
                            ),
                            _DetailActionButton(
                              onPressed: () => _copy(inviteUrl, '초대 링크'),
                              icon: Icons.link_outlined,
                              label: '링크 복사',
                            ),
                            _DetailActionButton(
                              onPressed: _showQrDialog,
                              icon: Icons.qr_code_2,
                              label: 'QR 보기',
                              filled: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Ios26FrostedCard(
              radius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.black54,
                indicator: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                tabs: const [
                  Tab(text: '멤버'),
                  Tab(text: '수업'),
                  Tab(text: '채팅'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBarView(
                controller: _tabController,
                children: [_memberTab(), _courseTab(), _chatTab()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _noticePreviewText(String html) {
  final plain = html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return plain.isEmpty ? '본문 없음' : plain;
}

String _noticeTimestamp(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}';
}

String _plainTextToNoticeHtml(String text) {
  final escaped = text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .trim();
  if (escaped.isEmpty) return '';
  return escaped
      .split(RegExp(r'\r?\n\r?\n'))
      .map((block) => '<p>${block.replaceAll('\n', '<br>')}</p>')
      .join();
}

String _buildNoticeHtmlDocument(String title, String body) {
  return '''
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      margin: 0;
      padding: 20px;
      color: #173321;
      background: #f6fbf7;
    }
    article {
      background: #ffffff;
      border-radius: 18px;
      padding: 24px;
      box-shadow: 0 12px 28px rgba(27, 64, 43, 0.08);
    }
    h1 { margin-top: 0; font-size: 28px; }
    img { max-width: 100%; height: auto; }
    table { width: 100%; border-collapse: collapse; }
    td, th { border: 1px solid #d9e5dc; padding: 8px; }
  </style>
</head>
<body>
  <article>
    <h1>$title</h1>
    $body
  </article>
</body>
</html>
''';
}

class _NoticeDraft {
  const _NoticeDraft({required this.title, required this.contentText});

  final String title;
  final String contentText;
}

class _Ios26DetailShell extends StatelessWidget {
  const _Ios26DetailShell({
    required this.groupName,
    required this.child,
    this.trailingIcons = const [],
  });

  final String groupName;
  final Widget child;
  final List<Ios26ActionIcon> trailingIcons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const TeacherAppDrawer(currentRoute: '/groups'),
      backgroundColor: Colors.white,
      body: Builder(
        builder: (scaffoldContext) => SafeArea(
          child: Column(
            children: [
              Ios26TopBar(
                brandColor: AppColors.primary,
                title: 'AIFlow 선생님',
                onBack: () => Navigator.of(context).maybePop(),
                onMenu: () => Scaffold.of(scaffoldContext).openEndDrawer(),
                items: [
                  const Ios26NavItem(label: '그룹스터디'),
                  Ios26NavItem(label: groupName, active: true),
                ],
                trailingIcons: trailingIcons,
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupChatWorkspace extends StatefulWidget {
  const _GroupChatWorkspace({
    required this.groupId,
    required this.students,
    required this.studentUsernames,
  });

  final String groupId;
  final List<AcademyGroupMember> students;
  final Map<String, String> studentUsernames;

  @override
  State<_GroupChatWorkspace> createState() => _GroupChatWorkspaceState();
}

class _GroupChatWorkspaceState extends State<_GroupChatWorkspace> {
  @override
  Widget build(BuildContext context) {
    return Ios26FrostedCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            '채팅',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _ChatRoomTile(
            icon: Icons.forum_outlined,
            title: '그룹스터디 단체채팅',
            subtitle: '이 그룹 전체에게 보내는 채팅방',
            onTap: () => _openGroupChat(context),
          ),
          const SizedBox(height: 8),
          if (widget.students.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('소속 학생이 없습니다.')),
            )
          else
            for (final student in widget.students) ...[
              _ChatRoomTile(
                icon: Icons.chat_bubble_outline,
                title: _studentLabel(student),
                subtitle: '개인채팅',
                onTap: () => _openDirectChat(context, student),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  String _studentLabel(AcademyGroupMember student) {
    final username = widget.studentUsernames[student.userId];
    if (username != null && username.trim().isNotEmpty) return username.trim();
    return student.userId;
  }

  String _peerUsername(AcademyGroupMember student) {
    final username = widget.studentUsernames[student.userId];
    if (username != null && username.trim().isNotEmpty) return username.trim();
    return student.userId;
  }

  void _openGroupChat(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _ChatRoomDialog(
        title: '그룹스터디 단체채팅',
        child: _GroupMessagePanel(groupId: widget.groupId),
      ),
    );
  }

  void _openDirectChat(BuildContext context, AcademyGroupMember student) {
    showDialog<void>(
      context: context,
      builder: (_) => _ChatRoomDialog(
        title: _studentLabel(student),
        child: _DirectMessageRoom(peerUsername: _peerUsername(student)),
      ),
    );
  }
}

class _ChatRoomTile extends StatelessWidget {
  const _ChatRoomTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatRoomDialog extends StatelessWidget {
  const _ChatRoomDialog({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 720,
        height: 640,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(padding: const EdgeInsets.all(12), child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupMessagePanel extends StatefulWidget {
  const _GroupMessagePanel({required this.groupId});

  final String groupId;

  @override
  State<_GroupMessagePanel> createState() => _GroupMessagePanelState();
}

class _GroupMessagePanelState extends State<_GroupMessagePanel> {
  final _controller = TextEditingController();
  bool _loading = true;
  List<StudyGroupMessage> _messages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final messages = await ApiClient.instance.fetchStudyGroupMessages(
        groupId: widget.groupId,
        limit: 80,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await ApiClient.instance.sendStudyGroupMessage(
      groupId: widget.groupId,
      text: text,
    );
    _controller.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return _ChatShell(
      title: '그룹스터디 단체채팅',
      icon: Icons.forum_outlined,
      loading: _loading,
      messages: [
        for (final message in _messages)
          _ChatBubbleData(
            sender: message.userId,
            text: message.text,
            isMine: false,
          ),
      ],
      controller: _controller,
      onRefresh: _load,
      onSend: _send,
    );
  }
}

class _DirectMessageRoom extends StatefulWidget {
  const _DirectMessageRoom({required this.peerUsername});

  final String peerUsername;

  @override
  State<_DirectMessageRoom> createState() => _DirectMessageRoomState();
}

class _DirectMessageRoomState extends State<_DirectMessageRoom> {
  final _controller = TextEditingController();
  bool _loading = false;
  List<DirectMessage> _messages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _DirectMessageRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peerUsername != widget.peerUsername) _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.peerUsername.isEmpty) {
      setState(() => _messages = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final messages = await ApiClient.instance.fetchDirectMessages(
        peerUsername: widget.peerUsername,
        limit: 80,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages.reversed.toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.peerUsername.isEmpty) return;
    await ApiClient.instance.sendDirectMessage(
      peerUsername: widget.peerUsername,
      text: text,
    );
    _controller.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return _ChatShell(
      title: '개인채팅',
      icon: Icons.chat_bubble_outline,
      loading: _loading,
      messages: [
        for (final message in _messages)
          _ChatBubbleData(
            sender: message.from,
            text: message.text,
            isMine: message.isMine,
          ),
      ],
      controller: _controller,
      onRefresh: _load,
      onSend: _send,
    );
  }
}

class _ChatShell extends StatelessWidget {
  const _ChatShell({
    required this.title,
    required this.icon,
    required this.loading,
    required this.messages,
    required this.controller,
    required this.onRefresh,
    required this.onSend,
  });

  final String title;
  final IconData icon;
  final bool loading;
  final List<_ChatBubbleData> messages;
  final TextEditingController controller;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Ios26FrostedCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '새로고침',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Expanded(
            child: _ChatMessageList(loading: loading, messages: messages),
          ),
          _ChatInput(controller: controller, onSend: onSend),
        ],
      ),
    );
  }
}

class _ChatMessageList extends StatelessWidget {
  const _ChatMessageList({required this.loading, required this.messages});

  final bool loading;
  final List<_ChatBubbleData> messages;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (messages.isEmpty) return const Center(child: Text('아직 메시지가 없습니다.'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return Align(
          alignment: message.isMine
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: message.isMine
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!message.isMine)
                  Text(
                    message.sender,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                Text(message.text),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({required this.controller, required this.onSend});

  final TextEditingController controller;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '메시지 입력',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.82),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) {
              onSend();
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onSend,
          icon: const Icon(Icons.send_rounded),
          tooltip: '전송',
        ),
      ],
    );
  }
}

class _ChatBubbleData {
  const _ChatBubbleData({
    required this.sender,
    required this.text,
    required this.isMine,
  });

  final String sender;
  final String text;
  final bool isMine;
}

class _LessonHeroTimetable extends StatelessWidget {
  const _LessonHeroTimetable({
    required this.assignments,
    required this.students,
    required this.onDelete,
    required this.onShiftDueDate,
  });

  final List<GroupAssignment> assignments;
  final List<AcademyGroupMember> students;
  final ValueChanged<GroupAssignment> onDelete;
  final void Function(GroupAssignment assignment, int days) onShiftDueDate;

  @override
  Widget build(BuildContext context) {
    final sorted = [...assignments]
      ..sort((a, b) {
        final ad = a.dueDate ?? '9999-99-99';
        final bd = b.dueDate ?? '9999-99-99';
        return ad.compareTo(bd);
      });
    return Ios26FrostedCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '수업 타임테이블',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text('${students.length}명'),
            ],
          ),
          const SizedBox(height: 14),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('아직 배정된 코스나 숙제가 없습니다.')),
            )
          else
            ...sorted.map(
              (assignment) => _AssignmentRow(
                assignment: assignment,
                onDelete: () => onDelete(assignment),
                onMinusDay: () => onShiftDueDate(assignment, -1),
                onPlusDay: () => onShiftDueDate(assignment, 1),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.assignment,
    required this.onDelete,
    required this.onMinusDay,
    required this.onPlusDay,
  });

  final GroupAssignment assignment;
  final VoidCallback onDelete;
  final VoidCallback onMinusDay;
  final VoidCallback onPlusDay;

  @override
  Widget build(BuildContext context) {
    final isCourse = assignment.kind == 'course';
    final due = assignment.dueDate?.isNotEmpty == true
        ? assignment.dueDate!
        : '기한 없음';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(
            isCourse ? Icons.menu_book_rounded : Icons.assignment_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.title ?? assignment.refId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${isCourse ? '코스' : '숙제'} · $due · ${assignment.refId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '하루 줄이기',
            onPressed: assignment.dueDate == null ? null : onMinusDay,
            icon: const Icon(Icons.remove_rounded),
          ),
          IconButton(
            tooltip: '하루 늘리기',
            onPressed: assignment.dueDate == null ? null : onPlusDay,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: '삭제',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _StudentPickerDialog extends StatefulWidget {
  const _StudentPickerDialog({
    required this.students,
    required this.initialSelected,
  });

  final List<AcademyGroupMember> students;
  final Set<String> initialSelected;

  @override
  State<_StudentPickerDialog> createState() => _StudentPickerDialogState();
}

class _StudentPickerDialogState extends State<_StudentPickerDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelected};
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('학생 선택'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            CheckboxListTile(
              value: _selected.length == widget.students.length,
              onChanged: (value) {
                setState(() {
                  _selected.clear();
                  if (value == true) {
                    _selected.addAll(widget.students.map((e) => e.userId));
                  }
                });
              },
              title: const Text('전체 학생'),
            ),
            const Divider(),
            for (final student in widget.students)
              CheckboxListTile(
                value: _selected.contains(student.userId),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selected.add(student.userId);
                    } else {
                      _selected.remove(student.userId);
                    }
                  });
                },
                title: Text(student.userId),
                subtitle: Text(student.role),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected.toList()),
          child: const Text('선택'),
        ),
      ],
    );
  }
}

class _CoursePickerDialog extends StatelessWidget {
  const _CoursePickerDialog({required this.courses});

  final List<Map<String, dynamic>> courses;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('코스 선택'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: courses.isEmpty
            ? const Center(child: Text('보유 코스가 없습니다.'))
            : ListView.builder(
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  return ListTile(
                    leading: const Icon(Icons.menu_book_rounded),
                    title: Text(course['title']?.toString() ?? '제목 없음'),
                    subtitle: Text(
                      '권장 기간 ${course['duration']?.toString() ?? '미지정'}',
                    ),
                    onTap: () => Navigator.of(context).pop(course),
                  );
                },
              ),
      ),
    );
  }
}

class _DocumentPickerDialog extends StatelessWidget {
  const _DocumentPickerDialog({required this.documents});

  final List<Map<String, dynamic>> documents;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('문서함'),
      content: SizedBox(
        width: 560,
        height: 440,
        child: documents.isEmpty
            ? const Center(child: Text('문서함에 교재가 없습니다.'))
            : ListView.builder(
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final doc = documents[index];
                  final id =
                      (doc['textbook_id'] ??
                              doc['document_id'] ??
                              doc['id'] ??
                              '')
                          .toString();
                  return ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(doc['title']?.toString() ?? '제목 없음'),
                    subtitle: Text(
                      '${doc['category']?.toString() ?? '미분류'} · $id',
                    ),
                    onTap: () => Navigator.of(context).pop(doc),
                  );
                },
              ),
      ),
    );
  }
}

class _StudentAnalysisList extends StatelessWidget {
  const _StudentAnalysisList({required this.students});

  final List<AcademyGroupMember> students;

  @override
  Widget build(BuildContext context) {
    return Ios26FrostedCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '학습 분석',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('활성 학생이 없습니다.')),
            )
          else
            for (final student in students)
              _StudentRatingTile(userId: student.userId),
        ],
      ),
    );
  }
}

class _StudentRatingTile extends StatefulWidget {
  const _StudentRatingTile({required this.userId});

  final String userId;

  @override
  State<_StudentRatingTile> createState() => _StudentRatingTileState();
}

class _StudentRatingTileState extends State<_StudentRatingTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiClient.instance.fetchStudentAnalysis(widget.userId),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.analytics_outlined),
            title: Text(widget.userId),
            subtitle: Text(
              snapshot.hasError ? '분석 데이터를 불러오지 못했습니다.' : '분석 데이터 로딩 중',
            ),
            trailing: snapshot.hasError
                ? const Icon(Icons.error_outline, color: Colors.red)
                : const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
          );
        }
        final rating = Map<String, dynamic>.from(
          data['rating'] as Map? ?? const {},
        );
        final ovr = _num(rating['ovr']);
        final delta = _num(rating['ovr_delta']);
        final accuracy = _num(rating['recent_accuracy']);
        final recent = (rating['recent_results'] as List? ?? const [])
            .map((e) => _num(e))
            .toList();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: Text(widget.userId),
                subtitle: Text(
                  'OVR ${ovr.toStringAsFixed(1)} · 최근 50문제 ${(accuracy * 100).toStringAsFixed(0)}%',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      delta.toStringAsFixed(1),
                      style: TextStyle(
                        color: delta >= 0 ? AppColors.primary : Colors.red,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                      ),
                      onPressed: () => setState(() => _expanded = !_expanded),
                    ),
                  ],
                ),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetricStrip(
                        ovr: ovr,
                        delta: delta,
                        accuracy: accuracy,
                        recent: recent,
                      ),
                      const SizedBox(height: 12),
                      _WeaknessGraph(items: _list(data['weakness_tags'])),
                      const SizedBox(height: 12),
                      _HistoryList(items: _list(data['solve_history'])),
                      const SizedBox(height: 12),
                      _LevelTestAnalysisList(
                        items: _list(data['level_test_analysis']),
                      ),
                      const SizedBox(height: 12),
                      _ProgressList(
                        title: '배정된 숙제 진행 상태',
                        icon: Icons.assignment_turned_in_outlined,
                        items: _list(data['homework']),
                      ),
                      const SizedBox(height: 12),
                      _ProgressList(
                        title: '배정된 코스 진행 상태',
                        icon: Icons.menu_book_outlined,
                        items: _list(data['courses']),
                      ),
                      const SizedBox(height: 12),
                      _ScheduleList(items: _list(data['student_schedule'])),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({
    required this.ovr,
    required this.delta,
    required this.accuracy,
    required this.recent,
  });

  final double ovr;
  final double delta;
  final double accuracy;
  final List<double> recent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricChip(label: 'OVR', value: ovr.toStringAsFixed(1)),
            _MetricChip(
              label: '최근 50문제',
              value: '${(accuracy * 100).toStringAsFixed(0)}%',
            ),
            _MetricChip(label: '변화량', value: delta.toStringAsFixed(1)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final value in recent.take(50))
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: value > 0 ? 30 : 10,
                    decoration: BoxDecoration(
                      color: value > 0
                          ? AppColors.primary
                          : Colors.red.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              if (recent.isEmpty) const Expanded(child: Text('최근 풀이 기록 없음')),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBF6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _WeaknessGraph extends StatelessWidget {
  const _WeaknessGraph({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final maxCount = items
        .map((e) => (e['count'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return _SectionBox(
      title: '자주 틀리는 태그',
      icon: Icons.bar_chart_rounded,
      child: items.isEmpty
          ? const Text('약점 태그 없음')
          : Column(
              children: [
                for (final item in items.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            item['tag']?.toString() ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: maxCount <= 0
                                ? 0
                                : (((item['count'] as num?)?.toDouble() ?? 0) /
                                      maxCount),
                            minHeight: 8,
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.07,
                            ),
                            color: Colors.red.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${item['count'] ?? 0}'),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return _SectionBox(
      title: '최근 풀이 이력',
      icon: Icons.history_rounded,
      child: items.isEmpty
          ? const Text('최근 풀이 이력 없음')
          : Column(
              children: [
                for (final item in items.take(5))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${item['kind'] ?? '-'} · ${item['quest_id'] ?? item['exam_id'] ?? '-'}',
                    ),
                    subtitle: Text(item['created_at']?.toString() ?? ''),
                  ),
              ],
            ),
    );
  }
}

class _LevelTestAnalysisList extends StatelessWidget {
  const _LevelTestAnalysisList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return _SectionBox(
      title: '레벨 테스트 분석',
      icon: Icons.trending_up_rounded,
      child: items.isEmpty
          ? const Text('레벨 테스트 분석 없음')
          : Column(
              children: [
                for (final item in items.take(5))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item['exam_title']?.toString().isNotEmpty == true
                          ? item['exam_title'].toString()
                          : item['exam_id']?.toString() ?? '레벨 테스트',
                    ),
                    subtitle: Text(_subtitle(item)),
                    trailing: Text(
                      item['passed'] == true ? '통과' : '미통과',
                      style: TextStyle(
                        color: item['passed'] == true
                            ? AppColors.primary
                            : Colors.red,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  static String _percent(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return '${number.toStringAsFixed(0)}%';
  }

  static String _subtitle(Map<String, dynamic> item) {
    final ai = item['ai_summary'] is Map
        ? Map<String, dynamic>.from(item['ai_summary'] as Map)
        : const <String, dynamic>{};
    final summary = ai['summary']?.toString().trim() ?? '';
    final base =
        '정답률 ${_percent(item['accuracy'])} · 오답 ${item['incorrect_count'] ?? 0}문항 · 보관 ${item['expires_at'] ?? '-'}까지';
    return summary.isEmpty ? base : '$base\n$summary';
  }
}

class _ProgressList extends StatelessWidget {
  const _ProgressList({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return _SectionBox(
      title: title,
      icon: icon,
      child: items.isEmpty
          ? const Text('배정 항목 없음')
          : Column(
              children: [
                for (final item in items.take(8))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item['title']?.toString() ??
                          item['ref_id']?.toString() ??
                          '-',
                    ),
                    subtitle: Text(
                      '기한 ${item['due_date'] ?? '없음'} · 상태 ${item['status'] ?? '-'}',
                    ),
                    trailing: item.containsKey('progress')
                        ? Text(
                            '${(((item['progress'] as num?)?.toDouble() ?? 0) * 100).toStringAsFixed(0)}%',
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return _SectionBox(
      title: '학생이 등록한 세부 일정',
      icon: Icons.event_note_rounded,
      child: items.isEmpty
          ? const Text('학생 등록 일정 없음')
          : Column(
              children: [
                for (final item in items.take(10))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['title']?.toString() ?? '-'),
                    subtitle: Text(item['date']?.toString() ?? ''),
                  ),
              ],
            ),
    );
  }
}

class _SectionBox extends StatelessWidget {
  const _SectionBox({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 7),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailActionButton extends StatelessWidget {
  const _DetailActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.filled = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.surfaceMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
