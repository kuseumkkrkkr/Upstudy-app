import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/sessions/friend/friend.dart';
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

  testWidgets('모바일 소셜은 ASCII 카드 순서와 전폭 행동을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SoWidget(preview: true)));
    await tester.pump();

    expect(find.text('친구 · 소셜'), findsOneWidget);
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
    expect(find.text('활동 중인 그룹 더보기'), findsOneWidget);
    expect(find.text('활동 중인 그룹'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mobile-active-groups-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-study-together-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-friend-ranking-card')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mobile-my-rating-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
