import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';

void main() {
  testWidgets('synthetic private reader opens without any product request', (
    tester,
  ) async {
    final api = ApiClient.instance;
    var requests = 0;
    api.setTokenForTest('synthetic-parametric-local-only');
    api.setHttpClientForTest(
      MockClient((_) async {
        requests++;
        throw StateError('Unexpected product request');
      }),
    );
    addTearDown(() {
      api.clearTokenForTest();
      api.setHttpClientForTest(http.Client());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final book = BookData.fromJson({
      ...jsonDecode(
            File('test/fixtures/parametric_reader.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
      'textbook_id': 'synthetic-parametric-local',
    });
    await tester.pumpWidget(
      MaterialApp(home: BookWidget(book: book, persistenceEnabled: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('INTERACTIVE FIGURE'), findsOneWidget);
    expect(find.textContaining('로그인이 필요해요'), findsNothing);
    expect(requests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
