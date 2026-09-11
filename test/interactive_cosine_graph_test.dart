import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/ui/graphs/interactive_cosine_graph.dart';

void main() {
  testWidgets('그래프는 접근성 설명과 확대 제스처를 제공한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(height: 320, child: InteractiveCosineGraph())),
      ),
    );

    expect(find.bySemanticsLabel('코사인 함수 그래프'), findsOneWidget);
    final before = tester.getSize(find.byType(CustomPaint).first);
    await tester.startGesture(const Offset(160, 150));
    await tester.pump();
    expect(tester.getSize(find.byType(CustomPaint).first), before);
  });
}
