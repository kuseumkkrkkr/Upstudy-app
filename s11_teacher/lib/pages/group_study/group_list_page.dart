import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:s11_teacher/pages/group_study/group_detail_page.dart';
import 'package:s11_teacher/services/api_client.dart';
import 'package:s11_teacher/shared/theme/app_colors.dart';
import 'package:s11_teacher/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11_teacher/widgets/teacher_app_drawer.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  static const String routeName = '/groups';

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  bool _isLoading = true;
  String? _error;
  List<StudyGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groups = await ApiClient.instance.listMyStudyGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
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

  Future<void> _copyText(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCreateDialog() async {
    final created = await showDialog<StudyGroup>(
      context: context,
      builder: (_) => const _CreateTeacherGroupDialog(),
    );
    if (created == null) return;
    if (!mounted) return;
    await _loadGroups();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _ShareDialog(group: created),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _Ios26TeacherShell(
        trailingIcons: const [],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _Ios26TeacherShell(
        trailingIcons: const [],
        child: Center(
          child: Ios26FrostedCard(
            radius: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('오류: $_error'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadGroups,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _Ios26TeacherShell(
      trailingIcons: [
        Ios26ActionIcon(
          icon: Icons.add_rounded,
          label: '그룹 생성',
          onTap: _showCreateDialog,
          active: true,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _loadGroups,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Ios26FrostedCard(
              radius: 30,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '교사용 그룹 관리',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '검색 노출 없이 초대 코드와 링크만으로 입장하는 그룹스터디를 관리합니다.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_groups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 56),
                child: Center(child: Text('아직 생성된 그룹이 없습니다.')),
              ),
            ..._groups.map((group) {
              final inviteUrl = ApiClient.instance.buildStudentInviteUrl(
                group.inviteCode ?? '',
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Ios26FrostedCard(
                  radius: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF27272A,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.school_outlined,
                              color: Color(0xFF27272A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  group.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '교사 생성',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF27272A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            label: '인원',
                            value:
                                '${group.memberIds.length}/${group.maxMembers}',
                          ),
                          _InfoChip(
                            label: '참여코드',
                            value: group.inviteCode ?? '-',
                          ),
                          const _InfoChip(label: '검색', value: '비노출'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _GlassActionButton(
                            onPressed: () => _copyText(
                              group.inviteCode ?? '',
                              '참여코드를 복사했습니다.',
                            ),
                            icon: Icons.pin_outlined,
                            label: '코드 복사',
                          ),
                          const SizedBox(width: 8),
                          _GlassActionButton(
                            onPressed: () =>
                                _copyText(inviteUrl, '초대 링크를 복사했습니다.'),
                            icon: Icons.link_outlined,
                            label: '링크 복사',
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (_) => _ShareDialog(group: group),
                              );
                            },
                            child: const Text('QR 보기'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _FooterButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GroupDetailPage(
                                    groupId: group.groupId,
                                    groupName: group.name,
                                    academyId: '',
                                  ),
                                ),
                              );
                            },
                            label: '관리',
                            filled: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Text(
        '$label  $value',
        style: const TextStyle(fontSize: 12, color: AppColors.primary),
      ),
    );
  }
}

class _CreateTeacherGroupDialog extends StatefulWidget {
  const _CreateTeacherGroupDialog();

  @override
  State<_CreateTeacherGroupDialog> createState() =>
      _CreateTeacherGroupDialogState();
}

class _CreateTeacherGroupDialogState extends State<_CreateTeacherGroupDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _maxCtrl = TextEditingController(text: '20');
  final _inviteCtrl = TextEditingController();
  bool _lockEnabled = false;
  final _passwordCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _maxCtrl.dispose();
    _inviteCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final group = await ApiClient.instance.createStudyGroup(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        maxMembers: int.tryParse(_maxCtrl.text.trim()) ?? 20,
        isPublic: false,
        lockEnabled: _lockEnabled,
        password: _lockEnabled ? _passwordCtrl.text.trim() : null,
        inviteCode: _inviteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(group);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('생성 실패: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Ios26FrostedCard(
        radius: 30,
        child: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '교사용 그룹 생성',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '학생 검색에는 보이지 않고, 공유 코드와 링크만 활성화됩니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 18),
                _Ios26Field(controller: _nameCtrl, label: '그룹명'),
                const SizedBox(height: 10),
                _Ios26Field(
                  controller: _descCtrl,
                  label: '설명',
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                _Ios26Field(
                  controller: _maxCtrl,
                  label: '최대 인원',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _Ios26Field(
                  controller: _inviteCtrl,
                  label: '참여코드',
                  hint: '비워두면 자동 생성',
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    value: _lockEnabled,
                    onChanged: (value) => setState(() => _lockEnabled = value),
                    title: const Text('비밀번호 잠금'),
                  ),
                ),
                if (_lockEnabled) ...[
                  const SizedBox(height: 10),
                  _Ios26Field(controller: _passwordCtrl, label: '비밀번호'),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _FooterButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      label: '취소',
                    ),
                    const SizedBox(width: 8),
                    _FooterButton(
                      onPressed: _isSubmitting ? null : _submit,
                      label: _isSubmitting ? '생성 중' : '생성',
                      filled: true,
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

class _ShareDialog extends StatelessWidget {
  const _ShareDialog({required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final inviteCode = group.inviteCode ?? '';
    final inviteUrl = ApiClient.instance.buildStudentInviteUrl(inviteCode);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Ios26FrostedCard(
        radius: 30,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                group.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              QrImageView(data: inviteUrl, size: 180),
              const SizedBox(height: 12),
              SelectableText('참여코드: $inviteCode'),
              const SizedBox(height: 6),
              SelectableText(inviteUrl, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              _FooterButton(
                onPressed: () => Navigator.of(context).pop(),
                label: '닫기',
                filled: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ios26TeacherShell extends StatelessWidget {
  const _Ios26TeacherShell({required this.child, required this.trailingIcons});

  final Widget child;
  final List<Ios26ActionIcon> trailingIcons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const TeacherAppDrawer(currentRoute: GroupListPage.routeName),
      backgroundColor: Colors.white,
      body: Builder(
        builder: (scaffoldContext) => SafeArea(
          child: Column(
            children: [
              Ios26TopBar(
                brandColor: AppColors.primary,
                title: 'AIFlow 선생님',
                onBack: Navigator.of(context).canPop()
                    ? () => Navigator.of(context).maybePop()
                    : null,
                onMenu: () => Scaffold.of(scaffoldContext).openEndDrawer(),
                items: const [Ios26NavItem(label: '그룹스터디', active: true)],
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

class _GlassActionButton extends StatelessWidget {
  const _GlassActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.surfaceMuted,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.onPressed,
    required this.label,
    this.filled = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Text(label);
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.22)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: child,
    );
  }
}

class _Ios26Field extends StatelessWidget {
  const _Ios26Field({
    required this.controller,
    required this.label,
    this.hint,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int? minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
    );
  }
}
