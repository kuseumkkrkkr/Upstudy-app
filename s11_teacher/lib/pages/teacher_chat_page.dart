// UTF-8 only: This file must be read/written as UTF-8.
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../shared/theme/app_colors.dart';
import '../shared/ui/ios26/ios26_chrome.dart';
import '../widgets/design_tokens.dart';

class TeacherChatPage extends StatefulWidget {
  const TeacherChatPage({super.key, required this.peerUsername});

  final String peerUsername;

  @override
  State<TeacherChatPage> createState() => _TeacherChatPageState();
}

class _TeacherChatPageState extends State<TeacherChatPage> {
  final _textCtrl = TextEditingController();
  bool _loading = true;
  List<DirectMessage> _messages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final messages = await ApiClient.instance.fetchDirectMessages(
        peerUsername: widget.peerUsername,
        limit: 50,
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
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ApiClient.instance.sendDirectMessage(
        peerUsername: widget.peerUsername,
        text: text,
      );
      if (!mounted) return;
      _textCtrl.clear();
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    }
  }

  Future<void> _sendCourseLink() async {
    try {
      final courses = await ApiClient.instance.listCoursesV2(mineOnly: true);
      if (!mounted) return;
      if (courses.isEmpty) return;
      final picked = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('코스 링크 보내기'),
          children: courses
              .map(
                (c) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(c),
                  child: Text(
                    c['title']?.toString() ?? c['id']?.toString() ?? '코스',
                  ),
                ),
              )
              .toList(),
        ),
      );
      if (picked == null) return;
      final id = picked['id']?.toString() ?? '';
      if (id.isEmpty) return;
      final text = '코스 초대 링크\n/sessions/course?id=$id';
      await ApiClient.instance.sendDirectMessage(
        peerUsername: widget.peerUsername,
        text: text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('코스 링크를 전송했습니다.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('코스 링크 전송 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Ios26TopBar(
            brandColor: kCourseGreen,
            title: widget.peerUsername,
            onBack: () => Navigator.of(context).maybePop(),
            items: const [Ios26NavItem(label: '1:1 채팅', active: true)],
            trailingIcons: [
              Ios26ActionIcon(
                icon: Icons.send_to_mobile_rounded,
                label: '코스 링크 보내기',
                onTap: _sendCourseLink,
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      return Align(
                        alignment: m.isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: m.isMine
                                ? kCourseGreen
                                : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: m.isMine
                                  ? kCourseGreen
                                  : AppColors.surfaceBorder,
                            ),
                          ),
                          child: Text(
                            m.text,
                            style: TextStyle(
                              color: m.isMine ? Colors.white : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      decoration: InputDecoration(
                        hintText: '메시지 입력',
                        filled: true,
                        fillColor: AppColors.surfaceMuted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: AppColors.surfaceBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: AppColors.surfaceBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: kCourseLightGreen,
                            width: 2,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _send,
                    style: FilledButton.styleFrom(
                      backgroundColor: kCourseGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(96, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('전송'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
