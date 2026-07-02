import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/shared/theme/app_colors.dart';

class HeaderBar extends StatelessWidget {
  final VoidCallback onSearchPressed;
  final VoidCallback onMenuPressed;

  const HeaderBar({
    super.key,
    required this.onSearchPressed,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 125,
      decoration: const BoxDecoration(color: AppColors.primary),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildIconButton(icon: Icons.search, onPressed: onSearchPressed),
          Text(
            'AIFlow',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 90,
              fontWeight: FontWeight.w600,
            ),
          ),
          _buildIconButton(icon: Icons.menu, onPressed: onMenuPressed),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      iconSize: 80,
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
    );
  }
}
