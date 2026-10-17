// Regression release gate: MockClient only, no real account or server writes.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/shared/services/api/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'switching account before POST prevents private draft creation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = ApiClient.instance;
      api.setTokenForTest('synthetic-owner-A');
      final scope = await api.requireSessionScope();
      var sent = 0;
      var otherAccountHeader = false;
      api.setHttpClientForTest(
        MockClient((request) async {
          sent++;
          otherAccountHeader =
              request.headers['Authorization'] == 'Bearer synthetic-owner-B';
          return http.Response(
            '{"textbook_id":"synthetic-private-draft"}',
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      try {
        final pending = api.createTextbook({
          'title': 'Synthetic owner-A draft',
        }, expectedScope: scope);
        api.setTokenForTest('synthetic-owner-B');
        await expectLater(pending, throwsA(isA<ApiException>()));
        expect(
          otherAccountHeader,
          isFalse,
          reason: 'A private payload must never be sent under the next account',
        );
        expect(sent, 0, reason: 'Reject the scope change before any write');
      } finally {
        api.clearTokenForTest();
        api.setHttpClientForTest(http.Client());
      }
    },
  );
}
