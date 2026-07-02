// UTF-8 only: This file must be read/written as UTF-8.
import 'package:flutter/material.dart';

import '../services/api_client.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('전송 실패: $e')),
      );
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
                  child: Text(c['title']?.toString() ?? c['id']?.toString() ?? '코스'),
                ),
              )
              .toList(),
        ),
      );
      if (picked == null) return;
      final id = picked['id']?.toString() ?? '';
      if (id.isEmpty) return;
      final text = '코스 초대 링크\n/sessions/course?id=$id';
      await ApiClient.instance.sendDirectMessage(peerUsername: widget.peerUsername, text: text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('코스 링크를 전송했습니다.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('코스 링크 전송 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerUsername),
        actions: [
          IconButton(
            tooltip: '코스 링크 보내기',
            icon: const Icon(Icons.send_to_mobile),
            onPressed: _sendCourseLink,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      return Align(
                        alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: m.isMine ? Colors.green.shade100 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(m.text),
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
                      decoration: const InputDecoration(
                        hintText: '메시지 입력',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _send, child: const Text('전송')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
