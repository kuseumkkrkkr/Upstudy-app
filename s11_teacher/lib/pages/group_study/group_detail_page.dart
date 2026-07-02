import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      if (!mounted) return;
      setState(() {
        _group = group;
        _members = members;
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
    final hasAcademyContext = widget.academyId.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hasAcademyContext
                ? '수업/운영 화면은 기존 대시보드를 그대로 사용합니다.'
                : '이 그룹은 학원 대시보드와 연결되어 있지 않습니다.',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          if (hasAcademyContext) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AcademyDashboardPage(
                      academyId: widget.academyId,
                      groupId: widget.groupId,
                    ),
                  ),
                );
              },
              child: const Text('대시보드 열기'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chatTab() {
    return const Center(
      child: Text(
        '그룹 채팅 기능은 학생용 그룹과 같은 서버 흐름을 사용합니다.',
        style: TextStyle(fontSize: 14, color: Colors.black54),
      ),
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
      backgroundColor: const Color(0xFFF2F7F3),
      body: Builder(
        builder: (scaffoldContext) => Stack(
          children: [
            Positioned(
              top: -100,
              right: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x3345BF63),
                ),
              ),
            ),
            Positioned(
              left: -80,
              bottom: -70,
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x221B402B),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Ios26TopBar(
                    brandColor: AppColors.primary,
                    title: 'AIFlow Teacher',
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
          ],
        ),
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
        backgroundColor: Colors.white.withValues(alpha: 0.62),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
