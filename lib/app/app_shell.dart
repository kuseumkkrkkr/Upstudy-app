import 'package:flutter/material.dart';
import 'package:s11/shared/theme/app_colors.dart';

/// AIFlow 공통 앱 쉘 (Scaffold + AppBar 패턴).
///
/// 반복되는 AppBar 디자인 (색상, elevation, 뒤로가기)을 추출하여
/// 모든 페이지에서 일관된 앱바를 사용합니다.
class AppShell {
  AppShell._();

  /// 기본 AppBar를 생성합니다.
  ///
  /// [title] — AppBar 중앙 제목
  /// [actions] — 오른쪽 액션 버튼 목록
  /// [showBackButton] — 뒤로가기 버튼 표시 여부 (기본 true)
  /// [elevation] — 그림자 깊이 (기본 0)
  static AppBar appBar(
    BuildContext context, {
    required String title,
    List<Widget>? actions,
    bool showBackButton = true,
    double elevation = 0,
  }) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: elevation,
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: showBackButton && Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      actions: actions,
    );
  }

  /// 기본 Scaffold를 생성합니다.
  ///
  /// [body] — 본문 위젯
  /// [bottomNavigationBar] — 하단 네비게이션
  /// [floatingActionButton] — FAB
  static Scaffold scaffold({
    required Widget body,
    PreferredSizeWidget? appBar,
    Widget? bottomNavigationBar,
    Widget? floatingActionButton,
    Color? backgroundColor,
  }) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
