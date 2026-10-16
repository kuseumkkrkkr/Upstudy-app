// Synthetic remote regression, exact private candidates on loopback only.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';

BookData synthetic(bool after) => BookData.fromJson({
  'schema_version': 2,
  'textbook_id': 'coordinate-synthetic-$after',
  'title': '합성 좌표 탐색',
  'chapters': [
    {
      'title': '기능 확인',
      'pages': [
        {
          'id': 'point',
          'title': '점 이동',
          'template': 'experiment',
          'blocks': [
            after
                ? {
                    'type': 'activity',
                    'activity': {
                      'id': 'point',
                      'kind': 'coordinatePoint',
                      'prompt': '점을 움직여 좌표를 확인하세요.',
                      'x': -2,
                      'y': 3,
                      'hints': ['가로와 세로 위치를 차례로 확인하세요.'],
                    },
                  }
                : {'type': 'paragraph', 'text': '고정 안내문을 재현한 합성 비교입니다.'},
          ],
        },
        {
          'id': 'quiz',
          'title': '합성 확인',
          'template': 'practice',
          'blocks': [
            {
              'type': 'activity',
              'activity': {
                'id': 'quiz',
                'kind': 'quiz',
                'prompt': 'x>0, y<0인 점의 사분면은?',
                'options': ['1', '2', '3', '4'],
                'correct_index': 3,
                'correct_feedback': '제4사분면입니다.',
                'incorrect_feedback': '두 좌표의 부호를 확인하세요.',
              },
            },
          ],
        },
        {
          'id': 'disclosure',
          'title': '접기와 펼치기',
          'template': 'practice',
          'blocks': [
            {
              'type': 'activity',
              'activity': {
                'id': 'disclosure',
                'kind': 'disclosure',
                'prompt': '합성 본문 열기',
                'content': '합성 본문입니다. 다시 눌러 닫을 수 있습니다.',
              },
            },
          ],
        },
      ],
    },
  ],
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  ApiClient.instance.setHttpClientForTest(
    MockClient((_) async => throw StateError('Product calls blocked')),
  );
  var book = synthetic(true), status = '합성 좌표 QA · 원고/AI/DB 없음';
  var version = 0, entry = 0, epoch = 0;
  runApp(
    MaterialApp(
      title: '좌표 원고 연결 합성 QA',
      theme: ThemeData(useMaterial3: true, fontFamily: 'NotoSansKR'),
      home: StatefulBuilder(
        builder: (context, setState) {
          Future<void> load(bool after) async {
            if (Uri.base.host != '127.0.0.1') return;
            final requestEpoch = ++epoch;
            final response = await http.get(
              Uri.base.resolve(
                '/qa-book?variant=${after ? 'after' : 'before'}',
              ),
            );
            if (response.statusCode != 200) {
              throw StateError('Private load failed');
            }
            final next = BookData.fromJson(
              jsonDecode(response.body) as Map<String, dynamic>,
            );
            if (!context.mounted || requestEpoch != epoch) return;
            setState(() {
              book = next;
              version++;
              entry = 1;
              status = after ? '로컬 좌표 후보 · 공개 승인 아님' : '로컬 원문 · 변경 전';
            });
          }

          return Scaffold(
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
                                    epoch++;
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
        },
      ),
    ),
  );
}
