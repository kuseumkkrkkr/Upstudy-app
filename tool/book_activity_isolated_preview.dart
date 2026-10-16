// Isolated static feature QA. Never the student app entrypoint or manuscript.
import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';

void main() => runApp(const BookActivityIsolatedPreview());

/// Synthetic definitions and reader-local state only. No auth/API/storage imports.
class BookActivityIsolatedPreview extends StatefulWidget {
  const BookActivityIsolatedPreview({super.key});
  @override
  State<BookActivityIsolatedPreview> createState() => _PreviewState();
}

class _PreviewState extends State<BookActivityIsolatedPreview> {
  final _keys = <String, GlobalKey>{};
  final _states = <String, Map<String, Object?>>{};
  int _page = 0, _session = 0;
  static final _activities = [
    BookActivity.fromJson({
      'id': 'synthetic-mean',
      'kind': 'statisticsEstimator',
      'prompt': '표본평균 체험 · 합성 자료',
      'statistics': {
        'mode': 'mean',
        'sample_values': [2, 4, 6],
      },
      'hints': ['표본의 합을 표본 크기로 나누세요.'],
    }),
    BookActivity.fromJson({
      'id': 'synthetic-proportion',
      'kind': 'statisticsEstimator',
      'prompt': '표본비율 체험 · 합성 자료',
      'statistics': {'mode': 'proportion', 'successes': 3, 'trials': 10},
      'hints': ['조건에 맞는 수를 전체 표본 크기로 나누세요.'],
    }),
    BookActivity.fromJson({
      'id': 'synthetic-dice',
      'kind': 'discreteExperiment',
      'prompt': '주사위 체험 · 짝수 사건',
      'experiment': {
        'outcomes': [
          for (var face = 1; face <= 6; face++)
            {'label': '$face', 'weight': 1, 'success': face.isEven},
        ],
        'max_trials': 50,
        'batch_sizes': [1, 10],
      },
      'hints': ['짝수 횟수를 전체 시행 횟수와 비교하세요.'],
    }),
  ];
  void _newSession() => setState(() {
    _keys.clear();
    _states.clear();
    _session++;
    _page = 0;
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BookData 체험 기능 검증',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.black),
    home: Scaffold(
      appBar: AppBar(title: const Text('체험 기능 검증')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _page == 0 ? null : () => setState(() => _page--),
                child: const Text('이전 활동'),
              ),
              OutlinedButton(
                onPressed: _page == _activities.length - 1
                    ? null
                    : () => setState(() => _page++),
                child: const Text('다음 활동'),
              ),
              TextButton(onPressed: _newSession, child: const Text('새 로컬 세션')),
            ],
          ),
        ),
      ),
      body: BookActivityKeyScope(
        keys: _keys,
        states: _states,
        bookId: 'synthetic-session-$_session',
        child: Builder(
          builder: (context) {
            final activity = _activities[_page];
            return ListView(
              key: ValueKey('$_session/$_page'),
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '합성 QA 자료 · 학생 앱/실제 교재가 아닙니다. 로그인·서버 저장·채점·등급 반영이 없습니다.',
                ),
                const SizedBox(height: 12),
                Text(
                  '활동 ${_page + 1} / ${_activities.length} · 로컬 세션 $_session',
                ),
                const SizedBox(height: 12),
                BookActivityView(
                  key: BookActivityKeyScope.keyFor(context, activity.id),
                  activity: activity,
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
