import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/services/api/api_contract.dart';

void main() {
  test('product API defaults to Vercel and OCR stays on the same origin', () {
    final productOrigin = Uri.parse(ApiContract.baseUrl);
    final ocrUri = Uri.parse(ApiContract.ocrQueueBaseUrl);

    expect(ApiContract.baseUrl, 'https://aiflow-web-canary.vercel.app');
    expect(productOrigin.scheme, 'https');
    expect(ocrUri.origin, productOrigin.origin);
    expect(ocrUri.path, '/api/ocr');
    expect(ApiContract.uri(ApiPaths.authMe).origin, productOrigin.origin);
    expect(ApiPaths.analysisVariantGrade, '/analysis/solve/variant-grade');
    expect(ApiPaths.problemHabits, '/habit/problem');
    expect(ApiPaths.problemHabitReplay, '/habit/problem/replay');
    expect(
      ApiContract.uri(ApiPaths.problemHabits).origin,
      productOrigin.origin,
    );
    expect(
      ApiContract.uri(ApiPaths.problemHabitReplay).origin,
      productOrigin.origin,
    );
    expect(
      ApiContract.uri(ApiPaths.analysisVariantGrade).origin,
      productOrigin.origin,
    );
  });
}
