class SignupDraft {
  const SignupDraft({
    required this.displayName,
    required this.track,
    required this.gradeLabel,
    required this.schoolName,
    this.subject,
  });

  final String displayName;
  final String track;
  final String gradeLabel;
  final String schoolName;
  final String? subject;

  String get displayGrade {
    final buffer = StringBuffer();
    buffer.write(track);
    buffer.write(' ');
    buffer.write(gradeLabel);
    return buffer.toString();
  }

  String get gradeSummary {
    final buffer = StringBuffer();
    buffer.write(displayGrade);
    if (subject != null && subject!.trim().isNotEmpty) {
      buffer.write(' / ');
      buffer.write(subject);
    }
    return buffer.toString();
  }
}
