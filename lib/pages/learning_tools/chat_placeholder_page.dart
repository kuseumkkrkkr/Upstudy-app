import 'package:flutter/material.dart';

class ChatPlaceholderPage extends StatelessWidget {
  const ChatPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('AI 채팅'),
        backgroundColor: const Color(0xFF1B402B),
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
