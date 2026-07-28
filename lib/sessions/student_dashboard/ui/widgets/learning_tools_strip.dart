import 'package:flutter/material.dart';

const _toolInk = Color(0xFF09090B);
const _toolLine = Color(0x2E09090B);

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
    final compact = MediaQuery.sizeOf(context).width <= 780;
    final portraitMobile =
        compact && MediaQuery.orientationOf(context) == Orientation.portrait;
    if (portraitMobile) {
      // 필요한 변수는 네 도구와 각 이동 콜백이다.
      // 작동 원리: 세로 화면에서는 작은 도형 네 개를 한 줄에 압축하지 않고,
      // 엄지로 누르기 쉬운 2열 카드에 큰 아이콘과 16px 라벨을 배치한다.
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.7,
        children: [
          _MobileToolCard(
            icon: Icons.edit_note_rounded,
            label: '노트패드',
            onTap: onNotepad,
            emphasized: true,
          ),
          _MobileToolCard(
            icon: Icons.timer_rounded,
            label: '타이머',
            onTap: onTimer,
          ),
          _MobileToolCard(
            icon: Icons.center_focus_strong_rounded,
            label: '집중 모드',
            onTap: onFocusMode,
          ),
          _MobileToolCard(
            icon: Icons.stacked_line_chart_rounded,
            label: '그래프',
            onTap: onGraph,
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ToolItem(
          icon: Icons.edit_note_rounded,
          label: '노트패드',
          onTap: onNotepad,
          shape: _ToolShape.note,
          compact: compact,
          portraitMobile: portraitMobile,
        ),
        _ToolItem(
          icon: Icons.timer_rounded,
          label: '타이머',
          onTap: onTimer,
          shape: _ToolShape.timer,
          compact: compact,
          portraitMobile: portraitMobile,
        ),
        _ToolItem(
          icon: Icons.center_focus_strong_rounded,
          label: '집중 모드',
          onTap: onFocusMode,
          shape: _ToolShape.focus,
          compact: compact,
          portraitMobile: portraitMobile,
        ),
        _ToolItem(
          icon: Icons.stacked_line_chart_rounded,
          label: '그래프 그리기',
          onTap: onGraph,
          shape: _ToolShape.graph,
          compact: compact,
          portraitMobile: portraitMobile,
        ),
      ],
    );
  }
}

class _MobileToolCard extends StatelessWidget {
  const _MobileToolCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  /// 필요한 변수는 도구 아이콘·라벨·강조 여부다.
  /// 작동 원리: 모바일 터치 기준을 만족하는 큰 라운드 카드 안에 아이콘과 기능명을 가로로 정렬한다.
  @override
  Widget build(BuildContext context) {
    final foreground = emphasized ? Colors.white : _toolInk;
    return Material(
      color: emphasized ? _toolInk : Colors.white,
      elevation: emphasized ? 0 : 1,
      shadowColor: const Color(0x14000000),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: emphasized
                      ? Colors.white.withValues(alpha: 0.14)
                      : const Color(0xFFF4F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: foreground, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
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

enum _ToolShape { note, timer, focus, graph }

class _ToolItem extends StatelessWidget {
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.shape,
    required this.compact,
    required this.portraitMobile,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _ToolShape shape;
  final bool compact;
  final bool portraitMobile;

  /// 필요한 변수는 도구 종류와 현재 화면 폭이다.
  /// 작동 원리: HTML의 사각 노트·원형 타이머·중첩 집중·회전 그래프 도형을 흑백으로 재현한다.
  @override
  Widget build(BuildContext context) {
    final size = portraitMobile
        ? 64.0
        : compact
        ? 52.0
        : 68.0;
    final isDark = shape == _ToolShape.note;
    final isCircle = shape == _ToolShape.timer;
    final isGraph = shape == _ToolShape.graph;
    final radius = isCircle
        ? size / 2
        : (shape == _ToolShape.focus ? 24.0 : 20.0);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Column(
              children: [
                Transform.rotate(
                  angle: isGraph ? 0.785398 : 0,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: isDark ? _toolInk : Colors.white,
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(color: _toolLine),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 22,
                          offset: Offset(0, 9),
                        ),
                      ],
                    ),
                    child: shape == _ToolShape.focus
                        ? Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: _toolInk, width: 8),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: const Center(
                              child: Icon(Icons.circle_outlined, size: 18),
                            ),
                          )
                        : Transform.rotate(
                            angle: isGraph ? -0.785398 : 0,
                            child: Icon(
                              icon,
                              color: isDark ? Colors.white : _toolInk,
                              size: compact ? 20 : 24,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: _toolInk,
                    fontSize: portraitMobile ? 14 : 11,
                    fontWeight: FontWeight.w800,
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
