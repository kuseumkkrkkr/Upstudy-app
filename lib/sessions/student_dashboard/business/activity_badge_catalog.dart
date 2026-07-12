import 'package:flutter/material.dart';

import 'package:s11/shared/business/repositories/activity_store.dart';

enum ActivityBadgeRarity {
  basic('베이직', 0),
  steady('스테디', 1),
  focused('포커스', 2),
  elite('엘리트', 3),
  radiant('래디언트', 4),
  aurora('오로라', 5);

  const ActivityBadgeRarity(this.label, this.sparkleLevel);

  final String label;
  final int sparkleLevel;
}

class ActivityBadgeDefinition {
  const ActivityBadgeDefinition({
    required this.id,
    required this.family,
    required this.title,
    required this.description,
    required this.metricLabel,
    required this.unit,
    required this.threshold,
    required this.tier,
    required this.rarity,
    required this.icon,
    required this.color,
  });

  final String id;
  final String family;
  final String title;
  final String description;
  final String metricLabel;
  final String unit;
  final int threshold;
  final int tier;
  final ActivityBadgeRarity rarity;
  final IconData icon;
  final Color color;
}

class ActivityBadgeProgress {
  const ActivityBadgeProgress({
    required this.badge,
    required this.value,
    required this.progress,
    required this.isEarned,
  });

  final ActivityBadgeDefinition badge;
  final int value;
  final double progress;
  final bool isEarned;

  String get progressText {
    final current = value.clamp(0, badge.threshold);
    if (badge.unit == '%') return '$current/${badge.threshold}%';
    return '$current/${badge.threshold}${badge.unit}';
  }
}

class ActivityBadgeStats {
  const ActivityBadgeStats({
    required this.totalSolved,
    required this.totalIncorrect,
    required this.totalScore,
    required this.maxDayScore,
    required this.activeDays,
    required this.streakDays,
    required this.bookViews,
    required this.courseViews,
    required this.examCompletions,
    required this.graphPractices,
    required this.accuracyPercent,
    required this.highProblemDays,
    required this.accountLevel,
  });

  factory ActivityBadgeStats.fromSnapshot(
    ActivitySnapshot snapshot, {
    DateTime? now,
    int accountLevel = 0,
  }) {
    final records = snapshot.days.values;
    final bookViews = records.fold<int>(
      0,
      (sum, record) => sum + record.bookNumbers.length,
    );
    final courseViews = records.fold<int>(
      0,
      (sum, record) => sum + record.courseNumbers.length,
    );
    final examCompletions = records.fold<int>(
      0,
      (sum, record) => sum + record.examNumbers.length,
    );
    final graphPractices = records.fold<int>(
      0,
      (sum, record) => sum + record.graphNumbers.length,
    );
    final totalScore = records.fold<int>(
      0,
      (sum, record) => sum + record.score,
    );
    final maxDayScore = records.fold<int>(
      0,
      (max, record) => record.score > max ? record.score : max,
    );
    final activeDays = records.where(_hasActivity).length;
    final highProblemDays = records
        .where((record) => record.problemNumbers.length >= 5)
        .length;
    final attempts = snapshot.totalSolvedCount + snapshot.totalIncorrectCount;
    final accuracyPercent = attempts < 10
        ? 0
        : ((snapshot.totalSolvedCount / attempts) * 100).round();

    return ActivityBadgeStats(
      totalSolved: snapshot.totalSolvedCount,
      totalIncorrect: snapshot.totalIncorrectCount,
      totalScore: totalScore,
      maxDayScore: maxDayScore,
      activeDays: activeDays,
      streakDays: _streakDays(snapshot, now ?? DateTime.now()),
      bookViews: bookViews,
      courseViews: courseViews,
      examCompletions: examCompletions,
      graphPractices: graphPractices,
      accuracyPercent: accuracyPercent,
      highProblemDays: highProblemDays,
      accountLevel: accountLevel,
    );
  }

  final int totalSolved;
  final int totalIncorrect;
  final int totalScore;
  final int maxDayScore;
  final int activeDays;
  final int streakDays;
  final int bookViews;
  final int courseViews;
  final int examCompletions;
  final int graphPractices;
  final int accuracyPercent;
  final int highProblemDays;
  final int accountLevel;
}

class ActivityBadgeCatalog {
  ActivityBadgeCatalog._();

  static final List<ActivityBadgeDefinition> allBadges = List.unmodifiable(
    _families.expand(_buildFamilyBadges),
  );

  static String familyTitleOf(String familyId) {
    return _familyById[familyId]?.title ?? familyId;
  }

  static List<ActivityBadgeProgress> evaluate(
    ActivitySnapshot snapshot, {
    DateTime? now,
    int accountLevel = 0,
  }) {
    final stats = ActivityBadgeStats.fromSnapshot(
      snapshot,
      now: now,
      accountLevel: accountLevel,
    );
    return allBadges
        .map((badge) {
          final family = _familyById[badge.family]!;
          final value = family.valueOf(stats);
          return ActivityBadgeProgress(
            badge: badge,
            value: value,
            progress: (value / badge.threshold).clamp(0.0, 1.0),
            isEarned: value >= badge.threshold,
          );
        })
        .toList(growable: false);
  }

