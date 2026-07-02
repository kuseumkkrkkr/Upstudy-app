import 'package:flutter/material.dart';

class LearningToolsStrip extends StatelessWidget {
  const LearningToolsStrip({
    super.key,
    required this.onNotepad,
    required this.onTimer,
    required this.onFocusMode,
    required this.onGraph,
  });

  final VoidCallback onNotepad;
  final VoidCallback onTimer;
  final VoidCallback onFocusMode;
  final VoidCallback onGraph;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ToolItem(
          icon: Icons.edit_note_rounded,
          label: '노트패드',
          onTap: onNotepad,
          accentColor: const Color(0xFF246B45),
        ),
        _ToolItem(
          icon: Icons.timer_rounded,
          label: '타이머',
          onTap: onTimer,
          accentColor: const Color(0xFF2D6CDF),
        ),
        _ToolItem(
          icon: Icons.center_focus_strong_rounded,
          label: '집중 모드',
          onTap: onFocusMode,
          accentColor: const Color(0xFFD07A23),
        ),
        _ToolItem(
          icon: Icons.stacked_line_chart_rounded,
          label: '그래프 그리기',
          onTap: onGraph,
          accentColor: const Color(0xFF7C3AED),
        ),
      ],
    );
  }
}

class _ToolItem extends StatelessWidget {
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final softColor = Color.lerp(accentColor, Colors.white, 0.88)!;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Column(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: softColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.13),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: accentColor, size: 27),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
