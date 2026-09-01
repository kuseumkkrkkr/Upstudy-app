import 'package:flutter/material.dart';

import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/course/session/course_learning_page.dart';

/// 코스 런타임 딥링크 진입점이다.
///
/// `courseId`가 있으면 실제 코스 상세를 조회해 학습 화면으로 연결하고,
/// 인자가 없는 과거 주소만 코스 탐색으로 안전하게 위임한다.
class CourseRuntimePage extends StatefulWidget {
  const CourseRuntimePage({super.key, this.courseId});

  static const String routeName = '/course_runtime';
  final String? courseId;

  @override
  State<CourseRuntimePage> createState() => _CourseRuntimePageState();
}

class _CourseRuntimePageState extends State<CourseRuntimePage> {
  Future<Course>? _future;

  @override
  void initState() {
    super.initState();
    final courseId = widget.courseId?.trim() ?? '';
    if (courseId.isNotEmpty) _future = CourseService.fetchCourse(courseId);
  }

  Widget _shell(Widget child) {
    return StudentHtmlShell(
      title: '코스 런타임',
      activeRoute: '/courses',
      child: Center(child: child),
    );
  }

  Widget _status({
    required String title,
    required String detail,
    bool error = false,
  }) {
    return StudentDensitySurface(
      key: ValueKey('course-runtime-${error ? 'error' : 'loading'}'),
      radius: 0,
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.sync_rounded,
              size: 40,
              color: error ? Colors.redAccent : StudentDensityTokens.ink,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: StudentDensityTokens.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (error) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/courses'),
                style: FilledButton.styleFrom(
                  backgroundColor: StudentDensityTokens.dark,
                  minimumSize: const Size.fromHeight(48),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Text('코스 목록으로 돌아가기'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) return const CourseCatalogPage();
    return FutureBuilder<Course>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _shell(
            _status(title: '학습을 준비하고 있어요.', detail: '실제 코스 진행 상태를 불러오는 중입니다.'),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _shell(
            _status(
              title: '코스를 열지 못했어요.',
              detail: '인증 또는 코스 상태를 확인한 뒤 다시 코스 목록에서 시도해 주세요.',
              error: true,
            ),
          );
        }
        return CourseLearningPage(course: snapshot.data!);
      },
    );
  }
}
