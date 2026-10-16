// Synthetic remote regression only. Real manuscripts load on loopback only.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final response = await http.get(
    Uri.base.resolve('/synthetic-function-explorers.json'),
  );
  if (response.statusCode != 200) {
    runApp(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('검증 교재 로드 실패'))),
      ),
    );
    return;
  }
  final synthetic = BookData.fromJson(
    jsonDecode(response.body) as Map<String, dynamic>,
  );
  // ignore: invalid_use_of_visible_for_testing_member
  ApiClient.instance.setHttpClientForTest(
    MockClient((_) async => throw StateError('Product requests blocked')),
  );
  var book = synthetic, version = 0, epoch = 0, entry = 0;
  var status = '합성 함수 QA · 원고/AI/DB 없음';
  runApp(
    MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansKR', useMaterial3: true),
      home: StatefulBuilder(
        builder: (context, setState) {
          Future<void> load(String kind) async {
            if (Uri.base.host != '127.0.0.1') return;
            final request = ++epoch;
            final loaded = await http.get(
              Uri.base.resolve('/qa-book?kind=$kind'),
            );
            if (loaded.statusCode != 200) return;
            final next = BookData.fromJson(
              jsonDecode(loaded.body) as Map<String, dynamic>,
            );
            final nextEntry =
                int.tryParse(loaded.headers['x-qa-entry'] ?? '') ?? 0;
            if (!context.mounted || request != epoch) return;
            setState(() {
              book = next;
              entry = nextEntry;
              version++;
              status = '로컬 $kind 실제 원고 · 공개 승인 아님';
            });
          }

          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Text(status),
                  TextButton(
                    onPressed: () => setState(() {
                      epoch++;
                      book = synthetic;
                      entry = 0;
                      version++;
                      status = '합성 함수 QA · 원고/AI/DB 없음';
                    }),
                    child: const Text('합성 교재'),
                  ),
                  if (Uri.base.host == '127.0.0.1')
                    Wrap(
                      children: [
                        for (final kind in ['radical', 'rational', 'power'])
                          TextButton(
                            onPressed: () => load(kind),
                            child: Text('원고 $kind'),
                          ),
                      ],
                    ),
                  Expanded(
                    child: BookWidget(
                      key: ValueKey(version),
                      book: book,
                      initialEntryIndex: entry,
                      persistenceEnabled: false,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
