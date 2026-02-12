import 'package:flutter/material.dart';

class CampusMateLogo extends StatelessWidget {
  final double size;

  const CampusMateLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final bgBlue = const Color(0xFF2D7CFF);
    final capBlack = const Color(0xFF101216);
    final tassel = const Color(0xFFFFB532);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        color: bgBlue,
        boxShadow: [
          BoxShadow(
            color: bgBlue.withAlpha(80),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.school_rounded, size: size * 0.62, color: capBlack),
          Positioned(
            left: size * 0.68,
            top: size * 0.42,
            child: Container(
              width: size * 0.08,
              height: size * 0.24,
              decoration: BoxDecoration(
                color: tassel,
                borderRadius: BorderRadius.circular(size * 0.04),
              ),
            ),
          ),
          Positioned(
            left: size * 0.655,
            top: size * 0.66,
            child: Container(
              width: size * 0.13,
              height: size * 0.13,
              decoration: BoxDecoration(color: tassel, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}
