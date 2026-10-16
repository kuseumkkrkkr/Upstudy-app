import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';

void main() {
  final api = ApiClient.instance;
  testWidgets('graph snapshot and history are scoped to this chat session', (tester) async {
    final requests = <Map<String, dynamic>>[];
    api.setTokenForTest('synthetic-graph-A');
    api.setHttpClientForTest(MockClient((request) async {
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'assistant_message':'다음에는 어디를 비교할까요?'}),200,
        headers:{'content-type':'application/json'});
    }));
    addTearDown(() { api.clearTokenForTest(); api.setHttpClientForTest(http.Client()); });
    await tester.pumpWidget(const MaterialApp(home:ServerChatPage(standalone:true,initialMode:'socratic',
      initialContext:{'quest_title':'Synthetic graph','graph_context':[
        {'graph_id':'page-1-graph-0','parameters':[{'id':'p','value':2.5,'min':.5,'max':3.0}]},
      ]})));
    await tester.pumpAndSettle();
    Future<void> send(String text) async {
      await tester.enterText(find.byType(TextField),text);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
    }
    await send('첫 관찰');
    expect(requests.single['graph_context'],[{'graph_id':'page-1-graph-0','parameters':[{'id':'p','value':2.5,'min':.5,'max':3.0}]}]);
    expect(requests.single['mode'],'socratic');
    await send('후속 관찰');
    expect((requests.last['history'] as List).length,2);
    api.setTokenForTest('synthetic-graph-B');
    await tester.pumpAndSettle();
    await send('B 질문');
    expect(requests.last['graph_context'],isNull);
    expect(requests.last['history'],isNull);
    expect(requests.last['quest_title'],isNull);
    final count = requests.length;
    final racingRequest = api.sendServerChatMessage(message: '세션 경합 질문', graphContext: [
      {'graph_id':'page-1-graph-0','parameters':[{'id':'p','value':2.5,'min':.5,'max':3.0}]},
    ]);
    api.setTokenForTest('synthetic-graph-C');
    await expectLater(racingRequest, throwsA(isA<ApiException>()));
    expect(requests.length, count, reason: 'Old graph must not be sent with the new token');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
