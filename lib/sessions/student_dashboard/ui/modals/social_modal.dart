import 'package:flutter/material.dart';

import 'package:s11/shared/business/repositories/social_notification_store.dart';
import 'package:s11/shared/ui/ios26/ios26_modal.dart';

Future<T?> showSocialModal<T>({required BuildContext context}) {
  return showIos26Modal<T>(
    context: context,
    maxWidth: 860,
    maxHeight: 520,
    child: const SocialModal(),
  );
}

class SocialModal extends StatelessWidget {
  const SocialModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Ios26ModalShell(
      title: '알림',
      trailing: TextButton(
        onPressed: () => SocialNotificationStore.update(
          unreadMessages: 0,
          friendRemovals: 0,
        ),
        child: const Text('읽음 처리'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(24, 18, 24, 12),
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
                  items.add('미확인 쪽지 ${snapshot.unreadMessages}건이 있습니다.');
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
