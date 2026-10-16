import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/shared/services/api/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient api;
  setUp(() {
    api = ApiClient.instance;
    SharedPreferences.setMockInitialValues({});
    api.clearTokenForTest();
  });
  tearDown(() {
    api.clearTokenForTest();
    api.setHttpClientForTest(http.Client());
  });

  test(
    'login, account replacement and logout notify with updated auth state',
    () async {
      final initial = api.sessionChanges.value;
      final states = <bool>[];
      void listener() => states.add(api.hasAuthenticatedSession);
      api.sessionChanges.addListener(listener);
      try {
        await api.setToken('synthetic-owner-a');
        await api.setToken('synthetic-owner-b');
        await api.clearToken();
        expect(states, [true, true, false]);
        expect(api.sessionChanges.value, initial + 3);
      } finally {
        api.sessionChanges.removeListener(listener);
      }
    },
  );

  test(
    'restored credentials notify once before profile result is consumed',
    () async {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'synthetic-restored',
      });
      api.setHttpClientForTest(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer synthetic-restored');
          return http.Response('{"username":"synthetic"}', 200);
        }),
      );
      final states = <bool>[];
      void listener() => states.add(api.hasAuthenticatedSession);
      api.sessionChanges.addListener(listener);
      try {
        await api.getMyProfile();
        await api.getMyProfile();
        expect(states, [true]);
      } finally {
        api.sessionChanges.removeListener(listener);
      }
    },
  );
}
