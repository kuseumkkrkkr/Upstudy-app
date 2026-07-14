import 'package:flutter/material.dart';

import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/sessions/course/session/course_learning_page.dart';
import 'package:s11/sessions/course/session/course_pages.dart';
import 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/business/repositories/textbook_store.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

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
        _showMessage(messenger, '최근 이어서 할 항목이 없습니다.');
        return;
      }
      switch (last.type) {
        case ActivityEventType.exam:
          final examId = last.id.trim();
          if (examId.isEmpty) {
            _showMessage(messenger, '최근 시험 정보를 찾을 수 없습니다.');
            return;
          }
          final questionCountRaw = last.meta?['questionCount'];
          final expectedQuestions = questionCountRaw is num
              ? questionCountRaw.toInt()
              : null;
          navigator.push(
            MaterialPageRoute(
              builder: (_) => ExamPaperPage(
                examId: examId,
                expectedQuestionCount: expectedQuestions,
              ),
            ),
          );
          return;
        case ActivityEventType.book:
          final book = await TextbookStore.getById(last.id);
          if (book == null) {
            _showMessage(messenger, '최근 열었던 교재를 찾을 수 없습니다.');
            return;
          }
          navigator.push(
            MaterialPageRoute(builder: (_) => BookWidget(book: book)),
          );
          return;
        case ActivityEventType.course:
          Course? course;
          try {
            course = await CourseService.fetchCourse(last.id);
          } catch (_) {
            course = null;
          }
          if (course == null) {
            _showMessage(messenger, '최근 코스를 불러오지 못했습니다.');
            return;
          }
          final screen = last.meta?['screen']?.toString();
          if (screen == 'learning' && !course.isCompleted) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => CourseLearningPage(course: course!),
              ),
            );
            return;
          }
          navigator.push(
            MaterialPageRoute(
              builder: (_) => CourseDetailPage(course: course!),
            ),
          );
          return;
        case ActivityEventType.problem:
          final configRaw = last.meta?['config'] ?? snapshot.lastProblemConfig;
          final config = configRaw is Map
              ? ProblemSolveConfig.fromJson(
                  Map<String, dynamic>.from(configRaw),
                )
              : const ProblemSolveConfig();
          navigator.push(
            MaterialPageRoute(builder: (_) => BuildpageWidget(config: config)),
          );
          return;
        default:
          _showMessage(messenger, '이어할 내용을 찾지 못했습니다.');
      }
    });
  };
}

void _showMessage(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
