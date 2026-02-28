import 'dart:ui';

import 'package:flutter/material.dart';
import 'mainstudent.dart';

double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
  final width = MediaQuery.of(context).size.width;
  final scale = width / 1100;
  if (scale < min) return min;
  if (scale > max) return max;
  return scale;
}

class SoWidget extends StatefulWidget {
  const SoWidget({super.key});

  static String routeName = 'so';
  static String routePath = '/so';

  @override
  State<SoWidget> createState() => _SoWidgetState();
}

class _SoWidgetState extends State<SoWidget> {
  static const Color primaryColor = Color(0xFF1B402B);
  static const Color bgColor = Color(0xFFF5F5F5); // primaryBackground 대체
  static const Color cardColor = Colors.white; // secondaryBackground 대체

  static const TextStyle navStyle = TextStyle(
    color: primaryColor,
    fontSize: 30,
    fontWeight: FontWeight.normal,
  );

  final List<_FriendRank> _friendRanks = const [
    _FriendRank(rank: 1, name: '지민', ovr: 982, delta: 12),
    _FriendRank(rank: 2, name: '서준', ovr: 958, delta: 4),
    _FriendRank(rank: 3, name: '민지', ovr: 941, delta: -2),
    _FriendRank(rank: 4, name: '도윤', ovr: 910, delta: 1),
    _FriendRank(rank: 5, name: '하윤', ovr: 904, delta: 0),
  ];

  final List<_FriendInfo> _friends = const [
    _FriendInfo(name: '지민', status: '집중 모드', ovr: 982),
    _FriendInfo(name: '서준', status: '학습 중', ovr: 958),
    _FriendInfo(name: '민지', status: '휴식 중', ovr: 941),
    _FriendInfo(name: '도윤', status: '문제 풀이', ovr: 910),
    _FriendInfo(name: '하윤', status: '스터디 참여', ovr: 904),
  ];

  final List<_MessageInfo> _messages = const [
    _MessageInfo(name: '민지', lastMessage: '오늘 스터디 자료 공유했어.', timeAgo: '2분 전'),
    _MessageInfo(name: '서준', lastMessage: '내일 테스트 범위 알려줘!', timeAgo: '1시간 전'),
    _MessageInfo(name: '하윤', lastMessage: '문제 풀이 같이 해볼래?', timeAgo: '어제'),
  ];

  final List<_GroupInfo> _groups = const [
    _GroupInfo(
      name: '수학 올킬',
      description: '미적분 집중 스터디',
      members: 8,
      isPublic: true,
    ),
    _GroupInfo(
      name: '국어 독해',
      description: '비문학 독해 루틴',
      members: 5,
      isPublic: false,
    ),
    _GroupInfo(
      name: '영어 모의고사',
      description: '주 2회 실전 모의고사',
      members: 12,
      isPublic: true,
    ),
  ];

