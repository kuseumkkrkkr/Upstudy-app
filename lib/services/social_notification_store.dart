import 'package:flutter/foundation.dart';

class SocialNotificationSnapshot {
  const SocialNotificationSnapshot({
    required this.unreadMessages,
    required this.friendRequests,
  });

  final int unreadMessages;
  final int friendRequests;

  factory SocialNotificationSnapshot.empty() {
    return const SocialNotificationSnapshot(
      unreadMessages: 0,
      friendRequests: 0,
    );
  }

  SocialNotificationSnapshot copyWith({
    int? unreadMessages,
    int? friendRequests,
  }) {
    return SocialNotificationSnapshot(
      unreadMessages: unreadMessages ?? this.unreadMessages,
      friendRequests: friendRequests ?? this.friendRequests,
    );
  }

  SocialNotificationSnapshot normalized() {
    return SocialNotificationSnapshot(
      unreadMessages: unreadMessages < 0 ? 0 : unreadMessages,
      friendRequests: friendRequests < 0 ? 0 : friendRequests,
    );
  }
}

class SocialNotificationStore {
  static final ValueNotifier<SocialNotificationSnapshot> notifier =
      ValueNotifier<SocialNotificationSnapshot>(
        SocialNotificationSnapshot.empty(),
      );

  static void update({
    int? unreadMessages,
    int? friendRequests,
  }) {
    final current = notifier.value;
    final next = current
        .copyWith(
          unreadMessages: unreadMessages,
          friendRequests: friendRequests,
        )
        .normalized();
    notifier.value = next;
  }

  static void setCounts({
    required int unreadMessages,
    required int friendRequests,
  }) {
    update(
      unreadMessages: unreadMessages,
      friendRequests: friendRequests,
    );
  }

  static void clear() {
    notifier.value = SocialNotificationSnapshot.empty();
  }
}
