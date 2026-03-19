part of 'package:s11/pages/exam_paper_page.dart';

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

class _ZoomIcon extends StatelessWidget {
  const _ZoomIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Icon(icon, size: 20, color: const Color(0xFF1B402B)),
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


