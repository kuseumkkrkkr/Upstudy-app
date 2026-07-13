// UTF-8 only: This file must be read/written as UTF-8.
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../shared/theme/app_colors.dart';
import '../shared/ui/ios26/ios26_chrome.dart';
import '../shared/ui/ios26/teacher_adaptive_panel.dart';
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
      final picked = await showTeacherAdaptivePanel<Map<String, dynamic>>(
        context: context,
        eyebrow: 'SHARE IN CHAT',
        title: '코스 바로 보내기',
        description: '${widget.peerUsername} 학생이 열 수 있는 코스 링크를 선택합니다.',
        icon: Icons.send_to_mobile_rounded,
        bodyBuilder: (panelContext) => ListView.separated(
          itemCount: courses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, index) {
            final course = courses[index];
            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                onTap: () => Navigator.of(panelContext).pop(course),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.auto_stories_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          course['title']?.toString() ??
                              course['id']?.toString() ??
                              '코스',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            );
          },
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
                : _messages.isEmpty
                ? const Center(
                    child: Text(
                      '아직 메시지가 없습니다.',
                      style: TextStyle(
                        color: Colors.black45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                          constraints: const BoxConstraints(maxWidth: 520),
                          decoration: BoxDecoration(
                            color: m.isMine
                                ? kCourseGreen
                                : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(22),
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
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 960),
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.surfaceBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textCtrl,
                        decoration: InputDecoration(
                          hintText: '메시지 입력',
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: _send,
                        borderRadius: BorderRadius.circular(18),
                        child: const SizedBox(
                          width: 56,
                          height: 54,
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
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
}
