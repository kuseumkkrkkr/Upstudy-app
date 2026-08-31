import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/features/group_study/group_list_page.dart';
import 'package:s11/sessions/friend/friend.dart';
import 'package:s11/sessions/friend/ui/student_direct_chat_page.dart';
import 'package:s11/shared/services/api/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    ApiClient.instance.setHttpClientForTest(http.Client());
    await ApiClient.instance.clearToken();
  });

  testWidgets('모바일 친구 추가는 바텀시트에서 검색 후 요청을 한 번만 전송한다', (tester) async {
    // 필요한 변수는 모바일 소셜 미리보기와 검색·요청 모의 API다.
    // 작동 원리는 친구 추가 시트를 열어 검색 결과를 표시하고 요청 성공 뒤 버튼이
    // 요청됨 상태로 잠기며 같은 사용자에게 중복 전송하지 않는지 확인한다.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final searchedQueries = <String>[];
    final requestedUsers = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SoWidget(
          preview: true,
          searchFriends: ({query, limit}) async {
            searchedQueries.add(query ?? '');
            return [
              FriendProfile(
                userId: 'friend-1',
                username: '테스트친구',
                status: '수학 학습 중',
                ovr: 81,
              ),
            ];
          },
          sendFriendRequest: ({required username, message}) async {
            requestedUsers.add(username);
            return FriendRequest(
              requestId: 'request-1',
              fromUserId: 'me',
              toUserId: 'friend-1',
              status: 'pending',
              username: username,
              direction: 'outgoing',
              message: message,
            );
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('친구 추가').first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-add-friend-sheet')),
      findsOneWidget,
    );
    expect(find.text('친구의 닉네임을 검색해 친구 요청을 보낼 수 있어요.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('friend-search-field')),
      '테스트',
    );
    await tester.tap(find.byKey(const ValueKey('friend-search-submit')));
    await tester.pumpAndSettle();

    expect(searchedQueries, ['테스트']);
    expect(find.text('테스트친구'), findsOneWidget);
    expect(find.text('수학 학습 중'), findsOneWidget);

    final requestButton = find.byKey(const ValueKey('friend-request-테스트친구'));
    await tester.tap(requestButton);
    await tester.pump();

    expect(requestedUsers, ['테스트친구']);
    expect(find.text('친구 요청을 보냈어요.'), findsOneWidget);
    expect(find.text('요청됨'), findsOneWidget);

    await tester.tap(requestButton);
    await tester.pump();
    expect(requestedUsers, ['테스트친구']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 친구 요청 행에서 받은 요청을 실제로 수락한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ApiClient.instance.setToken('friend-accept-test-token');
    final requests = <http.Request>[];
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/social/friends') {
          return http.Response(
            jsonEncode({
              'friends': [
                {
                  'user_id': 'friend-preview-1',
                  'username': '김그래프',
                  'name': '김그래프',
                  'ovr': 0,
                  'status': '',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'user_id': 'friend-preview-1',
            'username': '김그래프',
            'name': '김그래프',
            'ovr': 0,
            'status': '',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: SoWidget(preview: true)));
    await tester.pump();
    await tester.tap(find.text('친구 요청'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-friend-requests-sheet')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('accept-friend-request-preview-1')),
    );
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/social/friend-requests/preview-1/accept',
      ),
      isTrue,
    );
    expect(find.text('김그래프님을 친구로 추가했어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('390 친구 프로필은 받은 정보만 표시하고 기존 쪽지 화면으로 잇는다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ApiClient.instance.setToken('friend-profile-mobile-token');
    final requests = <http.Request>[];
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/social/friends') {
          return http.Response(
            jsonEncode({
              'friends': [
                {
                  'user_id': 'peer-graph-1',
                  'username': 'graph-user',
                  'name': '김그래프',
                  'profile_image': '',
                  'ovr': 87.5,
                  'status': '함수 단원 학습 중',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/social/friend-requests') {
          return http.Response(
            jsonEncode({'requests': <Object>[]}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.method == 'GET' &&
            (request.url.path == '/social/conversations' ||
                request.url.path == '/social/messages')) {
          return http.Response(
            jsonEncode({'messages': <Object>[]}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({'detail': 'unexpected ${request.url.path}'}),
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: SoWidget()));
    await tester.pumpAndSettle();

    final friendRow = find.byKey(const ValueKey('social-friend-peer-graph-1'));
    await tester.ensureVisible(friendRow);
    await tester.tap(friendRow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('프로필 보기'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-friend-profile-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('friend-profile-avatar-fallback')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('friend-profile-display-name')),
      findsOneWidget,
    );
    expect(find.text('김그래프'), findsOneWidget);
    expect(find.text('@graph-user'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('friend-profile-status')),
        matching: find.text('함수 단원 학습 중'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('friend-profile-ovr')),
        matching: find.text('88'),
      ),
      findsOneWidget,
    );
    expect(find.text('peer-graph-1'), findsNothing);
    expect(find.text('프로필 보기 기능은 준비 중입니다.'), findsNothing);

    final friendRequestsBefore = requests
        .where((request) => request.url.path == '/social/friends')
        .length;
    await tester.tap(
      find.byKey(const ValueKey('friend-profile-message-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StudentDirectChatPage), findsOneWidget);
    expect(
      requests.where((request) => request.url.path == '/social/friends').length,
      friendRequestsBefore,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('1280 친구 프로필은 제한된 데스크톱 다이얼로그다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SoWidget(preview: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('social-friend-이수학')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('프로필 보기'));
    await tester.pumpAndSettle();

    final dialog = find.byKey(const ValueKey('desktop-friend-profile-dialog'));
    expect(dialog, findsOneWidget);
    expect(
      find.byKey(const ValueKey('mobile-friend-profile-sheet')),
      findsNothing,
    );
    expect(tester.getSize(dialog).width, lessThanOrEqualTo(440));
    expect(tester.getSize(dialog).height, lessThanOrEqualTo(430));
    expect(
      find.byKey(const ValueKey('friend-profile-message-button')),
      findsOneWidget,
    );
    expect(find.text('프로필 보기 기능은 준비 중입니다.'), findsNothing);

    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 친구 소셜과 스터디 그룹은 서로 다른 페이지다', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SoWidget(preview: true)));
    await tester.pump();

    expect(find.text('친구/소셜'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('mobile-social-add-friend')))
          .width,
      greaterThan(330),
    );
    expect(
      find.byKey(const ValueKey('mobile-social-summary-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-recent-conversations-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-friends-status-card')),
      findsOneWidget,
    );
    expect(find.text('활동 중인 그룹'), findsNothing);
    expect(
      find.byKey(const ValueKey('mobile-active-groups-card')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('mobile-study-together-card')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('mobile-friend-ranking-card')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('mobile-my-rating-card')), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(home: GroupListPage(initialGroups: <Object>[])),
    );
    await tester.pump();
    expect(find.text('그룹 스터디'), findsOneWidget);
    expect(find.text('내 그룹'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mobile-active-groups-card')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mobile-group-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-group-insights')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mobile-study-together-card')),
      findsNothing,
    );
    await tester.tap(find.text('학습 현황'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobile-friend-ranking-card')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mobile-my-rating-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 스터디 그룹은 개별 요약 카드에서 상세로 진입한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    RouteSettings? openedRoute;

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          openedRoute = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox(),
          );
        },
        home: GroupListPage(
          initialGroups: <Object>[
            StudyGroup(
              id: 'group-1',
              name: '중2 수학 챌린지',
              description: '매일 한 문제씩 함께 풀어요',
              memberCount: 4,
              maxMembers: 12,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('mobile-group-card-0')), findsOneWidget);
    expect(find.text('4 / 12명 · 공개'), findsOneWidget);
    expect(find.text('그룹 공간 열기'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mobile-group-card-0')));
    await tester.pumpAndSettle();
    expect(openedRoute?.name, '/group/detail');
    expect(openedRoute?.arguments, 'group-1');
  });

  testWidgets('모바일 채팅은 실제 쪽지 API로 전송하고 말풍선을 추가한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ApiClient.instance.setToken('direct-message-test-token');
    final requests = <http.Request>[];
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({'messages': <Object>[]}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 'message-1',
            'from': 'me',
            'to': body['peer'],
            'text': body['text'],
            'created_at': '2026-08-09T00:00:00Z',
            'is_mine': true,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(
      const MaterialApp(home: StudentDirectChatPage(peerUsername: 'friend01')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-direct-chat')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('mobile-chat-input')),
      '같이 공부하자',
    );
    await tester.tap(find.byKey(const ValueKey('mobile-chat-send')));
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/social/messages' &&
            request.body.contains('같이 공부하자'),
      ),
      isTrue,
    );
    expect(find.text('같이 공부하자'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
