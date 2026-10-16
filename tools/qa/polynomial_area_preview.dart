// Synthetic Preview harness. Private candidates are loaded only on loopback HTTP.
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
  ApiClient.instance.setHttpClientForTest(MockClient((_) async => throw StateError('Product requests blocked')));
  runApp(MaterialApp(title: '다항식 상호작용 합성 QA', theme: ThemeData(useMaterial3: true, fontFamily: 'NotoSansKR'),
    home: const Preview()));
}
class Preview extends StatefulWidget {
  const Preview({super.key});
  @override
  State<Preview> createState() => _State();
}
class _State extends State<Preview> {
  int mode = 0, entry = 0;
  String status = '합성 QA · 실제 원고/AI/DB 없음';
  BookData book = synthetic(true);
  static BookData synthetic(bool after) => BookData.fromJson({'schema_version': 2, 'textbook_id': 'synthetic-polynomial-$after',
    'title': '합성 넓이 모형', 'chapters': [{'title': '기능 확인', 'pages': [{
      'id': 'synthetic', 'title': '두 상수를 바꾸어 보세요', 'template': 'experiment', 'blocks': [{
        if (after) 'type': 'activity', if (after) 'activity': {'id': 'synthetic-area', 'kind': 'polynomialArea',
          'prompt': '두 상수를 바꾸며 전개식을 관찰하세요.', 'a': 3, 'b': 2, 'hints': []},
        if (!after) 'type': 'paragraph', if (!after) 'text': '기존 안내문만 표시되는 상태를 재현한 합성 비교입니다.',
      }]}, {'id': 'quiz', 'title': '간단한 확인', 'template': 'practice', 'blocks': [{
        'type': 'activity', 'activity': {'id': 'synthetic-quiz', 'kind': 'quiz',
          'prompt': 'a=4, b=2일 때 상수항은?', 'answer': 8,
          'correct_feedback': '정답입니다.', 'incorrect_feedback': '두 상수를 곱해 보세요.'}}]}]}]});
  static BookData regression(bool root) => BookData.fromJson({'schema_version': 2,
    'textbook_id': root ? 'synthetic-root' : 'synthetic-graph',
    'title': root ? '합성 제곱근 회귀' : '합성 그래프 회귀',
    'chapters': [{'title': '기능 확인', 'pages': [{'id': 'regression', 'title': '기존 기능 회귀 확인',
      'template': 'experiment', 'blocks': [root ? {'type': 'activity', 'activity': {
        'id': 'root', 'kind': 'squareRootNumberLine', 'prompt': 'n과 제곱근의 위치를 비교하세요.',
        'min': 1, 'max': 25}} : {'type': 'graph', 'graph': {
          'items': [{'id': 'f', 'type': 'function', 'expression': 'x^2-4*x+3', 'label': 'f(x)=x²−4x+3'},
                    {'id': 'df', 'type': 'function', 'expression': '2*x-4', 'label': 'f′(x)=2x−4'}],
          'settings': {'parameters': [{'id': 'observed_x', 'role': 'observationX', 'label': '관찰 위치 x',
            'value': 1, 'min': -1, 'max': 5, 'step': .1}]}}}]}]}]});
  Future<void> load(bool after) async {
    if (Uri.base.host != '127.0.0.1') return;
    final response = await http.get(Uri.base.resolve('/qa-book?variant=${after ? "after" : "before"}'));
    if (response.statusCode != 200) throw StateError('Private QA load unavailable');
    final next = BookData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    final pages = next.chapters.expand((chapter) => chapter.pages).toList();
    final index = pages.indexWhere((page) => page.id == 'ms31-22-polynomial-product-experiment');
    if (!mounted) return;
    setState(() { book = next; entry = index; mode++;
      status = after ? '로컬 비공개 변환 후보 · 공개 승인 아님' : '원문 BookData · 변경 전 안내문'; });
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Column(children: [
    Padding(padding: const EdgeInsets.all(8), child: Column(children: [Text(status),
      Row(children: [
        Expanded(child: TextButton(onPressed: () => setState(() { book = synthetic(false); mode++; entry=0;
          status='합성 변경 전 · 안내문만 표시'; }), child: const Text('합성 변경 전'))),
        Expanded(child: TextButton(onPressed: () => setState(() { book = synthetic(true); mode++; entry=0;
          status='합성 변경 후 · 원고/AI/DB 없음'; }), child: const Text('합성 변경 후'))),
      ]),
      Row(children: [
        Expanded(child: TextButton(onPressed: () => setState(() { book = regression(false); mode++; entry=0;
          status='합성 그래프 회귀 · 원고/AI/DB 없음'; }), child: const Text('그래프 회귀'))),
        Expanded(child: TextButton(onPressed: () => setState(() { book = regression(true); mode++; entry=0;
          status='합성 제곱근 회귀 · 원고/AI/DB 없음'; }), child: const Text('제곱근 회귀'))),
      ]),
      if (Uri.base.host == '127.0.0.1') Row(children: [
        Expanded(child: TextButton(onPressed: () => load(false), child: const Text('변경 전 원고'))),
        Expanded(child: TextButton(onPressed: () => load(true), child: const Text('변환 후보'))),
      ]),
    ])),
    Expanded(child: BookWidget(key: ValueKey(mode), book: book, initialEntryIndex: entry, persistenceEnabled: false)),
  ])));
}
