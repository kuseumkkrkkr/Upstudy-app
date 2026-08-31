import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/rating_detail_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/study_mode_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/today_tasks_modal.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/shared/business/repositories/social_notification_store.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

/// 필요한 변수는 실제 Android 세로 화면과 테스트 종료 복원 콜백이다.
/// 작동 원리는 모든 홈 모달 테스트에 390×844 논리 크기를 적용해 모바일 시트 분기를 고정한다.
void _setMobileView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    ApiClient.instance.setHttpClientForTest(http.Client());
  });

  testWidgets('학습 시작은 시안과 같은 1열 학습 카드 하단 시트를 연다', (tester) async {
    _setMobileView(tester);
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

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(StudypageCopyWidget), findsOneWidget);
    expect(find.text('어떤 방식으로 공부할까요?'), findsNothing);
    expect(find.text('STUDY MODE'), findsOneWidget);
    expect(find.text('학습하기'), findsOneWidget);
    expect(find.text('이어하기'), findsOneWidget);
    expect(find.text('교재보기'), findsOneWidget);
    expect(find.text('마지막 학습 위치'), findsOneWidget);
    expect(find.text('보유 문제세트 이어풀기'), findsOneWidget);
    expect(find.text('책가방에서 교재 선택'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('빈 오늘 할 일은 짧은 하단 시트와 다음 행동 문구를 사용한다', (tester) async {
    _setMobileView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showTodayTasksModal<void>(
                context: context,
                tasks: const [],
                onTaskTap: (_) {},
              ),
              child: const Text('할 일 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('할 일 열기'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('today-tasks-mobile-sheet')),
      findsOneWidget,
    );
    expect(find.text('TODAY TASKS'), findsNothing);
    expect(find.text('오늘은 예정된 할 일이 없어요'), findsOneWidget);
    expect(find.text('바로 학습을 시작해도 좋아요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('레이팅 상세는 모바일 전용 무테 시트 본문을 사용한다', (tester) async {
    _setMobileView(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RatingDetailModal(mobileSheet: true, initialRatings: {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('rating-detail-mobile-sheet')),
      findsOneWidget,
    );
    expect(find.text('레이팅 상세'), findsOneWidget);
    expect(find.text('현재 OVR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('알림 센터는 모바일에서 영문 상단바와 중복 닫기가 없는 하단 시트를 연다', (tester) async {
    _setMobileView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStudentNotifications(context),
              child: const Text('공지 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('공지 열기'));
    await tester.pump();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('알림 센터'), findsOneWidget);
    expect(find.text('LIVE STATUS'), findsNothing);
    expect(find.text('메시지, 친구 요청과 공지를 확인해요.'), findsNothing);
    expect(find.byTooltip('닫기'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('알림 센터의 받은 친구 요청을 눌러 확인하고 수락한다', (tester) async {
    _setMobileView(tester);
    await ApiClient.instance.setToken('notification-request-token');
    var acceptedRequestId = '';
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST') {
          acceptedRequestId = path.split('/')[3];
          return http.Response('{}', 200);
        }
        final body = switch (path) {
          '/social/friend-requests' => {
            'requests': [
              {
                'request_id': 'request-1',
                'from_user_id': 'alice-id',
                'to_user_id': 'student-id',
                'status': 'pending',
                'username': 'alice01',
                'direction': 'incoming',
                'message': '같이 공부해요',
              },
            ],
          },
          '/social/study-groups/notices/my/system' => {'notices': []},
          _ => {'items': []},
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStudentNotifications(context),
              child: const Text('공지 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('공지 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('alice01님의 친구 요청'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('같이 공부해요'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('수락'));
    await tester.pumpAndSettle();

    expect(acceptedRequestId, 'request-1');
    expect(find.text('alice01님의 친구 요청'), findsNothing);
    expect(find.text('alice01님과 친구가 되었습니다.'), findsOneWidget);
  });

  testWidgets('알림 센터에서 그룹 초대를 확인하고 거절할 수 있다', (tester) async {
    _setMobileView(tester);
    await ApiClient.instance.setToken('group-invitation-token');
    var resolvedPath = '';
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        if (request.method == 'POST') {
          resolvedPath = request.url.path;
          return http.Response('{}', 200);
        }
        final body = switch (request.url.path) {
          '/social/study-group-invitations' => {
            'invitations': [
              {
                'group_id': 'group-1',
                'group_name': '수학 집중방',
                'inviter_username': 'alice01',
                'created_at': '2026-08-09T00:00:00Z',
              },
            ],
          },
          '/social/friend-requests' => {'requests': []},
          '/social/study-groups/notices/my/system' => {'notices': []},
          _ => {'items': []},
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStudentNotifications(context),
              child: const Text('공지 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('공지 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수학 집중방 그룹 초대'));
    await tester.pumpAndSettle();
    expect(find.text('alice01님이 그룹에 초대했습니다.'), findsOneWidget);
    await tester.tap(find.text('거절'));
    await tester.pumpAndSettle();

    expect(resolvedPath, '/social/study-group-invitations/group-1/reject');
    expect(find.text('수학 집중방 그룹 초대'), findsNothing);
  });

  testWidgets('알림 센터는 읽지 않은 쪽지를 수신 알림으로 표시한다', (tester) async {
    _setMobileView(tester);
    SocialNotificationStore.clear();
    addTearDown(SocialNotificationStore.clear);
    await ApiClient.instance.setToken('direct-message-notification-token');
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        final body = request.url.path == '/social/conversations'
            ? {
                'messages': [
                  {
                    'id': 'message-1',
                    'from': 'alice01',
                    'to': 'student01',
                    'text': '새 쪽지가 왔어요',
                    'created_at': '2026-08-09T00:00:00Z',
                    'is_mine': false,
                    'is_read': false,
                  },
                ],
              }
            : request.url.path == '/social/friend-requests'
            ? {'requests': []}
            : request.url.path == '/social/study-groups/notices/my/system'
            ? {'notices': []}
            : {'items': []};
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStudentNotifications(context),
              child: const Text('공지 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('공지 열기'));
    await tester.pumpAndSettle();

    expect(find.text('alice01님의 새 쪽지'), findsOneWidget);
    expect(find.text('새 쪽지가 왔어요'), findsOneWidget);
    expect(SocialNotificationStore.notifier.value.unreadMessages, 1);
  });

  testWidgets('교재보기는 모바일에서 작은 테두리 대화상자 대신 전폭 시트를 사용한다', (tester) async {
    _setMobileView(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BookLibraryModal(books: [], mobileSheet: true)),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('book-library-mobile-sheet')),
      findsOneWidget,
    );
    expect(find.text('교재보기'), findsOneWidget);
    expect(find.text('학습 중인 교재와 공개 교재를 한 곳에서 이어 읽어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
