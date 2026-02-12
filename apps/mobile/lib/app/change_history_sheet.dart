import 'package:flutter/material.dart';

import 'change_history_service.dart';

Future<void> showChangeHistorySheet(BuildContext context) {
  final entries = ChangeHistoryService.recent(limit: 30);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) {
      if (entries.isEmpty) {
        return const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Text('No recent changes yet.'),
        );
      }

      String two(int x) => x.toString().padLeft(2, '0');
      String fmt(DateTime dt) =>
          '${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';

      return SizedBox(
        height: 420,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemBuilder: (_, i) {
            final e = entries[i];
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(e.action),
              subtitle: e.detail.isEmpty ? null : Text(e.detail),
              trailing: Text(
                fmt(e.at),
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: entries.length,
        ),
      );
    },
  );
}