  static List<ActivityBadgeProgress> earnedBadges(
    ActivitySnapshot snapshot, {
    DateTime? now,
    int accountLevel = 0,
  }) {
    final earned = evaluate(
      snapshot,
      now: now,
      accountLevel: accountLevel,
    ).where((entry) => entry.isEarned).toList();
    earned.sort((a, b) {
      final rarity = b.badge.rarity.index.compareTo(a.badge.rarity.index);
      if (rarity != 0) return rarity;
      return b.badge.tier.compareTo(a.badge.tier);
    });
    return earned;
  }

  static List<ActivityBadgeProgress> nextBadges(
    ActivitySnapshot snapshot, {
    int limit = 3,
    DateTime? now,
    int accountLevel = 0,
  }) {
    final locked = evaluate(
      snapshot,
      now: now,
      accountLevel: accountLevel,
    ).where((entry) => !entry.isEarned).toList();
    locked.sort((a, b) {
      final progress = b.progress.compareTo(a.progress);
      if (progress != 0) return progress;
      return a.badge.threshold.compareTo(b.badge.threshold);
    });
    return locked.take(limit).toList(growable: false);
  }
}

class _ActivityBadgeFamily {
  const _ActivityBadgeFamily({
    required this.id,
    required this.title,
    required this.description,
    required this.metricLabel,
    required this.unit,
    required this.thresholds,
    required this.icon,
    required this.color,
    required this.valueOf,
  });

  final String id;
  final String title;
  final String description;
  final String metricLabel;
  final String unit;
  final List<int> thresholds;
  final IconData icon;
  final Color color;
  final int Function(ActivityBadgeStats stats) valueOf;
}

final List<_ActivityBadgeFamily> _families = [
  _ActivityBadgeFamily(
    id: 'solve',
    title: '해답 항해',
    description: '누적 문제 풀이',
    metricLabel: '누적 풀이',
    unit: '문제',
    thresholds: [1, 5, 10, 20, 35, 50, 75, 100, 150, 250, 400, 600],
    icon: Icons.edit_note,
    color: const Color(0xFF3E6AE1),
    valueOf: (stats) => stats.totalSolved,
  ),
  _ActivityBadgeFamily(
    id: 'score',
    title: '열정 코어',
    description: '최근 기록 누적 활동 점수',
    metricLabel: '누적 활동점수',
    unit: '점',
    thresholds: [
      100,
      250,
      500,
      900,
      1400,
      2200,
      3200,
      4600,
      6400,
      9000,
      12500,
      17000,
    ],
    icon: Icons.bolt,
    color: const Color(0xFFE2A327),
    valueOf: (stats) => stats.totalScore,
  ),
  _ActivityBadgeFamily(
    id: 'daily_peak',
    title: '하루 점화',
    description: '하루 최고 활동 점수',
    metricLabel: '하루 최고점',
    unit: '점',
    thresholds: [
      50,
      100,
      180,
      300,
      450,
      650,
      850,
      1050,
      1250,
      1500,
      1750,
      2000,
    ],
    icon: Icons.local_fire_department,
    color: const Color(0xFFE85D3A),
    valueOf: (stats) => stats.maxDayScore,
  ),
  _ActivityBadgeFamily(
    id: 'streak',
    title: '연속 루틴',
    description: '끊기지 않은 학습 연속일',
    metricLabel: '연속 학습',
    unit: '일',
    thresholds: [1, 2, 3, 5, 7, 10, 14, 21, 30, 45, 60, 90],
    icon: Icons.calendar_month,
    color: const Color(0xFF2E9853),
    valueOf: (stats) => stats.streakDays,
  ),
  _ActivityBadgeFamily(
    id: 'active_days',
    title: '학습 발자국',
    description: '활동이 남은 날짜 수',
    metricLabel: '활동일',
    unit: '일',
    thresholds: [1, 2, 3, 5, 7, 10, 14, 21, 30, 40, 50, 60],
    icon: Icons.hiking,
    color: const Color(0xFF00A0A8),
    valueOf: (stats) => stats.activeDays,
  ),
  _ActivityBadgeFamily(
    id: 'book',
    title: '개념 탐험',
    description: '교재와 개념 페이지 열람',
    metricLabel: '교재 열람',
    unit: '회',
    thresholds: [1, 3, 5, 8, 12, 16, 20, 30, 40, 50, 75, 100],
    icon: Icons.menu_book,
    color: const Color(0xFF7C4DFF),
    valueOf: (stats) => stats.bookViews,
  ),
  _ActivityBadgeFamily(
    id: 'course',
    title: '커리큘럼 등반',
    description: '강의와 커리큘럼 진입',
    metricLabel: '강의 진입',
    unit: '회',
    thresholds: [1, 3, 5, 8, 12, 16, 20, 30, 40, 50, 75, 100],
    icon: Icons.school,
    color: const Color(0xFF1565C0),
    valueOf: (stats) => stats.courseViews,
  ),
  _ActivityBadgeFamily(
    id: 'exam',
    title: '실전 모의고사',
    description: '시험지와 모의고사 완료',
    metricLabel: '시험 완료',
    unit: '회',
    thresholds: [1, 2, 3, 5, 8, 12, 16, 20, 30, 40, 60, 80],
    icon: Icons.assignment_turned_in,
    color: const Color(0xFF00897B),
    valueOf: (stats) => stats.examCompletions,
  ),
  _ActivityBadgeFamily(
    id: 'graph_practice',
    title: '그래프 실습',
    description: '그래프 도구로 식과 예제 그래프 실습',
    metricLabel: '그래프 실습',
    unit: '회',
    thresholds: [1, 3, 5, 10, 20, 35, 50, 75, 100, 150, 250, 400],
    icon: Icons.timeline,
    color: const Color(0xFF5B6CFF),
    valueOf: (stats) => stats.graphPractices,
  ),
  _ActivityBadgeFamily(
    id: 'account_level',
    title: '레벨 성장',
    description: '계정 레벨',
    metricLabel: '계정 레벨',
    unit: '레벨',
    thresholds: [2, 3, 4, 5, 7, 10, 14, 18, 25, 35, 50, 70],
    icon: Icons.workspace_premium,
    color: const Color(0xFFB7791F),
    valueOf: (stats) => stats.accountLevel,
  ),
  _ActivityBadgeFamily(
    id: 'accuracy',
    title: '정밀 해답',
    description: '10회 이상 채점 후 정답률',
    metricLabel: '정답률',
    unit: '%',
    thresholds: [50, 55, 60, 65, 70, 75, 80, 85, 88, 90, 93, 95],
    icon: Icons.gps_fixed,
    color: const Color(0xFFD53F8C),
    valueOf: (stats) => stats.accuracyPercent,
  ),
  _ActivityBadgeFamily(
    id: 'high_problem_days',
    title: '문제 루틴',
    description: '하루 5문제 이상 푼 날짜',
    metricLabel: '5문제 이상일',
    unit: '일',
    thresholds: [1, 2, 3, 5, 7, 10, 14, 20, 28, 36, 48, 60],
    icon: Icons.auto_graph,
    color: const Color(0xFF455A64),
    valueOf: (stats) => stats.highProblemDays,
  ),
];

