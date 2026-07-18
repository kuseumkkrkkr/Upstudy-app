import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/study_mode_modal.dart';

/// 필요한 변수는 500px 테스트 화면과 학습하기 진입 버튼이다.
/// 작동 원리는 시험지 모달 전환 시 부모가 제거되고, 뒤로가면 부모만 복원되는지 확인한다.
void main() {
  testWidgets('시험지 모달은 학습하기와 겹치지 않고 뒤로가면 학습하기를 복원한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStudyModeModal<void>(context: context),
              child: const Text('학습 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('학습 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(StudypageCopyWidget), findsOneWidget);

    await tester.tap(find.text('시험지'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(StudypageCopyWidget), findsNothing);
    expect(find.text('시험지 학습하기'), findsOneWidget);

    await tester.tap(find.byTooltip('학습하기로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('시험지 학습하기'), findsNothing);
    expect(find.byType(StudypageCopyWidget), findsOneWidget);
  });
}
