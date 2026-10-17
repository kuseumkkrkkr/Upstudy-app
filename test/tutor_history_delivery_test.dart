import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';

void main() {
  final api = ApiClient.instance;
  setUp(() => api.setTokenForTest('synthetic-tutor-A'));
  tearDown(() {
    api.clearTokenForTest();
    api.setHttpClientForTest(http.Client());
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ServerChatPage(
          standalone: true,
          ephemeral: true,
          initialMode: 'socratic',
          initialContext: {
            'quest_title': 'Synthetic private A page',
            'answer_riddle': 'Synthetic A context',
            'graph_context': [
              {'graph_id': 'page-1-graph-0', 'parameters': [
                {'id': 'p', 'value': 2.5, 'min': .5, 'max': 3.0},
              ]},
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byKey(const ValueKey('tutor-send')));
    await tester.pumpAndSettle();
  }

  http.Response reply(String text, [int status = 200]) => http.Response(
    jsonEncode({'assistant_message': text}),
    status,
    headers: {'content-type': 'application/json'},
  );

  testWidgets(
    'second message carries only successful exchanges, not greeting',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      api.setHttpClientForTest(
        MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return reply('응답 ${requests.length}');
        }),
      );
      await open(tester);
      await send(tester, '첫 질문');
      await send(tester, '다음 답변');
      expect(requests.first['history'], isNull);
      expect(requests.last['history'], [
        {'role': 'user', 'content': '첫 질문'},
        {'role': 'assistant', 'content': '응답 1'},
      ]);
      expect(requests.last['mode'], 'socratic');
      expect(requests.last['ephemeral'], isTrue);
      expect((requests.first['graph_context'] as List).single['parameters'].single['value'], 2.5);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed turn and retry do not duplicate conversation history', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    api.setHttpClientForTest(
      MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return requests.length == 2
            ? reply('unavailable', 503)
            : reply('정상 응답');
      }),
    );
    await open(tester);
    await send(tester, '성공 질문');
    await send(tester, '재시도 질문');
    expect(find.text('다시 전송'), findsOneWidget);
    await tester.tap(find.text('다시 전송'));
    await tester.pumpAndSettle();
    expect(requests.length, 3);
    expect(requests[1]['history'], requests[2]['history']);
    expect((requests[2]['history'] as List).length, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'account switch clears history/context and discards late A reply',
    (tester) async {
      final pending = Completer<http.Response>();
      final requests = <Map<String, dynamic>>[];
      api.setHttpClientForTest(
        MockClient((request) {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return requests.length == 1
              ? pending.future
              : Future.value(reply('B 응답'));
        }),
      );
      await open(tester);
      await tester.enterText(find.byType(TextField), 'A private question');
      await tester.tap(find.byKey(const ValueKey('tutor-send')));
      await tester.pump();
      expect(requests.length, 1);
      api.setTokenForTest('synthetic-tutor-B');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A private question', findRichText: true),
        findsNothing,
      );
      await send(tester, 'B question');
      expect(requests.last['history'], isNull);
      expect(requests.last['quest_title'], isNull);
      expect(requests.last['flow'], isNull);
      expect(requests.last['graph_context'], isNull);
      pending.complete(reply('A late private reply'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A late private reply', findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('B 응답', findRichText: true), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
