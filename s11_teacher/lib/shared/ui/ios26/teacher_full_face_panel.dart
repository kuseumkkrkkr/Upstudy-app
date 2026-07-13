import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 필요 변수: 상단 라벨, 제목, 설명, 작업 콘텐츠, 선택적 하단 액션과 최대 폭.
/// 작동 원리: 팝업 대신 라우트 전체를 작업면으로 사용하고, PC에서는 콘텐츠 폭을
/// 제한하며 모바일에서는 가용 폭을 모두 사용한다. 기능 콜백은 전달받은 위젯이 처리한다.
class TeacherFullFacePanel extends StatelessWidget {
  const TeacherFullFacePanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.content,
    this.actions = const <Widget>[],
    this.maxContentWidth = 840,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget content;
  final List<Widget> actions;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 24,
                compact ? 16 : 22,
                compact ? 12 : 20,
                10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow,
                          style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.4,
                            color: Colors.black54,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: compact ? 25 : 30,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.all(compact ? 12 : 18),
                    padding: EdgeInsets.all(compact ? 16 : 22),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurface,
                      borderRadius: BorderRadius.circular(compact ? 26 : 32),
                      border: Border.all(color: Colors.white),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 30,
                          color: Color(0x12000000),
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.black54,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Expanded(child: content),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (actions.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 24,
                  12,
                  compact ? 16 : 24,
                  compact ? 16 : 20,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(spacing: 10, runSpacing: 8, children: actions),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
