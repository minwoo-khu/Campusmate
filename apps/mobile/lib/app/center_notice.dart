import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'theme.dart';

class CenterNotice {
  CenterNotice._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
    bool error = false,
  }) {
    if (!context.mounted || message.trim().isEmpty) return;

    _timer?.cancel();
    _removeEntry();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final cm = context.cmColors;
    final bgColor = error ? cm.deleteBg.withValues(alpha: 0.96) : cm.cardBg;
    final borderColor = error ? cm.deleteBg : cm.cardBorder;
    final textColor = error ? Colors.white : cm.textPrimary;

    _entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          ignoring: true,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: cm.navBarShadow,
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        error ? Icons.error_outline : Icons.info_outline,
                        size: 18,
                        color: textColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_entry!);
    _timer = Timer(duration, _removeEntry);
  }

  static Future<void> showActionDialog(
    BuildContext context, {
    String? title,
    required String message,
    required String actionLabel,
    required Future<void> Function() onAction,
    String? cancelLabel,
  }) async {
    if (!context.mounted) return;
    _timer?.cancel();
    _removeEntry();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: title == null ? null : Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(cancelLabel ?? dialogContext.tr('닫기', 'Close')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await onAction();
              },
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }

  static void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }
}
