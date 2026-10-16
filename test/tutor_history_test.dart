import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/services/tutor_history.dart';

void main() {
  test(
    'history retains at most four complete exchanges and copies snapshots',
    () {
      final history = TutorHistory();
      for (var i = 0; i < 5; i++) {
        history.rememberExchange('user $i', 'reply $i');
      }
      expect(history.snapshot.length, 8);
      expect(history.snapshot.first['content'], 'user 1');
      expect(history.snapshot.last['content'], 'reply 4');
      expect(
        () => history.snapshot.first['content'] = 'mutated',
        throwsUnsupportedError,
      );
      history.snapshot.clear();
      expect(history.snapshot.length, 8);
      history.clear();
      expect(history.snapshot, isEmpty);
    },
  );

  test(
    'aggregate bound evicts whole pairs and unicode truncation is valid',
    () {
      final history = TutorHistory();
      for (var i = 0; i < 4; i++) {
        history.rememberExchange('x' * 1500, 'y' * 1500);
      }
      expect(history.snapshot.length, 4);
      expect(
        history.snapshot.fold<int>(0, (n, v) => n + v['content']!.runes.length),
        6000,
      );
      history.clear();
      history.rememberExchange('사용자', '😀' * 2500);
      expect(history.snapshot.last['content']!.runes.length, 2000);
      expect(history.snapshot.last['content']!.endsWith('…'), isTrue);
      history.rememberExchange('', 'ignored');
      expect(history.snapshot.length, 2);
    },
  );
}
