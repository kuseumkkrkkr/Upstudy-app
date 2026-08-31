import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/features/group_study/group_detail_page.dart';
import 'package:s11/shared/services/api/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var groupMessageGetCount = 0;

  setUp(() {
    groupMessageGetCount = 0;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        final Object body;
        if (request.url.path == '/auth/me') {
          body = <String, Object>{'user_id': 'me', 'username': '나'};
        } else if (request.url.path == '/social/friends') {
          body = <String, Object>{
            'friends': <Object>[
              <String, Object>{
                'user_id': 'friend-2',
                'username': 'invite_friend',
                'name': '초대 친구',
              },
            ],
          };
        } else if (request.url.path.endsWith('/members')) {
          body = <Object>[
            <String, Object>{'username': '나', 'role': 'admin'},
            <String, Object>{'username': '수학친구', 'role': 'member'},
            <String, Object>{'username': 'invite_friend', 'role': 'member'},
          ];
        } else if (request.url.path == '/social/study-groups/mine') {
          body = <String, Object>{
            'groups': <Object>[
              <String, Object>{
                'group_id': 'group-1',
                'name': '중등 수학 챌린지',
                'members': 3,
                'max_members': 12,
              },
            ],
          };
        } else if (request.url.path.endsWith('/invite-friend')) {
          body = <String, Object>{'group_id': 'group-1'};
        } else if (request.url.path.endsWith('/messages')) {
          groupMessageGetCount += 1;
          body = <String, Object>{
            'messages': request.url.queryParameters.containsKey('before')
                ? <Object>[]
                : List<Object>.generate(
                    30,
                    (index) => <String, Object>{
                      'message_id': 'message-$index',
                      'user_id': index.isEven ? 'me' : 'friend-1',
                      'sender_name': index.isEven ? '나' : '수학친구',
                      'text': '메시지 $index',
                      'created_at':
                          '2026-08-09T00:${index.toString().padLeft(2, '0')}:00Z',
                    },
                  ),
          };
        } else if (request.url.path.endsWith('/schedules')) {
          body = <String, Object>{'schedules': <Object>[]};
        } else if (request.url.path.endsWith('/shared-flows')) {
          body = <Object>[];
        } else {
          body = <String, Object>{'items': <Object>[]};
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  tearDown(() async {
    ApiClient.instance.setHttpClientForTest(http.Client());
    await ApiClient.instance.clearToken();
  });

  testWidgets('모바일 그룹 상세는 핵심 기능을 단일 대시보드에 유지한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await ApiClient.instance.setToken('group-detail-mobile-token');

    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailPage(
          groupId: 'group-1',
          initialGroup: StudyGroup(
            id: 'group-1',
            name: '중2 수학 챌린지',
            description: '매일 한 문제씩 함께 풀어요',
            memberCount: 2,
            maxMembers: 12,
          ),
          initialMembers: const [
            StudyGroupMember(username: '나', role: 'admin'),
            StudyGroupMember(username: '수학친구'),
          ],
          initialShareHistory: const [],
          initialShareExams: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-group-dashboard')),
      findsOneWidget,
    );
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
    expect(find.byTooltip('뒤로가기'), findsOneWidget);
    expect(find.byTooltip('검색'), findsOneWidget);
    expect(find.byTooltip('알림'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-group-overview')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-group-schedule')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mobile-group-resource-switch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-group-resources')),
      findsOneWidget,
    );
    expect(find.text('STUDY GROUP'), findsNothing);
    expect(find.text('2 / 12명'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-group-add-schedule')));
    await tester.pumpAndSettle();
    expect(find.text('그룹 일정 추가'), findsOneWidget);
    Navigator.of(tester.element(find.text('그룹 일정 추가'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mobile-group-members')));
    await tester.pumpAndSettle();
    expect(find.text('그룹 멤버'), findsOneWidget);
    expect(find.text('수학친구'), findsOneWidget);
    expect(find.byKey(const ValueKey('group-member-scroll')), findsOneWidget);
    expect(find.text('관리자'), findsOneWidget);
    expect(find.text('N MEMBERS'), findsNothing);
    expect(find.textContaining('MEMBERS'), findsNothing);
    expect(find.text('현재 그룹의 멤버와 역할을 확인합니다.'), findsNothing);
    expect(find.textContaining('사용자 ID'), findsNothing);
    expect(find.byKey(const ValueKey('member-actions-수학친구')), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-study-group')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-invite-friend')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('group-invite-friend')));
    await tester.pumpAndSettle();
    expect(find.text('내 친구 초대'), findsWidgets);
    expect(find.text('초대 친구'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '초대').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mobile-group-chat')));
    await tester.pumpAndSettle();
    expect(find.text('이전 메시지 더보기'), findsNothing);
    expect(find.textContaining('최근 30개부터 표시'), findsNothing);
    expect(find.byIcon(Icons.history_rounded), findsNothing);
    await tester.fling(find.byType(ListView).last, const Offset(0, 1200), 2500);
    await tester.pumpAndSettle();
    expect(groupMessageGetCount, greaterThanOrEqualTo(2));
    Navigator.of(tester.element(find.text('메시지 0'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('시험지'));
    await tester.tap(find.text('시험지'));
    await tester.pump();
    expect(find.text('공유된 시험지'), findsOneWidget);
    expect(find.text('시험지 공유'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '필터'));
    await tester.pumpAndSettle();
    expect(find.text('공유 시험지 필터'), findsOneWidget);
    Navigator.of(tester.element(find.text('공유 시험지 필터'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '시험지 공유'));
    await tester.pumpAndSettle();
    expect(find.text('SHARE EXAM'), findsOneWidget);
    expect(find.text('선택 항목 공유'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그룹 상세 PC는 친구/소셜 공용 내비게이션을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await ApiClient.instance.setToken('group-detail-desktop-token');

    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailPage(
          groupId: 'group-1',
          initialGroup: StudyGroup(
            id: 'group-1',
            name: '중2 수학 챌린지',
            description: '매일 한 문제씩 함께 풀어요',
            memberCount: 2,
            maxMembers: 12,
          ),
          initialMembers: const [
            StudyGroupMember(username: '나', role: 'admin'),
            StudyGroupMember(username: '수학친구'),
          ],
          initialShareHistory: const [],
          initialShareExams: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('student-top-nav-친구/소셜')), findsOneWidget);
    expect(find.byTooltip('검색'), findsOneWidget);
    expect(find.byTooltip('알림'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('student-mobile-menu')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('STUDY GROUP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
