import 'package:flutter/material.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

class GroupJoinPage extends StatefulWidget {
  const GroupJoinPage({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  State<GroupJoinPage> createState() => _GroupJoinPageState();
}

class _GroupJoinPageState extends State<GroupJoinPage> {
  bool _isLoading = true;
  bool _isJoining = false;
  String? _error;
  StudyGroupInviteMeta? _meta;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final meta = await ApiClient.instance.fetchStudyGroupInviteMeta(
        widget.inviteCode,
      );
      if (!mounted) return;
      setState(() {
        _meta = meta;
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

  Future<void> _join() async {
    if (_isJoining) return;
    setState(() => _isJoining = true);
    try {
      final group = await ApiClient.instance.joinStudyGroupByInviteCode(
        inviteCode: widget.inviteCode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${group.name}에 참여했어요')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('참여 실패: $e')));
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  /// 필요한 변수는 현재 네비게이터 스택이다.
  /// 작동 원리는 초대 링크에서 진입했으면 이전 화면으로 돌아가고, 단독 경로면 실제 그룹 목록으로 복귀하는 것이다.
  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushNamedAndRemoveUntil('/groups', (route) => false);
  }

  /// 필요한 변수는 초대 메타 조회·참가 상태와 현재 화면 폭이다.
  /// 작동 원리는 모든 폭에서 같은 학생 셸을 유지하고, 참가 API의 로딩·실패·성공 흐름만 안쪽 카드에서 바꾸는 것이다.
  Widget _buildInviteBody(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final meta = _meta;
    return SingleChildScrollView(
      child: StudentDensityPage(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StudentDensityPageHeader(
                  eyebrow: 'STUDY GROUP',
                  title: '그룹 참여',
                  description: '초대받은 그룹 정보를 확인하고 참여를 확정하세요.',
                  showMobileDescription: true,
                ),
                SizedBox(height: mobile ? 22 : 32),
                if (_isLoading)
                  const StudentDensitySurface(
                    child: SizedBox(
                      height: 190,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_error != null)
                  StudentDensitySurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 34,
                          color: StudentDensityTokens.muted,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '초대 정보를 불러오지 못했습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: StudentDensityTokens.muted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20),
                        StudentDensityButton(
                          label: '다시 불러오기',
                          primary: true,
                          icon: Icons.refresh_rounded,
                          onPressed: _load,
                        ),
                      ],
                    ),
                  )
                else if (meta != null)
                  StudentDensitySurface(
                    padding: EdgeInsets.all(mobile ? 20 : 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: mobile ? 66 : 76,
                            height: mobile ? 66 : 76,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: StudentDensityTokens.dark,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.groups_2_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          meta.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: StudentDensityTokens.ink,
                            fontSize: mobile ? 25 : 32,
                            height: 1.05,
                            letterSpacing: mobile ? -1.2 : -1.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (meta.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            meta.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: StudentDensityTokens.muted,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InviteMetaPill(
                              icon: Icons.people_outline_rounded,
                              label: '${meta.members}/${meta.maxMembers}명',
                            ),
                            _InviteMetaPill(
                              icon: Icons.key_rounded,
                              label: '코드 ${meta.inviteCode}',
                            ),
                            if (meta.lockEnabled)
                              const _InviteMetaPill(
                                icon: Icons.lock_outline_rounded,
                                label: '비공개 그룹',
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: mobile ? 54 : 48,
                          child: FilledButton.icon(
                            onPressed: _isJoining ? null : _join,
                            icon: _isJoining
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(_isJoining ? '참여 중...' : '그룹 참여하기'),
                            style: FilledButton.styleFrom(
                              backgroundColor: StudentDensityTokens.dark,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StudentHtmlShell(
      key: const ValueKey('group-join-screen'),
      title: '그룹 참여',
      activeRoute: '/groups',
      showContextAside: MediaQuery.sizeOf(context).width > 1040,
      onMenu: _goBack,
      onSearch: () => showStudentQuickSearch(context),
      onNotifications: () => showStudentNotifications(context),
      child: _buildInviteBody(context),
    );
  }
}

class _InviteMetaPill extends StatelessWidget {
  const _InviteMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: StudentDensityTokens.surfaceMuted,
      border: Border.all(color: StudentDensityTokens.line),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: StudentDensityTokens.muted),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
