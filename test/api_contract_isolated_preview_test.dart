import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/services/api/api_contract.dart';

void main() {
  test(
    'explicit empty API base keeps preview requests on their own origin',
    () {
      expect(ApiContract.baseUrl, isEmpty);
      final preview = Uri.parse('https://isolated-preview.invalid/');
      for (final path in ['/auth/login', '/textbooks', '/textbooks/import']) {
        final request = ApiContract.uri(path);
        expect(request.hasAuthority, isFalse);
        expect(request.scheme, isEmpty);
        expect(request.path, path);
        expect(preview.resolveUri(request).origin, preview.origin);
      }
    },
    skip: ApiContract.baseUrl.isNotEmpty
        ? 'Run with --dart-define=API_BASE_URL=; default canary tested separately.'
        : false,
  );
}
