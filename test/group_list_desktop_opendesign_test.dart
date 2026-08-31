import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/features/group_study/group_list_page.dart';
import 'package:s11/shared/services/api/api_client.dart';

void main() {
  const viewport = Size(1280, 900);
  final group = StudyGroup(
    id: 'group-1',
    name: '수학 루틴',
    description: '매주 미적분 문제를 함께 풀어요.',
    memberCount: 3,
    maxMembers: 5,
  );

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: GroupListPage(initialGroups: [group]),
        onGenerateRoute: (settings) {
          if (settings.name == '/group/detail') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('group-detail-target')),
            );
          }
          return null;
        },
      ),
    );
    await tester.pump();
  }

  testWidgets('1280 그룹 화면은 기존 데스크톱 목록과 실제 상세 이동을 유지한다', (tester) async {
    await pumpPage(tester);

    expect(find.text('그룹 스터디'), findsOneWidget);
    expect(find.text('내 그룹'), findsOneWidget);
    expect(find.text('수학 루틴'), findsOneWidget);
    expect(find.text('그룹 찾기 · 코드 참가'), findsOneWidget);
    expect(find.text('그룹 만들기'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('수학 루틴'));
    await tester.pumpAndSettle();
    expect(find.text('group-detail-target'), findsOneWidget);
  });
}
