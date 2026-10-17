/// A module completion proven by the existing runtime's persisted day offset.
/// This is not a full curriculum state-transition or redistribution log.
class ConfirmedCourseCompletion {
  const ConfirmedCourseCompletion({
    required this.moduleId,
    required this.title,
    required this.completedAt,
  });
  final String moduleId;
  final String title;
  final DateTime completedAt;

  Map<String, String> toHistoryItem() => {
    'moduleId': moduleId,
    'title': title,
    'date':
        '${completedAt.year.toString().padLeft(4, '0')}-${completedAt.month.toString().padLeft(2, '0')}-${completedAt.day.toString().padLeft(2, '0')}',
    'newStatus': '완료',
  };

  /// Requires a persisted start ordinal, completion offset, completed ID and real title.
  /// Missing or malformed facts are omitted, never replaced with today's date.
  static List<ConfirmedCourseCompletion> fromRuntime(
    Map<String, dynamic> runtime,
  ) {
    final state = runtime['student_state'];
    final curriculum = runtime['curriculum'];
    if (state is! Map || curriculum is! Map) return const [];
    final started = state['started_day'];
    final completionDays = state['module_completed_day'];
    final completedIds = state['completed_modules'];
    final schedule = curriculum['schedule'];
    if (started is! int ||
        started < 1 ||
        started > 3652059 ||
        completionDays is! Map ||
        completedIds is! List ||
        schedule is! List) {
      return const [];
    }
    final completedIdSet = completedIds.toSet();
    final titles = <String, String>{};
    for (final module in schedule.whereType<Map>()) {
      final id = module['module_id'];
      final title = module['title'];
      if (id is String &&
          id.isNotEmpty &&
          title is String &&
          title.trim().isNotEmpty) {
        titles[id] = title.trim();
      }
    }
    final result = <ConfirmedCourseCompletion>[];
    for (final entry in completionDays.entries) {
      final id = entry.key;
      final offset = entry.value;
      if (id is! String ||
          !completedIdSet.contains(id) ||
          !titles.containsKey(id) ||
          offset is! int ||
          offset < 0 ||
          started + offset > 3652059) {
        continue;
      }
      result.add(
        ConfirmedCourseCompletion(
          moduleId: id,
          title: titles[id]!,
          completedAt: DateTime.utc(
            1,
            1,
            1,
          ).add(Duration(days: started - 1 + offset)),
        ),
      );
    }
    result.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return result;
  }
}
