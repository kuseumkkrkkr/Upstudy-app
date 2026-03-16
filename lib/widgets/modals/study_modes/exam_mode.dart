import 'package:flutter/material.dart';
import 'package:s11/dialogs/buildbox_widget.dart';
import 'package:s11/pages/exam_paper_page.dart';

VoidCallback buildExamAction(BuildContext context) {
  return () {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future.microtask(
      () => navigator.push(
        MaterialPageRoute(
          builder: (_) => BuildboxWidget(
            title: '시험지 생성',
            fixedQuestionCount: 30,
            submitLabel: '시험 풀기',
            onExamCreated: (context, examId) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ExamPaperPage(examId: examId),
                ),
              );
            },
          ),
        ),
      ),
    );
  };
}
