import 'package:flutter/material.dart';

import 'package:s11/shared/theme/app_colors.dart';

/// 레거시 링크를 위한 안내 화면이다. 실제 학생 튜터는 ServerChatPage를 사용한다.
class ChatPlaceholderPage extends StatelessWidget {
  const ChatPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('AI 채팅'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'AI 채팅 기능은 준비 중입니다.',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ),
    );
  }
}
