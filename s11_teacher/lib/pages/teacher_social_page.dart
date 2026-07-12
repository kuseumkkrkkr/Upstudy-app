// UTF-8 only: This file must be read/written as UTF-8.
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../shared/theme/app_colors.dart';
import '../shared/ui/ios26/ios26_chrome.dart';
import '../widgets/design_tokens.dart';
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

  List<FriendProfile> get _filteredFriends {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _friends;
    return _friends
        .where((friend) => friend.username.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
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
      backgroundColor: Colors.white,
      endDrawer: const TeacherAppDrawer(
        currentRoute: TeacherSocialPage.routeName,
      ),
      body: Builder(
        builder: (scaffoldContext) => SafeArea(
          child: Column(
            children: [
              Ios26TopBar(
                brandColor: kCourseGreen,
                title: '친구 · 채팅',
                onBack: () => Navigator.of(context).maybePop(),
                onMenu: () => Scaffold.of(scaffoldContext).openEndDrawer(),
                items: const [
                  Ios26NavItem(label: '친구 목록', active: true),
                  Ios26NavItem(label: '1:1 채팅'),
                ],
                trailingIcons: [
                  Ios26ActionIcon(
                    icon: Icons.refresh_rounded,
                    label: '새로고침',
                    onTap: _loading ? null : _load,
                  ),
                ],
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    children: [
                      _SocialSummaryCard(
                        controller: _searchCtrl,
                        friendCount: _friends.length,
                        onAdd: _addByNickname,
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 64),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_filteredFriends.isEmpty)
                        const _EmptyFriendsCard()
                      else
                        ..._filteredFriends.map(
                          (friend) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _FriendCard(
                              friend: friend,
                              onChat: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TeacherChatPage(
                                      peerUsername: friend.username,
                                    ),
                                  ),
                                );
                              },
                              onRemove: () => _removeFriend(friend.username),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialSummaryCard extends StatelessWidget {
  const _SocialSummaryCard({
    required this.controller,
    required this.friendCount,
    required this.onAdd,
  });

  final TextEditingController controller;
  final int friendCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Ios26FrostedCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SocialPill(label: '친구 수', value: '$friendCount명'),
              const _SocialPill(label: '대화 방식', value: '1:1 채팅'),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '닉네임으로 친구를 추가하고 바로 대화를 시작하세요.',
            style: TextStyle(
              color: kCourseGreen,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: '닉네임',
                    hintText: '닉네임으로 친구 추가',
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
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: kCourseGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(110, 54),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('추가'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialPill extends StatelessWidget {
  const _SocialPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: kCourseGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.onChat,
    required this.onRemove,
  });

  final FriendProfile friend;
  final VoidCallback onChat;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Ios26FrostedCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person_rounded, color: kCourseGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.username,
                  style: const TextStyle(
                    color: kCourseGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'user_id: ${friend.userId}',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.58),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onChat,
            style: OutlinedButton.styleFrom(
              foregroundColor: kCourseGreen,
              side: const BorderSide(color: AppColors.surfaceBorder),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('채팅'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '친구 삭제',
            onPressed: onRemove,
            icon: const Icon(
              Icons.person_remove_alt_1_rounded,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFriendsCard extends StatelessWidget {
  const _EmptyFriendsCard();

  @override
  Widget build(BuildContext context) {
    return const Ios26FrostedCard(
      radius: 24,
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          '표시할 친구가 없습니다.',
          style: TextStyle(color: kCourseGreen, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
