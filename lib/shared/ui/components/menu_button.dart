import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MenuButton extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;

  const MenuButton({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: imageUrl.isEmpty ? Colors.teal : Colors.grey[300],
          image: imageUrl.isNotEmpty
              ? DecorationImage(
                  fit: BoxFit.cover,
                  image: NetworkImage(imageUrl),
                )
              : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 100,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
