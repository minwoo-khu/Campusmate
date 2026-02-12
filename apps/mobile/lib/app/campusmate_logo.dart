import 'package:flutter/material.dart';

import 'theme.dart';

class CampusMateLogo extends StatelessWidget {
  final double size;

  const CampusMateLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    final bgColor = cm.navActive;
    final capColor = Color.lerp(cm.textPrimary, Colors.black, 0.55)!;
    final tasselColor = cm.priorityMedium;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: bgColor.withAlpha(80),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.school_rounded, size: size * 0.62, color: capColor),
          Positioned(
            left: size * 0.68,
            top: size * 0.42,
            child: Container(
              width: size * 0.08,
              height: size * 0.24,
              decoration: BoxDecoration(
                color: tasselColor,
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
              decoration: BoxDecoration(
                color: tasselColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
