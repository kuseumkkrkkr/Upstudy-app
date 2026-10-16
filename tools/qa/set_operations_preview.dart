// Synthetic-only remote harness; original manuscripts load on loopback only.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  ApiClient.instance.setHttpClientForTest(
    MockClient((_) async => throw StateError('Product calls blocked')),
  );
  runApp(
    MaterialApp(
      title: '집합 연산 합성 QA',
      theme: ThemeData(useMaterial3: true, fontFamily: 'NotoSansKR'),
      home: const Preview(),
    ),
  );
}

class Preview extends StatefulWidget {
  const Preview({super.key});
  @override
  State<Preview> createState() => _PreviewState();
}

class _PreviewState extends State<Preview> {
  int version = 0, entry = 0;
  String status = '합성 QA · 원고/AI/DB 없음';
  BookData book = synthetic(true);
  static BookData synthetic(bool after) => BookData.fromJson({
    'schema_version': 2,
    'textbook_id': 'set-synthetic-$after',
    'title': '합성 집합 연산',
    'chapters': [
      {
        'title': '두 집합',
        'pages': [
          {
            'id': 'sets',
            'title': '원소와 연산',
            'template': 'experiment',
            'blocks': [
              after
                  ? {
                      'type': 'activity',
                      'activity': {
                        'id': 'sets',
                        'kind': 'setOperations',
                        'prompt': '원소와 연산을 바꾸어 보세요.',
                        'universe': [1, 2, 3, 4, 5, 6],
                        'set_a': [1, 2, 3],
                        'set_b': [3, 4, 5],
                        'operation': 'intersection',
                        'hints': [],
                      },
                    }
                  : {'type': 'paragraph', 'text': '동작 없는 안내문을 재현한 합성 비교입니다.'},
            ],
          },
          {
            'id': 'quiz',
            'title': '별도 사례 확인',
            'template': 'practice',
            'blocks': [
              {
                'type': 'activity',
                'activity': {
                  'id': 'quiz',
                  'kind': 'quiz',
                  'prompt': '별도 사례 A={1}, B={2}에서 A⊆B일까요?',
                  'options': ['참', '거짓'],
                  'correct_index': 1,
                  'correct_feedback': '1이 반례입니다.',
                  'incorrect_feedback': 'A의 원소가 B에도 있는지 확인하세요.',
                },
              },
            ],
          },
        ],
      },
    ],
  });
  Future<void> load(bool after) async {
    if (Uri.base.host != '127.0.0.1') return;
    final response = await http.get(
      Uri.base.resolve('/qa-book?variant=${after ? 'after' : 'before'}'),
    );
    if (response.statusCode != 200) throw StateError('Private load failed');
    final next = BookData.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (!mounted) return;
    setState(() {
      book = next;
      entry = 1;
      version++;
      status = after ? '로컬 비공개 후보 · 공개 승인 아님' : '로컬 원문 · 변경 전';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(status),
                Row(
                  children: [
                    for (final after in [false, true])
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() {
                            book = synthetic(after);
                            entry = 0;
                            version++;
                            status =
                                '합성 ${after ? '변경 후' : '변경 전'} · 원고/AI/DB 없음';
                          }),
                          child: Text(after ? '합성 변경 후' : '합성 변경 전'),
                        ),
                      ),
                  ],
                ),
                if (Uri.base.host == '127.0.0.1')
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => load(false),
                          child: const Text('변경 전 원고'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () => load(true),
                          child: const Text('변환 후보'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
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
}
