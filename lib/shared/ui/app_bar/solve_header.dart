import 'package:flutter/material.dart';
import 'package:s11/shared/utils/ui_scale.dart';
import 'package:s11/shared/theme/app_colors.dart';

class SolveHeader extends StatelessWidget {
  const SolveHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onInfo,
    this.infoIcon = Icons.share_outlined,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onInfo;
  final IconData infoIcon;

  static const Color _kGreen = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final scale = uiScale(context);
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
                icon: Icon(infoIcon, color: _kGreen),
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
