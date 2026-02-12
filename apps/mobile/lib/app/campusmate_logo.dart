import 'package:flutter/material.dart';

import 'theme.dart';

class CampusMateLogo extends StatelessWidget {
  final double size;

  const CampusMateLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cm.navActive, cm.priorityLow],
        ),
        boxShadow: [
          BoxShadow(
            color: cm.navActive.withAlpha(71),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'CM',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
    );
  }
}
