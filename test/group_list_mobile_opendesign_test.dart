import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/features/group_study/group_list_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/friend/friend.dart';

void main() {
  const viewport = Size(390, 844);
  final group = StudyGroup(
    id: 'group-1',
    name: '수학 루틴',
    description: '매주 미적분 문제를 함께 풀어요.',
    memberCount: 3,
    maxMembers: 5,
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    required List<Object> groups,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: GroupListPage(initialGroups: groups),
        routes: {'/social': (_) => const Scaffold(body: Text('social-target'))},
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

  testWidgets('390×844 그룹 탭은 시안의 64/52 헤더와 92px 계층을 유지한다', (tester) async {
    await pumpPage(tester, groups: const []);

    final topbar = find.byKey(const ValueKey('groups-mobile-topbar'));
    final tabs = find.byKey(const ValueKey('groups-mobile-tabs'));
    final heading = find.byKey(const ValueKey('groups-mobile-heading'));
    final empty = find.byKey(const ValueKey('groups-mobile-empty'));
    final add = find.byKey(const ValueKey('groups-mobile-add'));
    final emptyAdd = find.byKey(const ValueKey('groups-mobile-empty-add'));

    expect(tester.getSize(topbar), const Size(390, 64));
    expect(tester.getTopLeft(tabs).dy, closeTo(64, 1));
    expect(tester.getSize(tabs).height, closeTo(52, 1));
    expect(tester.getTopLeft(heading).dy, closeTo(116, 1));
    expect(tester.getTopLeft(add), const Offset(262, 138));
    expect(tester.getSize(add), const Size(114, 48));
    expect(tester.getTopLeft(emptyAdd).dx, closeTo(262, 1));
    expect(tester.getSize(emptyAdd), const Size(114, 60));
    expect(tester.getTopLeft(empty).dy, closeTo(201, 1));
    expect(tester.getSize(empty).height, closeTo(92, 1));
    expect(find.text('그룹 0/3'), findsOneWidget);
    expect(find.text('참여 중인 그룹에서 학습을 이어가세요.'), findsOneWidget);
    expect(find.text('참여 중인 그룹이 없어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그룹 추가는 사각 시트 세 진입과 기존 검색/생성 흐름을 연다', (tester) async {
    await pumpPage(tester, groups: const []);

    await tester.tap(find.byKey(const ValueKey('groups-mobile-add')));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const ValueKey('group-mobile-add-sheet'));
    expect(sheet, findsOneWidget);
    expect(tester.getTopLeft(sheet).dy, closeTo(539, 10));
    expect(tester.getSize(sheet).height, closeTo(305, 1));
    expect(
      tester.getSize(find.byKey(const ValueKey('group-mobile-add-close'))),
      const Size(48, 48),
    );
    expect(find.text('공개 그룹 찾기'), findsOneWidget);
    expect(find.text('코드로 참여'), findsOneWidget);
    expect(find.text('그룹 만들기'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('group-mobile-find')));
    await tester.pumpAndSettle();
    expect(find.text('그룹 찾기'), findsOneWidget);
  });

  testWidgets('실제 그룹 행은 상세 route로, 대화/친구 탭은 해당 소셜 탭으로 이동한다', (tester) async {
    await pumpPage(tester, groups: [group]);

    await tester.tap(find.byKey(const ValueKey('groups-mobile-tab-대화')));
    await tester.pumpAndSettle();
    final conversation = find.byType(FriendScreen);
    expect(conversation, findsOneWidget);
    expect(tester.widget<FriendScreen>(conversation).initialTab, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('groups-mobile-tab-친구')));
    await tester.pumpAndSettle();
    final friends = find.byType(FriendScreen);
    expect(friends, findsOneWidget);
    expect(tester.widget<FriendScreen>(friends).initialTab, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('groups-mobile-row-group-1')));
    await tester.pumpAndSettle();
    expect(find.text('group-detail-target'), findsOneWidget);
  });
}
