import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:s11_teacher/pages/group_study/group_detail_page.dart';
import 'package:s11_teacher/services/api_client.dart';
import 'package:s11_teacher/shared/theme/app_colors.dart';
import 'package:s11_teacher/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11_teacher/shared/ui/ios26/teacher_adaptive_panel.dart';
import 'package:s11_teacher/shared/ui/ios26/teacher_studio_shell.dart';
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
    final created = await showTeacherAdaptivePanel<StudyGroup>(
      context: context,
      eyebrow: 'NEW PRIVATE CLASS',
      title: '새 그룹 설계',
      description: '학생 공개 검색 없이 초대 링크로만 참여하는 수업 공간을 만듭니다.',
      icon: Icons.group_add_rounded,
      barrierDismissible: false,
      bodyBuilder: (_) => const _CreateTeacherGroupDialog(),
    );
    if (created == null) return;
    if (!mounted) return;
    await _loadGroups();
    if (!mounted) return;
    await _showSharePanel(created);
  }

  /// 필요 변수: 생성되었거나 기존에 선택한 그룹.
  /// 작동 원리: 작은 QR 팝업 대신 복사 가능한 코드·링크와 QR을 한 작업면에 제공한다.
  Future<void> _showSharePanel(StudyGroup group) {
    return showTeacherAdaptivePanel<void>(
      context: context,
      eyebrow: 'INVITE STUDENTS',
      title: '${group.name} 공유',
      description: '학생은 참여코드나 QR 링크 중 편한 방식으로 입장할 수 있습니다.',
      icon: Icons.ios_share_rounded,
      maxWidth: 520,
      bodyBuilder: (_) => _ShareDialog(group: group),
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
                              _showSharePanel(group);
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelSectionLabel(
            index: '01',
            title: '기본 정보',
            description: '학생 화면에서 구분하기 쉬운 이름과 설명을 입력하세요.',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE3E3E7)),
            ),
            child: Column(
              children: [
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
              ],
            ),
          ),
          const SizedBox(height: 22),
          _PanelSectionLabel(
            index: '02',
            title: '입장 방식',
            description: '참여코드는 자동 생성하거나 직접 지정할 수 있습니다.',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE3E3E7)),
            ),
            child: Column(
              children: [
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
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: TeacherPanelAction(
              label: _isSubmitting ? '그룹 생성 중' : '이 설정으로 그룹 만들기',
              icon: Icons.arrow_forward_rounded,
              primary: true,
              onTap: _isSubmitting ? null : _submit,
            ),
          ),
        ],
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
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE3E3E7)),
          ),
          child: Column(
            children: [
              QrImageView(data: inviteUrl, size: 210),
              const SizedBox(height: 14),
              const Text(
                '카메라로 스캔',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 5),
              const Text(
                '학생 기기에서 바로 참여 화면을 엽니다.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ShareValueCard(
          label: '참여코드',
          value: inviteCode,
          onCopy: () => Clipboard.setData(ClipboardData(text: inviteCode)),
        ),
        const SizedBox(height: 10),
        _ShareValueCard(
          label: '초대 링크',
          value: inviteUrl,
          onCopy: () => Clipboard.setData(ClipboardData(text: inviteUrl)),
        ),
      ],
    );
  }
}

class _Ios26TeacherShell extends StatelessWidget {
  const _Ios26TeacherShell({required this.child, required this.trailingIcons});

  final Widget child;
  final List<Ios26ActionIcon> trailingIcons;

  @override
  Widget build(BuildContext context) {
    return TeacherStudioShell(
      currentRoute: GroupListPage.routeName,
      eyebrow: 'CLASS COMMUNITY',
      title: '그룹 관리',
      description: '초대부터 수업 배정까지 그룹 운영에 필요한 작업을 한곳에서 처리합니다.',
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).maybePop()
          : null,
      endDrawer: const TeacherAppDrawer(currentRoute: GroupListPage.routeName),
      actions: [
        for (final action in trailingIcons)
          TeacherStudioAction(
            label: action.label,
            icon: action.icon,
            onTap: action.onTap,
            primary: action.active,
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: ColoredBox(color: Colors.white, child: child),
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

class _PanelSectionLabel extends StatelessWidget {
  const _PanelSectionLabel({
    required this.index,
    required this.title,
    required this.description,
  });

  final String index;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            index,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(color: Colors.black54, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareValueCard extends StatelessWidget {
  const _ShareValueCard({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SelectableText(
                      value,
                      maxLines: 2,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.copy_rounded),
            ],
          ),
        ),
      ),
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
