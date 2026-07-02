import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class GraphCard extends StatelessWidget {
  final String title;
  final String formula;
  final CustomPainter painter;
  final List<SliderDef> sliders;

  const GraphCard({
    super.key,
    required this.title,
    required this.formula,
    required this.painter,
    required this.sliders,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Math.tex(
                title,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                mathStyle: MathStyle.display,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Math.tex(
                formula,
                textStyle: const TextStyle(fontSize: 16),
                mathStyle: MathStyle.text,
              ),
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: painter,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            for (final s in sliders)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.label,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _fmt(s.value),
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: s.value,
                      min: s.min,
                      max: s.max,
                      divisions: s.divisions,
                      onChanged: s.onChanged,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class SliderDef {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const SliderDef({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
}

String _fmt(double v) {
  final s = v.toStringAsFixed(2);
  if (s.endsWith('.00')) return s.substring(0, s.length - 3);
  if (s.endsWith('0')) return s.substring(0, s.length - 1);
  return s;
}
