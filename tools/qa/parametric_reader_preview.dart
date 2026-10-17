// Local synthetic reader only. No manuscript loading, persistence or AI.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  ApiClient.instance.setHttpClientForTest(
    MockClient((_) async {
      throw StateError('Product calls disabled in local synthetic QA');
    }),
  );
  if (Uri.base.host != '127.0.0.1') {
    throw StateError('This synthetic reader is loopback-only');
  }
  final response = await http.get(
    Uri.base.resolve('synthetic-parametric-reader.json'),
  );
  if (response.statusCode != 200) {
    throw StateError('Synthetic fixture unavailable');
  }
  final book = BookData.fromJson(
    jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
  );
  runApp(
    MaterialApp(
      title: '합성 매개변수 리더 QA · DB/AI 없음',
      theme: ThemeData(fontFamily: 'NotoSansKR', useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Text('합성 QA · 저장/AI/원고 공개 없음'),
              Expanded(
                child: BookWidget(book: book, persistenceEnabled: false),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
