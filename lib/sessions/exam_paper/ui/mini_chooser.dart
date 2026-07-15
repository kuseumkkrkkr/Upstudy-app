part of 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

class _MiniChooser extends StatelessWidget {
  const _MiniChooser({required this.children, this.height = 42});

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: SizedBox(
          height: height,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children:
                  children.expand((w) => [w, const SizedBox(width: 6)]).toList()
                    ..removeLast(),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChoice extends StatelessWidget {
  const _MiniChoice({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: child,
    );
  }
}
