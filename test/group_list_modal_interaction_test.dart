import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/features/group_study/group_list_page.dart';
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

  testWidgets('390 그룹 추가 메뉴의 만들기는 실제 생성 요청을 보낸다', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await ApiClient.instance.setToken('group-modal-390-token');
    final requests = <http.Request>[];
    _installGroupApiMock(requests);

    await tester.pumpWidget(_groupPage());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('groups-mobile-add')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('group-mobile-add-sheet')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('group-mobile-create')));
    await tester.pumpAndSettle();

    final createDialog = find.byType(Dialog);
    expect(createDialog, findsOneWidget);
    final fields = find.descendant(
      of: createDialog,
      matching: find.byType(TextField),
    );
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(0), '390 검증 그룹');
    await tester.enterText(fields.at(1), '실제 생성 계약 검증');
    await tester.enterText(fields.at(2), '8');
    await tester.enterText(fields.at(3), '1234');
    final submit = find.descendant(
      of: createDialog,
      matching: find.widgetWithText(FilledButton, '그룹 만들기'),
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final createRequest = requests.singleWhere(
      (request) =>
          request.method == 'POST' &&
          request.url.path == '/social/study-groups',
    );
    expect(jsonDecode(createRequest.body), {
      'name': '390 검증 그룹',
      'description': '실제 생성 계약 검증',
      'password': '1234',
      'max_members': 8,
      'is_public': true,
      'lock_enabled': true,
    });
    expect(find.byKey(const ValueKey('group-mobile-add-sheet')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('780 그룹 추가 메뉴의 공개 찾기와 코드 참가는 실제 API 계약을 지킨다', (tester) async {
    _setViewport(tester, const Size(780, 844));
    await ApiClient.instance.setToken('group-modal-780-token');
    final requests = <http.Request>[];
    _installGroupApiMock(requests);

    await tester.pumpWidget(_groupPage());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('groups-mobile-add')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('group-mobile-add-sheet')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('group-mobile-find')));
    await tester.pumpAndSettle();

    final findDialog = find.byType(Dialog);
    expect(findDialog, findsOneWidget);
    final searchFields = find.descendant(
      of: findDialog,
      matching: find.byType(TextField),
    );
    expect(searchFields, findsNWidgets(3));

    await tester.enterText(searchFields.at(0), '기하');
    await tester.tap(
      find.descendant(of: findDialog, matching: find.byTooltip('그룹 검색')),
    );
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (request) =>
            request.method == 'GET' &&
            request.url.path == '/social/study-groups/search' &&
            request.url.queryParameters['q'] == '기하',
      ),
      isTrue,
    );
    expect(find.text('기하 집중반'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: findDialog,
        matching: find.widgetWithText(TextButton, '참가'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/social/study-groups/public-geometry/join',
      ),
      isTrue,
    );
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.byKey(const ValueKey('groups-mobile-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('group-mobile-join-code')));
    await tester.pumpAndSettle();

    final inviteDialog = find.byType(Dialog);
    expect(inviteDialog, findsOneWidget);
    final inviteFields = find.descendant(
      of: inviteDialog,
      matching: find.byType(TextField),
    );
    expect(inviteFields, findsNWidgets(3));
    await tester.enterText(inviteFields.at(1), 'AF-7800');
    await tester.enterText(inviteFields.at(2), '5678');
    final verify = find.descendant(
      of: inviteDialog,
      matching: find.widgetWithText(FilledButton, '코드 확인 후 참가'),
    );
    await tester.ensureVisible(verify);
    await tester.tap(verify);
    await tester.pumpAndSettle();

    final confirmDialog = find.byType(AlertDialog);
    expect(confirmDialog, findsOneWidget);
    await tester.tap(
      find.descendant(
        of: confirmDialog,
        matching: find.widgetWithText(FilledButton, '참가'),
      ),
    );
    await tester.pumpAndSettle();

    final codeJoinRequest = requests.singleWhere(
      (request) =>
          request.method == 'POST' &&
          request.url.path == '/social/study-groups/join-by-code',
    );
    expect(jsonDecode(codeJoinRequest.body), {
      'invite_code': 'AF-7800',
      'password': '5678',
    });
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1280 그룹 찾기와 만들기는 직접 여는 제한된 데스크톱 다이얼로그다', (tester) async {
    _setViewport(tester, const Size(1280, 900));
    await ApiClient.instance.setToken('group-modal-1280-token');
    final requests = <http.Request>[];
    _installGroupApiMock(requests);

    await tester.pumpWidget(_groupPage());
    await tester.pumpAndSettle();
    await tester.tap(find.text('그룹 찾기 · 코드 참가'));
    await tester.pumpAndSettle();

    final findDialog = find.byType(Dialog);
    final findPanel = find.descendant(
      of: findDialog,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.maxWidth == 560 &&
            widget.constraints.maxHeight == 720,
      ),
    );
    expect(findDialog, findsOneWidget);
    expect(findPanel, findsOneWidget);
    expect(tester.getSize(findPanel).width, lessThanOrEqualTo(560));
    expect(tester.getSize(findPanel).height, lessThanOrEqualTo(720));
    expect(find.byKey(const ValueKey('group-mobile-add-sheet')), findsNothing);
    await tester.tap(
      find.descendant(of: findDialog, matching: find.byTooltip('닫기')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('그룹 만들기'));
    await tester.pumpAndSettle();
    final createDialog = find.byType(Dialog);
    final createPanel = find.descendant(
      of: createDialog,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox && widget.constraints.maxWidth == 500,
      ),
    );
    expect(createDialog, findsOneWidget);
    expect(createPanel, findsOneWidget);
    expect(tester.getSize(createPanel).width, lessThanOrEqualTo(500));
    expect(find.byKey(const ValueKey('group-mobile-add-sheet')), findsNothing);
    await tester.tap(
      find.descendant(of: createDialog, matching: find.byTooltip('닫기')),
    );
    await tester.pumpAndSettle();
    expect(createDialog, findsNothing);
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

Widget _groupPage() =>
    const MaterialApp(home: GroupListPage(initialGroups: <Object>[]));

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _installGroupApiMock(List<http.Request> requests) {
  ApiClient.instance.setHttpClientForTest(
    MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        switch (request.url.path) {
          case '/social/study-groups/mine':
            return _json({'groups': <Object>[]});
          case '/social/friends/rankings':
            return _json({'ranks': <Object>[]});
          case '/rating/tags':
            return _json({'tags': <Object>[]});
          case '/rating/user':
            return _json({
              'rating': 0,
              'ovr': 0,
              'ovr_delta': 0,
              'recent_accuracy': 0,
              'lose_streak': 0,
            });
          case '/social/study-groups/search':
            return _json({
              'groups': [
                {
                  'group_id': 'public-geometry',
                  'name': '기하 집중반',
                  'description': '도형 문제를 함께 풀어요',
                  'member_count': 3,
                  'max_members': 12,
                  'is_public': true,
                },
              ],
            });
          case '/social/study-groups/invite/AF-7800':
            return _json({
              'group_id': 'invite-7800',
              'name': '초대 코드 그룹',
              'description': '코드로 참여하는 실제 그룹',
              'members': 2,
              'max_members': 8,
              'lock_enabled': true,
              'invite_code': 'AF-7800',
            });
        }
      }
      if (request.method == 'POST') {
        switch (request.url.path) {
          case '/social/study-groups':
            return _json({
              'group_id': 'created-group',
              'name': '390 검증 그룹',
              'member_count': 1,
            });
          case '/social/study-groups/public-geometry/join':
            return _json(<String, Object>{});
          case '/social/study-groups/join-by-code':
            return _json({
              'group_id': 'invite-7800',
              'name': '초대 코드 그룹',
              'member_count': 3,
            });
        }
      }
      return _json({
        'detail': 'unexpected ${request.method} ${request.url.path}',
      }, 404);
    }),
  );
}

http.Response _json(Object body, [int statusCode = 200]) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
