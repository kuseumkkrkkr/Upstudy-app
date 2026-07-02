part of 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: size * 0.8,
      child: Icon(icon, size: size, color: color),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _WidthChip extends StatelessWidget {
  const _WidthChip({
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 54,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B402B) : const Color(0xFFE9E9E9),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Container(
          width: width * 6,
          height: width * 6,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _PenSettings {
  const _PenSettings({required this.color, required this.width});

  final Color color;
  final double width;
}

class _GradingScreen extends StatelessWidget {
  const _GradingScreen();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 16),
              Text(
                '채점 중',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
