import 'package:flutter/material.dart';

class SolveHeader extends StatelessWidget {
  const SolveHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onInfo,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onInfo;

  static const Color _kGreen = Color(0xFF1B402B);

  double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 1100;
    if (scale < min) return min;
    if (scale > max) return max;
    return scale;
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    return SizedBox(
      height: 72 * scale,
      child: Row(
        children: [
          SizedBox(width: 16 * scale),
          IconButton(
            iconSize: 28 * scale,
            icon: const Icon(Icons.arrow_back, color: _kGreen),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 36 * scale,
                  fontWeight: FontWeight.bold,
                  color: _kGreen,
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                iconSize: 28 * scale,
                icon: const Icon(Icons.info_outline, color: _kGreen),
                onPressed: onInfo ?? () {},
              ),
              SizedBox(width: 8 * scale),
            ],
          ),
        ],
      ),
    );
  }
}
