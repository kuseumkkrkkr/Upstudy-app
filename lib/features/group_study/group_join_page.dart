import 'package:flutter/material.dart';
import 'package:s11/shared/services/api/api_client.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('그룹 참여')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _isLoading
                ? const CircularProgressIndicator()
                : _error != null
                ? Text(
                    '초대 정보를 불러오지 못했습니다.\n$_error',
                    textAlign: TextAlign.center,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_add, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _meta?.name ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _meta?.description ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_meta?.members ?? 0}/${_meta?.maxMembers ?? 0}명 · 코드 ${_meta?.inviteCode ?? ''}',
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isJoining ? null : _join,
                        child: _isJoining
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('참여하기'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
