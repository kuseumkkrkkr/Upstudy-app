// This is a basic Flutter widget test.
//
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:s11_teacher/main.dart';
import 'package:s11_teacher/pages/problem_editor_page.dart';

void main() {
  testWidgets('Teacher app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TeacherApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Problem editor renders advanced canvas controls', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: ProblemEditorPage(initialTags: ['#함수'])),
    );
    await tester.pump();

    expect(find.text('문항 제작 스튜디오'), findsOneWidget);

    await tester.tap(find.text('고급'));
    await tester.pumpAndSettle();

    expect(find.text('풀이 논리 캔버스'), findsOneWidget);
    expect(find.text('고급 설정'), findsOneWidget);
    expect(find.text('파라미터'), findsOneWidget);
    expect(find.text('문항 생성'), findsOneWidget);
  });
}
