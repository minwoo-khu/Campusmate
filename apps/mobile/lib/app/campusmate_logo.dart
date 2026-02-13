import 'package:flutter/material.dart';

import 'theme.dart';

class CampusMateLogo extends StatelessWidget {
  final double size;

  const CampusMateLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.asset(
          'assets/images/campusmate_logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _LogoFallback(size: size),
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  final double size;

  const _LogoFallback({required this.size});

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        color: cm.navActive,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.school_rounded,
        size: size * 0.6,
        color: Color.lerp(cm.textPrimary, Colors.black, 0.55),
      ),
    );
  }
}