final Map<String, _ActivityBadgeFamily> _familyById = {
  for (final family in _families) family.id: family,
};

const List<String> _tierLabels = [
  '입문',
  '불씨',
  '도약',
  '몰입',
  '집중',
  '정진',
  '숙련',
  '정예',
  '마스터',
  '레전드',
  '프리즘',
  '오로라',
];

Iterable<ActivityBadgeDefinition> _buildFamilyBadges(
  _ActivityBadgeFamily family,
) sync* {
  for (var index = 0; index < family.thresholds.length; index++) {
    final threshold = family.thresholds[index];
    final tier = index + 1;
    yield ActivityBadgeDefinition(
      id: '${family.id}_${tier.toString().padLeft(2, '0')}',
      family: family.id,
      title: '${family.title} ${_tierLabels[index]}',
      description:
          '${family.description} ${_formatThreshold(threshold, family.unit)} 달성',
      metricLabel: family.metricLabel,
      unit: family.unit,
      threshold: threshold,
      tier: tier,
      rarity: _rarityForTier(index),
      icon: family.icon,
      color: _colorForTier(family.color, index),
    );
  }
}

ActivityBadgeRarity _rarityForTier(int index) {
  if (index >= 10) return ActivityBadgeRarity.aurora;
  if (index >= 8) return ActivityBadgeRarity.radiant;
  if (index >= 6) return ActivityBadgeRarity.elite;
  if (index >= 4) return ActivityBadgeRarity.focused;
  if (index >= 2) return ActivityBadgeRarity.steady;
  return ActivityBadgeRarity.basic;
}

Color _colorForTier(Color base, int index) {
  final hsl = HSLColor.fromColor(base);
  final lightness = (hsl.lightness + (index - 5) * 0.018).clamp(0.28, 0.64);
  final saturation = (hsl.saturation + index * 0.018).clamp(0.48, 0.95);
  return hsl.withLightness(lightness).withSaturation(saturation).toColor();
}

String _formatThreshold(int value, String unit) {
  if (unit == '%') return '$value%';
  return '$value$unit';
}

bool _hasActivity(ActivityDayRecord record) {
  return record.score > 0 ||
      record.problemNumbers.isNotEmpty ||
      record.bookNumbers.isNotEmpty ||
      record.courseNumbers.isNotEmpty ||
      record.examNumbers.isNotEmpty ||
      record.graphNumbers.isNotEmpty;
}

int _streakDays(ActivitySnapshot snapshot, DateTime now) {
  var streak = 0;
  var cursor = DateTime(now.year, now.month, now.day);
  while (true) {
    final record = snapshot.days[_dateKey(cursor)];
    if (record == null || !_hasActivity(record)) return streak;
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
}

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
