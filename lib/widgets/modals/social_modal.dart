import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/social_notification_store.dart';

Future<T?> showSocialModal<T>({required BuildContext context}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            const Center(child: SocialModal()),
          ],
        ),
      );
    },
  );
}

class SocialModal extends StatelessWidget {
  const SocialModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 860,
      height: 520,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Text('알림', style: TextStyle(fontSize: 22)),
              const Spacer(),
              TextButton(
                onPressed: () => SocialNotificationStore.update(
                  unreadMessages: 0,
                  friendRemovals: 0,
                ),
                child: const Text('읽음 처리'),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 12),
            child: Text(
              '최근 받은 쪽지, 친구 요청, 친구 삭제 알림을 확인하세요.',
              style: TextStyle(fontSize: 15),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<SocialNotificationSnapshot>(
              valueListenable: SocialNotificationStore.notifier,
              builder: (context, snapshot, _) {
                final items = <String>[];
                if (snapshot.unreadMessages > 0) {
                  items.add('새 쪽지 ${snapshot.unreadMessages}건이 도착했습니다.');
                }
                if (snapshot.friendRequests > 0) {
                  items.add('친구 요청 ${snapshot.friendRequests}건이 있습니다.');
                }
                if (snapshot.friendRemovals > 0) {
                  items.add('친구 삭제 알림 ${snapshot.friendRemovals}건이 있습니다.');
                }
                if (items.isEmpty) {
                  items.add('새로운 알림이 없습니다.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _SocialItem(text: items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialItem extends StatelessWidget {
  const _SocialItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
