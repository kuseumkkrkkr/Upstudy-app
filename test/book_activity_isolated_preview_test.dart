import 'package:flutter_test/flutter_test.dart';
import '../tool/book_activity_isolated_preview.dart';

void main() {
  testWidgets(
    'isolated entrypoint calculates and retains state without product imports',
    (tester) async {
      await tester.pumpWidget(const BookActivityIsolatedPreview());
      await tester.tap(find.text('추정하기'));
      await tester.pump();
      expect(find.text('모평균의 추정값: 4.0000'), findsOneWidget);
      await tester.tap(find.text('힌트 한 단계'));
      await tester.pump();
      await tester.ensureVisible(find.text('다음 활동'));
      await tester.tap(find.text('다음 활동'));
      await tester.pump();
      await tester.tap(find.text('추정하기'));
      await tester.pump();
      expect(find.text('모비율의 추정값: 30.00%'), findsOneWidget);
      await tester.ensureVisible(find.text('이전 활동'));
      await tester.tap(find.text('이전 활동'));
      await tester.pump();
      expect(find.text('모평균의 추정값: 4.0000'), findsOneWidget);
      expect(find.text('표본의 합을 표본 크기로 나누세요.'), findsOneWidget);
      await tester.ensureVisible(find.text('새 로컬 세션'));
      await tester.tap(find.text('새 로컬 세션'));
      await tester.pump();
      expect(find.text('모평균의 추정값: 4.0000'), findsNothing);
      expect(find.text('표본의 합을 표본 크기로 나누세요.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
