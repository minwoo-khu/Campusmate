import 'dart:convert';

import 'package:hive/hive.dart';

class ChangeHistoryEntry {
  final DateTime at;
  final String action;
  final String detail;

  const ChangeHistoryEntry({
    required this.at,
    required this.action,
    required this.detail,
  });
}

class ChangeHistoryService {
  ChangeHistoryService._();

  static const boxName = 'change_history';
  static const _maxEntries = 80;

  static Box<String> get _box => Hive.box<String>(boxName);

  static Future<void> log(String action, {String detail = ''}) async {
    final payload = jsonEncode({
      'at': DateTime.now().toIso8601String(),
      'action': action,
      'detail': detail,
    });

    await _box.add(payload);

    while (_box.length > _maxEntries) {
      await _box.deleteAt(0);
    }
  }

  static List<ChangeHistoryEntry> recent({int limit = 20}) {
    final values = _box.values.toList();
    final out = <ChangeHistoryEntry>[];

    for (var i = values.length - 1; i >= 0; i--) {
      final raw = values[i];
      try {
        final parsed = jsonDecode(raw) as Map<String, dynamic>;
        out.add(
          ChangeHistoryEntry(
            at:
                DateTime.tryParse(parsed['at'] as String? ?? '') ??
                DateTime.now(),
            action: parsed['action'] as String? ?? 'Unknown action',
            detail: parsed['detail'] as String? ?? '',
          ),
        );
      } catch (_) {
        // Ignore malformed entries.
      }

      if (out.length >= limit) break;
    }

    return out;
  }
}
