import 'package:flutter/material.dart';

class LearningToolsStrip extends StatelessWidget {
  const LearningToolsStrip({
    super.key,
    required this.onNotepad,
    required this.onTimer,
    required this.onFocusMode,
    required this.onChat,
  });

  final VoidCallback onNotepad;
  final VoidCallback onTimer;
  final VoidCallback onFocusMode;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ToolItem(
          icon: Icons.edit_note,
          label: '노트패드',
          description: '무한 스크롤 필기',
          onTap: onNotepad,
        ),
        _ToolItem(
          icon: Icons.timer,
          label: '타이머',
          description: '스톱워치/타이머',
          onTap: onTimer,
        ),
        _ToolItem(
          icon: Icons.self_improvement,
          label: '집중모드',
          description: '집중 화면 보호',
          onTap: onFocusMode,
        ),
        _ToolItem(
          icon: Icons.chat_bubble_outline,
          label: 'AI채팅',
          description: '준비 중',
          onTap: onChat,
        ),
      ],
    );
  }
}

class _ToolItem extends StatelessWidget {
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1B402B), size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
