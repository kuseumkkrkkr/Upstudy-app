import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/study_mode_modal.dart';

/// 필요한 변수는 390x844 모바일 화면과 학습하기 모달 진입 버튼이다.
/// 작동 원리는 모바일 전용 순백 표면·여섯 학습 행·단일 닫기 구조가 작은 화면에서도 유지되는지 확인하는 것이다.
void main() {
  testWidgets('모바일 학습하기는 순백 표면과 여섯 개의 큰 학습 행을 사용한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
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

    final surface = tester.widget<Material>(
      find.byKey(const ValueKey('study-mode-mobile-surface')),
    );
    expect(surface.color, Colors.white);
    expect(
      find.byKey(const ValueKey('study-mode-mobile-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('study-mode-mobile-close')),
      findsOneWidget,
    );
    expect(find.byType(OutlinedButton), findsNothing);

    for (final label in ['이어하기', '코스보기', '복습', '문제세트', '시험지', '교재보기']) {
      expect(find.byKey(ValueKey('study-mode-mobile-$label')), findsOneWidget);
    }
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('study-mode-mobile-교재보기')))
          .dy,
      lessThanOrEqualTo(844),
    );
  });
}
