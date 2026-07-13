import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11_teacher/pages/course_list_page.dart';
import 'package:s11_teacher/pages/teacher_dashboard_page.dart';
import 'package:s11_teacher/shared/ui/ios26/teacher_adaptive_panel.dart';

/// 필요 변수: 모바일·PC 테스트 화면과 새 작업 중심 UI.
/// 작동 원리: 기능 카드 나열이 작업 단계로 바뀌었는지, 필터와 확인 작업이 별도
/// 적응형 작업면에서 열리고 기존 Navigator 반환값을 유지하는지 검증한다.
void main() {
  testWidgets('교사용 홈은 제작·준비·운영 순서로 작업을 안내한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: TeacherDashboardPage()));
    await tester.pump();

    expect(find.text('제작 시작'), findsOneWidget);
    expect(find.text('수업 준비'), findsOneWidget);
    expect(find.text('운영 확인'), findsOneWidget);
    expect(find.text('코스 교재 흐름'), findsNothing);
    expect(find.text('빠른 점검'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('코스 필터는 상시 드롭다운 대신 보기 작업면에서 편집한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: CourseListPage()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.textContaining('전체 · 최근 수정'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('목록 보기 방식'), findsOneWidget);
    expect(find.text('공개 상태'), findsOneWidget);
    expect(find.text('정렬 기준'), findsOneWidget);
    expect(find.text('이 보기 적용'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('검토 패널은 설명을 확인한 뒤 기존 bool 결과를 반환한다', (tester) async {
    bool? result;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showTeacherDecisionPanel(
                    context: context,
                    title: '코스 삭제',
                    description: '삭제 전에 영향을 확인합니다.',
                    confirmLabel: '삭제하기',
                    destructive: true,
                    consequences: const ['코스 목록에서 제거됩니다.'],
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('실행 전 확인할 내용'), findsOneWidget);
    expect(find.text('코스 목록에서 제거됩니다.'), findsOneWidget);

    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
