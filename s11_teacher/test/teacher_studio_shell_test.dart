import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11_teacher/shared/ui/ios26/teacher_studio_shell.dart';

/// 필요 변수: 테스트 화면 크기와 공통 스튜디오 셸.
/// 작동 원리: PC 폭에서는 사이드바 접기와 단일 화면 제목을, 모바일 폭에서는
/// 하단 핵심 탐색 노출을 확인해 반응형 재구성이 기능 경로를 가리지 않는지 검증한다.
void main() {
  Widget buildShell() {
    return const MaterialApp(
      home: TeacherStudioShell(
        currentRoute: '/dashboard',
        eyebrow: 'TEST WORKSPACE',
        title: '테스트 작업',
        description: '공통 셸의 반응형 동작을 확인합니다.',
        endDrawer: Drawer(child: Text('전체 메뉴')),
        child: ColoredBox(color: Colors.white),
      ),
    );
  }

  testWidgets('PC 사이드바를 접어 작업 폭을 확장하고 제목은 한 번만 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    expect(find.text('테스트 작업'), findsOneWidget);
    expect(find.text('교사용 홈'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_left_rounded));
    await tester.pumpAndSettle();

    expect(find.text('교사용 홈'), findsNothing);
    expect(
      find.byIcon(Icons.keyboard_double_arrow_right_rounded),
      findsOneWidget,
    );
  });

  testWidgets('모바일에서는 핵심 경로를 하단 탐색으로 유지한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    expect(find.text('테스트 작업'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('문항'), findsOneWidget);
    expect(find.text('편집'), findsOneWidget);
    expect(find.text('그룹'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
  });
}