  Future<void> _showBlurDialog(Widget child) async {
    await showGeneralDialog(
      context: context,
      barrierLabel: 'dialog',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.2),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Center(
            child: Material(color: Colors.transparent, child: child),
          ),
        );
      },
      transitionBuilder: (_, animation, __, dialogChild) {
        return FadeTransition(opacity: animation, child: dialogChild);
      },
    );
  }

  void _openAddFriendModal() {
    _showBlurDialog(
      _dialogShell(
        title: '친구 추가',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '친구의 닉네임을 검색해 추가할 수 있어요.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: '닉네임 검색',
                filled: true,
                fillColor: bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('검색'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInboxModal() {
    _showBlurDialog(
      _dialogShell(
        title: '쪽지함',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('최근 대화 목록', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ..._messages.map((message) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    _openMessageCompose(message);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(0.15),
                          child: Text(
                            message.name.substring(0, 1),
                            style: const TextStyle(color: primaryColor),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message.lastMessage,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          message.timeAgo,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _openMessageCompose(_MessageInfo info) {
    _showBlurDialog(
      _dialogShell(
        title: '쪽지 보내기',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('받는 사람: ${info.name}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '쪽지를 입력하세요',
                filled: true,
                fillColor: bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('보내기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGroupManageModal() {
    _showBlurDialog(
      _dialogShell(
        title: '그룹 관리',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '그룹 이름 또는 그룹 ID로 검색하세요.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: '그룹 검색 / ID 입력',
                filled: true,
                fillColor: bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('검색'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGroupModal(_GroupInfo group) {
    _showBlurDialog(
      _dialogShell(
        title: group.name,
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          color: primaryColor,
          onPressed: () {
            Navigator.of(context).pop();
            _openGroupManageModal();
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(group.description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              children: [
                _infoPill('인원 ${group.members}명'),
                const SizedBox(width: 8),
                _infoPill(group.isPublic ? '공개' : '비공개'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('그룹 열기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogShell({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: 520,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _tagChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '#$text',
        style: const TextStyle(
          fontSize: 12,
          color: primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final baseWidth = screenWidth < 1900 ? screenWidth : 1900.0;
    final contentWidth = baseWidth > 20 ? baseWidth - 20 : 0.0;
    const cardGap = 10.0;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          top: true,
          child: Stack(
            children: [
              SingleChildScrollView(
                primary: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // ── 헤더 ──────────────────────────────────────
                    Container(
                      width: double.infinity,
                      height: 72 * scale,
                      color: Colors.white,
                      child: Row(
                        children: [
                          SizedBox(width: 16 * scale),
                          IconButton(
                            iconSize: 28 * scale,
                            icon: const Icon(
                              Icons.menu_outlined,
                              color: primaryColor,
                            ),
                            onPressed: () {},
                          ),
                          SizedBox(width: 12 * scale),
                          SizedBox(width: 12 * scale),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const MainStudentPage(),
                                ),
                                (route) => false,
                              );
                            },
                            child: Text(
                              'AIFlow',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 36 * scale,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 120 * scale),
                          Expanded(
                            child: Container(
                              color: Colors.white,
                              height: 72 * scale,
                              alignment: Alignment.centerRight,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final label in [
                                      '학습터',
                                      '문서고',
                                      '친구/소셜',
                                      '마켓플레이스',
                                    ])
                                      Padding(
                                        padding: EdgeInsets.only(
                                          right: label == '마켓플레이스'
                                              ? 24 * scale
                                              : 0,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12 * scale,
                                          ),
                                          child: Text(
                                            label,
                                            style: navStyle.copyWith(
                                              fontSize: 16 * scale,
                                            ),
                                          ),
                                        ),
                                      ),
                                    SizedBox(width: 16 * scale),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── 친구랭킹 / 나의정보 카드 ─────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      child: Container(
                        width: contentWidth,
                        height: 400,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.fromLTRB(26, 16, 26, 20),
                        child: Column(
                          children: [
                            Row(
                              children: const [
                                Expanded(
                                  child: Text(
                                    '친구랭킹',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Text(
                                    '나의정보',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '내 OVR 순위',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Expanded(
                                          child: ListView.separated(
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: _friendRanks.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 8),
                                            itemBuilder: (context, index) {
                                              final rank = _friendRanks[index];
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: bgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 36,
                                                      height: 36,
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: primaryColor
                                                            .withOpacity(0.12),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Text(
                                                        '${rank.rank}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: primaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        rank.name,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      'OVR ${rank.ovr}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      rank.delta >= 0
                                                          ? '+${rank.delta}'
                                                          : '${rank.delta}',
                                                      style: TextStyle(
                                                        color: rank.delta >= 0
                                                            ? primaryColor
                                                            : Colors.black54,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '현재 OVR',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          '894',
                                          style: TextStyle(
                                            fontSize: 44,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          '약점 태그',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            _tagChip('시간관리'),
                                            _tagChip('도형'),
                                            _tagChip('영어'),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          '강점 태그',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            _tagChip('수학'),
                                            _tagChip('국어'),
                                            _tagChip('집중력'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ?? ?? ? ? ?? ???????????????????????????
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: contentWidth,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final availableWidth = constraints.maxWidth;
                              final gap = cardGap;
                              final cardW = (availableWidth - gap) / 2;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(right: gap),
                                    child: Container(
                                      width: cardW,
                                      height: 400,
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        22,
                                        18,
                                        22,
                                        16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                '????',
                                                style: TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.person_add_alt_1,
                                                  color: primaryColor,
                                                ),
                                                onPressed: _openAddFriendModal,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Expanded(
                                            child: ListView.separated(
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: _friends.length,
                                              separatorBuilder: (_, __) =>
                                                  const SizedBox(height: 8),
                                              itemBuilder: (context, index) {
                                                final friend = _friends[index];
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 10,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: bgColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      CircleAvatar(
                                                        backgroundColor:
                                                            primaryColor
                                                                .withOpacity(
                                                                  0.12,
                                                                ),
                                                        child: Text(
                                                          friend.name.substring(
                                                            0,
                                                            1,
                                                          ),
                                                          style: const TextStyle(
                                                            color: primaryColor,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              friend.name,
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Text(
                                                              friend.status,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Text(
                                                        'OVR ${friend.ovr}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: cardW,
                                    height: 400,
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      18,
                                      22,
                                      16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              '???',
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 18,
                                                color: primaryColor,
                                              ),
                                              onPressed: _openInboxModal,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Expanded(
                                          child: ListView.separated(
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: _messages.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 8),
                                            itemBuilder: (context, index) {
                                              final message = _messages[index];
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: bgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      backgroundColor:
                                                          primaryColor
                                                              .withOpacity(
                                                                0.12,
                                                              ),
                                                      child: Text(
                                                        message.name.substring(
                                                          0,
                                                          1,
                                                        ),
                                                        style: const TextStyle(
                                                          color: primaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            message.name,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            message.lastMessage,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Text(
                                                      message.timeAgo,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // 그룹스터디 섹션
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      child: Container(
                        width: contentWidth,
                        height: 400,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '그룹스터디',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: _groups.isEmpty
                                  ? Center(
                                      child: InkWell(
                                        onTap: _openGroupManageModal,
                                        child: const Text(
                                          '그룹에 참여해 보세요',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _groups.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        final group = _groups[index];
                                        return InkWell(
                                          onTap: () => _openGroupModal(group),
                                          child: Container(
                                            width: 320,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      backgroundColor:
                                                          primaryColor
                                                              .withOpacity(
                                                                0.12,
                                                              ),
                                                      child: Text(
                                                        group.name.substring(
                                                          0,
                                                          1,
                                                        ),
                                                        style: const TextStyle(
                                                          color: primaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        group.name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  group.description,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Row(
                                                  children: [
                                                    _infoPill(
                                                      '${group.members}명',
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _infoPill(
                                                      group.isPublic
                                                          ? '공개'
                                                          : '비공개',
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendRank {
  const _FriendRank({
    required this.rank,
    required this.name,
    required this.ovr,
    required this.delta,
  });

  final int rank;
  final String name;
  final int ovr;
  final int delta;
}

class _FriendInfo {
  const _FriendInfo({
    required this.name,
    required this.status,
    required this.ovr,
  });

  final String name;
  final String status;
  final int ovr;
}

class _MessageInfo {
  const _MessageInfo({
    required this.name,
    required this.lastMessage,
    required this.timeAgo,
  });

  final String name;
  final String lastMessage;
  final String timeAgo;
}

class _GroupInfo {
  const _GroupInfo({
    required this.name,
    required this.description,
    required this.members,
    required this.isPublic,
  });

  final String name;
  final String description;
  final int members;
  final bool isPublic;
}
