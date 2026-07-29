import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/rating_detail_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/study_mode_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/today_tasks_modal.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

/// 필요한 변수는 실제 Android 세로 화면과 테스트 종료 복원 콜백이다.
/// 작동 원리는 모든 홈 모달 테스트에 390×844 논리 크기를 적용해 모바일 시트 분기를 고정한다.
void _setMobileView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('학습 시작은 전체 화면 패널 대신 2열 Material 하단 시트를 연다', (tester) async {
    _setMobileView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStudyModeModal<void>(context: context),
              child: const Text('학습 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('학습 열기'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(StudypageCopyWidget), findsOneWidget);
    expect(find.text('어떤 방식으로 공부할까요?'), findsOneWidget);
    expect(find.text('STUDY MODE'), findsNothing);
    expect(find.text('이어하기'), findsOneWidget);
    expect(find.text('교재보기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('빈 오늘 할 일은 짧은 하단 시트와 다음 행동 문구를 사용한다', (tester) async {
    _setMobileView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showTodayTasksModal<void>(
                context: context,
                tasks: const [],
                onTaskTap: (_) {},
              ),
              child: const Text('할 일 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('할 일 열기'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('today-tasks-mobile-sheet')),
      findsOneWidget,
    );
    expect(find.text('TODAY TASKS'), findsNothing);
    expect(find.text('오늘은 예정된 할 일이 없어요'), findsOneWidget);
    expect(find.text('바로 학습을 시작해도 좋아요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('레이팅 상세는 모바일 전용 무테 시트 본문을 사용한다', (tester) async {
    _setMobileView(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RatingDetailModal(mobileSheet: true, initialRatings: {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('rating-detail-mobile-sheet')),
      findsOneWidget,
    );
    expect(find.text('레이팅 상세'), findsOneWidget);
    expect(find.text('현재 OVR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('알림 센터는 모바일에서 영문 상단바와 중복 닫기가 없는 하단 시트를 연다', (tester) async {
    _setMobileView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStudentNotifications(context),
              child: const Text('공지 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('공지 열기'));
    await tester.pump();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('알림 센터'), findsOneWidget);
    expect(find.text('LIVE STATUS'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('교재보기는 모바일에서 작은 테두리 대화상자 대신 전폭 시트를 사용한다', (tester) async {
    _setMobileView(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BookLibraryModal(books: [], mobileSheet: true)),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('book-library-mobile-sheet')),
      findsOneWidget,
    );
    expect(find.text('교재보기'), findsOneWidget);
    expect(find.text('학습 중인 교재와 공개 교재를 한 곳에서 이어 읽어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
