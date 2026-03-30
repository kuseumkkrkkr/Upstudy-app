import 'package:flutter/material.dart';
import 'package:s11/book_page.dart';
import 'package:s11/models/course.dart';
import 'package:s11/pages/course_learning_page.dart';
import 'package:s11/pages/course_pages.dart';
import 'package:s11/services/activity_store.dart';
import 'package:s11/services/textbook_store.dart';
import 'package:s11/tryout.dart';

VoidCallback buildResumeAction(BuildContext context) {
  return () {
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(navigator.context);
    navigator.pop();
    Future.microtask(() async {
      final snapshot = await ActivityStore.load();
      if (!navigator.mounted || !messenger.mounted) return;
      final last = snapshot.lastEvent;
      if (last == null) {
        _showMessage(messenger, '최근 활동이 없습니다.');
        return;
      }
      switch (last.type) {
        case ActivityEventType.book:
          final book = await TextbookStore.getById(last.id);
          if (book == null) {
            _showMessage(messenger, '최근 교재를 찾을 수 없습니다.');
            return;
          }
          navigator.push(
            MaterialPageRoute(builder: (_) => BookWidget(book: book)),
          );
          return;
        case ActivityEventType.course:
          Course? course;
          for (final entry in kSampleCourses) {
            if (entry.id == last.id) {
              course = entry;
              break;
            }
          }
          if (course == null) {
            _showMessage(messenger, '최근 코스를 찾을 수 없습니다.');
            return;
          }
          final Course resolvedCourse = course;
          final screen = last.meta?['screen']?.toString();
          if (screen == 'learning') {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => CourseLearningPage(course: resolvedCourse),
              ),
            );
            return;
          }
          navigator.push(
            MaterialPageRoute(
              builder: (_) => CourseDetailPage(course: resolvedCourse),
            ),
          );
          return;
        case ActivityEventType.problem:
          final configRaw =
              last.meta?['config'] ?? snapshot.lastProblemConfig;
          final config = configRaw is Map
              ? ProblemSolveConfig.fromJson(
                  Map<String, dynamic>.from(configRaw),
                )
              : const ProblemSolveConfig();
          navigator.push(
            MaterialPageRoute(
              builder: (_) => BuildpageWidget(config: config),
            ),
          );
          return;
        default:
          _showMessage(messenger, '최근 활동을 불러올 수 없습니다.');
      }
    });
  };
}

void _showMessage(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
