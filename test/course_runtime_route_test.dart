import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:s11/app/router.dart';

void main() {
  testWidgets('인자 없는 course_runtime은 코스 목록으로 조용히 대체하지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.courseRuntime,
        routes: appRoutes(),
        onGenerateRoute: onGenerateAppRoute,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('코스 ID가 필요해요.'), findsOneWidget);
    expect(find.text('학습을 시작하려면 실제 코스에서 이어하기를 눌러 주세요.'), findsOneWidget);
    expect(find.text('코스 목록으로 돌아가기'), findsOneWidget);
  });
}
