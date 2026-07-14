import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/exam_paper/exam_paper.dart';
import 'package:s11/shared/data/models/course.dart';

Course _course({
  String? status,
  double progress = 0,
  Map<String, dynamic>? detail,
}) {
  return Course(
    id: 'course-1',
    title: '테스트 코스',
    description: '상태별 진입 검증',
    level: '기본',
    duration: '7일',
    status: status,
    progress: progress,
    progressDetail: detail ?? const <String, dynamic>{},
  );
}

void main() {
  test('Course.isCompleted가 완료 판정의 단일 기준이다', () {
    expect(_course(status: 'completed').isCompleted, isTrue);
    expect(_course(status: 'finished').isCompleted, isTrue);
    expect(_course(progress: 1).isCompleted, isTrue);
    expect(_course(status: 'in_progress', progress: .7).isCompleted, isFalse);
  });

  test('수강 중 코스만 학습으로 직행하고 완료 코스는 상세로 간다', () {
    expect(
      courseEntryTarget(_course(status: 'in_progress')),
      CourseEntryTarget.learning,
    );
    expect(
      courseEntryTarget(_course(status: 'completed')),
      CourseEntryTarget.detail,
    );
    expect(courseEntryTarget(_course()), CourseEntryTarget.detail);
  });

  testWidgets('시험 진도 제출 실패는 재시도 성공 전 완료를 차단한다', (tester) async {
    var retryCount = 0;
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModuleSubmissionFooter(
            passed: true,
            submissionRequired: true,
            initialSubmissionSucceeded: false,
            onRetry: () async {
              retryCount += 1;
              return true;
            },
            onComplete: () => completed = true,
          ),
        ),
      ),
    );

    expect(find.text('진도 제출이 필요해요'), findsOneWidget);
    await tester.tap(find.text('코스 진도 다시 제출'));
    await tester.pumpAndSettle();
    expect(retryCount, 1);
    expect(find.text('완료'), findsOneWidget);
    await tester.tap(find.text('완료'));
    expect(completed, isTrue);
  });
}
