import 'package:flutter/foundation.dart';

class SocialNotificationSnapshot {
  const SocialNotificationSnapshot({
    required this.unreadMessages,
    required this.friendRequests,
    required this.friendRemovals,
  });

  final int unreadMessages;
  final int friendRequests;
  final int friendRemovals;

  factory SocialNotificationSnapshot.empty() {
    return const SocialNotificationSnapshot(
      unreadMessages: 0,
      friendRequests: 0,
      friendRemovals: 0,
    );
  }

  SocialNotificationSnapshot copyWith({
    int? unreadMessages,
    int? friendRequests,
    int? friendRemovals,
  }) {
    return SocialNotificationSnapshot(
      unreadMessages: unreadMessages ?? this.unreadMessages,
      friendRequests: friendRequests ?? this.friendRequests,
      friendRemovals: friendRemovals ?? this.friendRemovals,
    );
  }

  SocialNotificationSnapshot normalized() {
    return SocialNotificationSnapshot(
      unreadMessages: unreadMessages < 0 ? 0 : unreadMessages,
      friendRequests: friendRequests < 0 ? 0 : friendRequests,
      friendRemovals: friendRemovals < 0 ? 0 : friendRemovals,
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
    int? friendRemovals,
  }) {
    final current = notifier.value;
    final next = current
        .copyWith(
          unreadMessages: unreadMessages,
          friendRequests: friendRequests,
          friendRemovals: friendRemovals,
        )
        .normalized();
    notifier.value = next;
  }

  static void setCounts({
    required int unreadMessages,
    required int friendRequests,
    int friendRemovals = 0,
  }) {
    update(
      unreadMessages: unreadMessages,
      friendRequests: friendRequests,
      friendRemovals: friendRemovals,
    );
  }

  static void clear() {
    notifier.value = SocialNotificationSnapshot.empty();
  }
}
