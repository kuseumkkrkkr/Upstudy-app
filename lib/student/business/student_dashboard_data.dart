class StudentDashboardData {
  const StudentDashboardData({
    required this.username,
    required this.grade,
    required this.profileImageUrl,
    required this.completionRate,
    required this.activityLevels,
    this.dailyGraphLabel = '{Daily_Graph_Grid}',
  });

  final String username;
  final String grade;
  final String profileImageUrl;
  final double completionRate; // 0.0 ~ 1.0
  final List<int> activityLevels; // Github-style activity heatmap
  final String dailyGraphLabel;

  static const String defaultProfileImage =
      'https://images.unsplash.com/photo-1601370690183-1c7796ecec61';

  static const StudentDashboardData demo = StudentDashboardData(
    username: '학생',
    grade: '3학년',
    profileImageUrl: defaultProfileImage,
    completionRate: 0.5,
    activityLevels: demoActivityLevels,
  );

  StudentDashboardData copyWith({
    String? username,
    String? grade,
    String? profileImageUrl,
    double? completionRate,
    List<int>? activityLevels,
    String? dailyGraphLabel,
  }) {
    return StudentDashboardData(
      username: username ?? this.username,
      grade: grade ?? this.grade,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      completionRate: completionRate ?? this.completionRate,
      activityLevels: activityLevels ?? this.activityLevels,
      dailyGraphLabel: dailyGraphLabel ?? this.dailyGraphLabel,
    );
  }

  static const List<int> demoActivityLevels = <int>[
    // row 1 ~ 10
    0, 1, 2, 1, 3, 0,
    1, 2, 3, 4, 2, 1,
    0, 0, 1, 2, 3, 2,
    4, 3, 2, 1, 2, 3,
    0, 1, 0, 1, 2, 1,
    2, 3, 2, 1, 0, 1,

    // row 11 ~ 20
    0, 1, 2, 1, 3, 0,
    1, 2, 3, 4, 2, 1,
    0, 0, 1, 2, 3, 2,
    4, 3, 2, 1, 2, 3,
    0, 1, 0, 1, 2, 1,
    2, 3, 2, 1, 0, 1,

    // row 21 ~ 30
    0, 1, 2, 1, 3, 0,
    1, 2, 3, 4, 2, 1,
    0, 0, 1, 2, 3, 2,
    4, 3, 2, 1, 2, 3,
    0, 1, 0, 1, 2, 1,
    2, 3, 2, 1, 0, 1,

    // row 31 ~ 40
    0, 1, 2, 1, 3, 0,
    1, 2, 3, 4, 2, 1,
    0, 0, 1, 2, 3, 2,
    4, 3, 2, 1, 2, 3,
    0, 1, 0, 1, 2, 1,
    2, 3, 2, 1, 0, 1,

    // row 41 ~ 50
    0, 1, 2, 1, 3, 0,
    1, 2, 3, 4, 2, 1,
    0, 0, 1, 2, 3, 2,
    4, 3, 2, 1, 2, 3,
    0, 1, 0, 1, 2, 1,
    2, 3, 2, 1, 0, 1,

    // row 51 ~ 60
    0, 1, 2, 1, 3, 0,
    1, 2, 3, 4, 2, 1,
    0, 0, 1, 2, 3, 2,
    4, 3, 2, 1, 2, 3,
    0, 1, 0, 1, 2, 1,
    2, 3, 2, 1, 0, 1,

    // row 61 ~ 70
    0, 1, 2, 1, 3, 0,
    1, 2, 3, 4, 2, 1,
    0, 0, 1, 2, 3, 2,
    4, 3, 2, 1, 2, 3,
  ];
}
