// This is a basic Flutter widget test.
//
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:s11_teacher/main.dart';

void main() {
  testWidgets('Teacher app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TeacherApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
