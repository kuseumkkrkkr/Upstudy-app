import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';

void main() {
  final api = ApiClient.instance;
  final draft = <String, dynamic>{'schema_version': 2, 'title': 'Synthetic remote draft',
    'chapters': [{'title': 'Sample', 'tags': ['chapter-tag'], 'pages': [{
      'id': 'sample', 'title': 'Quiz', 'template': 'experiment', 'blocks': [{
        'type': 'activity', 'activity': {'id': 'quiz', 'kind': 'quiz', 'prompt': '1+1?',
          'answer': 2, 'correct_feedback': 'Yes', 'incorrect_feedback': 'Try again'}}]}]}]};
  Map<String, dynamic> result() => {...draft, 'textbook_id': 'synthetic-private-id'};
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.setTokenForTest('synthetic-owner');
  });
  tearDown(() {
    api.clearTokenForTest();
    api.setHttpClientForTest(http.Client());
  });
  test('editor creation reaches authenticated remote API without losing V2', () async {
    api.setHttpClientForTest(MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/textbooks');
      expect(request.headers['Authorization'], 'Bearer synthetic-owner');
      expect(jsonDecode(request.body), draft);
      return http.Response(jsonEncode(result()), 201);
    }));
    final book = BookData.fromJson(await api.createTextbook(draft));
    expect(book.id, 'synthetic-private-id');
    expect(book.schemaVersion, 2);
    expect(book.chapters.single.tags, ['chapter-tag']);
    expect(book.chapters.single.pages.single.blocks.single.activity, isNotNull);
  });
  test('empty response is not a successful local fallback', () async {
    api.setHttpClientForTest(MockClient((_) async => http.Response('{}', 201)));
    await expectLater(api.createTextbook(draft), throwsA(isA<ApiException>()));
  });
  test('late response cannot enter another account session', () async {
    final entered = Completer<void>(), pending = Completer<http.Response>();
    api.setHttpClientForTest(MockClient((_) { entered.complete(); return pending.future; }));
    final future = api.createTextbook(draft);
    final assertion = expectLater(future, throwsA(isA<ApiException>()));
    await entered.future;
    api.setTokenForTest('synthetic-other');
    pending.complete(http.Response(jsonEncode(result()), 201));
    await assertion;
  });
}
