import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
// sqflite 공개 API에는 Flutter 플러그인 없이 동작하는 테스트 factory가 없다.
// ignore: implementation_imports
import 'package:sqflite/src/sqflite_import.dart' show buildDatabaseFactory;
import 'package:s11/app/router.dart';
import 'package:s11/features/group_study/group_list_page.dart';
import 'package:s11/features/level_test/level_test_home_page.dart';
import 'package:s11/features/wrong_answer/wrong_answer_list_page.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/friend/friend.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';
import 'package:s11/sessions/marketplace/ui/pages/marketplace_page.dart';
import 'package:s11/sessions/textbook/ui/pages/docx_box.dart' as docx;
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

class _QuickSearchDestination {
  const _QuickSearchDestination(this.label, this.route, this.pageType);

  final String label;
  final String route;
  final Type pageType;
}

Future<dynamic> _localDbTestMethod(String method, [Object? arguments]) async {
  switch (method) {
    case 'getDatabasesPath':
      return '.';
    case 'openDatabase':
      return <String, Object>{'id': 1};
    case 'query':
      final sql = (arguments as Map?)?['sql'];
      if (sql == 'PRAGMA user_version') {
        return <Map<String, Object>>[
          <String, Object>{'user_version': 1},
        ];
      }
      return <Map<String, Object>>[];
    case 'insert':
    case 'update':
      return 1;
    case 'execute':
    case 'closeDatabase':
      return null;
    default:
      throw StateError('Unexpected local database method: $method');
  }
}

const _destinations = <_QuickSearchDestination>[
  _QuickSearchDestination('코스', AppRoutes.courses, CourseCatalogPage),
  _QuickSearchDestination('책가방', AppRoutes.bookbag, docx.BookWidget),
  _QuickSearchDestination('오답 노트', AppRoutes.wrongAnswers, WrongAnswerListPage),
  _QuickSearchDestination('레벨 테스트', AppRoutes.levelTest, LevelTestHomePage),
  _QuickSearchDestination('친구/소셜', AppRoutes.social, SoWidget),
  _QuickSearchDestination('스터디 그룹', AppRoutes.groups, GroupListPage),
  _QuickSearchDestination('AI 학습 튜터', AppRoutes.tools, ServerChatPage),
  _QuickSearchDestination('마켓플레이스', AppRoutes.marketplace, MarketplacePage),
];

Widget _quickSearchApp(double width, String destinationRoute) {
  return MaterialApp(
    key: ValueKey('quick-search-app-$width-$destinationRoute'),
    initialRoute: '/quick-search-host',
    routes: <String, WidgetBuilder>{
      ...appRoutes(),
      '/quick-search-host': (_) => const _QuickSearchHost(),
    },
    onGenerateRoute: onGenerateAppRoute,
  );
}

Future<void> _revealQuickSearchResult(
  WidgetTester tester,
  Finder result,
) async {
  final list = find.byType(ListView);
  for (var attempt = 0; attempt < 4; attempt++) {
    if (result.evaluate().isEmpty) {
      await tester.drag(list, const Offset(0, -220));
      await tester.pump();
      continue;
    }
    final listRect = tester.getRect(list);
    final resultRect = tester.getRect(result);
    final belowViewport = resultRect.bottom - listRect.bottom;
    final aboveViewport = listRect.top - resultRect.top;
    if (belowViewport <= 0 && aboveViewport <= 0) return;
    final delta = belowViewport > 0
        ? -(belowViewport + 16)
        : aboveViewport + 16;
    await tester.drag(list, Offset(0, delta));
    await tester.pump();
  }
}

class _QuickSearchHost extends StatelessWidget {
  const _QuickSearchHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const ValueKey('open-student-quick-search'),
        onPressed: () => showStudentQuickSearch(context),
        child: const Text('전체 검색 열기'),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sqflite.databaseFactory = buildDatabaseFactory(
      tag: 'quick-search-route-test',
      invokeMethod: _localDbTestMethod,
    );
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        if (request.url.path == '/history/solve') {
          return http.Response(jsonEncode(<String, Object>{'items': []}), 200);
        }
        if (request.url.path == '/weakness/tags') {
          return http.Response(jsonEncode(<String, Object>{'tags': []}), 200);
        }
        if (request.url.path == '/social/friends') {
          return http.Response(
            jsonEncode(<String, Object>{'friends': []}),
            200,
          );
        }
        if (request.url.path == '/social/friend-requests') {
          return http.Response(
            jsonEncode(<String, Object>{'requests': []}),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    await ApiClient.instance.setToken('quick-search-route-test-token');
  });

  tearDown(() async {
    ApiClient.instance.setHttpClientForTest(http.Client());
    await ApiClient.instance.clearToken();
    sqflite.databaseFactory = null;
  });

  testWidgets('공용 전체 검색은 모든 폭에서 여덟 실제 목적지로 연결한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in const <double>[390, 780, 1280]) {
      for (final destination in _destinations) {
        tester.view.physicalSize = Size(width, width <= 780 ? 844 : 900);
        await tester.pumpWidget(_quickSearchApp(width, destination.route));
        await tester.pump();

        await tester.tap(
          find.byKey(const ValueKey('open-student-quick-search')),
        );
        await tester.pumpAndSettle();
        expect(find.text('전체 검색'), findsOneWidget);

        final result = find.text(destination.label);
        await _revealQuickSearchResult(tester, result);
        expect(result, findsOneWidget);
        await tester.tap(result);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final page = find.byType(destination.pageType);
        expect(page, findsOneWidget, reason: '${destination.label} at $width');
        expect(
          ModalRoute.of(tester.element(page))?.settings.name,
          destination.route,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
