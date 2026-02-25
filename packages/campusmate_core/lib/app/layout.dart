import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double kDesktopLayoutBreakpoint = 1000;
const double kDesktopContentMaxWidth = 1240;

bool _isDesktopTargetPlatform(TargetPlatform platform) {
  return platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux;
}

bool isDesktopLayout(
  BuildContext context, {
  double minWidth = kDesktopLayoutBreakpoint,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final desktopLike = kIsWeb || _isDesktopTargetPlatform(defaultTargetPlatform);
  return desktopLike && width >= minWidth;
}

Widget responsiveContent(
  BuildContext context, {
  required Widget child,
  double maxWidth = kDesktopContentMaxWidth,
}) {
  if (!isDesktopLayout(context)) return child;
  return Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
