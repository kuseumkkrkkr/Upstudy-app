import 'package:flutter/material.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

/// 필요한 변수는 브라우저가 제공하는 현재 viewport다.
/// 공용 학생 셸을 API 없이 실행해 390px·500px·1280px 검수 캡처에 사용한다.
void main() {
  runApp(const StudentDensityPreviewApp());
}

class StudentDensityPreviewApp extends StatelessWidget {
  const StudentDensityPreviewApp({super.key});

  /// 필요한 변수는 공용 디자인 토큰과 현재 반응형 너비다.
  /// 실제 학생 홈과 같은 상단 메뉴·카드·행동 구조를 고정 데이터로 렌더한다.
  @override
  Widget build(BuildContext context) {
    final previewWidth = double.tryParse(
      Uri.base.queryParameters['width'] ?? '',
    );
    final previewHeight = double.tryParse(
      Uri.base.queryParameters['height'] ?? '',
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        if (previewWidth == null || previewHeight == null || child == null) {
          return child ?? const SizedBox.shrink();
        }
        final media = MediaQuery.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: MediaQuery(
              data: media.copyWith(size: Size(previewWidth, previewHeight)),
              child: child,
            ),
          ),
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: StudentDensityTokens.dark,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: StudentDensityTokens.background,
        fontFamilyFallback: const ['Malgun Gothic', 'Arial'],
      ),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Ios26TopBar(
                brandColor: StudentDensityTokens.dark,
                showLevelIndicator: false,
                onMenu: () {},
                items: const [
                  Ios26NavItem(label: '학습터', active: true),
                  Ios26NavItem(label: '책가방'),
                  Ios26NavItem(label: '친구/소셜'),
                  Ios26NavItem(label: '마켓플레이스'),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: StudentDensityPage(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const StudentDensityPageHeader(
                          eyebrow: 'STUDENT HOME',
                          title: '오늘의 학습',
                          description: '현재 코스와 일일 퀘스트를 한눈에 확인합니다.',
                        ),
                        const SizedBox(height: 24),
                        StudentDensitySurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const StudentDensityEyebrow('ACTIVE COURSE'),
                              const SizedBox(height: 10),
                              const Text(
                                '중2 일차함수 집중 코스',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('현재 단원 · 기울기와 그래프'),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: 0.62,
                                color: StudentDensityTokens.dark,
                                backgroundColor: StudentDensityTokens.line,
                              ),
                              const SizedBox(height: 18),
                              StudentDensityButton(
                                label: '이어서 학습',
                                primary: true,
                                icon: Icons.play_arrow_rounded,
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
