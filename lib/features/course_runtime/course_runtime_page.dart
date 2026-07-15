import 'package:flutter/material.dart';

import 'package:s11/sessions/course/ui/course_catalog_page.dart';

/// 인자 없는 과거 코스 런타임 주소의 호환 페이지다.
class CourseRuntimePage extends StatelessWidget {
  const CourseRuntimePage({super.key});

  static const String routeName = '/course_runtime';

  /// 필요한 변수는 실제 코스·런타임 상태를 고르는 코스 목록이다.
  /// 작동 원리: 과거 경로에는 courseId가 없어 학습 화면을 안전하게 복원할 수 없으므로,
  /// HTML 시안과 같은 코스 탐색 화면으로 위임해 사용자가 실제 CourseLearningPage로 진입하게 한다.
  @override
  Widget build(BuildContext context) => const CourseCatalogPage();
}
