import 'package:flutter/foundation.dart';

import 'package:s11/shared/services/api/api_client.dart';

class RatingSnapshot {
  final double ovr;
  final double delta;
  final double recentAccuracy;
  final int loseStreak;
  final bool isLoaded;
  final bool placementCompleted;

  const RatingSnapshot({
    required this.ovr,
    required this.delta,
    required this.recentAccuracy,
    required this.loseStreak,
    required this.isLoaded,
    required this.placementCompleted,
  });

  const RatingSnapshot.empty()
    : ovr = 0.0,
      delta = 0.0,
      recentAccuracy = 0.0,
      loseStreak = 0,
      isLoaded = false,
      placementCompleted = false;

  RatingSnapshot copyWith({
    double? ovr,
    double? delta,
    double? recentAccuracy,
    int? loseStreak,
    bool? isLoaded,
    bool? placementCompleted,
  }) {
    return RatingSnapshot(
      ovr: ovr ?? this.ovr,
      delta: delta ?? this.delta,
      recentAccuracy: recentAccuracy ?? this.recentAccuracy,
      loseStreak: loseStreak ?? this.loseStreak,
      isLoaded: isLoaded ?? this.isLoaded,
      placementCompleted: placementCompleted ?? this.placementCompleted,
    );
  }
}

class RatingStore {
  RatingStore._();

  static final ValueNotifier<RatingSnapshot> notifier = ValueNotifier(
    const RatingSnapshot.empty(),
  );

  static Future<void> refresh() async {
    try {
      final rating = await ApiClient.instance.fetchUserRating();
      notifier.value = RatingSnapshot(
        ovr: rating.ovr,
        delta: rating.ovrDelta,
        recentAccuracy: rating.recentAccuracy,
        loseStreak: rating.loseStreak,
        isLoaded: true,
        placementCompleted: rating.placementCompleted,
      );
    } catch (_) {
      // keep previous value on failure
    }
  }

  static void updateFromRating(UserRating rating) {
    notifier.value = RatingSnapshot(
      ovr: rating.ovr,
      delta: rating.ovrDelta,
      recentAccuracy: rating.recentAccuracy,
      loseStreak: rating.loseStreak,
      isLoaded: true,
      placementCompleted: rating.placementCompleted,
    );
  }
}
