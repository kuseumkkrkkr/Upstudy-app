// UTF-8 only: This file must be read/written as UTF-8.
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/teacher_app_drawer.dart';
import 'teacher_chat_page.dart';

class TeacherSocialPage extends StatefulWidget {
  const TeacherSocialPage({super.key});

  static const String routeName = '/teacher-social';

  @override
  State<TeacherSocialPage> createState() => _TeacherSocialPageState();
}

class _TeacherSocialPageState extends State<TeacherSocialPage> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  List<FriendProfile> _friends = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final friends = await ApiClient.instance.listFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addByNickname() async {
    final nickname = _searchCtrl.text.trim();
    if (nickname.isEmpty) return;
    try {
      await ApiClient.instance.addFriend(nickname);
      if (!mounted) return;
      _searchCtrl.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$nickname 님을 친구로 추가했습니다.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('친구 추가 실패: $e')));
    }
  }

  Future<void> _removeFriend(String username) async {
    try {
      await ApiClient.instance.removeFriend(username);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$username 님을 친구에서 제거했습니다.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('친구 삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const TeacherAppDrawer(
        currentRoute: TeacherSocialPage.routeName,
      ),
      appBar: AppBar(
        title: const Text('친구 및 채팅'),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: '메뉴',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: '닉네임',
                      hintText: '닉네임으로 친구 추가',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addByNickname(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addByNickname,
                  child: const Text('추가'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _friends.length,
                      itemBuilder: (context, index) {
                        final f = _friends[index];
                        return ListTile(
                          title: Text(f.username),
                          subtitle: Text('user_id: ${f.userId}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '1:1 채팅',
                                icon: const Icon(Icons.chat_bubble_outline),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TeacherChatPage(
                                        peerUsername: f.username,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: '친구 삭제',
                                icon: const Icon(
                                  Icons.person_remove_alt_1,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeFriend(f.username),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
