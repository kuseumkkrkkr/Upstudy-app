import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

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
          'AI 채팅 기능?� 준�?중입?�다.',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ),
    );
  }
}

